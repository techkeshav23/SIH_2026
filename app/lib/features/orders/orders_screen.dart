import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Incoming Orders')),
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Could not load orders')),
        data: (items) => items.isEmpty
            ? const _Empty()
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Order #${order.id.substring(0, 6)}',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
                _StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Qty: ${order.quantity} × ₹${order.unitPrice.toStringAsFixed(0)}'),
                Text('₹${order.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 18)),
              ],
            ),
            if (order.note != null && order.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(order.note!, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            ],
            if (order.isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _act(context, () => api.rejectOrder(order.id), 'rejected'),
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
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final colors = {
      'pending': AppColors.accent,
      'accepted': AppColors.success,
      'rejected': Colors.red,
      'paid': AppColors.primary,
      'shipped': Colors.blue,
      'completed': Colors.green,
      'cancelled': Colors.grey,
    };
    final c = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 72, color: AppColors.muted),
            SizedBox(height: 12),
            Text('No orders yet', style: TextStyle(color: AppColors.muted, fontSize: 16)),
          ],
        ),
      );
}
