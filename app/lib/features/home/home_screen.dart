import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';
import '../notifications/notifications_screen.dart';

final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  final list = await ref.read(apiProvider).listProducts();
  ref.keepAlive(); // survive tab switches so the list isn't refetched every tap
  return list;
});

final pendingProvider = FutureProvider.autoDispose<int>((ref) async {
  return (await LocalStore.pendingDrafts()).length;
});

/// Everything the home landing needs: artisan name, business snapshot, and how
/// many bulk quotes await the artisan's response.
class HomeHead {
  final String? name;
  final ArtisanStats? stats;
  final int openQuotes;
  const HomeHead({this.name, this.stats, this.openQuotes = 0});
}

final homeHeadProvider = FutureProvider.autoDispose<HomeHead>((ref) async {
  final api = ref.read(apiProvider);
  // Fire all three GETs concurrently — awaiting them in sequence made Home's
  // first paint wait for the sum of three round-trips. Handlers are attached at
  // creation so an early failure never surfaces as an unhandled error.
  final nameF = api.getMe().then<String?>((u) => u.name, onError: (_) => null);
  final statsF =
      api.artisanStats().then<ArtisanStats?>((s) => s, onError: (_) => null);
  final quotesF = api.incomingQuotes().then<int>(
      (qs) => qs.where((q) => q.isOpen && q.turn == 'artisan').length,
      onError: (_) => 0);
  final name = await nameF;
  final stats = await statsF;
  final openQuotes = await quotesF;
  ref.keepAlive();
  return HomeHead(name: name, stats: stats, openQuotes: openQuotes);
});

// ─────────────────────────────────────────────────────────────────────────────
// HOME — a rich landing: gradient hero + snapshot + quick action + carousel.
// ─────────────────────────────────────────────────────────────────────────────
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final hi = lang == AppLang.hi;
    final products = ref.watch(productsProvider);
    final pending = ref.watch(pendingProvider).valueOrNull ?? 0;
    final head = ref.watch(homeHeadProvider).valueOrNull;
    String t(String k) => T.of(context, lang, k);

    Future<void> refreshAll() async {
      ref.invalidate(productsProvider);
      ref.invalidate(pendingProvider);
      ref.invalidate(homeHeadProvider);
    }

    // Light status-bar icons over the coloured hero.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: AppScaffold(
        current: 0,
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: refreshAll,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Hero(head: head, hi: hi, unread: ref.watch(unreadProvider).valueOrNull ?? 0),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AddProductHero(hi: hi, onTap: () async {
                      await context.push('/create');
                      refreshAll();
                    }),
                    _AttentionSection(
                      pendingOrders: head?.stats?.ordersPending ?? 0,
                      openQuotes: head?.openQuotes ?? 0, hi: hi),
                    if (pending > 0) ...[
                      Gap.m,
                      _PendingBanner(count: pending, onSync: () async {
                        final n = await ref.read(apiProvider).syncPendingDrafts();
                        refreshAll();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(n > 0 ? '$n draft(s) synced' : 'Still offline')));
                        }
                      }),
                    ],
                    Gap.l,
                    _SectionHeader(
                      title: t('my_products'),
                      actionLabel: hi ? 'सभी देखें' : 'See all',
                      onAction: () => context.go('/products'),
                    ),
                    Gap.s,
                    products.when(
                      loading: () => const Padding(padding: EdgeInsets.all(40), child: KLoading()),
                      error: (e, _) => KErrorState(
                          message: hi ? 'सर्वर से संपर्क नहीं हुआ' : 'Could not reach server',
                          onRetry: () => ref.invalidate(productsProvider)),
                      data: (items) => items.isEmpty
                          ? _EmptyProducts(hi: hi, onAdd: () async {
                              await context.push('/create');
                              refreshAll();
                            })
                          : _ProductCarousel(items: items, api: ref.read(apiProvider),
                              onTap: (p) async {
                                await context.push('/product/${p.id}');
                                refreshAll();
                              }),
                    ),
                    Gap.l,
                    _TipCard(hi: hi),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient hero with a top bar, greeting, and two glass snapshot cards.
