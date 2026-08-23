import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';

/// Full privacy policy + grievance officer (DPDP Act 2023 §13). Reachable from
/// the consent gate and from Settings.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  static const _sections = <List<String>>[
    // [title_en, body_en, title_hi, body_hi]
    [
      'What we collect',
      'Phone number (for OTP login), your product photos and descriptions, prices you set, and order details. In demo mode nothing leaves your device.',
      'हम क्या इकट्ठा करते हैं',
      'फ़ोन नंबर (OTP लॉगिन के लिए), आपकी उत्पाद फ़ोटो व विवरण, आपकी तय क़ीमतें, और ऑर्डर की जानकारी। डेमो मोड में कुछ भी आपके डिवाइस से बाहर नहीं जाता।',
    ],
    [
      'How we use it',
      'To generate your bilingual listings and price suggestions (via Google Vertex AI, processed in India), to show your products to buyers, and to manage orders. We do not sell your personal data or use it for advertising.',
      'हम इसका उपयोग कैसे करते हैं',
      'आपकी द्विभाषी लिस्टिंग और क़ीमत सुझाव बनाने (Google Vertex AI द्वारा, भारत में प्रोसेस), आपके उत्पाद खरीदारों को दिखाने, और ऑर्डर संभालने के लिए। हम आपका निजी डेटा बेचते नहीं और न ही विज्ञापन के लिए उपयोग करते हैं।',
    ],
    [
      'Where it is stored',
      'On Google Cloud servers in Mumbai (asia-south1) — your data stays in India. Access is restricted and connections are encrypted.',
      'यह कहाँ संग्रहित होता है',
      'मुंबई (asia-south1) के Google Cloud सर्वर पर — आपका डेटा भारत में ही रहता है। पहुँच सीमित है और कनेक्शन एन्क्रिप्टेड हैं।',
    ],
    [
      'Your rights',
      'Under the DPDP Act 2023 you can access, correct, or delete your data, and withdraw consent at any time. Contact the Grievance Officer below to exercise these rights.',
      'आपके अधिकार',
      'DPDP अधिनियम 2023 के तहत आप अपना डेटा देख, सुधार या हटा सकते हैं, और कभी भी सहमति वापस ले सकते हैं। इन अधिकारों के लिए नीचे दिए शिकायत अधिकारी से संपर्क करें।',
    ],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final hi = lang == AppLang.hi;
    final text = Theme.of(context).textTheme;
    String t(String k) => T.of(context, lang, k);

    return Scaffold(
      appBar: AppBar(title: Text(t('privacy_policy'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(hi ? 'अंतिम अपडेट: अगस्त 2026' : 'Last updated: August 2026',
              style: text.labelMedium?.copyWith(color: AppColors.muted)),
          const SizedBox(height: 16),
          for (final s in _sections) ...[
            Text(hi ? s[2] : s[0], style: text.titleMedium?.copyWith(color: AppColors.primaryDark)),
            const SizedBox(height: 6),
            Text(hi ? s[3] : s[1], style: text.bodyLarge?.copyWith(height: 1.5)),
            const SizedBox(height: 20),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: AppColors.line),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(t('grievance_officer'), style: text.titleMedium),
              const SizedBox(height: 8),
              Text(hi
                  ? 'नाम: KalaSetu डेटा संरक्षण टीम\nईमेल: privacy@kalasetu.in\nजवाब का समय: 7 कार्यदिवस के भीतर'
                  : 'Name: KalaSetu Data Protection Team\nEmail: privacy@kalasetu.in\nResponse time: within 7 working days',
                  style: text.bodyMedium?.copyWith(height: 1.6)),
            ]),
          ),
        ],
      ),
    );
  }
}
