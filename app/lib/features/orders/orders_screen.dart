import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

final incomingOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  return ref.read(apiProvider).incomingOrders();
});

/// Artisan's view of incoming B2B orders with accept / reject actions.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(incomingOrdersProvider);
    return AppScaffold(
      current: 1,
      body: Column(
        children: [
          KHeader(
            title: 'Incoming Orders',
            subtitle: 'Review and respond to buyer requests',
            leading: drawerButton(),
          ),
          Expanded(
            child: orders.when(
              loading: () => const KLoading(),
              error: (e, _) => KErrorState(
                message: 'Could not load orders',
                onRetry: () => ref.invalidate(incomingOrdersProvider),
              ),
              data: (items) => items.isEmpty
                  ? const KEmpty(
                      icon: Icons.inbox_outlined,
                      title: 'No orders yet',
                      subtitle: 'New buyer orders will appear here.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(incomingOrdersProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _OrderCard(order: items[i], ref: ref),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.ref});
  final Order order;
  final WidgetRef ref;

  Future<void> _act(BuildContext context, Future<Order> Function() action, String label) async {
    try {
      await action();
      ref.invalidate(incomingOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order $label ✓')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiProvider);
    return KCard(
      onTap: () => context.push('/order-detail', extra: order),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: const Icon(Icons.receipt_long, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Order #${order.id.substring(0, 6)}',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              KStatusPill(order.status),
            ],
          ),
          Gap.m,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Qty: ${order.quantity} × ₹${order.unitPrice.toStringAsFixed(0)}',
                  style: Theme.of(context).textTheme.bodyMedium),
              Text('₹${order.totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                    fontSize: 22,
                    letterSpacing: -0.5,
                  )),
            ],
          ),
          if (order.note != null && order.note!.isNotEmpty) ...[
            Gap.s,
            Text(order.note!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (order.isPending) ...[
            Gap.m,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final ok = await confirmDialog(context,
                          title: 'Reject order?',
                          message: 'This will decline the buyer\'s order.',
                          confirm: 'Reject', danger: true);
                      if (ok && context.mounted) {
                        await _act(context, () => api.rejectOrder(order.id), 'rejected');
                      }
                    },
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _act(context, () => api.acceptOrder(order.id), 'accepted'),
                    child: const Text('Accept'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
