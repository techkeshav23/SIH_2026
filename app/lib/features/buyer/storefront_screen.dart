import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

/// Public artisan storefront — bio + their listed products. Reached from a
/// product's "View shop" link.
class StorefrontScreen extends ConsumerStatefulWidget {
  const StorefrontScreen({super.key, required this.artisanId});
  final String artisanId;

  @override
  ConsumerState<StorefrontScreen> createState() => _StorefrontScreenState();
}

class _StorefrontScreenState extends ConsumerState<StorefrontScreen> {
  Storefront? _shop;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _shop = await ref.read(apiProvider).getStorefront(widget.artisanId);
    } catch (_) {
      _shop = null;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final api = ref.read(apiProvider);
    final text = Theme.of(context).textTheme;
    String t(String k) => T.of(context, lang, k);
    final shop = _shop;

    return Scaffold(
      appBar: AppBar(title: Text(t('shop'))),
      body: _loading
          ? const Center(child: KLoading())
          : shop == null
              ? KEmpty(icon: Icons.storefront_outlined, title: t('could_not_load'))
              : CustomScrollView(slivers: [
                  SliverToBoxAdapter(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      decoration: BoxDecoration(gradient: Decor.warmGradient),
                      child: Column(children: [
                        CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white,
                          child: Text(
                            (shop.name?.trim().isNotEmpty ?? false) ? shop.name!.trim().characters.first : 'K',
                            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(shop.name ?? t('shop'),
                            style: text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                        if ((shop.craftType ?? '').isNotEmpty)
                          Text(shop.craftType!, style: const TextStyle(color: Colors.white70)),
                        if ((shop.region ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.place_outlined, size: 15, color: Colors.white70),
                              const SizedBox(width: 4),
                              Text(shop.region!, style: const TextStyle(color: Colors.white70)),
                            ]),
                          ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                              color: Colors.white24, borderRadius: BorderRadius.circular(Radii.pill)),
                          child: Text('${shop.products.length} ${t('products')}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ]),
                    ),
                  ),
                  if (shop.products.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: KEmpty(icon: Icons.inventory_2_outlined, title: t('no_listed')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.72),
                        delegate: SliverChildBuilderDelegate(
                          (_, i) {
                            final p = shop.products[i];
                            final img = p.enhancedImageUrl ?? p.rawImageUrl;
                            return KCard(
                              padding: EdgeInsets.zero,
                              onTap: () => context.push('/buyer/product', extra: p),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.md)),
                                  child: KNetImage(img == null ? null : api.mediaUrl(img),
                                      height: 120, width: double.infinity),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(p.titleFor(lang == AppLang.hi) ?? 'Product',
                                        maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                                    const SizedBox(height: 4),
                                    Text(rupees(p.finalPrice ?? p.suggestedPriceMax ?? 0),
                                        style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.text)),
                                  ]),
                                ),
                              ]),
                            );
                          },
                          childCount: shop.products.length,
                        ),
                      ),
                    ),
                ]),
    );
  }
}
