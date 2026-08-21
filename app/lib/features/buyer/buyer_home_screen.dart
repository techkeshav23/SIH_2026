import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';

final buyerFeedProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  return ref.read(apiProvider).buyerFeed();
});

final myOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  return ref.read(apiProvider).myOrders();
});

/// Buyer app shell: browse the marketplace and track orders.
class BuyerHomeScreen extends ConsumerStatefulWidget {
  const BuyerHomeScreen({super.key});
  @override
  ConsumerState<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends ConsumerState<BuyerHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Marketplace' : 'My Orders'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ref.read(apiProvider).logout();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: _tab == 0 ? const _BrowseTab() : const _MyOrdersTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.storefront), label: 'Browse'),
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Orders'),
        ],
      ),
    );
  }
}

// ---------------- Browse ----------------
class _BrowseTab extends ConsumerWidget {
  const _BrowseTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(buyerFeedProvider);
    final api = ref.read(apiProvider);
    return feed.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Could not load marketplace')),
      data: (items) => items.isEmpty
          ? const Center(child: Text('No products listed yet.'))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(buyerFeedProvider),
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 0.66, crossAxisSpacing: 12, mainAxisSpacing: 12),
                itemCount: items.length,
                itemBuilder: (_, i) => _ProductTile(
                  product: items[i], api: api,
                  onOrder: () => _openOrderSheet(context, ref, items[i]),
                ),
              ),
            ),
    );
  }

  void _openOrderSheet(BuildContext context, WidgetRef ref, Product p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _OrderSheet(product: p, ref: ref),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.api, required this.onOrder});
  final Product product;
  final Api api;
  final VoidCallback onOrder;
  @override
  Widget build(BuildContext context) {
    final img = product.enhancedImageUrl ?? product.rawImageUrl;
    final price = product.finalPrice ?? product.suggestedPriceMax;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: img != null
                ? Image.network(api.mediaUrl(img), width: double.infinity, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _Ph())
                : const _Ph(),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.titleEn ?? product.titleHi ?? 'Product',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(price != null ? '₹${price.toStringAsFixed(0)}' : '',
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onOrder,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(34)),
                    child: const Text('Order', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderSheet extends StatefulWidget {
  const _OrderSheet({required this.product, required this.ref});
  final Product product;
  final WidgetRef ref;
  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  int _qty = 1;
  bool _placing = false;

  Future<void> _place() async {
    setState(() => _placing = true);
    try {
      await widget.ref.read(apiProvider).placeOrder(widget.product.id, _qty);
      widget.ref.invalidate(myOrdersProvider);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed — awaiting artisan approval ✓')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not place order')));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.product.finalPrice ?? widget.product.suggestedPriceMax ?? 0;
    return Padding(
      padding: EdgeInsets.only(left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.product.titleEn ?? widget.product.titleHi ?? 'Product',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Quantity', style: TextStyle(fontSize: 16)),
              Row(
                children: [
                  IconButton(onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
                      icon: const Icon(Icons.remove_circle_outline)),
                  Text('$_qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => setState(() => _qty++),
                      icon: const Icon(Icons.add_circle_outline)),
                ],
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total', style: TextStyle(fontSize: 16)),
              Text('₹${(price * _qty).toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.success)),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _placing ? null : _place,
            icon: const Icon(Icons.check),
            label: Text(_placing ? 'Placing…' : 'Place order'),
          ),
        ],
      ),
    );
  }
}

// ---------------- My Orders ----------------
class _MyOrdersTab extends ConsumerWidget {
  const _MyOrdersTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(myOrdersProvider);
    return orders.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(child: Text('Could not load orders')),
      data: (items) => items.isEmpty
          ? const Center(child: Text('No orders yet — browse the marketplace.'))
          : RefreshIndicator(
              onRefresh: () async => ref.invalidate(myOrdersProvider),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _BuyerOrderCard(order: items[i], ref: ref),
              ),
            ),
    );
  }
}

class _BuyerOrderCard extends StatelessWidget {
  const _BuyerOrderCard({required this.order, required this.ref});
  final Order order;
  final WidgetRef ref;

  Future<void> _pay(BuildContext context) async {
    try {
      await ref.read(apiProvider).payAndConfirm(order.id);
      ref.invalidate(myOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment successful ✓')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Order #${order.id.substring(0, 6)}',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16))),
                _StatusChip(status: order.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Qty: ${order.quantity}'),
                Text('₹${order.totalPrice.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 18)),
              ],
            ),
            if (order.isAccepted) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _pay(context),
                  icon: const Icon(Icons.payment),
                  label: const Text('Pay now'),
                ),
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
      'pending': AppColors.accent, 'accepted': AppColors.success, 'rejected': Colors.red,
      'paid': AppColors.primary, 'shipped': Colors.blue, 'completed': Colors.green, 'cancelled': Colors.grey,
    };
    final c = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Ph extends StatelessWidget {
  const _Ph();
  @override
  Widget build(BuildContext context) => Container(
        color: AppColors.bg, child: const Center(child: Icon(Icons.image_outlined, color: AppColors.muted)));
}
