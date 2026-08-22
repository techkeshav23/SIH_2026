import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

/// Sidebar for the buyer app — brand, language, logout.
class _BuyerDrawer extends ConsumerWidget {
  const _BuyerDrawer();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hi = ref.watch(langProvider) == AppLang.hi;
    final api = ref.read(apiProvider);
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
            decoration: const BoxDecoration(gradient: Decor.heroGradient),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 56, height: 56, padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                child: Image.asset('assets/icon/logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(height: 14),
              const Text('KalaSetu',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              const SizedBox(height: 2),
              Text(api.demoMode ? (hi ? 'डेमो · खरीदार' : 'Demo · Buyer') : (hi ? 'खरीदार खाता' : 'Buyer account'),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
            ]),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.translate_rounded, color: AppColors.textSoft),
            title: Text(hi ? 'भाषा: हिंदी' : 'Language: English',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => ref.read(langProvider.notifier).state = hi ? AppLang.en : AppLang.hi,
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger),
            title: Text(hi ? 'लॉग आउट' : 'Logout',
                style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            onTap: () async {
              Navigator.pop(context);
              final ok = await confirmDialog(context,
                  title: hi ? 'लॉग आउट करें?' : 'Logout?',
                  message: hi ? 'KalaSetu से साइन आउट करें?' : 'Sign out of KalaSetu?',
                  confirm: hi ? 'लॉग आउट' : 'Logout', danger: true);
              if (!ok || !context.mounted) return;
              await api.logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('SIH 2026 · PS 26090',
                style: TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.4)),
          ),
        ]),
      ),
    );
  }
}

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
      drawer: const _BuyerDrawer(),
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Marketplace' : 'My Orders'),
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
      loading: () => const KLoading(),
      error: (e, _) => KErrorState(
        message: 'Could not load marketplace',
        onRetry: () => ref.invalidate(buyerFeedProvider),
      ),
      data: (items) => items.isEmpty
          ? const KEmpty(
              icon: Icons.storefront_outlined,
              title: 'No products yet',
              subtitle: 'New handmade pieces will appear here soon.',
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => ref.invalidate(buyerFeedProvider),
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, childAspectRatio: 0.62, crossAxisSpacing: 14, mainAxisSpacing: 14),
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: AppColors.line),
        boxShadow: Decor.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: KNetImage(
              img != null ? api.mediaUrl(img) : null,
              width: double.infinity,
              radius: 0,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.titleEn ?? product.titleHi ?? 'Product',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(price != null ? '₹${price.toStringAsFixed(0)}' : '—',
                    style: const TextStyle(
                        color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: -0.2)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onOrder,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                    child: const Text('Order', style: TextStyle(fontSize: 14)),
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
      padding: EdgeInsets.only(left: 20, right: 20, top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44, height: 5,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ),
          Text(widget.product.titleEn ?? widget.product.titleHi ?? 'Product',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Quantity', style: Theme.of(context).textTheme.titleMedium),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StepBtn(
                      icon: Icons.remove,
                      onTap: _qty > 1 ? () => setState(() => _qty--) : null,
                    ),
                    SizedBox(
                      width: 40,
                      child: Text('$_qty',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.text)),
                    ),
                    _StepBtn(
                      icon: Icons.add,
                      onTap: () => setState(() { if (_qty < 99) _qty++; }),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Total', style: Theme.of(context).textTheme.titleMedium),
              Text('₹${(price * _qty).toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.success, letterSpacing: -0.6)),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _placing ? null : _place,
            icon: _placing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(_placing ? 'Placing…' : 'Place order'),
          ),
        ],
      ),
    );
  }
}

/// Rounded tappable button used in the quantity stepper.
class _StepBtn extends StatelessWidget {
  const _StepBtn({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 22,
              color: enabled ? AppColors.primary : AppColors.muted),
        ),
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
      loading: () => const KLoading(),
      error: (e, _) => KErrorState(
        message: 'Could not load orders',
        onRetry: () => ref.invalidate(myOrdersProvider),
      ),
      data: (items) => items.isEmpty
          ? const KEmpty(
              icon: Icons.receipt_long_outlined,
              title: 'No orders yet',
              subtitle: 'Browse the marketplace to place your first order.',
            )
          : RefreshIndicator(
              color: AppColors.primary,
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
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Order #${order.id.substring(0, 6)}',
                  style: Theme.of(context).textTheme.titleMedium)),
              KStatusPill(order.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Qty: ${order.quantity}', style: Theme.of(context).textTheme.bodyMedium),
              Text('₹${order.totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.success, fontSize: 20, letterSpacing: -0.4)),
            ],
          ),
          if (order.isAccepted) ...[
            const SizedBox(height: 14),
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
    );
  }
}
