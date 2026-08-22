import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';

/// Order detail with a vertical status timeline. Order is passed via route extra.
class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.order});
  final Order order;

  static const _flow = ['pending', 'accepted', 'paid', 'shipped', 'completed'];
  static const _labels = {
    'pending': ['Order placed', 'ऑर्डर मिला'],
    'accepted': ['Accepted', 'स्वीकृत'],
    'paid': ['Payment received', 'भुगतान हुआ'],
    'shipped': ['Shipped', 'भेजा गया'],
    'completed': ['Delivered', 'पहुँच गया'],
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final hi = lang == AppLang.hi;
    String t(String k) => T.of(context, lang, k);

    final terminated = order.status == 'rejected' || order.status == 'cancelled';
    final currentIdx = _flow.indexOf(order.status);

    return Scaffold(
      appBar: AppBar(title: Text('${t('order_no')} #${order.id.substring(0, 6).toUpperCase()}')),
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
                  Text('${t('qty')}: ${order.quantity} × ₹${order.unitPrice.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 2),
                  Text('₹${order.totalPrice.toStringAsFixed(0)}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22, color: AppColors.success)),
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
        ],
      ),
    );
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
