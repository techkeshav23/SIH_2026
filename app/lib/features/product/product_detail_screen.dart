import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
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
    final p = await _api.getProduct(widget.productId);
    _titleHi.text = p.titleHi ?? '';
    _titleEn.text = p.titleEn ?? '';
    _descHi.text = p.descHi ?? '';
    _price.text = (p.finalPrice ?? p.suggestedPriceMax ?? '').toString();
    setState(() { _p = p; _loading = false; });
  }

  Future<void> _save({bool publish = false}) async {
    setState(() => _saving = true);
    try {
      final patch = <String, dynamic>{
        'title_hi': _titleHi.text,
        'title_en': _titleEn.text,
        'desc_hi': _descHi.text,
        if (_price.text.trim().isNotEmpty) 'final_price': double.tryParse(_price.text.trim()),
        if (publish) 'status': 'listed',
      };
      final p = await _api.updateProduct(widget.productId, patch);
      setState(() => _p = p);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(publish ? 'Listed on marketplace ✓' : 'Saved ✓')),
        );
        if (publish) context.pop();
      }
    } finally {
      setState(() => _saving = false);
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
          if (p != null) _StatusChip(status: p.status),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading || p == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (p.enhancedImageUrl != null || p.rawImageUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      _api.mediaUrl(p.enhancedImageUrl ?? p.rawImageUrl!),
                      height: 240, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        height: 240, color: AppColors.bg,
                        child: const Icon(Icons.image_outlined, size: 48, color: AppColors.muted),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                _field('शीर्षक (हिंदी)', _titleHi),
                _field('Title (English)', _titleEn),
                _field('विवरण (हिंदी)', _descHi, maxLines: 4),
                if (p.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(spacing: 6, children: [for (final t in p.tags) Chip(label: Text('#$t'))]),
                  ),
                const Divider(height: 28),
                if (p.suggestedPriceMin != null)
                  Text(
                    'AI suggested: ₹${p.suggestedPriceMin!.toStringAsFixed(0)} – ₹${p.suggestedPriceMax!.toStringAsFixed(0)}',
                    style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 8),
                _field('Final price (₹)', _price, keyboard: TextInputType.number),
                const SizedBox(height: 20),
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
                const SizedBox(height: 40),
              ],
            ),
    );
  }

  Widget _field(String label, TextEditingController c,
          {int maxLines = 1, TextInputType? keyboard}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          keyboardType: keyboard,
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final colors = {
      'draft': Colors.grey,
      'processing': AppColors.accent,
      'ready': AppColors.success,
      'listed': AppColors.primary,
    };
    return Chip(
      label: Text(status, style: TextStyle(color: colors[status] ?? Colors.grey, fontSize: 12)),
      backgroundColor: (colors[status] ?? Colors.grey).withValues(alpha: 0.12),
    );
  }
}
