import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/tts.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../promote/promote_screen.dart';

/// View + edit a product's AI-generated listing, set final price, and publish.
class ProductDetailScreen extends ConsumerStatefulWidget {
  const ProductDetailScreen({super.key, required this.productId});
  final String productId;

  @override
  ConsumerState<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  final _titleHi = TextEditingController();
  final _titleEn = TextEditingController();
  final _descHi = TextEditingController();
  final _descEn = TextEditingController();
  final _price = TextEditingController();

  Product? _p;
  bool _loading = true;
  bool _saving = false;
  List<Campaign> _campaigns = [];
  bool _boosting = false;

  Api get _api => ref.read(apiProvider);

  @override
  void dispose() {
    _titleHi.dispose();
    _titleEn.dispose();
    _descHi.dispose();
    _descEn.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await _api.getProduct(widget.productId);
      _titleHi.text = p.titleHi ?? '';
      _titleEn.text = p.titleEn ?? '';
      _descHi.text = p.descHi ?? '';
      _descEn.text = p.descEn ?? '';
      final pv = p.finalPrice ?? p.suggestedPriceMax;
      _price.text = pv == null ? '' : (pv % 1 == 0 ? pv.toInt().toString() : pv.toString());
      setState(() { _p = p; _loading = false; });
      // Best-effort — a campaigns-load failure shouldn't block viewing the product.
      try {
        final c = await _api.campaignsForProduct(widget.productId);
        if (mounted) setState(() => _campaigns = c);
      } catch (_) {/* no campaigns card shown */}
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        final lang = ref.read(langProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(T.of(context, lang, 'could_not_load'))));
        context.pop();
      }
    }
  }

  Future<void> _save({bool publish = false}) async {
    final lang = ref.read(langProvider);
    final price = double.tryParse(_price.text.trim());
    final okMsg = T.of(context, lang, publish ? 'listed_ok' : 'saved');
    final failMsg = T.of(context, lang, 'try_again');
    if (publish) {
      if (_titleHi.text.trim().isEmpty && _titleEn.text.trim().isEmpty) {
        _snack(T.of(context, lang, 'add_title_first'));
        return;
      }
      if (price == null || price <= 0) {
        _snack(T.of(context, lang, 'set_price_first'));
        return;
      }
      final ok = await confirmDialog(context,
          title: T.of(context, lang, 'list_q'),
          message: T.of(context, lang, 'list_msg'),
          confirm: T.of(context, lang, 'publish'));
      if (!ok) return;
    }
    setState(() => _saving = true);
    try {
      final patch = <String, dynamic>{
        'title_hi': _titleHi.text,
        'title_en': _titleEn.text,
        'desc_hi': _descHi.text,
        'desc_en': _descEn.text,
        'final_price': ?price,
        if (publish) 'status': 'listed',
      };
      final p = await _api.updateProduct(widget.productId, patch);
      setState(() => _p = p);
      if (mounted) {
        _snack(okMsg);
        if (publish) context.pop();
      }
    } catch (_) {
      _snack(failMsg);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final lang = ref.read(langProvider);
    final okMsg = T.of(context, lang, 'deleted_ok');
    final failMsg = T.of(context, lang, 'try_again');
    final ok = await confirmDialog(context,
        title: T.of(context, lang, 'delete_product_q'),
        message: T.of(context, lang, 'delete_product_msg'),
        confirm: T.of(context, lang, 'delete_product'), danger: true);
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await _api.deleteProduct(widget.productId);
      if (mounted) {
        _snack(okMsg);
        context.pop();
      }
    } catch (_) {
      _snack(failMsg);
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _boostBudget(Campaign c, double amount) async {
    final lang = ref.read(langProvider);
    final okMsg = T.of(context, lang, 'budget_boosted');
    final failMsg = T.of(context, lang, 'try_again');
    setState(() => _boosting = true);
    try {
      final updated = await _api.boostCampaignBudget(c.id, amount);
      setState(() => _campaigns = [
            for (final x in _campaigns) if (x.id == updated.id) updated else x,
          ]);
      _snack(okMsg);
    } catch (_) {
      _snack(failMsg);
    } finally {
      if (mounted) setState(() => _boosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final p = _p;
    return Scaffold(
      appBar: AppBar(
        title: Text(T.of(context, lang, 'my_products')),
        actions: [
          KSpeak([
            // Read the title + description in the selected language (fall back).
            lang == AppLang.hi
                ? (_titleHi.text.trim().isNotEmpty ? _titleHi.text : _titleEn.text)
                : (_titleEn.text.trim().isNotEmpty ? _titleEn.text : _titleHi.text),
            lang == AppLang.hi
                ? (_descHi.text.trim().isNotEmpty ? _descHi.text : _descEn.text)
                : (_descEn.text.trim().isNotEmpty ? _descEn.text : _descHi.text),
          ].where((s) => s.trim().isNotEmpty).join('. ')),
          if (p != null) KStatusPill(p.status),
          if (p != null)
            IconButton(
              tooltip: T.of(context, lang, 'delete_product'),
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading || p == null
          ? const KLoading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (p.enhancedImageUrl != null || p.rawImageUrl != null)
                  KNetImage(
                    _api.mediaUrl(p.enhancedImageUrl ?? p.rawImageUrl!),
                    height: 240,
                    width: double.infinity,
                    radius: Radii.lg,
                  ),
                Gap.m,
                // Promote: make a poster to share, or boost as an ad.
                FilledButton.icon(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => PromoteScreen(product: p))),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: const Color(0xFF3A2A20),
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: const Icon(Icons.campaign_rounded),
                  label: Text(lang == AppLang.hi ? 'प्रचार करें (पोस्टर / विज्ञापन)' : 'Promote (poster / ad)'),
                ),
                Gap.m,
                KSectionTitle(T.of(context, lang, 'listing')),
                Gap.s,
                // Show the selected language's title + description first, so an
                // English-mode artisan sees the English listing (not Hindi), then
                // the other language below (both stay editable).
                if (lang == AppLang.hi) ...[
                  _field(T.of(context, lang, 'title_hi'), _titleHi),
                  _field(T.of(context, lang, 'desc_hi'), _descHi, maxLines: 4),
                  _field(T.of(context, lang, 'title_en'), _titleEn),
                  _field(T.of(context, lang, 'desc_en'), _descEn, maxLines: 4),
                ] else ...[
                  _field(T.of(context, lang, 'title_en'), _titleEn),
                  _field(T.of(context, lang, 'desc_en'), _descEn, maxLines: 4),
                  _field(T.of(context, lang, 'title_hi'), _titleHi),
                  _field(T.of(context, lang, 'desc_hi'), _descHi, maxLines: 4),
                ],
                if (p.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(spacing: 6, children: [for (final t in p.tags) Chip(label: Text('#$t'))]),
                  ),
                Gap.m,
                KSectionTitle(T.of(context, lang, 'pricing')),
                Gap.s,
                if (p.suggestedPriceMin != null || p.suggestedPriceMax != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(Radii.md),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.30)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, size: 18, color: AppColors.success),
                        Gap.s,
                        Expanded(
                          child: Text(
                            (p.suggestedPriceMin != null && p.suggestedPriceMax != null)
                                ? '${T.of(context, lang, 'ai_suggested')}: ${rupees(p.suggestedPriceMin!)} – ${rupees(p.suggestedPriceMax!)}'
                                : '${T.of(context, lang, 'ai_suggested')}: ${rupees(p.suggestedPriceMax ?? p.suggestedPriceMin!)}',
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap.m,
                ],
                _field(T.of(context, lang, 'final_price'), _price,
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
                if (p.status == 'listed' && _campaigns.isNotEmpty) ...[
                  Gap.l,
                  KSectionTitle(T.of(context, lang, 'running_ads')),
                  Gap.s,
                  for (final c in _campaigns)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _BoostCard(
                        c: c, lang: lang, busy: _boosting,
                        onBoost: (amount) => _boostBudget(c, amount),
                      ),
                    ),
                ],
                Gap.l,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _save(),
                        child: Text(T.of(context, lang, 'save')),
                      ),
                    ),
                    // "List on Market" only makes sense before it's listed —
                    // once live, re-showing it implies the product isn't public
                    // yet and just re-runs the same publish flow pointlessly.
                    if (p.status != 'listed') ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : () => _save(publish: true),
                          icon: const Icon(Icons.storefront),
                          label: Text(T.of(context, lang, 'publish')),
                        ),
                      ),
                    ],
                  ],
                ),
                Gap.xl,
              ],
            ),
    );
  }

  Widget _field(String label, TextEditingController c,
          {int maxLines = 1, TextInputType? keyboard, List<TextInputFormatter>? formatters}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          keyboardType: keyboard,
          inputFormatters: formatters,
          decoration: InputDecoration(labelText: label),
        ),
      );
}

