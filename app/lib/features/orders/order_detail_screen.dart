import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

/// Order detail with a vertical status timeline + role-aware fulfilment actions.
/// Order is passed via route extra.
class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.order});
  final Order order;

  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  late Order _order = widget.order;
  bool _busy = false;

  static const _flow = ['pending', 'accepted', 'paid', 'shipped', 'completed'];
  static const _labels = {
    'pending': ['Order placed', 'ऑर्डर मिला'],
    'accepted': ['Accepted', 'स्वीकृत'],
    'paid': ['Payment received', 'भुगतान हुआ'],
    'shipped': ['Shipped', 'भेजा गया'],
    'completed': ['Delivered', 'पहुँच गया'],
  };

  Api get _api => ref.read(apiProvider);

  Future<void> _run(Future<Order> Function() action, String okKey) async {
    final lang = ref.read(langProvider);
    setState(() => _busy = true);
    try {
      final updated = await action();
      setState(() => _order = updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(T.of(context, lang, okKey))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(T.of(context, lang, 'action_failed'))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final hi = lang == AppLang.hi;
    String t(String k) => T.of(context, lang, k);

    final order = _order;
    final terminated = order.status == 'rejected' || order.status == 'cancelled';
    final currentIdx = _flow.indexOf(order.status);

    return Scaffold(
      appBar: AppBar(title: Text('${t('order_no')} #${order.shortId.toUpperCase()}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          KCard(
            child: Row(children: [
              KNetImage(order.productImage, width: 56, height: 56),
              Gap.m,
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (order.productTitle != null) ...[
                    Text(order.productTitle!,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                  ],
                  Text('${t('qty')}: ${order.quantity} × ${rupees(order.unitPrice)}',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text(rupees(order.totalPrice),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.text)),
                ]),
              ),
              Gap.m,
              KStatusPill(order.status),
            ]),
          ),
          if (order.note != null && order.note!.isNotEmpty) ...[
            Gap.m,
            KCard(child: Row(children: [
              const Icon(Icons.sticky_note_2_outlined, color: AppColors.muted),
              Gap.m,
              Expanded(child: Text(order.note!, style: Theme.of(context).textTheme.bodyMedium)),
            ])),
          ],
          if ((order.shipAddress ?? '').isNotEmpty) ...[
            Gap.m,
            KCard(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
              Gap.m,
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t('ship_to')}: ${order.shipName ?? ''}',
                    style: Theme.of(context).textTheme.titleSmall),
                if ((order.shipPhone ?? '').isNotEmpty)
                  Text(order.shipPhone!, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(order.shipAddress!, style: Theme.of(context).textTheme.bodyMedium),
              ])),
            ])),
          ],
          Gap.l,
          KSectionTitle(t('order_timeline')),
          Gap.m,
          if (terminated)
            KCard(child: Row(children: [
              const Icon(Icons.cancel_rounded, color: AppColors.danger),
              Gap.m,
              Expanded(child: Text(hi ? 'यह ऑर्डर रद्द / अस्वीकृत हो गया।' : 'This order was cancelled / rejected.',
                  style: Theme.of(context).textTheme.bodyMedium)),
            ]))
          else
            KCard(
              child: Column(
                children: [
                  for (int i = 0; i < _flow.length; i++)
                    _TimelineStep(
                      label: _labels[_flow[i]]![hi ? 1 : 0],
                      done: i <= currentIdx,
                      current: i == currentIdx,
                      isLast: i == _flow.length - 1,
                    ),
                ],
              ),
            ),
          ..._actions(t),
        ],
      ),
    );
  }

  /// Role- and status-aware fulfilment buttons.
  List<Widget> _actions(String Function(String) t) {
    final s = _order.status;
    final isBuyer = _api.isBuyer;
    final buttons = <Widget>[];

    // Artisan dispatches a paid order.
    if (!isBuyer && s == 'paid') {
      buttons.add(FilledButton.icon(
        onPressed: _busy ? null : () => _run(() => _api.shipOrder(_order.id), 'order_shipped_ok'),
        icon: const Icon(Icons.local_shipping_rounded),
        label: Text(t('mark_shipped')),
      ));
    }
    // Buyer confirms receipt of a shipped order.
    if (isBuyer && s == 'shipped') {
      buttons.add(FilledButton.icon(
        onPressed: _busy ? null : () => _run(() => _api.confirmDelivery(_order.id), 'delivery_confirmed'),
        icon: const Icon(Icons.check_circle_rounded),
        label: Text(t('confirm_received')),
      ));
    }
    // Buyer cancels an order that isn't paid yet.
    if (isBuyer && (s == 'pending' || s == 'accepted')) {
      buttons.add(OutlinedButton.icon(
        onPressed: _busy
            ? null
            : () async {
                final ok = await confirmDialog(context,
                    title: t('cancel_order_q'), message: t('cancel_order_msg'),
                    confirm: t('cancel_order'), danger: true);
                if (ok) await _run(() => _api.cancelOrder(_order.id), 'order_cancelled_ok');
              },
        icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
        label: Text(t('cancel_order'), style: const TextStyle(color: AppColors.danger)),
      ));
    }

    if (buttons.isEmpty) return [];
    return [Gap.l, ...buttons.expand((b) => [b, Gap.s])];
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.label, required this.done, required this.current, required this.isLast});
  final String label;
  final bool done;
  final bool current;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.success : AppColors.line;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: done ? AppColors.success : AppColors.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: done
                  ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
                  : null,
            ),
            if (!isLast)
              Expanded(child: Container(width: 2, color: done ? AppColors.success : AppColors.line)),
          ]),
          const SizedBox(width: 14),
          Padding(
            padding: const EdgeInsets.only(bottom: 22, top: 2),
            child: Text(label,
                style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: current ? FontWeight.w800 : FontWeight.w600,
                    color: done ? AppColors.text : AppColors.muted)),
          ),
        ],
      ),
    );
  }
}
