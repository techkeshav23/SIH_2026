import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/nav.dart';
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
    return AppScaffold(
      current: 2,
      body: stats.when(
        loading: () => const KLoading(),
        error: (_, _) => KErrorState(
          message: t('could_not_load'),
          onRetry: () => ref.invalidate(statsProvider),
        ),
        data: (s) {
          final summary =
              '${t('total_earnings')} ₹${s.earnings.toStringAsFixed(0)}. '
              '${s.products} ${t('products')}, ${s.listed} ${t('listed')}.';
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(statsProvider),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                KHeader(
                  title: t('dashboard'),
                  leading: drawerButton(),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KSpeak(summary, color: Colors.white),
                      _EarningsHero(
                        earnings: s.earnings,
                        paid: s.ordersPaid,
                        fromPaid: t('from_paid'),
                      ),
                    ],
                  ),
                ),
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
                          _StatCard(label: t('products'), value: '${s.products}', icon: Icons.inventory_2_rounded, color: AppColors.primary),
                          _StatCard(label: t('listed'), value: '${s.listed}', icon: Icons.storefront_rounded, color: AppColors.accent),
                          _StatCard(label: t('total_orders'), value: '${s.ordersTotal}', icon: Icons.receipt_long_rounded, color: AppColors.indigo),
                          _StatCard(label: t('pending'), value: '${s.ordersPending}', icon: Icons.hourglass_top_rounded, color: AppColors.success),
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

/// Compact earnings summary shown inside the gradient hero header.
class _EarningsHero extends StatelessWidget {
  const _EarningsHero({required this.earnings, required this.paid, required this.fromPaid});
  final double earnings;
  final int paid;
  final String fromPaid;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '₹${earnings.toStringAsFixed(0)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$paid $fromPaid',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
        ),
      ],
    );
  }
}

/// Subtle repeat of total earnings as a labelled banner below the hero.
class _EarningsBanner extends StatelessWidget {
  const _EarningsBanner({required this.earnings, required this.paid, required this.totalEarnings, required this.fromPaid});
  final double earnings;
  final int paid;
  final String totalEarnings;
  final String fromPaid;
  @override
  Widget build(BuildContext context) {
    return KCard(
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.payments_rounded, color: AppColors.primary),
          ),
          Gap.m,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(totalEarnings, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  '₹${earnings.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ],
            ),
          ),
          Text(
            '$paid $fromPaid',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => KCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(label, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      );
}
