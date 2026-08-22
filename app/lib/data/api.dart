import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo.dart';
import 'local_store.dart';
import 'models.dart';

/// Backend base URL. Override at build time for a real device / deployment:
///   flutter build apk --dart-define=BASE_URL=http://192.168.1.5:8000
/// Android emulator uses 10.0.2.2 (host loopback) by default.
const String kBaseUrl =
    String.fromEnvironment('BASE_URL', defaultValue: 'http://10.0.2.2:8000');

final apiProvider = Provider<Api>((ref) => Api());

class Api {
  final Dio _dio;
  String? _token;
  String? _refreshToken;
  String? _role; // 'artisan' | 'buyer'
  bool demoMode = false; // offline demo — serves canned data, no backend needed

  Api() : _dio = Dio(BaseOptions(baseUrl: kBaseUrl)) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        // On a 401, try a one-shot refresh then replay the original request.
        final isAuthRoute = e.requestOptions.path.startsWith('/auth/');
        if (e.response?.statusCode == 401 &&
            _refreshToken != null &&
            !isAuthRoute &&
            e.requestOptions.extra['retried'] != true) {
          if (await _refreshAccess()) {
            final opts = e.requestOptions..extra['retried'] = true;
            opts.headers['Authorization'] = 'Bearer $_token';
            try {
              return handler.resolve(await _dio.fetch(opts));
            } catch (_) {/* fall through */}
          }
        }
        handler.next(e);
      },
    ));
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    _refreshToken = prefs.getString('refresh_token');
    _role = prefs.getString('role');
    demoMode = prefs.getBool('demo') ?? false;
  }

  /// Enter offline demo mode as [role] ('artisan' | 'buyer') — no backend needed.
  Future<void> enterDemo(String role) async {
    demoMode = true;
    _token = 'demo';
    _refreshToken = null;
    _role = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', 'demo');
    await prefs.setString('role', role);
    await prefs.setBool('demo', true);
  }

  Future<void> _saveTokens(String access, String refresh, String role) async {
    _token = access;
    _refreshToken = refresh;
    _role = role;
    demoMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', access);
    await prefs.setString('refresh_token', refresh);
    await prefs.setString('role', role);
    await prefs.setBool('demo', false);
  }

  Future<void> logout() async {
    _token = _refreshToken = _role = null;
    demoMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refresh_token');
    await prefs.remove('role');
    await prefs.remove('demo');
  }

  Future<bool> _refreshAccess() async {
    try {
      final path = _role == 'buyer' ? '/buyer/auth/refresh' : '/auth/refresh';
      final r = await _dio.post(path, data: {'refresh_token': _refreshToken});
      _token = r.data['access_token'];
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      return true;
    } catch (_) {
      return false;
    }
  }

  bool get isLoggedIn => _token != null;
  String? get role => _role;
  bool get isBuyer => _role == 'buyer';

  bool _isOffline(Object e) =>
      e is DioException &&
      (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.unknown);

  // ---- auth ----
  Future<String?> requestOtp(String phone) async {
    final r = await _dio.post('/auth/request-otp', data: {'phone': phone});
    return r.data['dev_otp']; // dev convenience
  }

  Future<UserModel> verifyOtp(String phone, String otp) async {
    final r = await _dio.post('/auth/verify-otp', data: {'phone': phone, 'otp': otp});
    await _saveTokens(r.data['access_token'], r.data['refresh_token'], 'artisan');
    return UserModel.fromJson(r.data['user']);
  }

  // ---- buyer auth ----
  Future<String?> buyerRequestOtp(String phone) async {
    final r = await _dio.post('/buyer/auth/request-otp', data: {'phone': phone});
    return r.data['dev_otp'];
  }

  Future<void> buyerVerifyOtp(String phone, String otp) async {
    final r = await _dio.post('/buyer/auth/verify-otp', data: {'phone': phone, 'otp': otp});
    await _saveTokens(r.data['access_token'], r.data['refresh_token'], 'buyer');
  }

  // ---- profile (artisan) ----
  Future<UserModel> getMe() async {
    if (demoMode) return UserModel.fromJson(Demo.profile);
    final r = await _dio.get('/me');
    return UserModel.fromJson(r.data);
  }

  Future<UserModel> updateMe(Map<String, dynamic> patch) async {
    if (demoMode) return UserModel.fromJson(Demo.updateProfile(patch));
    final r = await _dio.patch('/me', data: patch);
    return UserModel.fromJson(r.data);
  }

  // ---- products ----
  /// Online: fetch + cache. Offline: return cached list (best-effort).
  Future<List<Product>> listProducts() async {
    if (demoMode) return Demo.products.map((e) => Product.fromJson(e)).toList();
    try {
      final r = await _dio.get('/products');
      await LocalStore.cacheProducts(r.data as List);
      return (r.data as List).map((e) => Product.fromJson(e)).toList();
    } catch (e) {
      if (_isOffline(e)) {
        final cached = await LocalStore.cachedProducts();
        return cached.map((e) => Product.fromJson(e)).toList();
      }
      rethrow;
    }
  }

  Future<Product> createProduct({String? category, String? material}) async {
    if (demoMode) return Product.fromJson(Demo.newProduct(category, material));
    final r = await _dio.post('/products',
        data: {'category': category, 'material': material});
    return Product.fromJson(r.data);
  }

  Future<Product> getProduct(String id) async {
    if (demoMode) return Product.fromJson(Demo.byId(id) ?? Demo.products.first);
    final r = await _dio.get('/products/$id');
    return Product.fromJson(r.data);
  }

  Future<Product> updateProduct(String id, Map<String, dynamic> patch) async {
    if (demoMode) return Product.fromJson(Demo.update(id, patch));
    final r = await _dio.patch('/products/$id', data: patch);
    return Product.fromJson(r.data);
  }

  // ---- AI ----
  Future<void> enhanceImage(String productId, String filePath) async {
    if (demoMode) {
      Demo.enhance(productId);
      return;
    }
    final form = FormData.fromMap({
      'product_id': productId,
      'file': await MultipartFile.fromFile(filePath),
    });
    await _dio.post('/ai/enhance-image', data: form);
  }

  Future<void> catalogFromVoice(String productId, String filePath,
      {String sourceLang = 'hi'}) async {
    final form = FormData.fromMap({
      'product_id': productId,
      'source_lang': sourceLang,
      'file': await MultipartFile.fromFile(filePath),
    });
    await _dio.post('/ai/catalog-from-voice', data: form);
  }

  Future<Product> catalogFromText(String productId, String text,
      {String sourceLang = 'hi'}) async {
    if (demoMode) return Product.fromJson(Demo.catalog(productId, text));
    final r = await _dio.post('/ai/catalog-from-text',
        data: {'product_id': productId, 'text': text, 'source_lang': sourceLang});
    return Product.fromJson(r.data);
  }

  // ---- pricing ----
  Future<PriceSuggestion> suggestPrice(String productId, {double? materialCost}) async {
    if (demoMode) return PriceSuggestion.fromJson(Demo.price(productId));
    final r = await _dio.post('/pricing/suggest',
        data: {'product_id': productId, 'material_cost': materialCost});
    return PriceSuggestion.fromJson(r.data);
  }

  // ---- buyers / marketplace ----
  Future<List<Product>> buyerFeed({String? category}) async {
    if (demoMode) {
      return (Demo.listed()['items'] as List).map((e) => Product.fromJson(e)).toList();
    }
    final r = await _dio.get('/buyers/feed',
        queryParameters: {'category': ?category});
    return (r.data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<void> sendInquiry(String productId, String orgName, String message) async {
    if (demoMode) return;
    await _dio.post('/buyers/inquiries',
        data: {'product_id': productId, 'org_name': orgName, 'message': message});
  }

  // ---- reviews ----
  Future<List<Review>> getReviews(String productId) async {
    if (demoMode) return Demo.reviewsFor(productId).map((e) => Review.fromJson(e)).toList();
    try {
      final r = await _dio.get('/products/$productId/reviews');
      return (r.data as List).map((e) => Review.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> addReview(String productId, int rating, String text) async {
    if (demoMode) {
      Demo.addReview(productId, rating, text);
      return;
    }
    try {
      await _dio.post('/products/$productId/reviews', data: {'rating': rating, 'text': text});
    } catch (_) {}
  }

  // ---- notifications ----
  Future<List<AppNotification>> getNotifications() async {
    if (demoMode) return Demo.notifications.map((e) => AppNotification.fromJson(e)).toList();
    try {
      final r = await _dio.get('/notifications');
      return (r.data as List).map((e) => AppNotification.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> unreadNotifications() async {
    if (demoMode) return Demo.unreadCount();
    return 0;
  }

  Future<void> markNotificationsRead() async {
    if (demoMode) {
      Demo.markAllRead();
      return;
    }
    try {
      await _dio.post('/notifications/read');
    } catch (_) {}
  }

  // ---- dashboard (artisan) ----
  Future<ArtisanStats> artisanStats() async {
    if (demoMode) return ArtisanStats.fromJson(Demo.stats());
    final r = await _dio.get('/dashboard/artisan');
    return ArtisanStats.fromJson(r.data);
  }

  // ---- orders (artisan side) ----
  Future<List<Order>> incomingOrders() async {
    if (demoMode) return Demo.orders.map((e) => Order.fromJson(e)).toList();
    final r = await _dio.get('/orders/incoming');
    return (r.data as List).map((e) => Order.fromJson(e)).toList();
  }

  Future<Order> acceptOrder(String id) async {
    if (demoMode) return Order.fromJson(Demo.setOrderStatus(id, 'accepted'));
    final r = await _dio.post('/orders/$id/accept');
    return Order.fromJson(r.data);
  }

  Future<Order> rejectOrder(String id) async {
    if (demoMode) return Order.fromJson(Demo.setOrderStatus(id, 'rejected'));
    final r = await _dio.post('/orders/$id/reject');
    return Order.fromJson(r.data);
  }

  // ---- orders (buyer side) ----
  Future<Order> placeOrder(String productId, int quantity, {String? note}) async {
    if (demoMode) return Order.fromJson(Demo.placeOrder(productId, quantity));
    final r = await _dio.post('/orders',
        data: {'product_id': productId, 'quantity': quantity, 'note': note});
    return Order.fromJson(r.data);
  }

  Future<List<Order>> myOrders() async {
    if (demoMode) return Demo.buyerOrders().map((e) => Order.fromJson(e)).toList();
    final r = await _dio.get('/orders');
    return (r.data as List).map((e) => Order.fromJson(e)).toList();
  }

  /// Pay (mock gateway) then confirm — returns the paid order.
  Future<Order> payAndConfirm(String orderId) async {
    if (demoMode) return Order.fromJson(Demo.setOrderStatus(orderId, 'paid'));
    final checkout = await _dio.post('/orders/$orderId/pay');
    final paymentId = checkout.data['provider_order_id'];
    final r = await _dio.post('/orders/$orderId/confirm-payment',
        data: {'provider_payment_id': paymentId});
    return Order.fromJson(r.data);
  }

  // ---- offline draft sync ----
  /// Flush locally-queued drafts to the server (create + generate listing).
  /// Returns number synced.
  Future<int> syncPendingDrafts() async {
    final pending = await LocalStore.pendingDrafts();
    if (pending.isEmpty) return 0;
    var synced = 0;
    for (final d in pending) {
      try {
        final p = await createProduct(category: d.category, material: d.material);
        await catalogFromText(p.id, d.text, sourceLang: d.lang);
        synced++;
      } catch (_) {
        // stop on first failure (likely still offline); keep remaining queued
        break;
      }
    }
    if (synced == pending.length) {
      await LocalStore.clearPendingDrafts();
    }
    return synced;
  }

  /// Poll a product until it leaves the `processing` state (max ~30s).
  Future<Product> pollUntilReady(String id) async {
    for (var i = 0; i < 30; i++) {
      final p = await getProduct(id);
      if (!p.isProcessing) return p;
      await Future.delayed(const Duration(seconds: 1));
    }
    return getProduct(id);
  }

  String mediaUrl(String path) =>
      (path.startsWith('http') || path.startsWith('asset:')) ? path : '$kBaseUrl$path';
}
