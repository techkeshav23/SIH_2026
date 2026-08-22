import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  return ref.read(apiProvider).getNotifications();
});

/// Unread badge count — watched by app bars.
final unreadProvider = FutureProvider.autoDispose<int>((ref) async {
  return ref.read(apiProvider).unreadNotifications();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  IconData _icon(String type) {
    switch (type) {
      case 'order': return Icons.receipt_long_rounded;
      case 'payment': return Icons.payments_rounded;
      case 'inquiry': return Icons.question_answer_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _color(String type) {
    switch (type) {
      case 'order': return AppColors.indigo;
      case 'payment': return AppColors.success;
      case 'inquiry': return AppColors.accent;
      default: return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final notifs = ref.watch(notificationsProvider);
    String t(String k) => T.of(context, lang, k);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('notifications')),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(apiProvider).markNotificationsRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadProvider);
            },
            child: Text(t('mark_all_read')),
          ),
        ],
      ),
      body: notifs.when(
        loading: () => const KLoading(),
        error: (e, _) => KErrorState(message: t('could_not_load'), onRetry: () => ref.invalidate(notificationsProvider)),
        data: (items) => items.isEmpty
            ? KEmpty(icon: Icons.notifications_off_outlined, title: t('no_notifications'))
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final n = items[i];
                  return KCard(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(color: _color(n.type).withValues(alpha: 0.14), shape: BoxShape.circle),
                        child: Icon(_icon(n.type), color: _color(n.type), size: 22),
                      ),
                      Gap.m,
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(n.title, style: Theme.of(context).textTheme.titleMedium)),
                            if (!n.read)
                              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                          ]),
                          const SizedBox(height: 3),
                          Text(n.body, style: Theme.of(context).textTheme.bodyMedium),
                          if (n.time != null) ...[
                            const SizedBox(height: 4),
                            Text(n.time!, style: Theme.of(context).textTheme.labelSmall),
                          ],
                        ]),
                      ),
                    ]),
                  );
                },
              ),
      ),
    );
  }
}
