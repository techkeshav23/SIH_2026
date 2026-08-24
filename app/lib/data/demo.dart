/// In-memory demo dataset so the whole app is fully usable WITHOUT a backend.
/// Enabled via Api.enterDemo(role). Real bundled craft photos (assets/demo/*)
/// back the catalog so it reads like a genuine marketplace, not a template.
class Demo {
  static const _iso = '2026-08-20T10:00:00Z';
  static String _img(String name) => 'asset:assets/demo/$name.jpg';
  static const sampleRaw = 'asset:assets/demo/sample_raw.jpg';
  static const sampleEnhanced = 'asset:assets/demo/sample_enhanced.jpg';

  static final List<Map<String, dynamic>> products = [
    _p('d1', 'Banarasi Silk Saree', 'बनारसी सिल्क साड़ी', 'Saree', 'Silk', 'saree',
        ['handloom', 'banarasi', 'silk', 'bridal'], 'listed', 2400, 3200, 2800,
        'Handwoven Banarasi saree in pure mulberry silk with intricate gold zari motifs — a heritage weave from Varanasi.',
        'वाराणसी की विरासत — शुद्ध रेशम पर सोने की ज़री से बुनी बनारसी साड़ी, हर धागे में कारीगरी।'),
    _p('d2', 'Blue Pottery Vase', 'ब्लू पॉटरी फूलदान', 'Pottery', 'Ceramic', 'pottery',
        ['jaipur', 'blue-pottery', 'handpainted', 'decor'], 'listed', 550, 900, 750,
        'Hand-thrown Jaipur blue pottery vase, glazed and hand-painted with traditional floral patterns.',
        'जयपुर की मशहूर ब्लू पॉटरी — हाथ से बना और पारंपरिक फूलों से सजाया फूलदान।'),
    _p('d3', 'Pashmina Shawl', 'पश्मीना शॉल', 'Shawl', 'Pashmina', 'shawl',
        ['kashmir', 'pashmina', 'handwoven', 'winter'], 'listed', 4200, 5800, 5200,
        'Feather-light Kashmiri pashmina shawl, hand-spun from the finest Changthangi wool.',
        'कश्मीर की बारीक चांगथांगी ऊन से हाथ से बुनी हल्की पश्मीना शॉल — गरम और मुलायम।'),
    _p('d4', 'Pattachitra Painting', 'पट्टचित्र पेंटिंग', 'Painting', 'Canvas', 'painting',
        ['odisha', 'pattachitra', 'folk-art', 'handmade'], 'listed', 1800, 2600, 2200,
        'Traditional Odisha Pattachitra on treated cloth, painted with natural pigments and fine detailing.',
        'ओडिशा का पट्टचित्र — कपड़े पर प्राकृतिक रंगों से बनी बारीक लोक-कला।'),
    _p('d5', 'Silver Filigree Earrings', 'चांदी की फ़िलिग्री बालियां', 'Jewellery', 'Silver', 'jewellery',
        ['cuttack', 'filigree', 'silver', 'handmade'], 'listed', 1200, 1900, 1600,
        'Delicate Cuttack silver filigree (tarakasi) earrings, hand-crafted from fine silver wire.',
        'कटक की तारकसी — बारीक चांदी के तार से हाथ से बनी नाज़ुक बालियां।'),
    _p('d6', 'Cane Storage Basket', 'बेंत की टोकरी', 'Basketry', 'Cane', 'basket',
        ['assam', 'cane', 'eco', 'storage'], 'listed', 450, 700, 600,
        'Sturdy handwoven cane basket from Assam — eco-friendly storage with a natural finish.',
        'असम की हाथ से बुनी मज़बूत बेंत की टोकरी — प्राकृतिक और पर्यावरण-अनुकूल।'),
    _p('d7', 'Brass Table Lamp', 'पीतल का टेबल लैंप', 'Metalcraft', 'Brass', 'lamp',
        ['moradabad', 'brass', 'handcrafted', 'decor'], 'ready', 1500, 2200, null,
        'Hand-etched Moradabad brass table lamp with a warm antique finish.',
        'मुरादाबाद का हाथ से उकेरा पीतल का टेबल लैंप — गरम एंटीक फ़िनिश।'),
    _p('d8', 'Handwoven Wool Scarf', 'ऊनी हाथ-बुना स्कार्फ़', 'Scarf', 'Wool', 'scarf',
        ['himachal', 'wool', 'handwoven', 'winter'], 'listed', 700, 1100, 950,
        'Warm handwoven wool scarf from Himachal with a classic geometric border.',
        'हिमाचल का हाथ से बुना गरम ऊनी स्कार्फ़ — क्लासिक ज्यामितीय बॉर्डर के साथ।'),
  ];

