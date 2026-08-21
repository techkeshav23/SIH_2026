import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'local_store.dart';
import 'models.dart';

/// Change to your machine's LAN IP when testing on a real device,
/// e.g. http://192.168.1.5:8000. Android emulator uses 10.0.2.2.
const String kBaseUrl = 'http://10.0.2.2:8000';

final apiProvider = Provider<Api>((ref) => Api());

class Api {
  final Dio _dio;
  String? _token;
  String? _refreshToken;
  String? _role; // 'artisan' | 'buyer'

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
  }

  Future<void> _saveTokens(String access, String refresh, String role) async {
    _token = access;
    _refreshToken = refresh;
    _role = role;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', access);
    await prefs.setString('refresh_token', refresh);
    await prefs.setString('role', role);
  }

  Future<void> logout() async {
    _token = _refreshToken = _role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('refresh_token');
    await prefs.remove('role');
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

  // ---- products ----
  /// Online: fetch + cache. Offline: return cached list (best-effort).
  Future<List<Product>> listProducts() async {
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
    final r = await _dio.post('/products',
        data: {'category': category, 'material': material});
    return Product.fromJson(r.data);
  }

  Future<Product> getProduct(String id) async {
    final r = await _dio.get('/products/$id');
    return Product.fromJson(r.data);
  }

  Future<Product> updateProduct(String id, Map<String, dynamic> patch) async {
    final r = await _dio.patch('/products/$id', data: patch);
    return Product.fromJson(r.data);
  }

  // ---- AI ----
  Future<void> enhanceImage(String productId, String filePath) async {
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
    final r = await _dio.post('/ai/catalog-from-text',
        data: {'product_id': productId, 'text': text, 'source_lang': sourceLang});
    return Product.fromJson(r.data);
  }

  // ---- pricing ----
  Future<PriceSuggestion> suggestPrice(String productId, {double? materialCost}) async {
    final r = await _dio.post('/pricing/suggest',
        data: {'product_id': productId, 'material_cost': materialCost});
    return PriceSuggestion.fromJson(r.data);
  }

  // ---- buyers / marketplace ----
  Future<List<Product>> buyerFeed({String? category}) async {
    final r = await _dio.get('/buyers/feed',
        queryParameters: {'category': ?category});
    return (r.data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<void> sendInquiry(String productId, String orgName, String message) async {
    await _dio.post('/buyers/inquiries',
        data: {'product_id': productId, 'org_name': orgName, 'message': message});
  }

  // ---- dashboard (artisan) ----
  Future<ArtisanStats> artisanStats() async {
    final r = await _dio.get('/dashboard/artisan');
    return ArtisanStats.fromJson(r.data);
  }

  // ---- orders (artisan side) ----
  Future<List<Order>> incomingOrders() async {
    final r = await _dio.get('/orders/incoming');
    return (r.data as List).map((e) => Order.fromJson(e)).toList();
  }

  Future<Order> acceptOrder(String id) async {
    final r = await _dio.post('/orders/$id/accept');
    return Order.fromJson(r.data);
  }

  Future<Order> rejectOrder(String id) async {
    final r = await _dio.post('/orders/$id/reject');
    return Order.fromJson(r.data);
  }

  // ---- orders (buyer side) ----
  Future<Order> placeOrder(String productId, int quantity, {String? note}) async {
    final r = await _dio.post('/orders',
        data: {'product_id': productId, 'quantity': quantity, 'note': note});
    return Order.fromJson(r.data);
  }

  Future<List<Order>> myOrders() async {
    final r = await _dio.get('/orders');
    return (r.data as List).map((e) => Order.fromJson(e)).toList();
  }

  /// Pay (mock gateway) then confirm — returns the paid order.
  Future<Order> payAndConfirm(String orderId) async {
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

  String mediaUrl(String path) => path.startsWith('http') ? path : '$kBaseUrl$path';
}
