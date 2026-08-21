import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';

final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  return ref.read(apiProvider).listProducts();
});

final pendingProvider = FutureProvider.autoDispose<int>((ref) async {
  return (await LocalStore.pendingDrafts()).length;
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final products = ref.watch(productsProvider);
    final pending = ref.watch(pendingProvider).valueOrNull ?? 0;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/create');
          ref.invalidate(productsProvider);
          ref.invalidate(pendingProvider);
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: Text(T.of(context, lang, 'add_product')),
      ),
      body: Column(
        children: [
          KHeader(
            title: T.of(context, lang, 'my_products'),
            subtitle: T.of(context, lang, 'tagline'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              _HeaderIcon(icon: Icons.dashboard_rounded, tooltip: 'Dashboard', onTap: () => context.push('/dashboard')),
              _HeaderIcon(icon: Icons.receipt_long_rounded, tooltip: 'Orders', onTap: () => context.push('/orders')),
              _HeaderIcon(icon: Icons.storefront_rounded, tooltip: 'Market', onTap: () => context.push('/market')),
              _HeaderIcon(
                icon: Icons.translate_rounded, tooltip: 'Language',
                onTap: () => ref.read(langProvider.notifier).state = lang == AppLang.hi ? AppLang.en : AppLang.hi),
              _HeaderIcon(icon: Icons.logout_rounded, tooltip: 'Logout', onTap: () async {
                await ref.read(apiProvider).logout();
                if (context.mounted) context.go('/login');
              }),
            ]),
          ),
          if (pending > 0)
            _PendingBanner(count: pending, onSync: () async {
              final n = await ref.read(apiProvider).syncPendingDrafts();
              ref.invalidate(productsProvider);
              ref.invalidate(pendingProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(n > 0 ? '$n draft(s) synced ✓' : 'Still offline')));
              }
            }),
          Expanded(
            child: products.when(
              loading: () => const KLoading(),
              error: (e, _) => KErrorState(message: 'Could not reach server', onRetry: () => ref.invalidate(productsProvider)),
              data: (items) => items.isEmpty
                  ? KEmpty(
                      icon: Icons.add_a_photo_outlined,
                      title: lang == AppLang.hi ? 'अभी कोई उत्पाद नहीं' : 'No products yet',
                      subtitle: lang == AppLang.hi
                          ? 'नीचे बटन दबाकर पहला उत्पाद जोड़ें।'
                          : 'Tap the button below to add your first product.')
                  : RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async => ref.invalidate(productsProvider),
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _ProductCard(
                          p: items[i], api: ref.read(apiProvider),
                          onTap: () async {
                            await context.push('/product/${items[i].id}');
                            ref.invalidate(productsProvider);
                          }),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.tooltip, required this.onTap});
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 22),
      );
}

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count, required this.onSync});
  final int count;
  final VoidCallback onSync;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        ),
        child: Row(children: [
          const Icon(Icons.cloud_off_rounded, size: 20, color: AppColors.primaryDark),
          const SizedBox(width: 10),
          Expanded(child: Text('$count offline draft(s) waiting',
              style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.text))),
          TextButton(onPressed: onSync, child: const Text('Sync now')),
        ]),
      );
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.p, required this.api, required this.onTap});
  final Product p;
  final Api api;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final img = p.enhancedImageUrl ?? p.rawImageUrl;
    return KCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          KNetImage(img == null ? null : api.mediaUrl(img), width: 76, height: 76),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(p.titleHi ?? p.titleEn ?? 'Draft',
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 6),
                if (p.finalPrice != null)
                  Text('₹${p.finalPrice!.toStringAsFixed(0)}',
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 15))
                else if (p.suggestedPriceMin != null)
                  Text('₹${p.suggestedPriceMin!.toStringAsFixed(0)} – ₹${p.suggestedPriceMax!.toStringAsFixed(0)}',
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 8),
                KStatusPill(p.status),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
        ],
      ),
    );
  }
}
