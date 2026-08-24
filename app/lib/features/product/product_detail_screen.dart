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
  final _price = TextEditingController();

  Product? _p;
  bool _loading = true;
  bool _saving = false;

  Api get _api => ref.read(apiProvider);

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
      final pv = p.finalPrice ?? p.suggestedPriceMax;
      _price.text = pv == null ? '' : (pv % 1 == 0 ? pv.toInt().toString() : pv.toString());
      setState(() { _p = p; _loading = false; });
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

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final p = _p;
    return Scaffold(
      appBar: AppBar(
        title: Text(T.of(context, lang, 'my_products')),
        actions: [
          KSpeak([
            // Read the title in the selected language (fall back to the other).
            lang == AppLang.hi
                ? (_titleHi.text.trim().isNotEmpty ? _titleHi.text : _titleEn.text)
                : (_titleEn.text.trim().isNotEmpty ? _titleEn.text : _titleHi.text),
            _descHi.text,
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
                KSectionTitle(T.of(context, lang, 'listing')),
                Gap.s,
                _field(T.of(context, lang, 'title_hi'), _titleHi),
                _field(T.of(context, lang, 'title_en'), _titleEn),
                _field(T.of(context, lang, 'desc_hi'), _descHi, maxLines: 4),
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
                Gap.l,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _save(),
                        child: Text(T.of(context, lang, 'save')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : () => _save(publish: true),
                        icon: const Icon(Icons.storefront),
                        label: Text(T.of(context, lang, 'publish')),
                      ),
                    ),
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