class _Hero extends ConsumerWidget {
  const _Hero({required this.head, required this.hi, required this.unread});
  final HomeHead? head;
  final bool hi;
  final int unread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = head?.name;
    final s = head?.stats;
    final greeting = (name != null && name.isNotEmpty)
        ? '${hi ? 'नमस्ते' : 'Namaste'}, $name'
        : (hi ? 'नमस्ते!' : 'Namaste!');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(Radii.xl)),
        image: DecorationImage(
          image: AssetImage('assets/hero.jpg'),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
      // warm scrim BETWEEN the AI photo and the content so white text + glass
      // cards stay crisp while the craft imagery shows through.
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xE68F3620), Color(0xC2BE4A2F)],
          ),
        ),
        padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 12, 12, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // top bar
          Row(children: [
            Builder(builder: (c) => IconButton(
              onPressed: () => Scaffold.of(c).openDrawer(),
              icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 26),
            )),
            const Spacer(),
            const Text('KalaSetu',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
            const Spacer(),
            Stack(alignment: Alignment.center, children: [
              IconButton(
                onPressed: () => context.push('/notifications'),
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 24)),
              if (unread > 0)
                Positioned(right: 10, top: 10, child: Container(width: 9, height: 9,
                    decoration: BoxDecoration(color: AppColors.accent, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5)))),
            ]),
            IconButton(
              onPressed: () => ref.read(langProvider.notifier).state = hi ? AppLang.en : AppLang.hi,
              icon: const Icon(Icons.translate_rounded, color: Colors.white, size: 22)),
          ]),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(greeting,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(hi ? 'आपका व्यापार एक नज़र में' : 'Your business at a glance',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13.5)),
            ]),
          ),
          const SizedBox(height: 18),
          Row(children: [
            _GlassStat(
              icon: Icons.account_balance_wallet_outlined,
              label: hi ? 'कुल कमाई' : 'Earnings',
              value: s == null ? '—' : rupees(s.earnings),
              onTap: () => context.push('/dashboard')),
            const SizedBox(width: 12),
            _GlassStat(
              icon: Icons.receipt_long_outlined,
              label: hi ? 'ऑर्डर' : 'Orders',
              value: s == null ? '—' : '${s.ordersTotal}',
              onTap: () => context.go('/orders')),
          ]),
          ],
        ),
      ),
    );
  }
}

/// Translucent "glass" stat card that sits on the gradient hero.
class _GlassStat extends StatelessWidget {
  const _GlassStat({required this.icon, required this.label, required this.value, required this.onTap});
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.md),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 8),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
          ]),
        ),
      ),
    );
  }
}

/// The hero action — turn a photo + voice into a ready listing.
class _AddProductHero extends StatelessWidget {
  const _AddProductHero({required this.hi, required this.onTap});
  final bool hi;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.30)),
          boxShadow: Decor.soft,
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(gradient: Decor.warmGradient, borderRadius: BorderRadius.circular(Radii.sm)),
            child: const Icon(Icons.add_a_photo_rounded, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hi ? 'नया उत्पाद बनाएं' : 'Create a new product',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(hi ? 'फ़ोटो + आवाज़ → तैयार लिस्टिंग' : 'Photo + voice → a ready listing',
                  style: Theme.of(context).textTheme.bodyMedium),
            ]),
          ),
          const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
        ]),
      ),
    );
  }
}

/// "Needs your attention" — pending orders + open bulk quotes.
class _AttentionSection extends StatelessWidget {
  const _AttentionSection({required this.pendingOrders, required this.openQuotes, required this.hi});
  final int pendingOrders;
  final int openQuotes;
  final bool hi;
  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];
    if (pendingOrders > 0) {
      chips.add(_chip(context, Icons.inbox_rounded, '$pendingOrders ${hi ? 'नए ऑर्डर' : 'orders'}',
          hi ? 'जवाब दें' : 'to review', () => context.go('/orders')));
    }
    if (openQuotes > 0) {
      chips.add(_chip(context, Icons.gavel_rounded, '$openQuotes ${hi ? 'सौदे' : 'quotes'}',
          hi ? 'आपकी बारी' : 'your turn', () => context.go('/quotes')));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 18),
      Text(hi ? 'आपका ध्यान चाहिए' : 'Needs your attention',
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Row(children: [
        for (int i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: chips[i]),
        ],
      ]),
    ]);
  }

  Widget _chip(BuildContext c, IconData icon, String big, String small, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(big, style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text, fontSize: 14)),
              Text(small, style: const TextStyle(color: AppColors.textSoft, fontSize: 11.5, fontWeight: FontWeight.w600)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// Section header with a "see all" action.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.actionLabel, required this.onAction});
  final String title;
  final String actionLabel;
  final VoidCallback onAction;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            child: Row(children: [
              Text(actionLabel),
              const Icon(Icons.chevron_right_rounded, size: 18),
            ]),
          ),
        ],
      );
}

