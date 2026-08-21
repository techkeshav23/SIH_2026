import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// Change to your machine's LAN IP when testing on a real device,
/// e.g. http://192.168.1.5:8000. Android emulator uses 10.0.2.2.
const String kBaseUrl = 'http://10.0.2.2:8000';

final apiProvider = Provider<Api>((ref) => Api());

class Api {
  final Dio _dio;
  String? _token;

  Api() : _dio = Dio(BaseOptions(baseUrl: kBaseUrl)) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_token != null) {
          options.headers['Authorization'] = 'Bearer $_token';
        }
        handler.next(options);
      },
    ));
  }

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
  }

  Future<void> _saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  bool get isLoggedIn => _token != null;

  // ---- auth ----
  Future<String?> requestOtp(String phone) async {
    final r = await _dio.post('/auth/request-otp', data: {'phone': phone});
    return r.data['dev_otp']; // dev convenience
  }

  Future<UserModel> verifyOtp(String phone, String otp) async {
    final r = await _dio.post('/auth/verify-otp', data: {'phone': phone, 'otp': otp});
    await _saveToken(r.data['access_token']);
    return UserModel.fromJson(r.data['user']);
  }

  // ---- products ----
  Future<List<Product>> listProducts() async {
    final r = await _dio.get('/products');
    return (r.data as List).map((e) => Product.fromJson(e)).toList();
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
