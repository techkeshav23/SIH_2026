import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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

/// DPDP Act 2023 consent version. Bump when the privacy terms change to
/// re-prompt every user for fresh consent.
const String kConsentVersion = '2026-08-dpdp-v1';

/// Defensively coerce an API body into a list of row-maps. Tolerates a wrapped
/// `{items:[...]}` shape or an error object, and drops any non-map elements —
/// so one malformed row never crashes a whole list.
List<Map<String, dynamic>> _rows(dynamic d) {
  final list = d is List
      ? d
      : (d is Map && d['items'] is List ? d['items'] as List : const []);
  return list.whereType<Map<String, dynamic>>().toList();
}

final apiProvider = Provider<Api>((ref) => Api());

class Api {
  final Dio _dio;
  String? _token;
  String? _refreshToken;
  String? _role; // 'artisan' | 'buyer'
  bool demoMode = false; // offline demo — serves canned data, no backend needed
  bool consentGiven = false; // DPDP consent accepted for kConsentVersion

  /// Bumped whenever the session is force-invalidated (unrecoverable 401).
  /// The router listens to this to redirect back to /login.
  final ValueNotifier<int> authChanged = ValueNotifier(0);

  Api()
      : _dio = Dio(BaseOptions(
          baseUrl: kBaseUrl,
          // Without these a slow/unreachable backend leaves every screen stuck
          // on a spinner forever (looks like the app hung). Fail fast instead.
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30), // AI voice/image jobs
          sendTimeout: const Duration(seconds: 30),
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
      onError: (e, handler) async {
        final isAuthRoute = e.requestOptions.path.startsWith('/auth/') ||
            e.requestOptions.path.startsWith('/buyer/auth/');
        if (e.response?.statusCode == 401 && !isAuthRoute && !demoMode) {
          // One-shot refresh, then replay the original request.
          if (_refreshToken != null && e.requestOptions.extra['retried'] != true) {
            if (await _refreshAccess()) {
              final opts = e.requestOptions..extra['retried'] = true;
              opts.headers['Authorization'] = 'Bearer $_token';
              try {
                return handler.resolve(await _dio.fetch(opts));
              } catch (_) {/* fall through to hard logout */}
            }
          }
          // Unrecoverable: drop the session and signal the router to show login.
          await logout();
          authChanged.value++;
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
    consentGiven = prefs.getString('consent_version') == kConsentVersion;
  }

  /// Record DPDP consent locally (and on the server in real mode).
  Future<void> recordConsent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('consent_version', kConsentVersion);
    consentGiven = true;
    if (!demoMode) {
      try {
        await _dio.post('/consent', data: {'version': kConsentVersion});
      } catch (_) {/* stored locally regardless; retried on next app open */}
    }
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
    // Keep consent: it's device + terms-version scoped (see kConsentVersion),
    // not per-account — wiping it forced the DPDP gate on every re-login.
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
      final rows = _rows(r.data);
      await LocalStore.cacheProducts(rows);
      return rows.map(Product.fromJson).toList();
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

  /// Soft-delete (archive) a product so it leaves listings.
  Future<void> deleteProduct(String id) async {
    if (demoMode) {
      Demo.deleteProduct(id);
      return;
    }
    await _dio.delete('/products/$id');
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

  /// Upload a recorded WAV clip; backend runs Vertex multimodal (speech->listing)
  /// as a durable job. Caller polls the product until it leaves `processing`.
  Future<void> catalogFromVoice(String productId, String filePath,
      {String sourceLang = 'hi'}) async {
    final form = FormData.fromMap({
      'product_id': productId,
      'source_lang': sourceLang,
      'file': await MultipartFile.fromFile(
        filePath,
        filename: 'voice.wav',
        contentType: DioMediaType('audio', 'wav'),
      ),
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
    return _rows(r.data).map(Product.fromJson).toList();
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
      return _rows(r.data).map(Review.fromJson).toList();
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
      return _rows(r.data).map(AppNotification.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  Future<int> unreadNotifications() async {
    if (demoMode) return Demo.unreadCount();
    try {
      final r = await _dio.get('/notifications');
      return _rows(r.data).where((n) => n['read'] != true).length;
    } catch (_) {
      return 0;
    }
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
    return _rows(r.data).map(Order.fromJson).toList();
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
  Future<Order> placeOrder(String productId, int quantity,
      {String? note, String? addressId}) async {
    if (demoMode) return Order.fromJson(Demo.placeOrder(productId, quantity));
    final r = await _dio.post('/orders', data: {
      'product_id': productId,
      'quantity': quantity,
      'note': note,
      'address_id': addressId,
    });
    return Order.fromJson(r.data);
  }

  // ---- delivery addresses (buyer) ----
  Future<List<Address>> listAddresses() async {
    if (demoMode) return Demo.addresses.map((e) => Address.fromJson(e)).toList();
    final r = await _dio.get('/orders/addresses');
    return _rows(r.data).map(Address.fromJson).toList();
  }

  Future<Address> addAddress(Map<String, dynamic> body) async {
    if (demoMode) return Address.fromJson(Demo.addAddress(body));
    final r = await _dio.post('/orders/addresses', data: body);
    return Address.fromJson(r.data);
  }

  Future<void> deleteAddress(String id) async {
    if (demoMode) {
      Demo.deleteAddress(id);
      return;
    }
    await _dio.delete('/orders/addresses/$id');
  }

  // ---- B2B quotes / negotiation (RFQ) ----
  Future<Quote> createQuote(String productId, int quantity, double targetPrice, {String? message}) async {
    if (demoMode) return Quote.fromJson(Demo.createQuote(productId, quantity, targetPrice, message));
    final r = await _dio.post('/quotes', data: {
      'product_id': productId, 'quantity': quantity, 'target_price': targetPrice, 'message': message,
    });
    return Quote.fromJson(r.data);
  }

  Future<List<Quote>> myQuotes() async {
    if (demoMode) return Demo.quotes.map((e) => Quote.fromJson(e)).toList();
    final r = await _dio.get('/quotes');
    return _rows(r.data).map(Quote.fromJson).toList();
  }

  Future<List<Quote>> incomingQuotes() async {
    if (demoMode) return Demo.quotes.map((e) => Quote.fromJson(e)).toList();
    final r = await _dio.get('/quotes/incoming');
    return _rows(r.data).map(Quote.fromJson).toList();
  }

  Future<Quote> counterQuote(String id, double price) async {
    if (demoMode) return Quote.fromJson(Demo.quoteAction(id, 'counter', price: price, byBuyer: isBuyer));
    final r = await _dio.post('/quotes/$id/counter', data: {'price': price});
    return Quote.fromJson(r.data);
  }

  Future<Quote> acceptQuote(String id) async {
    if (demoMode) return Quote.fromJson(Demo.quoteAction(id, 'accept', byBuyer: isBuyer));
    final r = await _dio.post('/quotes/$id/accept');
    return Quote.fromJson(r.data);
  }

  Future<Quote> declineQuote(String id) async {
    if (demoMode) return Quote.fromJson(Demo.quoteAction(id, 'decline', byBuyer: isBuyer));
    final r = await _dio.post('/quotes/$id/decline');
    return Quote.fromJson(r.data);
  }

  // ---- artisan storefront (public) ----
  Future<Storefront> getStorefront(String artisanId) async {
    if (demoMode) return Storefront.fromJson(Demo.storefront());
    final r = await _dio.get('/buyers/storefront/$artisanId');
    return Storefront.fromJson(r.data);
  }

  Future<List<Order>> myOrders() async {
    if (demoMode) return Demo.buyerOrders().map((e) => Order.fromJson(e)).toList();
    final r = await _dio.get('/orders');
    return _rows(r.data).map(Order.fromJson).toList();
  }

  // ---- fulfilment ----
  /// Artisan dispatches a paid order.
  Future<Order> shipOrder(String id) async {
    if (demoMode) return Order.fromJson(Demo.setOrderStatus(id, 'shipped'));
    final r = await _dio.post('/orders/$id/ship');
    return Order.fromJson(r.data);
  }

  /// Buyer confirms receipt -> completed.
  Future<Order> confirmDelivery(String id) async {
    if (demoMode) return Order.fromJson(Demo.setOrderStatus(id, 'completed'));
    final r = await _dio.post('/orders/$id/confirm-delivery');
    return Order.fromJson(r.data);
  }

  /// Buyer cancels an unpaid order.
  Future<Order> cancelOrder(String id) async {
    if (demoMode) return Order.fromJson(Demo.setOrderStatus(id, 'cancelled'));
    final r = await _dio.post('/orders/$id/cancel');
    return Order.fromJson(r.data);
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
