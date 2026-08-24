import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/cart.dart';
import '../../data/models.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});
  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _placing = false;
  Address? _address;

  Api get _api => ref.read(apiProvider);

  @override
  void initState() {
    super.initState();
    _loadDefaultAddress();
  }

  Future<void> _loadDefaultAddress() async {
    try {
      final addrs = await _api.listAddresses();
      if (addrs.isNotEmpty && mounted) {
        setState(() => _address = addrs.firstWhere((a) => a.isDefault, orElse: () => addrs.first));
      }
    } catch (_) {/* addresses optional */}
  }

  Future<void> _pickAddress() async {
    final picked = await context.push<Object?>('/addresses', extra: true);
    if (picked is Address && mounted) setState(() => _address = picked);
  }

  Future<void> _checkout() async {
    final lang = ref.read(langProvider);
    final items = ref.read(cartProvider);
    if (items.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final selectMsg = T.of(context, lang, 'select_address');
    final okMsg = T.of(context, lang, 'order_confirmed');
    final failMsg = T.of(context, lang, 'try_again');
    // Require a delivery address in real mode.
    if (_address == null && !_api.demoMode) {
      messenger.showSnackBar(SnackBar(content: Text(selectMsg)));
      await _pickAddress();
      if (_address == null) return;
    }
    setState(() => _placing = true);
    try {
      // Drop each line as its order is placed, so a mid-loop failure leaves only
      // the un-ordered items in the cart — a retry won't duplicate placed orders.
      for (final c in items) {
        await _api.placeOrder(c.product.id, c.qty, addressId: _address?.id);
        ref.read(cartProvider.notifier).remove(c.product.id);
      }
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
                    Text(rupees(total),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.text)),
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
          : Column(children: [
              _AddressBar(address: _address, onTap: _pickAddress, t: t),
              Expanded(
                child: ListView.separated(
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
                        Text(c.product.titleFor(lang == AppLang.hi) ?? 'Product',
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text('${rupees(c.unit)} × ${c.qty} = ${rupees(c.lineTotal)}',
                            style: const TextStyle(color: AppColors.textSoft, fontWeight: FontWeight.w700)),
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
              ),
            ]),
    );
  }
}

/// Compact delivery-address selector shown above the cart items.
class _AddressBar extends StatelessWidget {
  const _AddressBar({required this.address, required this.onTap, required this.t});
  final Address? address;
  final VoidCallback onTap;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final a = address;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(children: [
          const Icon(Icons.location_on_outlined, color: AppColors.primary),
          Gap.m,
          Expanded(
            child: a == null
                ? Text(t('select_address'),
                    style: const TextStyle(fontWeight: FontWeight.w600))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${t('ship_to')}: ${a.name}',
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(a.oneLine,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ]),
          ),
          Text(t('change'), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
