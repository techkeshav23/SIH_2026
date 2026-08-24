import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../campaigns/campaigns_screen.dart' show campaignsProvider;
import '../home/home_screen.dart' show productsProvider;
import '../promote/promote_screen.dart';

/// Marketing hub (bottom-nav tab): promote products — make a shareable poster
/// or boost as an ad. Front-and-centre because reaching buyers is the core.
class MarketingScreen extends ConsumerWidget {
  const MarketingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final hi = lang == AppLang.hi;
    final text = Theme.of(context).textTheme;
    final api = ref.read(apiProvider);
    final products = ref.watch(productsProvider);
    final campaigns = ref.watch(campaignsProvider);

    return AppScaffold(
      current: 3,
      body: Column(children: [
        KHeader(title: hi ? 'मार्केटिंग' : 'Marketing', leading: drawerButton()),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(productsProvider);
              ref.invalidate(campaignsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                // intro hero
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF8F3620), Color(0xFFBE4A2F)],
                    ),
                    borderRadius: BorderRadius.circular(Radii.lg),
                    boxShadow: Decor.soft,
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      const Icon(Icons.campaign_rounded, color: AppColors.accent, size: 22),
                      const SizedBox(width: 8),
                      Text(hi ? 'अपने product का प्रचार करें' : 'Promote your products',
                          style: text.titleLarge?.copyWith(color: Colors.white)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      hi
                          ? 'पोस्टर बनाएँ और WhatsApp/Instagram पर शेयर करें, या विज्ञापन चलाकर ज़्यादा खरीदारों तक पहुँचें।'
                          : 'Make a poster to share on WhatsApp/Instagram, or run an ad to reach more buyers.',
                      style: text.bodyMedium?.copyWith(color: Colors.white70, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Row(children: [
                      _pill(hi ? '🖼 पोस्टर · मुफ़्त' : '🖼 Poster · Free'),
                      const SizedBox(width: 8),
                      _pill(hi ? '🚀 Boost · विज्ञापन' : '🚀 Boost · Ads'),
                    ]),
                  ]),
                ),
                // Running campaigns — boosts created here and campaigns created
                // from the Ad Campaigns screen both land in GET /campaigns, so
                // this is the single place the artisan sees what's live.
                ...campaigns.maybeWhen(
                  data: (list) => list.isEmpty
                      ? const <Widget>[]
                      : <Widget>[
                          Gap.l,
                          Row(children: [
                            Expanded(
                              child: Text(hi ? 'चल रहे अभियान' : 'Your campaigns',
                                  style: text.titleMedium),
                            ),
                            TextButton(
                              onPressed: () => context.push('/campaigns'),
                              style: TextButton.styleFrom(
                                  minimumSize: const Size(0, 36),
                                  visualDensity: VisualDensity.compact),
                              child: Text(hi ? 'सभी देखें' : 'See all'),
                            ),
                          ]),
                          Gap.xs,
                          for (final c in list.take(3))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _CampaignRow(campaign: c, hi: hi),
                            ),
                        ],
                  orElse: () => const <Widget>[],
                ),
                Gap.l,
                Text(hi ? 'किस product का प्रचार करें?' : 'Which product to promote?',
                    style: text.titleMedium),
                Gap.s,
                // NOTE: KLoading/KEmpty/KErrorState are Center-based, which resolve
                // to infinite height inside a ListView (unbounded main axis) and throw
                // a box.dart layout assertion — killing everything below. Give them a
                // bounded height here.
                products.when(
                  loading: () => const SizedBox(height: 220, child: KLoading()),
                  error: (_, _) => SizedBox(
                    height: 260,
                    child: KErrorState(
                        message: hi ? 'लोड नहीं हुआ' : 'Could not load',
                        onRetry: () => ref.invalidate(productsProvider)),
                  ),
                  data: (list) {
                    final items = list.where((p) => p.status != 'archived').toList();
                    if (items.isEmpty) {
                      return SizedBox(
                        height: 420,
                        child: KEmpty(
                          icon: Icons.inventory_2_outlined,
                          title: hi ? 'कोई product नहीं' : 'No products yet',
                          subtitle: hi ? 'पहले एक product जोड़ें' : 'Add a product first',
                          action: FilledButton.icon(
                            onPressed: () async {
                              await context.push('/create');
                              ref.invalidate(productsProvider);
                            },
                            icon: const Icon(Icons.add_a_photo_rounded),
                            label: Text(hi ? 'नया उत्पाद जोड़ें' : 'Add Product'),
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: [
                        for (final p in items)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _PromoteRow(product: p, api: api, hi: hi),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _pill(String s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(Radii.pill),
        ),
        child: Text(s, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
      );
}

/// Compact row for a live (PAUSED on the ad platform) campaign.
class _CampaignRow extends StatelessWidget {
  const _CampaignRow({required this.campaign, required this.hi});
  final Campaign campaign;
  final bool hi;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        Container(
          width: 34, height: 34, alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(Radii.sm),
          ),
          child: const Icon(Icons.campaign_rounded, size: 18, color: AppColors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(campaign.name,
                maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
            const SizedBox(height: 1),
            Text(
              '${rupees(campaign.dailyBudget)}/${hi ? 'दिन' : 'day'}'
              '${campaign.isStub ? (hi ? ' · डेमो' : ' · demo') : ''}',
              style: text.labelSmall,
            ),
          ]),
        ),
        // Same status vocabulary as the Campaigns screen — one source of truth.
        KStatusPill(campaign.status),
      ]),
    );
  }
}

class _PromoteRow extends StatelessWidget {
  const _PromoteRow({required this.product, required this.api, required this.hi});
  final Product product;
  final Api api;
  final bool hi;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final img = product.enhancedImageUrl ?? product.rawImageUrl;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        KNetImage(img == null ? null : api.mediaUrl(img), width: 52, height: 52),
        Gap.m,
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(product.titleFor(hi) ?? 'Product',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
            Text(rupees(product.finalPrice ?? product.suggestedPriceMax ?? 0),
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13)),
          ]),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => PromoteScreen(product: product))),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: const Color(0xFF3A2A20),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            // The app theme sets minimumSize: Size.fromHeight(54), i.e. INFINITE
            // width (for full-width buttons). Inside a Row the main axis is
            // unbounded, so that infinite width is an invalid constraint and
            // breaks layout for the whole list. Override it with a finite size.
            minimumSize: const Size(0, 40),
          ),
          icon: const Icon(Icons.campaign_rounded, size: 18),
          label: Text(hi ? 'प्रचार' : 'Promote'),
        ),
      ]),
    );
  }
}
