import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';

final statsProvider = FutureProvider.autoDispose<ArtisanStats>((ref) async {
  return ref.read(apiProvider).artisanStats();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load stats')),
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(statsProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _EarningsCard(earnings: s.earnings, paid: s.ordersPaid),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                children: [
                  _StatCard(label: 'Products', value: '${s.products}', icon: Icons.inventory_2, color: AppColors.primary),
                  _StatCard(label: 'Listed', value: '${s.listed}', icon: Icons.storefront, color: AppColors.accent),
                  _StatCard(label: 'Total orders', value: '${s.ordersTotal}', icon: Icons.receipt_long, color: Colors.blue),
                  _StatCard(label: 'Pending', value: '${s.ordersPending}', icon: Icons.hourglass_top, color: Colors.orange),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.earnings, required this.paid});
  final double earnings;
  final int paid;
  @override
  Widget build(BuildContext context) => Card(
        color: AppColors.primary,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total earnings', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 6),
              Text('₹${earnings.toStringAsFixed(0)}',
                  style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('from $paid paid order(s)', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ],
          ),
        ),
      );
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color),
              Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
          ),
        ),
      );
}
