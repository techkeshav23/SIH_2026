import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

final campaignsProvider = FutureProvider.autoDispose<List<Campaign>>((ref) async {
  return ref.read(apiProvider).listCampaigns();
});

/// Every ad campaign the artisan has — whether it came from Marketing → Boost
/// (promote one product) or from the custom-campaign form here. All are created
/// PAUSED on Meta: visible in Ads Manager, never spending until resumed.
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
            // Same pill/vocabulary as everywhere else the status is shown.
            KStatusPill(c.status),
          ]),
          Gap.s,
          Row(children: [
            const Icon(Icons.facebook_rounded, size: 15, color: AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${c.platformLabel} · ${rupees(c.dailyBudget)}/${hi ? 'दिन' : 'day'}',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelSmall,
              ),
            ),
          ]),
          if (c.isStub) ...[
            Gap.s,
            Row(children: [
              const Icon(Icons.science_outlined, size: 13, color: AppColors.muted),
              const SizedBox(width: 5),
              Expanded(child: Text(t('demo_campaign_note'), style: text.labelSmall)),
            ]),
          ] else ...[
            Gap.s,
            Row(children: [
              const Icon(Icons.verified_rounded, size: 13, color: AppColors.success),
              const SizedBox(width: 5),
              Expanded(
                child: Text(t('campaign_live_note'),
                    style: text.labelSmall?.copyWith(color: AppColors.success)),
              ),
            ]),
          ],
          // Surface why a creative/image was skipped instead of failing silently.
          if ((c.error ?? '').isNotEmpty) ...[
            Gap.s,
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.muted),
              const SizedBox(width: 5),
              Expanded(child: Text(c.error!, style: text.labelSmall, maxLines: 3)),
            ]),
          ],
        ],
      ),
    );
  }
}
