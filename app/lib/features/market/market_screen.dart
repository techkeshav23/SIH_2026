import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/nav.dart';
import '../../core/theme.dart';
import '../../core/tts.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

final feedProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  return ref.read(apiProvider).buyerFeed();
});

/// Buyer-facing marketplace — simulated ONDC / GeM discovery of listed products.
class MarketScreen extends ConsumerWidget {
  const MarketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(feedProvider);
    final lang = ref.watch(langProvider);
    final title = T.of(context, lang, 'b2b_marketplace');
    final subtitle = T.of(context, lang, 'ondc_ready');
    return AppScaffold(
      current: 3,
      body: Column(
        children: [
          KHeader(
            title: title,
            subtitle: subtitle,
            leading: drawerButton(),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                KSpeak('$title. $subtitle', color: Colors.white),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(Radii.pill),
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.35)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded,
                          size: 15, color: Colors.white),
                      SizedBox(width: 6),
                      Text('Govt · ONDC',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: feed.when(
              loading: () => const KLoading(),
              error: (e, _) => KErrorState(
                message: T.of(context, lang, 'could_not_load'),
                onRetry: () => ref.invalidate(feedProvider),
              ),
              data: (items) => items.isEmpty
                  ? KEmpty(
                      icon: Icons.storefront_outlined,
                      title: T.of(context, lang, 'no_listed'),
                      subtitle:
                          'Listed crafts from artisans will appear here for bulk inquiry.',
                    )
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async => ref.invalidate(feedProvider),
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.66,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        itemCount: items.length,
                        itemBuilder: (_, i) =>
                            _FeedCard(p: items[i], api: ref.read(apiProvider)),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({required this.p, required this.api});
  final Product p;
  final Api api;

  @override
  Widget build(BuildContext context) {
    final img = p.enhancedImageUrl ?? p.rawImageUrl;
    final price = p.finalPrice != null
        ? '₹${p.finalPrice!.toStringAsFixed(0)}'
        : (p.suggestedPriceMin != null
            ? '₹${p.suggestedPriceMin!.toStringAsFixed(0)}+'
            : 'Ask price');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: AppColors.line),
        boxShadow: Decor.soft,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openInquiry(context),
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: KNetImage(
                  img != null ? api.mediaUrl(img) : null,
                  width: double.infinity,
                  radius: Radii.lg,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.titleEn ?? p.titleHi ?? 'Product',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      price,
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.chat_bubble_outline_rounded,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('Tap to inquire',
                            style: TextStyle(
                              color: AppColors.primary.withValues(alpha: 0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            )),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openInquiry(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InquirySheet(p: p, api: api),
    );
  }
}

class _InquirySheet extends ConsumerStatefulWidget {
  const _InquirySheet({required this.p, required this.api});
  final Product p;
  final Api api;
  @override
  ConsumerState<_InquirySheet> createState() => _InquirySheetState();
}

class _InquirySheetState extends ConsumerState<_InquirySheet> {
  final _org = TextEditingController();
  final _msg = TextEditingController(
      text: 'Interested in bulk order. Please share MOQ & rate.');
  bool _sending = false;

  Future<void> _send() async {
    final lang = ref.read(langProvider);
    if (_org.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(T.of(context, lang, 'org_name'))));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final sentMsg = T.of(context, lang, 'inquiry_sent');
    final failMsg = T.of(context, lang, 'could_not_load');
    setState(() => _sending = true);
    try {
      await widget.api
          .sendInquiry(widget.p.id, _org.text.trim(), _msg.text.trim());
      nav.pop();
      messenger.showSnackBar(SnackBar(content: Text(sentMsg)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(failMsg)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final title = widget.p.titleEn ?? widget.p.titleHi ?? 'this product';
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(Radii.pill),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(Radii.md),
                ),
                child: const Icon(Icons.mark_email_read_outlined,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(T.of(context, lang, 'inquire'),
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 2),
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _org,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: T.of(context, lang, 'org_name'),
              prefixIcon: const Icon(Icons.business_outlined),
            ),
          ),
          Gap.m,
          TextField(
            controller: _msg,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: T.of(context, lang, 'message'),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send_rounded),
            label: Text(_sending
                ? T.of(context, lang, 'processing')
                : T.of(context, lang, 'send_inquiry')),
          ),
        ],
      ),
    );
  }
}