/// Horizontal, image-forward product carousel.
class _ProductCarousel extends StatelessWidget {
  const _ProductCarousel({required this.items, required this.api, required this.onTap});
  final List<Product> items;
  final Api api;
  final void Function(Product) onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 208,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _CarouselCard(p: items[i], api: api, onTap: () => onTap(items[i])),
      ),
    );
  }
}

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({required this.p, required this.api, required this.onTap});
  final Product p;
  final Api api;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final hi = ProviderScope.containerOf(context).read(langProvider) == AppLang.hi;
    final img = p.enhancedImageUrl ?? p.rawImageUrl;
    final price = p.finalPrice ?? p.suggestedPriceMax;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.line),
          boxShadow: Decor.soft,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            KNetImage(img == null ? null : api.mediaUrl(img), width: 150, height: 130, radius: 0),
            Positioned(top: 8, left: 8, child: KStatusPill(p.status)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.titleFor(hi) ?? (hi ? 'ड्राफ़्ट' : 'Draft'),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 3),
              Text(price != null ? rupees(price) : (hi ? 'क़ीमत बाकी' : 'No price'),
                  style: TextStyle(
                      color: price != null ? AppColors.text : AppColors.muted,
                      fontWeight: FontWeight.w800, fontSize: 14)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.hi, required this.onAdd});
  final bool hi;
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(children: [
          const Icon(Icons.add_a_photo_outlined, size: 40, color: AppColors.primary),
          const SizedBox(height: 12),
          Text(hi ? 'अभी कोई उत्पाद नहीं' : 'No products yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(hi ? 'ऊपर बटन से पहला उत्पाद जोड़ें।' : 'Add your first from the card above.',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );
}

/// A friendly selling tip.
class _TipCard extends StatelessWidget {
  const _TipCard({required this.hi});
  final bool hi;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.indigo.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.indigo.withValues(alpha: 0.20)),
        ),
        child: Row(children: [
          const Icon(Icons.lightbulb_outline_rounded, color: AppColors.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hi ? 'सुझाव: साफ़ रोशनी में खींची फ़ोटो 3 गुना तेज़ बिकती है।'
                 : 'Tip: a photo in clear light sells up to 3× faster.',
              style: Theme.of(context).textTheme.bodyMedium),
          ),
        ]),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCTS — the artisan's full product list (its own tab).
// ─────────────────────────────────────────────────────────────────────────────
class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final hi = lang == AppLang.hi;
    final products = ref.watch(productsProvider);
    String t(String k) => T.of(context, lang, k);

    Future<void> refresh() async {
      ref.invalidate(productsProvider);
      ref.invalidate(homeHeadProvider);
    }

    return AppScaffold(
      current: 1,
      fab: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/create');
          refresh();
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: Text(t('add_product')),
      ),
      body: Column(children: [
        KHeader(title: t('my_products'), leading: drawerButton()),
        Expanded(
          child: products.when(
            loading: () => const KLoading(),
            error: (e, _) => KErrorState(
                message: hi ? 'सर्वर से संपर्क नहीं हुआ' : 'Could not reach server',
                onRetry: () => ref.invalidate(productsProvider)),
            data: (items) => items.isEmpty
                ? KEmpty(
                    icon: Icons.add_a_photo_outlined,
                    title: hi ? 'अभी कोई उत्पाद नहीं' : 'No products yet',
                    subtitle: hi ? 'नीचे बटन दबाकर पहला उत्पाद जोड़ें।'
                        : 'Tap the button below to add your first.')
                : RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: refresh,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => _ProductCard(
                          p: items[i], api: ref.read(apiProvider),
                          onTap: () async {
                            await context.push('/product/${items[i].id}');
                            refresh();
                          }),
                    ),
                  ),
          ),
        ),
      ]),
    );
  }
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onSync});
  final int count;
  final VoidCallback onSync;
  @override
  Widget build(BuildContext context) {
    final lang = ProviderScope.containerOf(context).read(langProvider);
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        const Icon(Icons.cloud_off_rounded, size: 20, color: AppColors.primaryDark),
        const SizedBox(width: 10),
        Expanded(child: Text('$count ${T.of(context, lang, 'drafts_waiting')}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text))),
        TextButton(onPressed: onSync, child: Text(T.of(context, lang, 'sync_now'))),
      ]),
    );
  }
}

/// Row card used in the full products list.
class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.p, required this.api, required this.onTap});
  final Product p;
  final Api api;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final img = p.enhancedImageUrl ?? p.rawImageUrl;
    final hi = ProviderScope.containerOf(context).read(langProvider) == AppLang.hi;
    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          KNetImage(img == null ? null : api.mediaUrl(img), width: 76, height: 76),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.titleFor(hi) ?? 'Draft',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                if (p.finalPrice != null)
                  Text(rupees(p.finalPrice!),
                      style: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w800, fontSize: 15))
                else if (p.suggestedPriceMin != null || p.suggestedPriceMax != null)
                  Text(
                      (p.suggestedPriceMin != null && p.suggestedPriceMax != null)
                          ? '${rupees(p.suggestedPriceMin!)} – ${rupees(p.suggestedPriceMax!)}'
                          : rupees(p.suggestedPriceMax ?? p.suggestedPriceMin!),
                      style: const TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w700, fontSize: 13.5)),
                const SizedBox(height: 8),
                KStatusPill(p.status),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}
