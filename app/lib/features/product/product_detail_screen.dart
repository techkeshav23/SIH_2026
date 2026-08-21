import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
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
      _price.text = (p.finalPrice ?? p.suggestedPriceMax ?? '').toString();
      setState(() { _p = p; _loading = false; });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load product')));
        context.pop();
      }
    }
  }

  Future<void> _save({bool publish = false}) async {
    final price = double.tryParse(_price.text.trim());
    if (publish) {
      if (_titleHi.text.trim().isEmpty && _titleEn.text.trim().isEmpty) {
        _snack('Add a title before listing');
        return;
      }
      if (price == null || price <= 0) {
        _snack('Set a valid price before listing');
        return;
      }
      final ok = await confirmDialog(context,
          title: 'List on marketplace?',
          message: 'This makes the product visible to B2B buyers.',
          confirm: 'List');
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
        _snack(publish ? 'Listed on marketplace ✓' : 'Saved ✓');
        if (publish) context.pop();
      }
    } catch (_) {
      _snack('Could not save — please try again');
    } finally {
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
          if (p != null) KStatusPill(p.status),
          const SizedBox(width: 12),
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
                const KSectionTitle('Listing'),
                Gap.s,
                _field('शीर्षक (हिंदी)', _titleHi),
                _field('Title (English)', _titleEn),
                _field('विवरण (हिंदी)', _descHi, maxLines: 4),
                if (p.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(spacing: 6, children: [for (final t in p.tags) Chip(label: Text('#$t'))]),
                  ),
                Gap.m,
                const KSectionTitle('Pricing'),
                Gap.s,
                if (p.suggestedPriceMin != null) ...[
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
                            'AI suggested: ₹${p.suggestedPriceMin!.toStringAsFixed(0)} – ₹${p.suggestedPriceMax!.toStringAsFixed(0)}',
                            style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Gap.m,
                ],
                _field('Final price (₹)', _price,
                    keyboard: const TextInputType.numberWithOptions(decimal: true),
                    formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
                Gap.l,
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _save(),
                        child: const Text('Save'),
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