  /// Seeded orders belong to OTHER buyers (artisan's incoming). The demo buyer's
  /// own "My Orders" starts empty and fills as they place orders (buyer_id 'me').
  static final List<Map<String, dynamic>> orders = [
    // buyer's OWN orders ('me') — populate the buyer's "My Orders" + show Pay-now
    _o('o1', 'd1', 'Banarasi Silk Saree', 'saree', 4, 2800, 'shipped', 'me'),
    _o('o4', 'd2', 'Blue Pottery Vase', 'pottery', 8, 750, 'accepted', 'me'),
    _o('o5', 'd4', 'Pattachitra Painting', 'painting', 3, 2200, 'pending', 'me'),
    // other buyers — artisan's incoming queue
    _o('o2', 'd3', 'Pashmina Shawl', 'shawl', 6, 5200, 'paid', 'demo-buyer'),
    _o('o3', 'd5', 'Silver Filigree Earrings', 'jewellery', 10, 1600, 'paid', 'demo-buyer'),
    _o('o6', 'd8', 'Handwoven Wool Scarf', 'scarf', 12, 950, 'pending', 'demo-buyer'),
  ];

  static List<Map<String, dynamic>> buyerOrders() =>
      orders.where((o) => o['buyer_id'] == 'me').toList();

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
    final p = _p('d${_seq++}', 'New Handmade Product', 'नया हस्तनिर्मित उत्पाद',
        category ?? 'Handicraft', material ?? 'Handmade', 'sample_enhanced',
        ['handmade'], 'draft', 0, 0, null, '', '');
    p['raw_image_url'] = null;
    p['enhanced_image_url'] = null;
    products.insert(0, p);
    return p;
  }

  static Map<String, dynamic>? byId(String id) {
    for (final p in products) {
      if (p['id'] == id) return p;
    }
    return null;
  }

  // Monotonic id source so ids never collide after deletes (length-based ids do).
  static int _seq = 100;

  static Map<String, dynamic> _stub() => _p('d${_seq++}', 'Product', 'उत्पाद',
      'Handicraft', 'Handmade', 'sample_enhanced', const ['handmade'], 'draft', 0, 0, null, '', '');

  /// byId, or the first product, or a throwaway stub if the list is empty
  /// (avoids 'Bad state: No element' after every product is deleted).
  static Map<String, dynamic> _findOrStub(String id) =>
      byId(id) ?? (products.isNotEmpty ? products.first : _stub());

  static Map<String, dynamic> catalog(String id, String text) {
    final p = _findOrStub(id);
    final cat = p['category'] == 'Handicraft' ? 'Handmade Craft' : p['category'];
    p['title_en'] = 'Handcrafted $cat — Artisan Made';
    p['title_hi'] = 'हस्तनिर्मित $cat — कारीगर द्वारा';
    p['desc_en'] = text.trim().isEmpty
        ? 'Authentic handcrafted piece made by a skilled Indian artisan using traditional techniques. Naturally finished, durable and unique.'
        : '$text — handcrafted by a skilled Indian artisan using traditional techniques. Each piece is unique.';
    p['desc_hi'] = 'कुशल भारतीय कारीगर द्वारा पारंपरिक तकनीक से बनी प्रामाणिक वस्तु। हर टुकड़ा अद्वितीय है।';
    p['tags'] = ['handmade', 'artisan', 'made-in-india'];
    p['status'] = 'ready';
    return p;
  }

  static Map<String, dynamic> price(String id) {
    final p = _findOrStub(id);
    final base = (p['suggested_price_max'] as num?)?.toDouble() ?? 900;
    final lo = (base * 0.85).roundToDouble();
    final hi = (base * 1.1).roundToDouble();
    p['suggested_price_min'] = lo;
    p['suggested_price_max'] = hi;
    return {
      'product_id': id,
      'suggested_price_min': lo,
      'suggested_price_max': hi,
      'currency': 'INR',
      'reasoning':
          'Based on 3 comparable ${p['material']} ${p['category']} listings (₹${(base * 0.8).round()}–₹${(base * 1.2).round()}) '
              'and typical market rates, ₹${lo.round()}–₹${hi.round()} is competitive. Price higher for premium finish or festive season.',
      'comparables': [
        {'title': 'Similar ${p['category']} on Meesho', 'price': (base * 0.8).round(), 'source': 'Meesho'},
        {'title': 'Handmade ${p['category']} on Amazon Karigar', 'price': (base * 1.05).round(), 'source': 'Amazon'},
        {'title': 'Artisan ${p['category']} on Etsy', 'price': (base * 1.2).round(), 'source': 'Etsy'},
      ],
    };
  }

  static Map<String, dynamic> enhance(String id) {
    final p = _findOrStub(id);
    p['raw_image_url'] = sampleRaw;
    p['enhanced_image_url'] = sampleEnhanced;
    p['status'] = 'ready';
    return p;
  }

  static Map<String, dynamic> update(String id, Map<String, dynamic> patch) {
    final p = _findOrStub(id);
    p.addAll(patch);
    return p;
  }

  static void deleteProduct(String id) => products.removeWhere((p) => p['id'] == id);

  static Map<String, dynamic> placeOrder(String productId, int qty) {
    final p = _findOrStub(productId);
    final unit = (p['final_price'] ?? p['suggested_price_max'] ?? 0) as num;
    final o = _o('o${_seq++}', productId, p['title_en'] ?? 'Product',
        p['image'] ?? 'saree', qty, unit, 'pending', 'me');
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
    return orders.isNotEmpty
        ? orders.first
        : {'id': id, 'status': status, 'quantity': 1, 'unit_price': 0, 'total_price': 0};
  }

  // ---- reviews ----
  static final Map<String, List<Map<String, dynamic>>> reviews = {
    'd1': [
      {'id': 'r1', 'product_id': 'd1', 'author': 'Priya S.', 'rating': 5, 'text': 'Beautiful weave, the zari is stunning. Worth every rupee.', 'date': '2 weeks ago'},
      {'id': 'r2', 'product_id': 'd1', 'author': 'Fabindia Buyer', 'rating': 4, 'text': 'Great quality for bulk order. Timely delivery.', 'date': '1 month ago'},
    ],
    'd2': [
      {'id': 'r3', 'product_id': 'd2', 'author': 'Anil K.', 'rating': 5, 'text': 'Authentic Jaipur blue pottery. Hand-painted details are lovely.', 'date': '5 days ago'},
    ],
    'd3': [
      {'id': 'r4', 'product_id': 'd3', 'author': 'Meera R.', 'rating': 5, 'text': 'So soft and warm — genuine pashmina. Highly recommend.', 'date': '3 weeks ago'},
      {'id': 'r5', 'product_id': 'd3', 'author': 'Retail Store', 'rating': 5, 'text': 'Our customers love these. Reordering.', 'date': '1 month ago'},
    ],
  };

  static List<Map<String, dynamic>> reviewsFor(String id) => reviews[id] ?? const [];

  static Map<String, dynamic> addReview(String productId, int rating, String text) {
    final r = {
      'id': 'r${DateTime.now().millisecondsSinceEpoch}',
      'product_id': productId, 'author': 'आप (You)', 'rating': rating, 'text': text, 'date': 'just now',
    };
    reviews.putIfAbsent(productId, () => []).insert(0, r);
    return r;
  }

  // ---- notifications ----
  static final List<Map<String, dynamic>> notifications = [
    {'id': 'n1', 'title': 'भुगतान मिला', 'body': 'ऑर्डर #O3 का ₹16,000 भुगतान हो गया।', 'type': 'payment', 'read': false, 'time': '2h'},
    {'id': 'n2', 'title': 'नया ऑर्डर', 'body': 'ब्लू पॉटरी फूलदान — 8 पीस का ऑर्डर मिला।', 'type': 'order', 'read': false, 'time': '5h'},
    {'id': 'n3', 'title': 'नई समीक्षा', 'body': 'बनारसी साड़ी को 5-स्टार समीक्षा मिली।', 'type': 'system', 'read': true, 'time': '1d'},
    {'id': 'n4', 'title': 'B2B पूछताछ', 'body': 'Fabindia ने पश्मीना शॉल के बारे में पूछताछ की।', 'type': 'inquiry', 'read': true, 'time': '2d'},
  ];

  static int unreadCount() => notifications.where((n) => n['read'] == false).length;

  static void markAllRead() {
    for (final n in notifications) {
      n['read'] = true;
    }
  }

  // ---- profile ----
  static final Map<String, dynamic> profile = {
    'id': 'demo',
    'phone': '+91 98765 43210',
    'name': 'कमला देवी',
    'language_pref': 'hi',
    'craft_type': 'हथकरघा बुनाई',
    'region': 'वाराणसी, उत्तर प्रदेश',
  };

  static Map<String, dynamic> updateProfile(Map<String, dynamic> patch) {
    profile.addAll(patch);
    return profile;
  }

  // ---- delivery addresses (buyer) ----
  static final List<Map<String, dynamic>> addresses = [
    {
      'id': 'addr1', 'name': 'राधा शर्मा', 'phone': '9876500011',
      'line1': '12, MG Road', 'line2': 'Near City Mall',
      'city': 'जयपुर', 'state': 'राजस्थान', 'pincode': '302001', 'is_default': true,
    },
  ];

  static Map<String, dynamic> addAddress(Map<String, dynamic> body) {
    final isFirst = addresses.isEmpty;
    if (body['is_default'] == true || isFirst) {
      for (final a in addresses) {
        a['is_default'] = false;
      }
    }
    final a = {
      ...body,
      'id': 'addr${addresses.length + 1}',
      'is_default': body['is_default'] == true || isFirst,
    };
    addresses.add(a);
    return a;
  }

  static void deleteAddress(String id) => addresses.removeWhere((a) => a['id'] == id);

  // ---- B2B quotes / negotiation ----
  static final List<Map<String, dynamic>> quotes = [
    {
      'id': 'q1', 'product_id': 'd3', 'product_title': 'Pashmina Shawl',
      'product_image': _img('shawl'), 'quantity': 50, 'buyer_price': 4200,
      'artisan_price': 4800, 'agreed_price': null, 'list_price': 5200,
      'status': 'open', 'turn': 'buyer', 'message': 'Bulk order for our export house',
      'order_id': null,
    },
  ];

  static Map<String, dynamic> createQuote(String pid, int qty, double target, String? msg) {
    final p = _findOrStub(pid);
    final q = {
      'id': 'q${_seq++}', 'product_id': pid, 'product_title': p['title_en'] ?? 'Product',
      'product_image': p['image'] != null ? _img(p['image']) : null,
      'quantity': qty, 'buyer_price': target, 'artisan_price': null, 'agreed_price': null,
      'list_price': p['final_price'] ?? p['suggested_price_max'], 'status': 'open',
      'turn': 'artisan', 'message': msg, 'order_id': null,
    };
    quotes.insert(0, q);
    return q;
  }

  static Map<String, dynamic> quoteAction(String id, String action, {double? price, bool byBuyer = false}) {
    final q = quotes.firstWhere((x) => x['id'] == id,
        orElse: () => quotes.isNotEmpty ? quotes.first : {'id': id, 'status': 'open', 'turn': 'artisan'});
    // parity with the backend state machine: only the party whose turn it is,
    // and only while still open, may act.
    final role = byBuyer ? 'buyer' : 'artisan';
    if (q['status'] != 'open' || q['turn'] != role) return q;

    if (action == 'counter') {
      if (price == null || price <= 0) return q;
      if (byBuyer) {
        q['buyer_price'] = price;
        q['turn'] = 'artisan';
      } else {
        q['artisan_price'] = price;
        q['turn'] = 'buyer';
      }
    } else if (action == 'accept') {
      final agreed = byBuyer ? q['artisan_price'] : q['buyer_price'];
      if (agreed == null) return q; // nothing to accept yet
      q['agreed_price'] = agreed;
      q['status'] = 'accepted';
      // spawn a real demo order so the deal shows up in My Orders
      final p = _findOrStub(q['product_id']?.toString() ?? '');
      final o = _o('o${_seq++}', q['product_id'] ?? '', q['product_title'] ?? 'Product',
          p['image'] ?? 'saree', (q['quantity'] ?? 1) as int, agreed as num, 'accepted', 'me');
      orders.insert(0, o);
      q['order_id'] = o['id'];
    } else if (action == 'decline') {
      q['status'] = 'declined';
    }
    return q;
  }

  // ---- promote / boost (demo) ----
  static Map<String, dynamic> boostProduct(double budgetRupees, int days) {
    final low = (budgetRupees * 1.4).round();
    final high = (budgetRupees * 3.2).round();
    return {
      'status': 'paused',
      'campaign_id': 'demo_campaign_${_seq++}',
      'ad_id': 'demo_ad_${_seq++}',
      'daily_budget': budgetRupees / (days == 0 ? 1 : days),
      'estimated_reach': [low, high],
      'permalink': null,
      'note': null,
    };
  }

  // ---- ad campaigns (Meta / Google Ads) ----
  static final List<Map<String, dynamic>> campaigns = [];

  static Map<String, dynamic> boostCampaign(String campaignId, double amount) {
    final c = campaigns.firstWhere((c) => c['id'] == campaignId, orElse: () => campaigns.first);
    c['daily_budget'] = ((c['daily_budget'] as num?) ?? 200.0) + amount;
    return c;
  }

  static Map<String, dynamic> newCampaign(String name, List<String> platforms, {String? productId}) {
    final ids = <String, dynamic>{};
    for (final pf in platforms) {
      ids[pf] = 'demo_${pf}_${_seq++}';
    }
    final c = {
      'id': 'c${_seq++}', 'name': name, 'product_id': productId,
      'objective': 'OUTCOME_TRAFFIC', 'daily_budget': 200.0,
      'platforms': platforms, 'status': 'paused',
      'platform_ids': ids, 'platform_urls': <String, dynamic>{}, 'error': null,
    };
    campaigns.insert(0, c);
    return c;
  }

  // ---- artisan storefront (public) ----
  static Map<String, dynamic> storefront() => {
        'artisan_id': 'demo',
        'name': profile['name'],
        'craft_type': profile['craft_type'],
        'region': profile['region'],
        'products': (listed()['items'] as List),
      };

  // ---- builders ----
  static Map<String, dynamic> _p(String id, String en, String hi, String cat, String mat,
      String image, List<String> tags, String status, num pmin, num pmax, num? fp,
      String descEn, String descHi) {
    return {
      'id': id,
      'user_id': 'demo',
      'title_en': en,
      'title_hi': hi,
      'desc_en': descEn,
      'desc_hi': descHi,
      'category': cat,
      'material': mat,
      'image': image,
      'tags': tags,
      'status': status,
      'raw_image_url': null,
      'enhanced_image_url': status == 'draft' ? null : _img(image),
      'suggested_price_min': pmin == 0 ? null : pmin,
      'suggested_price_max': pmax == 0 ? null : pmax,
      'final_price': fp,
      'created_at': _iso,
      'updated_at': _iso,
    };
  }

  static Map<String, dynamic> _o(String id, String pid, String title, String image,
      int qty, num unit, String status, String buyer) {
    return {
      'id': id,
      'product_id': pid,
      'product_title': title,
      'product_image': _img(image),
      'buyer_id': buyer,
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
