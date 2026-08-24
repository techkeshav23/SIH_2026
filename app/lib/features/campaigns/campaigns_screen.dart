import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

final campaignsProvider = FutureProvider.autoDispose<List<Campaign>>((ref) async {
  return ref.read(apiProvider).listCampaigns();
});

/// List of ad campaigns the artisan has created (Meta / Google Ads), each
/// created PAUSED — visible in the real ad account, never spending. Reached
/// from the drawer; "Create" pushes CreateCampaignScreen.
class CampaignsScreen extends ConsumerWidget {
  const CampaignsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final hi = lang == AppLang.hi;
    String t(String k) => T.of(context, lang, k);
    final campaigns = ref.watch(campaignsProvider);

    Future<void> refresh() async => ref.invalidate(campaignsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t('campaigns'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/campaigns/create');
          refresh();
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: Text(t('create_campaign')),
      ),
      body: campaigns.when(
        loading: () => const KLoading(),
        error: (e, _) => KErrorState(
          message: t('could_not_load'),
          onRetry: () => ref.invalidate(campaignsProvider),
        ),
        data: (items) => items.isEmpty
            ? KEmpty(
                icon: Icons.campaign_outlined,
                title: t('no_campaigns'),
                subtitle: t('no_campaigns_sub'),
              )
            : RefreshIndicator(
                onRefresh: refresh,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _CampaignCard(c: items[i], hi: hi, t: t),
                ),
              ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  const _CampaignCard({required this.c, required this.hi, required this.t});
  final Campaign c;
  final bool hi;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 40, height: 40, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: const Icon(Icons.campaign_rounded, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
            ),
            KStatusPill(c.status == 'created' ? 'listed' : c.status),
          ]),
          Gap.s,
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in c.platforms)
              Chip(
                avatar: Icon(p == 'meta' ? Icons.facebook_rounded : Icons.search_rounded, size: 14),
                label: Text(p == 'meta' ? 'Meta' : 'Google Ads'),
                visualDensity: VisualDensity.compact,
              ),
          ]),
          if (c.isStub) ...[
            Gap.s,
            Row(children: [
              const Icon(Icons.science_outlined, size: 13, color: AppColors.muted),
              const SizedBox(width: 5),
              Text(t('demo_campaign_note'), style: text.labelSmall),
            ]),
          ],
        ],
      ),
    );
  }
}
