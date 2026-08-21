import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';

final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  return ref.read(apiProvider).listProducts();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final products = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(T.of(context, lang, 'my_products'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/create');
          ref.invalidate(productsProvider);
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo),
        label: Text(T.of(context, lang, 'add_product')),
      ),
      body: products.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(onRetry: () => ref.invalidate(productsProvider)),
        data: (items) => items.isEmpty
            ? _EmptyState(lang: lang)
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(productsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) => _ProductCard(p: items[i], api: ref.read(apiProvider)),
                ),
              ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.p, required this.api});
  final Product p;
  final Api api;

  @override
  Widget build(BuildContext context) {
    final img = p.enhancedImageUrl ?? p.rawImageUrl;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: img != null
                  ? Image.network(api.mediaUrl(img), width: 72, height: 72, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const _Placeholder())
                  : const _Placeholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.titleHi ?? p.titleEn ?? 'Draft',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 4),
                  if (p.suggestedPriceMin != null)
                    Text('₹${p.suggestedPriceMin!.toStringAsFixed(0)} – ₹${p.suggestedPriceMax!.toStringAsFixed(0)}',
                        style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  _StatusChip(status: p.status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: (colors[status] ?? Colors.grey).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status, style: TextStyle(color: colors[status] ?? Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();
  @override
  Widget build(BuildContext context) => Container(
        width: 72, height: 72, color: AppColors.bg,
        child: const Icon(Icons.image_outlined, color: AppColors.muted),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.lang});
  final AppLang lang;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_a_photo_outlined, size: 72, color: AppColors.muted),
              const SizedBox(height: 16),
              Text(
                lang == AppLang.hi
                    ? 'अभी कोई उत्पाद नहीं।\nनीचे बटन दबाकर पहला उत्पाद जोड़ें।'
                    : 'No products yet.\nTap the button below to add your first.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 16),
              ),
            ],
          ),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off, size: 64, color: AppColors.muted),
            const SizedBox(height: 12),
            const Text('Could not reach server'),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}
