import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

final reviewsProvider =
    FutureProvider.autoDispose.family<List<Review>, String>((ref, id) async {
  return ref.read(apiProvider).getReviews(id);
});

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
    final title = product.titleFor(hi) ?? 'Product';
    final desc = product.descFor(hi) ?? '';

    return Scaffold(
      appBar: AppBar(actions: [KSpeak('$title. ${price != null ? rupees(price) : ''}. $desc')]),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(children: [
          IconButton.outlined(
            onPressed: () {
              ref.read(cartProvider.notifier).add(product);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('added_to_cart'))));
            },
            icon: const Icon(Icons.add_shopping_cart_rounded),
            style: IconButton.styleFrom(
              minimumSize: const Size(54, 54),
              side: const BorderSide(color: AppColors.line),
              foregroundColor: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _order(context, ref, api, price ?? 0),
              icon: const Icon(Icons.shopping_bag_rounded),
              label: Text('${t('order')}  ·  ${rupees(price ?? 0)}'),
            ),
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
                Text(rupees(price),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 24, color: AppColors.text)),
              Gap.m,
              if (product.category != null || product.material != null)
                Row(children: [
                  const Icon(Icons.storefront_rounded, size: 18, color: AppColors.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${t('by_artisan')} · ${product.category ?? ''} ${product.material ?? ''}'.trim(),
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/storefront/${product.userId}'),
                    icon: const Icon(Icons.store_mall_directory_outlined, size: 16),
                    label: Text(t('view_shop')),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  ),
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
              Gap.l,
              // B2B: negotiate a bulk price
              OutlinedButton.icon(
                onPressed: () => _requestQuote(context, ref, api, price ?? 0),
                icon: const Icon(Icons.gavel_rounded, size: 18),
                label: Text(t('bulk_quote')),
              ),
              Gap.l,
              _Reviews(productId: product.id),
              Gap.xl,
            ]),
          ),
        ],
      ),
    );
  }

  void _requestQuote(BuildContext context, WidgetRef ref, Api api, double listPrice) {
    final qtyCtrl = TextEditingController(text: '50');
    final priceCtrl = TextEditingController(
        text: listPrice > 0 ? (listPrice * 0.8).round().toString() : '');
    final msgCtrl = TextEditingController();
    final lang = ref.read(langProvider);
    String t(String k) => T.of(context, lang, k);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(c).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const Icon(Icons.gavel_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(t('bulk_quote'), style: Theme.of(c).textTheme.titleLarge),
          ]),
          if (listPrice > 0) ...[
            const SizedBox(height: 4),
            Text('${t('list_price')}: ${rupees(listPrice)}${t('per_unit')}',
                style: Theme.of(c).textTheme.labelSmall),
          ],
          Gap.m,
          TextField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: t('quote_qty')),
          ),
          Gap.s,
          TextField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: t('your_price_unit'), prefixText: '₹ '),
          ),
          Gap.s,
          TextField(
            controller: msgCtrl,
            maxLines: 2,
            decoration: InputDecoration(labelText: t('message')),
          ),
          Gap.l,
          FilledButton.icon(
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
              final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
              if (qty < 1 || price <= 0) return;
              final nav = Navigator.of(c);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await api.createQuote(product.id, qty, price, message: msgCtrl.text.trim());
                nav.pop();
                messenger.showSnackBar(SnackBar(content: Text(t('quote_sent'))));
                if (context.mounted) context.push('/quotes');
              } catch (_) {
                messenger.showSnackBar(SnackBar(content: Text(t('try_again'))));
              }
            },
            icon: const Icon(Icons.send_rounded),
            label: Text(t('send_request')),
          ),
        ]),
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
                Text(rupees(unit * qty),
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text)),
              ]),
              Gap.l,
              FilledButton.icon(
                onPressed: () async {
                  final nav = Navigator.of(c);
                  final messenger = ScaffoldMessenger.of(context);
                  try {
                    // Attach the buyer's default delivery address if they have one.
                    String? addrId;
                    try {
                      final addrs = await api.listAddresses();
                      if (addrs.isNotEmpty) {
                        addrId = addrs.firstWhere((a) => a.isDefault, orElse: () => addrs.first).id;
                      }
                    } catch (_) {/* address optional */}
                    await api.placeOrder(product.id, qty, addressId: addrId);
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

class _Reviews extends ConsumerWidget {
  const _Reviews({required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final reviews = ref.watch(reviewsProvider(productId));
    String t(String k) => T.of(context, lang, k);

    return reviews.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (list) {
        final avg = list.isEmpty ? 0.0 : list.map((r) => r.rating).reduce((a, b) => a + b) / list.length;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: KSectionTitle('${t('reviews')} (${list.length})')),
            if (list.isNotEmpty) ...[
              _Stars(avg),
              const SizedBox(width: 6),
              Text(avg.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800)),
            ],
          ]),
          Gap.s,
          if (list.isEmpty)
            Text(t('no_reviews'), style: Theme.of(context).textTheme.bodyMedium)
          else
            for (final r in list)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    _Stars(r.rating.toDouble(), size: 15),
                    const SizedBox(width: 8),
                    Text(r.author, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    if (r.date != null) Text(r.date!, style: Theme.of(context).textTheme.labelSmall),
                  ]),
                  const SizedBox(height: 3),
                  Text(r.text, style: Theme.of(context).textTheme.bodyMedium),
                ]),
              ),
          Gap.s,
          OutlinedButton.icon(
            onPressed: () => _write(context, ref),
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(t('write_review')),
          ),
        ]);
      },
    );
  }

  void _write(BuildContext context, WidgetRef ref) {
    int rating = 5;
    final ctrl = TextEditingController();
    final lang = ref.read(langProvider);
    String t(String k) => T.of(context, lang, k);
    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: Text(t('write_review')),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t('your_rating'), style: Theme.of(c).textTheme.labelSmall),
            const SizedBox(height: 4),
            Row(children: [
              for (int i = 1; i <= 5; i++)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => setD(() => rating = i),
                  icon: Icon(i <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: AppColors.accent, size: 30),
                ),
            ]),
            TextField(controller: ctrl, maxLines: 3, decoration: const InputDecoration(border: OutlineInputBorder())),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(t('cancel'))),
            FilledButton(
              onPressed: () async {
                await ref.read(apiProvider).addReview(productId, rating, ctrl.text.trim());
                ref.invalidate(reviewsProvider(productId));
                if (c.mounted) Navigator.pop(c);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t('review_thanks'))));
                }
              },
              child: Text(t('submit')),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  const _Stars(this.value, {this.size = 18});
  final double value;
  final double size;
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 1; i <= 5; i++)
            Icon(
              value >= i ? Icons.star_rounded : (value >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
              color: AppColors.accent, size: size),
        ],
      );
}
