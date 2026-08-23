import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/tts.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

final incomingOrdersProvider = FutureProvider.autoDispose<List<Order>>((ref) async {
  final orders = await ref.read(apiProvider).incomingOrders();
  ref.keepAlive(); // survive tab switches; refreshed via invalidate on actions
  return orders;
});

/// Artisan's view of incoming B2B orders with accept / reject actions.
class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(incomingOrdersProvider);
    final lang = ref.watch(langProvider);
    final title = T.of(context, lang, 'incoming_orders');
    final subtitle = T.of(context, lang, 'incoming_sub');
    return AppScaffold(
      current: 2,
      body: Column(
        children: [
          KHeader(
            title: title,
            subtitle: subtitle,
            leading: drawerButton(),
            trailing: KSpeak('$title — $subtitle'),
          ),
          Expanded(
            child: orders.when(
              loading: () => const KLoading(),
              error: (e, _) => KErrorState(
                message: T.of(context, lang, 'could_not_load'),
                onRetry: () => ref.invalidate(incomingOrdersProvider),
              ),
              data: (items) => items.isEmpty
                  ? KEmpty(
                      icon: Icons.inbox_outlined,
                      title: T.of(context, lang, 'no_orders'),
                      subtitle: lang == AppLang.hi
                          ? 'नए ऑर्डर यहाँ दिखेंगे।'
                          : 'New buyer orders will appear here.',
                    )
                  : RefreshIndicator(
                      onRefresh: () async => ref.invalidate(incomingOrdersProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) =>
                            _OrderCard(order: items[i], ref: ref, lang: lang),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.ref, required this.lang});
  final Order order;
  final WidgetRef ref;
  final AppLang lang;

  Future<void> _act(BuildContext context, Future<Order> Function() action, String message) async {
    try {
      await action();
      ref.invalidate(incomingOrdersProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lang == AppLang.hi ? 'कुछ गड़बड़ हुई' : 'Action failed')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final api = ref.read(apiProvider);
    String t(String key) => T.of(context, lang, key);
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
                    Text(order.productTitle ?? '${t('order_no')} #${order.shortId}',
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text('${t('order_no')} #${order.shortId}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              KStatusPill(order.status),
            ],
          ),
          Gap.m,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${t('qty')}: ${order.quantity} × ${rupees(order.unitPrice)}',
                  style: Theme.of(context).textTheme.bodyMedium),
              Text(rupees(order.totalPrice),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                    fontSize: 22,
                  )),
            ],
          ),
          if (order.note != null && order.note!.isNotEmpty) ...[
            Gap.s,
            Text(order.note!, style: Theme.of(context).textTheme.bodyMedium),
          ],
          if (order.isPending) ...[
            Gap.m,
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final ok = await confirmDialog(context,
                          title: t('reject_q'),
                          message: t('reject_msg'),
                          confirm: t('reject'), danger: true);
                      if (ok && context.mounted) {
                        await _act(context, () => api.rejectOrder(order.id),
                            lang == AppLang.hi ? 'ऑर्डर अस्वीकार किया' : 'Order rejected');
                      }
                    },
                    child: Text(t('reject')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _act(context, () => api.acceptOrder(order.id),
                        lang == AppLang.hi ? 'ऑर्डर स्वीकार किया' : 'Order accepted'),
                    child: Text(t('accept')),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
