import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Lightweight i18n — Hindi/English toggle without asset setup.
/// (For v1 scale, migrate to easy_localization/ARB; kept simple for the demo.)
enum AppLang { hi, en }

final langProvider = StateProvider<AppLang>((ref) => AppLang.hi);

class T {
  static const _map = <String, Map<AppLang, String>>{
    'app_name': {AppLang.hi: 'कलासेतु', AppLang.en: 'KalaSetu'},
    'tagline': {
      AppLang.hi: 'आपका डिजिटल व्यापार सहायक',
      AppLang.en: 'Your digital business manager',
    },
    'login': {AppLang.hi: 'लॉग इन करें', AppLang.en: 'Login'},
    'phone': {AppLang.hi: 'फ़ोन नंबर', AppLang.en: 'Phone number'},
    'send_otp': {AppLang.hi: 'OTP भेजें', AppLang.en: 'Send OTP'},
    'verify': {AppLang.hi: 'पुष्टि करें', AppLang.en: 'Verify'},
    'my_products': {AppLang.hi: 'मेरे उत्पाद', AppLang.en: 'My Products'},
    'add_product': {AppLang.hi: 'नया उत्पाद जोड़ें', AppLang.en: 'Add Product'},
    'take_photo': {AppLang.hi: 'फ़ोटो खींचें', AppLang.en: 'Take Photo'},
    'enhance': {AppLang.hi: 'फ़ोटो सुधारें', AppLang.en: 'Enhance Photo'},
    'record_voice': {AppLang.hi: 'आवाज़ में बताएं', AppLang.en: 'Describe by Voice'},
    'suggest_price': {AppLang.hi: 'क़ीमत सुझाएं', AppLang.en: 'Suggest Price'},
    'publish': {AppLang.hi: 'बाज़ार में डालें', AppLang.en: 'List on Market'},
    'processing': {AppLang.hi: 'तैयार हो रहा है…', AppLang.en: 'Processing…'},
    'before_after': {AppLang.hi: 'पहले / बाद में', AppLang.en: 'Before / After'},
  };

  static String of(BuildContext context, AppLang lang, String key) {
    return _map[key]?[lang] ?? key;
  }
}

/// Convenience extension: `context.tr(ref, 'key')`.
extension Tr on WidgetRef {
  String tr(BuildContext context, String key) =>
      T.of(context, read(langProvider), key);
}
