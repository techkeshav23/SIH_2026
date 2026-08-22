import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight i18n — Hindi/English. Default Hindi (primary audience).
enum AppLang { hi, en }

final langProvider = StateProvider<AppLang>((ref) => AppLang.hi);

/// Global text scale (accessibility / large-text mode). 1.0 = default.
final textScaleProvider = StateProvider<double>((ref) => 1.0);

class T {
  static const _map = <String, Map<AppLang, String>>{
    // ---- brand / common ----
    'app_name': {AppLang.hi: 'कलासेतु', AppLang.en: 'KalaSetu'},
    'tagline': {AppLang.hi: 'आपका डिजिटल व्यापार सहायक', AppLang.en: 'Your digital business manager'},
    'save': {AppLang.hi: 'सहेजें', AppLang.en: 'Save'},
    'cancel': {AppLang.hi: 'रद्द करें', AppLang.en: 'Cancel'},
    'confirm': {AppLang.hi: 'पुष्टि करें', AppLang.en: 'Confirm'},
    'retry': {AppLang.hi: 'फिर कोशिश करें', AppLang.en: 'Retry'},
    'logout': {AppLang.hi: 'लॉग आउट', AppLang.en: 'Logout'},
    'logout_q': {AppLang.hi: 'लॉग आउट करें?', AppLang.en: 'Logout?'},
    'logout_msg': {AppLang.hi: 'KalaSetu से साइन आउट करें?', AppLang.en: 'Sign out of KalaSetu?'},
    'language': {AppLang.hi: 'भाषा', AppLang.en: 'Language'},
    'settings': {AppLang.hi: 'सेटिंग्स', AppLang.en: 'Settings'},
    'profile': {AppLang.hi: 'प्रोफ़ाइल', AppLang.en: 'Profile'},
    'search': {AppLang.hi: 'खोजें', AppLang.en: 'Search'},
    'all': {AppLang.hi: 'सभी', AppLang.en: 'All'},
    'read_aloud': {AppLang.hi: 'पढ़कर सुनाएं', AppLang.en: 'Read aloud'},
    'could_not_load': {AppLang.hi: 'लोड नहीं हो सका', AppLang.en: 'Could not load'},
    'try_again': {AppLang.hi: 'कृपया फिर कोशिश करें', AppLang.en: 'Please try again'},
    'no_internet': {AppLang.hi: 'इंटरनेट नहीं है', AppLang.en: 'No internet'},

    // ---- auth ----
    'login': {AppLang.hi: 'लॉग इन करें', AppLang.en: 'Login'},
    'artisan': {AppLang.hi: 'कारीगर', AppLang.en: 'Artisan'},
    'buyer': {AppLang.hi: 'खरीदार', AppLang.en: 'Buyer'},
    'phone': {AppLang.hi: 'फ़ोन नंबर', AppLang.en: 'Phone number'},
    'send_otp': {AppLang.hi: 'OTP भेजें', AppLang.en: 'Send OTP'},
    'verify': {AppLang.hi: 'पुष्टि करें', AppLang.en: 'Verify'},
    'demo_mode': {AppLang.hi: 'डेमो मोड में देखें', AppLang.en: 'Continue in demo mode'},
    'invalid_phone': {AppLang.hi: 'सही 10 अंकों का नंबर डालें', AppLang.en: 'Enter a valid 10-digit number'},
    'invalid_otp': {AppLang.hi: '6 अंकों का OTP डालें', AppLang.en: 'Enter the 6-digit OTP'},

    // ---- home ----
    'my_products': {AppLang.hi: 'मेरे उत्पाद', AppLang.en: 'My Products'},
    'add_product': {AppLang.hi: 'नया उत्पाद जोड़ें', AppLang.en: 'Add Product'},
    'no_products': {AppLang.hi: 'अभी कोई उत्पाद नहीं', AppLang.en: 'No products yet'},
    'no_products_sub': {AppLang.hi: 'नीचे बटन दबाकर पहला उत्पाद जोड़ें।', AppLang.en: 'Tap the button below to add your first product.'},
    'drafts_waiting': {AppLang.hi: 'ऑफ़लाइन ड्राफ्ट सिंक होने बाकी', AppLang.en: 'offline draft(s) waiting'},
    'sync_now': {AppLang.hi: 'अभी सिंक करें', AppLang.en: 'Sync now'},

    // ---- studio / create ----
    'take_photo': {AppLang.hi: 'फ़ोटो खींचें', AppLang.en: 'Take Photo'},
    'enhance': {AppLang.hi: 'फ़ोटो सुधारें', AppLang.en: 'Enhance Photo'},
    'ai_enhanced': {AppLang.hi: 'AI द्वारा सुधारा गया', AppLang.en: 'AI enhanced'},
    'describe_product': {AppLang.hi: 'उत्पाद के बारे में बताएं', AppLang.en: 'Describe your product'},
    'voice_soon': {AppLang.hi: 'आवाज़ इनपुट जल्द आ रहा है — टाइप करके बताएं', AppLang.en: 'Voice input coming soon — describe by typing'},
    'generate_listing': {AppLang.hi: 'AI से लिस्टिंग बनाएं', AppLang.en: 'Generate listing with AI'},
    'suggest_price': {AppLang.hi: 'क़ीमत सुझाएं', AppLang.en: 'Suggest Price'},
    'publish': {AppLang.hi: 'बाज़ार में डालें', AppLang.en: 'List on Market'},
    'list_q': {AppLang.hi: 'बाज़ार में डालें?', AppLang.en: 'List on marketplace?'},
    'list_msg': {AppLang.hi: 'यह उत्पाद B2B खरीदारों को दिखेगा।', AppLang.en: 'This makes the product visible to B2B buyers.'},
    'processing': {AppLang.hi: 'तैयार हो रहा है…', AppLang.en: 'Processing…'},
    'enhancing': {AppLang.hi: 'AI फ़ोटो सुधार रहा है…', AppLang.en: 'AI enhancing photo…'},
    'writing_listing': {AppLang.hi: 'लिस्टिंग लिखी जा रही है…', AppLang.en: 'Writing listing…'},
    'analysing_market': {AppLang.hi: 'बाज़ार का विश्लेषण…', AppLang.en: 'Analysing market…'},

    // ---- product detail ----
    'listing': {AppLang.hi: 'लिस्टिंग', AppLang.en: 'Listing'},
    'pricing': {AppLang.hi: 'क़ीमत', AppLang.en: 'Pricing'},
    'title_hi': {AppLang.hi: 'शीर्षक (हिंदी)', AppLang.en: 'Title (Hindi)'},
    'title_en': {AppLang.hi: 'शीर्षक (English)', AppLang.en: 'Title (English)'},
    'desc_hi': {AppLang.hi: 'विवरण (हिंदी)', AppLang.en: 'Description (Hindi)'},
    'final_price': {AppLang.hi: 'अंतिम क़ीमत (₹)', AppLang.en: 'Final price (₹)'},
    'ai_suggested': {AppLang.hi: 'AI सुझाव', AppLang.en: 'AI suggested'},
    'saved': {AppLang.hi: 'सहेजा गया ✓', AppLang.en: 'Saved ✓'},
    'listed_ok': {AppLang.hi: 'बाज़ार में डाल दिया ✓', AppLang.en: 'Listed on marketplace ✓'},
    'add_title_first': {AppLang.hi: 'लिस्ट करने से पहले शीर्षक डालें', AppLang.en: 'Add a title before listing'},
    'set_price_first': {AppLang.hi: 'लिस्ट करने से पहले सही क़ीमत डालें', AppLang.en: 'Set a valid price before listing'},

    // ---- dashboard ----
    'dashboard': {AppLang.hi: 'डैशबोर्ड', AppLang.en: 'Dashboard'},
    'total_earnings': {AppLang.hi: 'कुल कमाई', AppLang.en: 'Total earnings'},
    'products': {AppLang.hi: 'उत्पाद', AppLang.en: 'Products'},
    'listed': {AppLang.hi: 'बाज़ार में', AppLang.en: 'Listed'},
    'total_orders': {AppLang.hi: 'कुल ऑर्डर', AppLang.en: 'Total orders'},
    'pending': {AppLang.hi: 'बाकी', AppLang.en: 'Pending'},
    'from_paid': {AppLang.hi: 'भुगतान वाले ऑर्डर से', AppLang.en: 'from paid orders'},

    // ---- orders ----
    'orders': {AppLang.hi: 'ऑर्डर', AppLang.en: 'Orders'},
    'incoming_orders': {AppLang.hi: 'आए हुए ऑर्डर', AppLang.en: 'Incoming Orders'},
    'incoming_sub': {AppLang.hi: 'खरीदारों के अनुरोध देखें और जवाब दें', AppLang.en: 'Review and respond to buyer requests'},
    'no_orders': {AppLang.hi: 'अभी कोई ऑर्डर नहीं', AppLang.en: 'No orders yet'},
    'accept': {AppLang.hi: 'स्वीकारें', AppLang.en: 'Accept'},
    'reject': {AppLang.hi: 'अस्वीकारें', AppLang.en: 'Reject'},
    'reject_q': {AppLang.hi: 'ऑर्डर अस्वीकारें?', AppLang.en: 'Reject order?'},
    'reject_msg': {AppLang.hi: 'इससे खरीदार का ऑर्डर मना हो जाएगा।', AppLang.en: 'This will decline the buyer\'s order.'},
    'qty': {AppLang.hi: 'मात्रा', AppLang.en: 'Qty'},
    'order_no': {AppLang.hi: 'ऑर्डर', AppLang.en: 'Order'},
    'order_timeline': {AppLang.hi: 'ऑर्डर की प्रगति', AppLang.en: 'Order progress'},

    // ---- market / buyer ----
    'marketplace': {AppLang.hi: 'बाज़ार', AppLang.en: 'Marketplace'},
    'b2b_marketplace': {AppLang.hi: 'B2B बाज़ार', AppLang.en: 'B2B Marketplace'},
    'ondc_ready': {AppLang.hi: 'ONDC · GeM पर तैयार', AppLang.en: 'Powered by ONDC · GeM ready'},
    'browse': {AppLang.hi: 'देखें', AppLang.en: 'Browse'},
    'order': {AppLang.hi: 'ऑर्डर करें', AppLang.en: 'Order'},
    'place_order': {AppLang.hi: 'ऑर्डर पक्का करें', AppLang.en: 'Place order'},
    'order_placed': {AppLang.hi: 'ऑर्डर हो गया — कारीगर की मंज़ूरी बाकी ✓', AppLang.en: 'Order placed — awaiting artisan approval ✓'},
    'total': {AppLang.hi: 'कुल', AppLang.en: 'Total'},
    'quantity': {AppLang.hi: 'मात्रा', AppLang.en: 'Quantity'},
    'pay_now': {AppLang.hi: 'अभी भुगतान करें', AppLang.en: 'Pay now'},
    'payment_ok': {AppLang.hi: 'भुगतान सफल ✓', AppLang.en: 'Payment successful ✓'},
    'my_orders': {AppLang.hi: 'मेरे ऑर्डर', AppLang.en: 'My Orders'},
    'no_listed': {AppLang.hi: 'अभी कोई उत्पाद बाज़ार में नहीं', AppLang.en: 'No listed products yet'},
    'inquire': {AppLang.hi: 'पूछताछ करें', AppLang.en: 'Inquire'},
    'send_inquiry': {AppLang.hi: 'पूछताछ भेजें', AppLang.en: 'Send inquiry'},
    'inquiry_sent': {AppLang.hi: 'कारीगर को पूछताछ भेज दी ✓', AppLang.en: 'Inquiry sent to artisan ✓'},
    'org_name': {AppLang.hi: 'आपकी संस्था / GSTIN', AppLang.en: 'Your organization / GSTIN'},
    'message': {AppLang.hi: 'संदेश', AppLang.en: 'Message'},
    'about_product': {AppLang.hi: 'उत्पाद के बारे में', AppLang.en: 'About this product'},
    'by_artisan': {AppLang.hi: 'कारीगर द्वारा', AppLang.en: 'By artisan'},

    // ---- profile / settings ----
    'shop_profile': {AppLang.hi: 'दुकान प्रोफ़ाइल', AppLang.en: 'Shop Profile'},
    'your_name': {AppLang.hi: 'आपका नाम', AppLang.en: 'Your name'},
    'craft_type': {AppLang.hi: 'शिल्प का प्रकार', AppLang.en: 'Craft type'},
    'region': {AppLang.hi: 'क्षेत्र / गाँव', AppLang.en: 'Region / village'},
    'org': {AppLang.hi: 'संस्था', AppLang.en: 'Organization'},
    'gstin': {AppLang.hi: 'GSTIN', AppLang.en: 'GSTIN'},
    'account': {AppLang.hi: 'खाता', AppLang.en: 'Account'},
    'text_size': {AppLang.hi: 'टेक्स्ट का आकार', AppLang.en: 'Text size'},
    'read_aloud_setting': {AppLang.hi: 'पढ़कर सुनाना', AppLang.en: 'Read screens aloud'},
    'about': {AppLang.hi: 'ऐप के बारे में', AppLang.en: 'About'},
    'about_line': {AppLang.hi: 'SIH 2026 · PS 26090 · सामाजिक न्याय मंत्रालय', AppLang.en: 'SIH 2026 · PS 26090 · Ministry of Social Justice'},
    'help': {AppLang.hi: 'मदद', AppLang.en: 'Help & Support'},
  };

  static String of(BuildContext context, AppLang lang, String key) {
    return _map[key]?[lang] ?? key;
  }
}

extension Tr on WidgetRef {
  String tr(BuildContext context, String key) => T.of(context, read(langProvider), key);
}
