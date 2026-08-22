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

class Order {
  final String id;
  final String productId;
  final String? productTitle;
  final String? productImage;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String status; // pending|accepted|rejected|paid|shipped|completed|cancelled
  final String? note;

  Order({
    required this.id,
    required this.productId,
    this.productTitle,
    this.productImage,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.status,
    this.note,
  });

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'],
        productId: j['product_id'],
        productTitle: j['product_title'],
        productImage: j['product_image'],
        quantity: j['quantity'] ?? 1,
        unitPrice: (j['unit_price'] as num).toDouble(),
        totalPrice: (j['total_price'] as num).toDouble(),
        status: j['status'] ?? 'pending',
        note: j['note'],
      );

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
}

class Review {
  final String id;
  final String productId;
  final String author;
  final int rating; // 1..5
  final String text;
  final String? date;

  Review({required this.id, required this.productId, required this.author,
      required this.rating, required this.text, this.date});

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'],
        productId: j['product_id'] ?? '',
        author: j['author'] ?? 'Buyer',
        rating: (j['rating'] as num?)?.toInt() ?? 5,
        text: j['text'] ?? '',
        date: j['date'],
      );
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // order|payment|inquiry|system
  final bool read;
  final String? time;

  AppNotification({required this.id, required this.title, required this.body,
      required this.type, this.read = false, this.time});

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'],
        title: j['title'] ?? '',
        body: j['body'] ?? '',
        type: j['type'] ?? 'system',
        read: j['read'] ?? false,
        time: j['time'],
      );
}

class ArtisanStats {
  final int products;
  final int listed;
  final int ordersTotal;
  final int ordersPending;
  final int ordersPaid;
  final double earnings;

  ArtisanStats({
    required this.products,
    required this.listed,
    required this.ordersTotal,
    required this.ordersPending,
    required this.ordersPaid,
    required this.earnings,
  });

  factory ArtisanStats.fromJson(Map<String, dynamic> j) => ArtisanStats(
        products: j['products'] ?? 0,
        listed: j['listed'] ?? 0,
        ordersTotal: j['orders_total'] ?? 0,
        ordersPending: j['orders_pending'] ?? 0,
        ordersPaid: j['orders_paid'] ?? 0,
        earnings: (j['earnings'] as num?)?.toDouble() ?? 0,
      );
}
