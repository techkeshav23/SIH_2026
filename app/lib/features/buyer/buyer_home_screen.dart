import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/tts.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/cart.dart';
import '../../data/models.dart';
import '../notifications/notifications_screen.dart';

/// App-bar icon with a small count badge (cart / notifications).
class KBadgeIcon extends StatelessWidget {
  const KBadgeIcon({super.key, required this.icon, required this.count, required this.onTap});
  final IconData icon;
  final int count;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Stack(
        alignment: Alignment.center,
        children: [
          IconButton(icon: Icon(icon), onPressed: onTap),
          if (count > 0)
            Positioned(
              right: 6, top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(10)),
                constraints: const BoxConstraints(minWidth: 17),
                child: Text('${count > 99 ? '99+' : count}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
              ),
            ),
        ],
      );
}

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
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(bottom: BorderSide(color: AppColors.line)),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44, padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(Radii.sm),
                  border: Border.all(color: AppColors.line),
                ),
                child: Image.asset('assets/icon/logo.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('KalaSetu',
                    style: TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 1),
                Text(api.demoMode ? (hi ? 'डेमो · खरीदार' : 'Demo · Buyer') : (hi ? 'खरीदार खाता' : 'Buyer account'),
                    style: const TextStyle(color: AppColors.textSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.translate_rounded, color: AppColors.textSoft),
            title: Text(hi ? 'भाषा: हिंदी' : 'Language: English',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () => ref.read(langProvider.notifier).state = hi ? AppLang.en : AppLang.hi,
          ),
          ListTile(
            leading: const Icon(Icons.gavel_rounded, color: AppColors.textSoft),
            title: Text(hi ? 'थोक सौदे' : 'Bulk Quotes', style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(context); context.push('/quotes'); },
          ),
          ListTile(
            leading: const Icon(Icons.settings_rounded, color: AppColors.textSoft),
            title: Text(hi ? 'सेटिंग्स' : 'Settings', style: const TextStyle(fontWeight: FontWeight.w600)),
            onTap: () { Navigator.pop(context); context.push('/settings'); },
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
              ref.invalidate(cartProvider); // don't leak the cart into the next account
              if (context.mounted) context.go('/login');
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('KalaSetu v1.0', style: Theme.of(context).textTheme.labelSmall),
              GestureDetector(
                onTap: () { Navigator.pop(context); context.push('/privacy'); },
                child: Text(hi ? 'गोपनीयता नीति' : 'Privacy Policy',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary)),
              ),
            ]),
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

final buyerSearchProvider = StateProvider<String>((ref) => '');
final buyerCategoryProvider = StateProvider<String?>((ref) => null);

class _CatChip extends StatelessWidget {
  const _CatChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
          showCheckmark: false,
          selectedColor: AppColors.primary,
          labelStyle: TextStyle(
              color: selected ? Colors.white : AppColors.textSoft,
              fontWeight: FontWeight.w600, fontSize: 13),
          backgroundColor: AppColors.surface,
          side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
        ),
      );
}

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
    final lang = ref.watch(langProvider);
    final title = T.of(context, lang, _tab == 0 ? 'marketplace' : 'my_orders');
    return Scaffold(
      drawer: const _BuyerDrawer(),
      appBar: AppBar(
        title: Text(title),
        actions: [
          KBadgeIcon(
            icon: Icons.notifications_none_rounded,
            count: ref.watch(unreadProvider).valueOrNull ?? 0,
            onTap: () => context.push('/notifications'),
          ),
          KBadgeIcon(
            icon: Icons.shopping_cart_outlined,
            count: ref.watch(cartCountProvider),
            onTap: () => context.push('/cart'),
          ),
          KSpeak(title),
        ],
      ),
      body: _tab == 0 ? const _BrowseTab() : const _MyOrdersTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.storefront), label: T.of(context, lang, 'browse')),
          NavigationDestination(icon: const Icon(Icons.receipt_long), label: T.of(context, lang, 'orders')),
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
    final lang = ref.watch(langProvider);
    final q = ref.watch(buyerSearchProvider).toLowerCase();
    final cat = ref.watch(buyerCategoryProvider);

    return feed.when(
      loading: () => const KLoading(),
      error: (e, _) => KErrorState(
        message: T.of(context, lang, 'could_not_load'),
        onRetry: () => ref.invalidate(buyerFeedProvider),
      ),
      data: (all) {
        final cats = <String>{for (final p in all) if (p.category != null) p.category!}.toList()..sort();
        final items = all.where((p) {
          final okCat = cat == null || p.category == cat;
          final hay = '${p.titleEn ?? ''} ${p.titleHi ?? ''} ${p.category ?? ''} ${p.tags.join(' ')}'.toLowerCase();
          return okCat && (q.isEmpty || hay.contains(q));
        }).toList();

        return Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              onChanged: (v) => ref.read(buyerSearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: T.of(context, lang, 'search'),
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              ),
            ),
          ),
          if (cats.isNotEmpty)
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _CatChip(label: T.of(context, lang, 'all'), selected: cat == null,
                      onTap: () => ref.read(buyerCategoryProvider.notifier).state = null),
                  for (final c in cats)
                    _CatChip(label: c, selected: cat == c,
                        onTap: () => ref.read(buyerCategoryProvider.notifier).state = c),
                ],
              ),
            ),
          Expanded(
            child: items.isEmpty
                ? KEmpty(
                    icon: Icons.search_off_rounded,
                    title: T.of(context, lang, 'no_listed'),
                  )
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: () async => ref.invalidate(buyerFeedProvider),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2, childAspectRatio: 0.72, crossAxisSpacing: 14, mainAxisSpacing: 14),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) => _ProductTile(
                        product: items[i], api: api,
                        onOrder: () => _openOrderSheet(context, ref, items[i]),
                        onTap: () => ctx.push('/buyer/product', extra: items[i]),
                      ),
                    ),
                  ),
          ),
        ]);
      },
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