/// A single ad running on this product — leads with "this is a real running
/// ad" (name, platform, when it was created, live/paused status), then offers
/// a quick daily-budget bump. Minimum bump is ₹100 (enforced here and again
/// server-side in POST /campaigns/{id}/boost).
class _BoostCard extends StatelessWidget {
  const _BoostCard({required this.c, required this.lang, required this.busy, required this.onBoost});
  final Campaign c;
  final AppLang lang;
  final bool busy;
  final ValueChanged<double> onBoost;

  // Matches the backend's BudgetIncrease minimum (₹100) and the platform's
  // per-day floor, so every option here actually takes effect on Meta.
  static const _quickAmounts = [100.0, 250.0, 500.0];

  @override
  Widget build(BuildContext context) {
    final hi = lang == AppLang.hi;
    final text = Theme.of(context).textTheme;
    return KCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: unmistakably "this is a running ad", not a form.
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 38, height: 38, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (c.isStub ? AppColors.muted : AppColors.success).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.sm),
              ),
              child: Icon(Icons.campaign_rounded, size: 19,
                  color: c.isStub ? AppColors.muted : AppColors.success),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                const SizedBox(height: 2),
                Row(children: [
                  Icon(Icons.facebook_rounded, size: 13, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${c.platformLabel} · ${T.of(context, lang, 'created_on')} ${createdOn(c.createdAt)}',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: text.labelSmall,
                    ),
                  ),
                ]),
              ]),
            ),
            KStatusPill(c.status),
          ]),
          Gap.m,
          const Divider(height: 1),
          Gap.m,
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(T.of(context, lang, 'current_budget'), style: text.labelSmall),
              Text('${rupees(c.dailyBudget)} / ${hi ? 'दिन' : 'day'}',
                  style: text.titleMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
            ]),
            if ((c.error ?? '').isEmpty)
              Row(children: [
                Icon(
                  c.isStub ? Icons.science_outlined : Icons.pause_circle_outline_rounded,
                  size: 15,
                  color: c.isStub ? AppColors.muted : AppColors.accent,
                ),
                const SizedBox(width: 5),
                Text(
                  c.isStub
                      ? T.of(context, lang, 'demo_campaign_note')
                      : (hi ? 'खर्च नहीं हो रहा (रुका हुआ)' : 'No spend while paused'),
                  style: text.labelSmall,
                ),
              ]),
          ]),
          // Surface why an image/creative was skipped instead of hiding it.
          if ((c.error ?? '').isNotEmpty) ...[
            Gap.s,
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.muted),
              const SizedBox(width: 6),
              Expanded(child: Text(c.error!, style: text.labelSmall, maxLines: 3)),
            ]),
          ],
          Gap.m,
          Text(T.of(context, lang, 'increase_by'), style: text.labelSmall),
          Gap.xs,
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final amount in _quickAmounts)
              OutlinedButton(
                onPressed: busy ? null : () => onBoost(amount),
                // Wrap's main axis is unbounded, and the app theme's
                // minimumSize: Size.fromHeight(54) means infinite width —
                // invalid here. Pin a finite size.
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text('+${rupees(amount)}'),
              ),
          ]),
        ],
      ),
    );
  }
}
