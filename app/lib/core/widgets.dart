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
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
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

/// Gradient hero header with rounded bottom — used at the top of key screens.
class KHeader extends StatelessWidget {
  const KHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.leading,
    this.gradient = Decor.heroGradient,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? leading;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 18, 20, 24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(Radii.xl)),
        boxShadow: Decor.lift,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
                ],
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
    final ph = Container(
      width: width, height: height, color: AppColors.surfaceAlt,
      child: const Center(child: Icon(Icons.image_outlined, color: AppColors.muted)),
    );
    // demo images are bundled assets ("asset:<path>")
    if (url != null && url!.startsWith('asset:')) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(url!.substring(6), width: width, height: height, fit: fit,
            errorBuilder: (_, _, _) => ph),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null
          ? ph
          : Image.network(url!, width: width, height: height, fit: fit,
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
