/// In-memory demo dataset so the whole app is fully usable WITHOUT a backend.
/// Enabled via Api.enterDemo() from the login screen ("Continue in demo mode").
/// Data is mutable so the demo flow reflects create/order/accept/pay actions.
class Demo {
  static const _iso = '2026-08-20T10:00:00Z';
  static const demoImage = 'asset:assets/icon/logo.png';

  static final List<Map<String, dynamic>> products = [
    _p('d1', 'Banarasi Silk Saree', 'बनारसी सिल्क साड़ी', 'saree', 'silk',
        ['handmade', 'banarasi', 'silk'], 'listed', 2400, 3000, 2800),
    _p('d2', 'Blue Pottery Vase', 'ब्लू पॉटरी फूलदान', 'pottery', 'clay',
        ['handmade', 'jaipur', 'pottery'], 'listed', 450, 650, 550),
    _p('d3', 'Pashmina Shawl', 'पश्मीना शॉल', 'shawl', 'pashmina',
        ['handmade', 'kashmir', 'wool'], 'ready', 4200, 5200, null),
    _p('d4', 'Pattachitra Painting', 'पट्टचित्र पेंटिंग', 'painting', 'canvas',
        ['handmade', 'odisha', 'art'], 'listed', 1800, 2600, 2200),
  ];

  static final List<Map<String, dynamic>> orders = [
    _o('o1', 'd1', 2, 2800, 'pending'),
    _o('o2', 'd2', 5, 550, 'accepted'),
    _o('o3', 'd4', 1, 2200, 'paid'),
  ];

  static Map<String, dynamic> stats() {
    final paid = orders.where((o) => o['status'] == 'paid').toList();
    return {
      'products': products.length,
      'listed': products.where((p) => p['status'] == 'listed').length,
      'orders_total': orders.length,
      'orders_pending': orders.where((o) => o['status'] == 'pending').length,
      'orders_paid': paid.length,
      'earnings': paid.fold<num>(0, (s, o) => s + (o['total_price'] as num)),
    };
  }

  static Map<String, dynamic> listed() =>
      {'items': products.where((p) => p['status'] == 'listed').toList()};

  static Map<String, dynamic> newProduct(String? category, String? material) {
    final p = _p('d${products.length + 1}', 'New Handmade Product', 'नया हस्तनिर्मित उत्पाद',
        category ?? 'handicraft', material ?? 'mixed', ['handmade'], 'draft', 0, 0, null);
    products.insert(0, p);
    return p;
  }

  static Map<String, dynamic>? byId(String id) {
    for (final p in products) {
      if (p['id'] == id) return p;
    }
    return null;
  }

  static Map<String, dynamic> catalog(String id, String text) {
    final p = byId(id) ?? products.first;
    p['title_en'] = 'Handcrafted ${p['material']} ${p['category']} — Artisan Made';
    p['title_hi'] = 'हस्तनिर्मित ${p['material']} ${p['category']} — कारीगर द्वारा';
    p['desc_en'] = 'Authentic handcrafted piece. $text Naturally dyed, durable, unique — perfect for gifting.';
    p['desc_hi'] = 'प्रामाणिक हस्तनिर्मित वस्तु। प्राकृतिक रंगों से रंगी, टिकाऊ और अद्वितीय।';
    p['tags'] = ['handmade', p['material'], 'artisan', 'made-in-india'];
    p['status'] = 'ready';
    return p;
  }

  static Map<String, dynamic> price(String id) {
    final p = byId(id) ?? products.first;
    final base = 800 + (p['id'].hashCode % 2000).abs();
    final lo = (base * 0.9).roundToDouble();
    final hi = (base * 1.25).roundToDouble();
    p['suggested_price_min'] = lo;
    p['suggested_price_max'] = hi;
    return {
      'product_id': id,
      'suggested_price_min': lo,
      'suggested_price_max': hi,
      'currency': 'INR',
      'reasoning':
          'Based on comparable ${p['material']} ${p['category']} listings (₹${(base * 0.85).round()}–₹${(base * 1.3).round()}) '
              'and typical market rates, a competitive price is ₹${lo.round()}–₹${hi.round()}.',
      'comparables': [
        {'title': 'Similar ${p['category']} (Meesho)', 'price': (base * 0.85).round(), 'source': 'meesho'},
        {'title': 'Handmade ${p['category']} (Amazon Karigar)', 'price': (base * 1.1).round(), 'source': 'amazon'},
      ],
    };
  }

  static Map<String, dynamic> enhance(String id) {
    final p = byId(id) ?? products.first;
    p['enhanced_image_url'] = demoImage;
    p['status'] = 'ready';
    return p;
  }

  static Map<String, dynamic> update(String id, Map<String, dynamic> patch) {
    final p = byId(id) ?? products.first;
    p.addAll(patch);
    return p;
  }

  static Map<String, dynamic> placeOrder(String productId, int qty) {
    final p = byId(productId) ?? products.first;
    final unit = (p['final_price'] ?? p['suggested_price_max'] ?? 0) as num;
    final o = _o('o${orders.length + 1}', productId, qty, unit, 'pending');
    orders.insert(0, o);
    return o;
  }

  static Map<String, dynamic> setOrderStatus(String id, String status) {
    for (final o in orders) {
      if (o['id'] == id) {
        o['status'] = status;
        return o;
      }
    }
    return orders.first;
  }

  // ---- builders ----
  static Map<String, dynamic> _p(String id, String en, String hi, String cat, String mat,
      List<String> tags, String status, num pmin, num pmax, num? fp) {
    return {
      'id': id,
      'user_id': 'demo',
      'title_en': en,
      'title_hi': hi,
      'desc_en': 'Authentic handcrafted $en made by skilled Indian artisans using traditional techniques.',
      'desc_hi': 'कुशल भारतीय कारीगरों द्वारा पारंपरिक तकनीक से बनी प्रामाणिक $hi।',
      'category': cat,
      'material': mat,
      'tags': tags,
      'status': status,
      'raw_image_url': null,
      'enhanced_image_url': status == 'draft' ? null : demoImage,
      'suggested_price_min': pmin == 0 ? null : pmin,
      'suggested_price_max': pmax == 0 ? null : pmax,
      'final_price': fp,
      'created_at': _iso,
      'updated_at': _iso,
    };
  }

  static Map<String, dynamic> _o(String id, String pid, int qty, num unit, String status) {
    return {
      'id': id,
      'product_id': pid,
      'buyer_id': 'demo-buyer',
      'artisan_id': 'demo',
      'quantity': qty,
      'unit_price': unit,
      'total_price': unit * qty,
      'status': status,
      'note': 'Bulk order inquiry',
      'created_at': _iso,
      'updated_at': _iso,
    };
  }
}
