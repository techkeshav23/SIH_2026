import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/tts.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

/// Buyer-facing product detail page. Product passed via route extra.
class BuyerProductScreen extends ConsumerWidget {
  const BuyerProductScreen({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final hi = lang == AppLang.hi;
    String t(String k) => T.of(context, lang, k);
    final api = ref.read(apiProvider);
    final price = product.finalPrice ?? product.suggestedPriceMax;
    final title = (hi ? product.titleHi : product.titleEn) ?? product.titleEn ?? product.titleHi ?? 'Product';
    final desc = (hi ? product.descHi : product.descEn) ?? product.descEn ?? product.descHi ?? '';

    return Scaffold(
      appBar: AppBar(actions: [KSpeak('$title. ${price != null ? '₹${price.toStringAsFixed(0)}' : ''}. $desc')]),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(t('total'), style: Theme.of(context).textTheme.labelSmall),
              Text(price != null ? '₹${price.toStringAsFixed(0)}' : '—',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.success)),
            ]),
          ),
          FilledButton.icon(
            onPressed: () => _order(context, ref, api, price ?? 0),
            icon: const Icon(Icons.shopping_bag_rounded),
            label: Text(t('order')),
          ),
        ]),
      ),
      body: ListView(
        children: [
          KNetImage(
            product.enhancedImageUrl == null ? null : api.mediaUrl(product.enhancedImageUrl!),
            height: 300, width: double.infinity, radius: 0,
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 6),
              if (price != null)
                Text('₹${price.toStringAsFixed(0)}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: AppColors.success)),
              Gap.m,
              if (product.category != null || product.material != null)
                Row(children: [
                  const Icon(Icons.storefront_rounded, size: 18, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Text('${t('by_artisan')} · ${product.category ?? ''} ${product.material ?? ''}'.trim(),
                      style: Theme.of(context).textTheme.bodyMedium),
                ]),
              Gap.l,
              KSectionTitle(t('about_product')),
              Gap.s,
              Text(desc, style: Theme.of(context).textTheme.bodyLarge),
              if (product.tags.isNotEmpty) ...[
                Gap.m,
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final tag in product.tags) Chip(label: Text('#$tag')),
                ]),
              ],
              Gap.xl,
            ]),
          ),
        ],
      ),
    );
  }

  void _order(BuildContext context, WidgetRef ref, Api api, double unit) {
    int qty = 1;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, setModal) {
          final lang = ref.read(langProvider);
          String t(String k) => T.of(c, lang, k);
          return Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(c).viewInsets.bottom + 24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(2)))),
              Gap.l,
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(t('quantity'), style: Theme.of(c).textTheme.titleMedium),
                Row(children: [
                  IconButton(onPressed: () => setModal(() { if (qty > 1) qty--; }), icon: const Icon(Icons.remove_circle_outline), iconSize: 30),
                  Text('$qty', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(onPressed: () => setModal(() { if (qty < 99) qty++; }), icon: const Icon(Icons.add_circle_outline), iconSize: 30),
                ]),
              ]),
              const Divider(),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(t('total'), style: Theme.of(c).textTheme.titleMedium),
                Text('₹${(unit * qty).toStringAsFixed(0)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.success)),
              ]),
              Gap.l,
              FilledButton.icon(
                onPressed: () async {
                  final nav = Navigator.of(c);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    await api.placeOrder(product.id, qty);
                    nav.pop();
                    if (context.mounted) context.pop();
                    messenger.showSnackBar(SnackBar(content: Text(t('order_placed'))));
                  } catch (_) {
                    messenger.showSnackBar(SnackBar(content: Text(t('try_again'))));
                  }
                },
                icon: const Icon(Icons.check_rounded),
                label: Text(t('place_order')),
              ),
            ]),
          );
        },
      ),
    );
  }
}
