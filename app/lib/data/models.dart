// Data models mirroring docs/openapi.yaml.

class UserModel {
  final String id;
  final String phone;
  final String? name;
  final String languagePref;
  final String? craftType;
  final String? region;

  UserModel({
    required this.id,
    required this.phone,
    this.name,
    this.languagePref = 'hi',
    this.craftType,
    this.region,
  });

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'],
        phone: j['phone'],
        name: j['name'],
        languagePref: j['language_pref'] ?? 'hi',
        craftType: j['craft_type'],
        region: j['region'],
      );
}

class Product {
  final String id;
  final String userId;
  final String? titleEn;
  final String? titleHi;
  final String? descEn;
  final String? descHi;
  final String? category;
  final String? material;
  final List<String> tags;
  final String status; // draft|processing|ready|listed
  final String? rawImageUrl;
  final String? enhancedImageUrl;
  final double? suggestedPriceMin;
  final double? suggestedPriceMax;
  final double? finalPrice;

  Product({
    required this.id,
    required this.userId,
    this.titleEn,
    this.titleHi,
    this.descEn,
    this.descHi,
    this.category,
    this.material,
    this.tags = const [],
    this.status = 'draft',
    this.rawImageUrl,
    this.enhancedImageUrl,
    this.suggestedPriceMin,
    this.suggestedPriceMax,
    this.finalPrice,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'],
        userId: j['user_id'],
        titleEn: j['title_en'],
        titleHi: j['title_hi'],
        descEn: j['desc_en'],
        descHi: j['desc_hi'],
        category: j['category'],
        material: j['material'],
        tags: (j['tags'] as List?)?.map((e) => e.toString()).toList() ?? const [],
        status: j['status'] ?? 'draft',
        rawImageUrl: j['raw_image_url'],
        enhancedImageUrl: j['enhanced_image_url'],
        suggestedPriceMin: (j['suggested_price_min'] as num?)?.toDouble(),
        suggestedPriceMax: (j['suggested_price_max'] as num?)?.toDouble(),
        finalPrice: (j['final_price'] as num?)?.toDouble(),
      );

  bool get isProcessing => status == 'processing';
}

class PriceSuggestion {
  final double min;
  final double max;
  final String reasoning;
  final List<Comparable> comparables;

  PriceSuggestion({
    required this.min,
    required this.max,
    required this.reasoning,
    this.comparables = const [],
  });

  factory PriceSuggestion.fromJson(Map<String, dynamic> j) => PriceSuggestion(
        min: (j['suggested_price_min'] as num).toDouble(),
        max: (j['suggested_price_max'] as num).toDouble(),
        reasoning: j['reasoning'] ?? '',
        comparables: (j['comparables'] as List?)
                ?.map((e) => Comparable.fromJson(e))
                .toList() ??
            const [],
      );
}

class Comparable {
  final String title;
  final double price;
  final String source;
  Comparable({required this.title, required this.price, required this.source});
  factory Comparable.fromJson(Map<String, dynamic> j) => Comparable(
        title: j['title'],
        price: (j['price'] as num).toDouble(),
        source: j['source'] ?? '',
      );
}