class _ProductTile extends ConsumerWidget {
  const _ProductTile({required this.product, required this.api, required this.onOrder, required this.onTap});
  final Product product;
  final Api api;
  final VoidCallback onOrder;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
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
            child: GestureDetector(
              onTap: onTap,
              child: KNetImage(
                img != null ? api.mediaUrl(img) : null,
                width: double.infinity,
                radius: 0,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.titleFor(lang == AppLang.hi) ?? 'Product',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                if ((product.category ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(product.category!,
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall),
                ],
                const SizedBox(height: 6),
                if (price == null)
                  Text(T.of(context, lang, 'price_on_request'),
                      style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w600, fontSize: 13))
                else
                  Builder(builder: (_) {
                    final mrp = product.suggestedPriceMax;
                    final hasDiscount = product.finalPrice != null && mrp != null && mrp > product.finalPrice!;
                    final off = hasDiscount ? (((mrp - price) / mrp) * 100).round() : 0;
                    return Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic, children: [
                      Text(rupees(price),
                          style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 16)),
                      if (hasDiscount) ...[
                        const SizedBox(width: 6),
                        Text(rupees(mrp),
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12, decoration: TextDecoration.lineThrough)),
                        const SizedBox(width: 5),
                        Text('$off% off',
                            style: const TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ]);
                  }),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onOrder,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(40)),
                    child: Text(T.of(context, lang, 'order'), style: const TextStyle(fontSize: 14)),
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
        final lang = widget.ref.read(langProvider);
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.of(context, lang, 'order_placed'))),
        );
      }
    } catch (_) {
      if (mounted) {
        final lang = widget.ref.read(langProvider);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(T.of(context, lang, 'try_again'))));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.ref.watch(langProvider);
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
          Text(widget.product.titleFor(ProviderScope.containerOf(context).read(langProvider) == AppLang.hi) ?? 'Product',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(T.of(context, lang, 'quantity'), style: Theme.of(context).textTheme.titleMedium),
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
              Text(T.of(context, lang, 'total'), style: Theme.of(context).textTheme.titleMedium),
              Text(rupees(price * _qty),
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
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
            label: Text(_placing ? T.of(context, lang, 'processing') : T.of(context, lang, 'place_order')),
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
    final lang = ref.watch(langProvider);
    return orders.when(
      loading: () => const KLoading(),
      error: (e, _) => KErrorState(
        message: T.of(context, lang, 'could_not_load'),
        onRetry: () => ref.invalidate(myOrdersProvider),
      ),
      data: (items) => items.isEmpty
          ? KEmpty(
              icon: Icons.receipt_long_outlined,
              title: T.of(context, lang, 'no_orders'),
              subtitle: lang == AppLang.hi
                  ? 'पहला ऑर्डर करने के लिए बाज़ार देखें।'
                  : 'Browse the marketplace to place your first order.',
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

class _BuyerOrderCard extends ConsumerWidget {
  const _BuyerOrderCard({required this.order, required this.ref});
  final Order order;
  final WidgetRef ref;

  Future<void> _pay(BuildContext context) async {
    final lang = ref.read(langProvider);
    try {
      await ref.read(apiProvider).payAndConfirm(order.id);
      ref.invalidate(myOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(T.of(context, lang, 'payment_ok'))));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(T.of(context, lang, 'try_again'))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    return KCard(
      onTap: () => context.push('/order-detail', extra: order),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KNetImage(order.productImage, width: 52, height: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(order.productTitle ?? '${T.of(context, lang, 'order_no')} #${order.shortId}',
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('${T.of(context, lang, 'order_no')} #${order.shortId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              KStatusPill(order.status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${T.of(context, lang, 'qty')}: ${order.quantity}', style: Theme.of(context).textTheme.bodyMedium),
              Text(rupees(order.totalPrice),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.text, fontSize: 20)),
            ],
          ),
          if (order.isAccepted) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _pay(context),
                icon: const Icon(Icons.payment),
                label: Text(T.of(context, lang, 'pay_now')),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
