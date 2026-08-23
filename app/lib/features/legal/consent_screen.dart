import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/tts.dart';
import '../../data/api.dart';

/// DPDP Act 2023 consent gate — shown once after login before the app opens.
/// Recording consent (locally + server) satisfies the "free, informed,
/// specific" consent requirement and gives an auditable version + timestamp.
class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key});
  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool _busy = false;

  Future<void> _agree() async {
    setState(() => _busy = true);
    await ref.read(apiProvider).recordConsent();
    if (!mounted) return;
    final api = ref.read(apiProvider);
    context.go(api.isBuyer ? '/buyer/home' : '/home');
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final text = Theme.of(context).textTheme;
    String t(String k) => T.of(context, lang, k);

    Widget point(IconData icon, String key) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(t(key), style: text.bodyLarge)),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(t('consent_title')),
        actions: [KSpeak('${t('consent_intro')} ${t('consent_p1')} ${t('consent_p2')} ${t('consent_p3')}')],
      ),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: Decor.warmGradient,
                    shape: BoxShape.circle,
                    boxShadow: Decor.soft,
                  ),
                  child: const Icon(Icons.shield_moon_rounded, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 16),
                Text(t('consent_intro'), style: text.titleMedium),
                const SizedBox(height: 8),
                const Divider(height: 28),
                point(Icons.inventory_2_outlined, 'consent_p1'),
                point(Icons.handshake_outlined, 'consent_p2'),
                point(Icons.verified_user_outlined, 'consent_p3'),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => context.push('/privacy'),
                  icon: const Icon(Icons.description_outlined, size: 18),
                  label: Text(t('view_privacy')),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _agree,
                icon: _busy
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline),
                label: Text(t('consent_agree')),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
