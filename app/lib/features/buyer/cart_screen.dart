import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/cart.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});
  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _placing = false;

  Future<void> _checkout() async {
    final lang = ref.read(langProvider);
    final items = ref.read(cartProvider);
    if (items.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final okMsg = T.of(context, lang, 'order_confirmed');
    final failMsg = T.of(context, lang, 'try_again');
    setState(() => _placing = true);
    try {
      for (final c in items) {
        await ref.read(apiProvider).placeOrder(c.product.id, c.qty);
      }
      ref.read(cartProvider.notifier).clear();
      messenger.showSnackBar(SnackBar(content: Text(okMsg)));
      if (mounted) context.pop();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failMsg)));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final items = ref.watch(cartProvider);
    final total = ref.watch(cartTotalProvider);
    final api = ref.read(apiProvider);
    String t(String k) => T.of(context, lang, k);

    return Scaffold(
      appBar: AppBar(title: Text(t('my_cart'))),
      bottomNavigationBar: items.isEmpty
          ? null
          : Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                    Text(t('total'), style: Theme.of(context).textTheme.labelSmall),
                    Text('₹${total.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.success)),
                  ]),
                ),
                FilledButton.icon(
                  onPressed: _placing ? null : _checkout,
                  icon: _placing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded),
                  label: Text(t('checkout')),
                ),
              ]),
            ),
      body: items.isEmpty
          ? KEmpty(icon: Icons.shopping_cart_outlined, title: t('cart_empty'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final c = items[i];
                final img = c.product.enhancedImageUrl ?? c.product.rawImageUrl;
                return KCard(
                  child: Row(children: [
                    KNetImage(img == null ? null : api.mediaUrl(img), width: 64, height: 64),
                    Gap.m,
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(c.product.titleHi ?? c.product.titleEn ?? 'Product',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text('₹${c.unit.toStringAsFixed(0)} × ${c.qty} = ₹${c.lineTotal.toStringAsFixed(0)}',
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700)),
                        Row(children: [
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => ref.read(cartProvider.notifier).setQty(c.product.id, c.qty - 1),
                            icon: const Icon(Icons.remove_circle_outline)),
                          Text('${c.qty}', style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => ref.read(cartProvider.notifier).setQty(c.product.id, c.qty + 1),
                            icon: const Icon(Icons.add_circle_outline)),
                          const Spacer(),
                          TextButton(
                            onPressed: () => ref.read(cartProvider.notifier).remove(c.product.id),
                            child: Text(t('remove'), style: const TextStyle(color: AppColors.danger))),
                        ]),
                      ]),
                    ),
                  ]),
                );
              },
            ),
    );
  }
}
