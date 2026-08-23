import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/tts.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

final statsProvider = FutureProvider.autoDispose<ArtisanStats>((ref) async {
  return ref.read(apiProvider).artisanStats();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    String t(String k) => T.of(context, lang, k);
    final stats = ref.watch(statsProvider);
    final summary = stats.valueOrNull == null
        ? ''
        : '${t('total_earnings')} ${rupees(stats.value!.earnings)}. '
            '${stats.value!.products} ${t('products')}, ${stats.value!.listed} ${t('listed')}.';
    return Scaffold(
      appBar: AppBar(
        title: Text(t('dashboard')),
        actions: [if (summary.isNotEmpty) KSpeak(summary), const SizedBox(width: 8)],
      ),
      body: stats.when(
        loading: () => const KLoading(),
        error: (_, _) => KErrorState(
          message: t('could_not_load'),
          onRetry: () => ref.invalidate(statsProvider),
        ),
        data: (s) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(statsProvider),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _EarningsBanner(
                        earnings: s.earnings,
                        paid: s.ordersPaid,
                        totalEarnings: t('total_earnings'),
                        fromPaid: t('from_paid'),
                      ),
                      Gap.m,
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.35,
                        children: [
                          _StatCard(label: t('products'), value: '${s.products}', icon: Icons.inventory_2_outlined),
                          _StatCard(label: t('listed'), value: '${s.listed}', icon: Icons.storefront_outlined),
                          _StatCard(label: t('total_orders'), value: '${s.ordersTotal}', icon: Icons.receipt_long_outlined),
                          _StatCard(label: t('pending'), value: '${s.ordersPending}', icon: Icons.hourglass_empty_rounded,
                              accent: s.ordersPending > 0 ? AppColors.accent : null),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Primary earnings card — the one strong-colour surface in the app.
class _EarningsBanner extends StatelessWidget {
  const _EarningsBanner({required this.earnings, required this.paid, required this.totalEarnings, required this.fromPaid});
  final double earnings;
  final int paid;
  final String totalEarnings;
  final String fromPaid;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(Radii.md),
        boxShadow: Decor.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(totalEarnings,
                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 8),
          Text(rupees(earnings),
              style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          const SizedBox(height: 6),
          Text('$paid $fromPaid',
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

/// Neutral metric tile — dark number, muted label, small line icon (no rainbow
/// pastel circles). An optional [accent] tints only when a value needs attention.
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, this.accent});
  final String label;
  final String value;
  final IconData icon;
  final Color? accent;
  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.textSoft;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: c, size: 20),
          Text(value,
              style: TextStyle(
                  color: accent ?? AppColors.text, fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
