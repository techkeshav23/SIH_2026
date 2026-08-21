import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight offline layer (SharedPreferences):
///  - caches the last product list so Home works without internet
///  - queues "pending drafts" created offline, flushed on next sync
class LocalStore {
  static const _kProducts = 'cached_products';
  static const _kPending = 'pending_drafts';

  // ---- product list cache ----
  static Future<void> cacheProducts(List<dynamic> rawList) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kProducts, jsonEncode(rawList));
  }

  static Future<List<dynamic>> cachedProducts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kProducts);
    if (raw == null) return [];
    return jsonDecode(raw) as List<dynamic>;
  }

  // ---- pending offline drafts ----
  static Future<void> addPendingDraft(PendingDraft d) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await pendingDrafts();
    list.add(d);
    await prefs.setString(_kPending, jsonEncode(list.map((e) => e.toJson()).toList()));
  }

  static Future<List<PendingDraft>> pendingDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPending);
    if (raw == null) return [];
    return (jsonDecode(raw) as List).map((e) => PendingDraft.fromJson(e)).toList();
  }

  static Future<void> clearPendingDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPending);
  }
}

class PendingDraft {
  final String category;
  final String material;
  final String text;
  final String lang;

  PendingDraft({
    required this.category,
    required this.material,
    required this.text,
    required this.lang,
  });

  Map<String, dynamic> toJson() =>
      {'category': category, 'material': material, 'text': text, 'lang': lang};

  factory PendingDraft.fromJson(Map<String, dynamic> j) => PendingDraft(
        category: j['category'] ?? '',
        material: j['material'] ?? '',
        text: j['text'] ?? '',
        lang: j['lang'] ?? 'hi',
      );
}
