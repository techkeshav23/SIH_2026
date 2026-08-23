import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';
import 'theme.dart';

/// Friendly, localized labels for raw status codes (en / hi).
const Map<String, List<String>> _statusLabels = {
  'draft': ['Draft', 'ड्राफ़्ट'],
  'processing': ['Processing', 'तैयार हो रहा'],
  'ready': ['Ready', 'तैयार'],
  'listed': ['Listed', 'बाज़ार में'],
  'pending': ['Pending', 'मंज़ूरी बाकी'],
  'accepted': ['Accepted', 'स्वीकृत'],
  'rejected': ['Rejected', 'अस्वीकृत'],
  'paid': ['Paid', 'भुगतान हुआ'],
  'shipped': ['Shipped', 'भेजा गया'],
  'completed': ['Completed', 'पूर्ण'],
  'cancelled': ['Cancelled', 'रद्द'],
};

/// Confirmation dialog for irreversible actions. Returns true if confirmed.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Confirm',
  bool danger = false,
}) async {
  final lang = ProviderScope.containerOf(context).read(langProvider);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(c, false),
          child: Text(T.of(context, lang, 'cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(c, true),
          style: danger ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          child: Text(confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Unified status -> colour mapping (products + orders).
Color statusColor(String status) {
  switch (status) {
    case 'ready':
    case 'accepted':
    case 'completed':
      return AppColors.success;
    case 'processing':
    case 'pending':
      return AppColors.accent;
    case 'listed':
    case 'paid':
      return AppColors.primary;
    case 'shipped':
      return AppColors.indigo;
    case 'rejected':
    case 'cancelled':
      return AppColors.danger;
    default:
      return AppColors.muted;
  }
}

/// Small pill showing a friendly, localized status with a soft tinted background.
class KStatusPill extends ConsumerWidget {
  const KStatusPill(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = statusColor(status);
    final hi = ref.watch(langProvider) == AppLang.hi;
    final label = _statusLabels[status]?[hi ? 1 : 0] ?? status;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.1)),
        ],
      ),
    );
  }
}

/// Flat, dense app header — dark title on the cream canvas with a hairline
/// divider (real-app chrome, not a gradient hero). [gradient] is accepted for
/// backwards-compatibility but ignored.
class KHeader extends StatelessWidget {
  const KHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.gradient,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(6, MediaQuery.of(context).padding.top + 8, 10, 10),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          ?leading,
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.headlineSmall),
                if (subtitle != null)
                  Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Rounded network image with graceful placeholder + error states.
class KNetImage extends StatelessWidget {
  const KNetImage(this.url, {super.key, this.width, this.height, this.radius = Radii.md, this.fit = BoxFit.cover});
  final String? url;
  final double? width;
  final double? height;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final ph = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width, height: height, color: AppColors.surfaceAlt,
        child: const Center(child: Icon(Icons.image_outlined, color: AppColors.muted)),
      ),
    );
    final u = url?.trim();
    if (u == null || u.isEmpty) return ph;
    // Decode to the on-screen size, not the source resolution. AI-enhanced
    // product JPEGs are ~1080px; decoding one into a 52px thumbnail wastes
    // ~400x the pixels, janks the raster thread and thrashes the image cache.
    final dpr = MediaQuery.of(context).devicePixelRatio;
    final cw = (width != null && width!.isFinite) ? (width! * dpr).round() : null;
    final ch = (height != null && height!.isFinite) ? (height! * dpr).round() : null;
    // demo images are bundled assets ("asset:<path>")
    if (u.startsWith('asset:')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(u.substring(6), width: width, height: height, fit: fit,
            cacheWidth: cw, cacheHeight: ch,
            errorBuilder: (_, _, _) => ph),
      );
    }
    // only attempt a network load for a real http(s) url; anything else -> placeholder
    final uri = Uri.tryParse(u);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) return ph;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(u, width: width, height: height, fit: fit,
          cacheWidth: cw, cacheHeight: ch,
          errorBuilder: (_, _, _) => ph,
          loadingBuilder: (c, child, p) => p == null
              ? child
              : Container(width: width, height: height, color: AppColors.surfaceAlt,
                  child: const Center(
                      child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))))),
    );
  }
}

/// Friendly empty state.
class KEmpty extends StatelessWidget {
  const KEmpty({super.key, required this.icon, required this.title, this.subtitle});
  final IconData icon;
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
                child: Icon(icon, size: 44, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(subtitle!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      );
}

class KLoading extends StatelessWidget {
  const KLoading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: AppColors.primary));
}

class KErrorState extends StatelessWidget {
  const KErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 56, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(message, style: Theme.of(context).textTheme.bodyMedium),
            if (onRetry != null)
              TextButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      );
}

/// Section title with optional trailing action.
class KSectionTitle extends StatelessWidget {
  const KSectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Container(width: 4, height: 18, decoration: BoxDecoration(
                color: AppColors.accent, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
            ?trailing,
          ],
        ),
      );
}

/// A tappable card with soft shadow (wraps content).
class KCard extends StatelessWidget {
  const KCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
