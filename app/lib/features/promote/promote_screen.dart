import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';
import '../campaigns/campaigns_screen.dart' show campaignsProvider;

/// Promote hub: from a product, either make a free shareable AI poster or boost
/// it as a paid ad (Meta). UI is fully demo-able; the poster is rendered + shared
/// on-device (real), the Boost flow calls the backend (friend wires Meta).
class PromoteScreen extends ConsumerWidget {
  const PromoteScreen({super.key, required this.product});
  final Product product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final hi = lang == AppLang.hi;
    final text = Theme.of(context).textTheme;
    final api = ref.read(apiProvider);
    final img = product.enhancedImageUrl ?? product.rawImageUrl;

    return Scaffold(
      appBar: AppBar(title: Text(hi ? 'प्रचार करें' : 'Promote')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // product mini
          Row(children: [
            KNetImage(img == null ? null : api.mediaUrl(img), width: 60, height: 60),
            Gap.m,
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(product.titleFor(hi) ?? 'Product',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: text.titleMedium),
                Text(rupees(product.finalPrice ?? product.suggestedPriceMax ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary)),
              ]),
            ),
          ]),
          Gap.l,
          Text(hi ? 'अपने product को ज़्यादा खरीदारों तक पहुँचाएँ' : 'Reach more buyers for your product',
              style: text.bodyMedium?.copyWith(color: AppColors.textSoft)),
          Gap.m,
          _OptionCard(
            icon: Icons.image_rounded,
            color: AppColors.accent,
            title: hi ? 'पोस्टर बनाएँ और शेयर करें' : 'Make a poster & share',
            subtitle: hi
                ? 'मुफ़्त — WhatsApp, Instagram पर शेयर करें'
                : 'Free — share on WhatsApp, Instagram',
            badge: hi ? 'मुफ़्त' : 'FREE',
            badgeColor: AppColors.success,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => PosterScreen(product: product))),
          ),
          Gap.m,
          _OptionCard(
            icon: Icons.rocket_launch_rounded,
            color: AppColors.primary,
            title: hi ? 'Boost करें (विज्ञापन)' : 'Boost with Ads',
            subtitle: hi
                ? 'Facebook · Instagram पर विज्ञापन चलाएँ'
                : 'Run ads on Facebook · Instagram',
            badge: hi ? 'पेड' : 'PAID',
            badgeColor: AppColors.primary,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => BoostScreen(product: product))),
          ),
        ],
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(Radii.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.lg),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(children: [
            Container(
              width: 52, height: 52, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(Radii.md),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            Gap.m,
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Flexible(child: Text(title, style: text.titleMedium)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(Radii.pill),
                    ),
                    child: Text(badge,
                        style: TextStyle(color: badgeColor, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ),
                ]),
                const SizedBox(height: 3),
                Text(subtitle, style: text.bodySmall?.copyWith(color: AppColors.textSoft)),
              ]),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI POSTER — rendered on-device, captured to PNG, shared to WhatsApp/Insta.
// ─────────────────────────────────────────────────────────────────────────────
class PosterScreen extends ConsumerStatefulWidget {
  const PosterScreen({super.key, required this.product});
  final Product product;
  @override
  ConsumerState<PosterScreen> createState() => _PosterScreenState();
}

class _PosterScreenState extends ConsumerState<PosterScreen> {
  final _posterKey = GlobalKey();
  bool _busy = false;
  final Map<String, String> _aiCaptions = {}; // lang -> AI caption
  final Set<String> _fetching = {};

  /// AI (Gemini) caption if ready; otherwise kick off a fetch and show the
  /// template meanwhile (so it's instant and always works offline).
  String _captionFor(bool hi) {
    final key = hi ? 'hi' : 'en';
    final ai = _aiCaptions[key];
    if (ai != null) return ai;
    if (!_fetching.contains(key)) {
      _fetching.add(key);
      ref.read(apiProvider).marketingCaption(widget.product.id, lang: key).then((c) {
        if (mounted && c != null && c.trim().isNotEmpty) {
          setState(() => _aiCaptions[key] = c.trim());
        }
      });
    }
    return _template(hi);
  }

  bool _captionReady(bool hi) => _aiCaptions.containsKey(hi ? 'hi' : 'en');

  String _template(bool hi) {
    final p = widget.product;
    final title = p.titleFor(hi) ?? 'Handmade product';
    final price = rupees(p.finalPrice ?? p.suggestedPriceMax ?? 0);
    final tags = p.tags.isEmpty ? ['handmade', 'artisan'] : p.tags;
    final hashtags = ['#KalaSetu', '#handmade', ...tags.take(3).map((t) => '#$t')].join(' ');
    return hi
        ? '✨ $title ✨\n\n💰 सिर्फ़ $price\n🎨 हाथ से बना · शुद्ध कारीगरी\n📞 ऑर्डर के लिए संपर्क करें!\n\n$hashtags'
        : '✨ $title ✨\n\n💰 Only $price\n🎨 Handmade · Authentic craft\n📞 DM to order!\n\n$hashtags';
  }

  Future<void> _share(bool hi) async {
    setState(() => _busy = true);
    try {
      final boundary =
          _posterKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = data!.buffer.asUint8List();
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/kalasetu_poster.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: _captionFor(hi));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(hi ? 'शेयर नहीं हो सका' : 'Could not share')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copyCaption(bool hi) async {
    await Clipboard.setData(ClipboardData(text: _captionFor(hi)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(hi ? 'कैप्शन कॉपी हो गया' : 'Caption copied')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final hi = lang == AppLang.hi;
    final api = ref.read(apiProvider);
    final p = widget.product;
    final img = p.enhancedImageUrl ?? p.rawImageUrl;

    return Scaffold(
      appBar: AppBar(title: Text(hi ? 'पोस्टर' : 'Poster')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // the poster (captured for sharing)
          Center(
            child: RepaintBoundary(
              key: _posterKey,
              child: _PosterCard(
                imageUrl: img == null ? null : api.mediaUrl(img),
                title: p.titleFor(hi) ?? 'Handmade',
                price: rupees(p.finalPrice ?? p.suggestedPriceMax ?? 0),
                hi: hi,
              ),
            ),
          ),
          Gap.l,
          FilledButton.icon(
            onPressed: _busy ? null : () => _share(hi),
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.share_rounded),
            label: Text(hi ? 'शेयर करें (WhatsApp, Insta…)' : 'Share (WhatsApp, Insta…)'),
          ),
          Gap.s,
          OutlinedButton.icon(
            onPressed: () => _copyCaption(hi),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: Text(hi ? 'कैप्शन कॉपी करें' : 'Copy caption'),
          ),
          Gap.m,
          Row(children: [
            const Icon(Icons.auto_awesome_rounded, size: 15, color: AppColors.accent),
            const SizedBox(width: 6),
            Text(hi ? 'AI कैप्शन' : 'AI caption',
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(width: 8),
            if (!_captionReady(hi))
              const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
          ]),
          Gap.xs,
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: AppColors.line),
            ),
            child: Text(_captionFor(hi), style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// The visual poster design (product photo + branded overlays).
class _PosterCard extends StatelessWidget {
  const _PosterCard({
    required this.imageUrl,
    required this.title,
    required this.price,
    required this.hi,
  });
  final String? imageUrl;
  final String title;
  final String price;
  final bool hi;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8F3620), Color(0xFFBE4A2F)],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        boxShadow: Decor.lift,
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // brand
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 16),
            const SizedBox(width: 6),
            Text(hi ? 'कलासेतु · हस्तनिर्मित' : 'KalaSetu · Handmade',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(Radii.md),
            child: (imageUrl == null)
                ? Container(height: 300, color: AppColors.surfaceAlt, child: const Icon(Icons.image, size: 60, color: AppColors.muted))
                : Image.network(imageUrl!, width: 300, height: 300, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(height: 300, color: AppColors.surfaceAlt)),
          ),
          const SizedBox(height: 10),
          Text(title,
              maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, height: 1.2)),
          const SizedBox(height: 8),
          // price + handmade badges
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(color: AppColors.accent, borderRadius: BorderRadius.circular(Radii.pill)),
              child: Text(price, style: const TextStyle(color: Color(0xFF3A2A20), fontWeight: FontWeight.w900, fontSize: 18)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(Radii.pill),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(hi ? '✋ हाथ से बना' : '✋ Handmade',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Text(hi ? '📞 ऑर्डर के लिए संपर्क करें' : '📞 Contact to order',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOST — configure a paid ad (image source, budget, days, audience). The
// "Boost now" call hits the backend the friend will wire to the Meta Ads API.
// ─────────────────────────────────────────────────────────────────────────────
class BoostScreen extends ConsumerStatefulWidget {
  const BoostScreen({super.key, required this.product});
  final Product product;
  @override
  ConsumerState<BoostScreen> createState() => _BoostScreenState();
}

enum _AdImage { poster, studio, gallery }

class _BoostScreenState extends ConsumerState<BoostScreen> {
  _AdImage _source = _AdImage.studio;

  /// Per-DAY budget, not a total. Meta charges per day and enforces a ~₹97/day
  /// floor, so picking a small total and spreading it over a week would silently
  /// be raised to the floor (e.g. "₹100 over 7 days" would really cost ~₹679).
  /// Choosing the daily rate and showing the derived total keeps it honest.
  int _dailyBudget = 100;
  int _days = 5;
  String _audience = 'nearby';
  String? _galleryPath;
  bool _busy = false;

  int get _total => _dailyBudget * _days;
  int get _reachLow => (_total * 1.4).round();
  int get _reachHigh => (_total * 3.2).round();

  Future<void> _pickGallery() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (f != null) setState(() { _galleryPath = f.path; _source = _AdImage.gallery; });
  }

  Future<void> _boost(bool hi) async {
    setState(() => _busy = true);
    try {
      final result = await ref.read(apiProvider).boostProduct(
            // The API takes the total; sending daily*days means the backend's
            // total/days lands back on exactly the rate shown here.
            productId: widget.product.id,
            budgetRupees: _total.toDouble(),
            days: _days,
            audience: _audience,
            imageSource: switch (_source) {
              _AdImage.poster => 'poster',
              _AdImage.studio => 'studio',
              _AdImage.gallery => 'gallery',
            },
          );
      if (!mounted) return;
      setState(() => _busy = false);
      // The boost is persisted as a Campaign server-side — refresh so it shows
      // up in the Marketing screen's "Your campaigns" list right away.
      ref.invalidate(campaignsProvider);
      final reach = result.estimatedReach.length == 2
          ? '${result.estimatedReach[0]}–${result.estimatedReach[1]}'
          : '$_reachLow–$_reachHigh';
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 40),
          title: Text(hi ? 'विज्ञापन बन गया' : 'Ad created'),
          content: Text(
            hi
                ? 'आपका विज्ञापन Facebook/Instagram खाते में रुका हुआ (paused) बना है — '
                    'जब आप चालू करेंगे तभी चलेगा और खर्च होगा।\n\n'
                    'अनुमानित पहुँच: $reach लोग।'
                : 'Your ad was created in your Facebook/Instagram account and is '
                    'paused — it only runs and spends once you resume it.\n\n'
                    'Estimated reach: $reach people.',
          ),
          actions: [
            FilledButton(
              onPressed: () { Navigator.pop(context); Navigator.pop(context); },
              child: Text(hi ? 'ठीक है' : 'OK'),
            ),
          ],
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(hi ? 'Boost नहीं हो सका — फिर कोशिश करें' : 'Could not boost — please try again')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final hi = lang == AppLang.hi;
    final text = Theme.of(context).textTheme;
    final api = ref.read(apiProvider);
    final img = widget.product.enhancedImageUrl ?? widget.product.rawImageUrl;
    final preview = _source == _AdImage.gallery && _galleryPath != null
        ? null
        : (img == null ? null : api.mediaUrl(img));

    return Scaffold(
      appBar: AppBar(title: Text(hi ? 'Boost करें' : 'Boost')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ad preview
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.md),
              child: _source == _AdImage.gallery && _galleryPath != null
                  ? Image.file(File(_galleryPath!), width: 220, height: 220, fit: BoxFit.cover)
                  : KNetImage(preview, width: 220, height: 220),
            ),
          ),
          Gap.m,
          _label(hi ? 'विज्ञापन की तस्वीर' : 'Ad image'),
          Gap.s,
          _choiceRow([
            (hi ? 'AI पोस्टर' : 'AI Poster', _source == _AdImage.poster,
                () => setState(() => _source = _AdImage.poster)),
            (hi ? 'Studio फ़ोटो' : 'Studio photo', _source == _AdImage.studio,
                () => setState(() => _source = _AdImage.studio)),
            (hi ? 'गैलरी' : 'Gallery', _source == _AdImage.gallery, _pickGallery),
          ]),
          Gap.l,
          _label(hi ? 'रोज़ का बजट' : 'Daily budget'),
          Gap.s,
          // Meta's floor is ~₹97/day, so ₹100 is the lowest honest option.
          _choiceRow([
            for (final b in [100, 250, 500])
              ('₹$b', _dailyBudget == b, () => setState(() => _dailyBudget = b)),
          ]),
          Gap.l,
          _label(hi ? 'कितने दिन' : 'Duration'),
          Gap.s,
          _choiceRow([
            for (final d in [3, 5, 7])
              ('$d ${hi ? 'दिन' : 'days'}', _days == d, () => setState(() => _days = d)),
          ]),
          Gap.l,
          _label(hi ? 'किसे दिखे' : 'Audience'),
          Gap.s,
          _choiceRow([
            (hi ? 'आस-पास' : 'Nearby', _audience == 'nearby',
                () => setState(() => _audience = 'nearby')),
            (hi ? 'पूरे भारत' : 'All India', _audience == 'india',
                () => setState(() => _audience = 'india')),
          ]),
          Gap.l,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
            ),
            child: Column(children: [
              Text(hi ? 'अनुमानित पहुँच' : 'Estimated reach', style: text.labelSmall),
              Gap.xs,
              Text('$_reachLow – $_reachHigh ${hi ? 'लोग' : 'people'}',
                  style: text.titleLarge?.copyWith(color: AppColors.success, fontWeight: FontWeight.w800)),
              // Show the derived total, so "₹100/day × 5 days = ₹500" is explicit
              // rather than the artisan guessing what they committed to.
              Text(
                  '₹$_dailyBudget/${hi ? 'दिन' : 'day'} × $_days ${hi ? 'दिन' : 'days'}'
                  ' = ₹$_total ${hi ? 'कुल' : 'total'}',
                  style: text.bodySmall),
            ]),
          ),
          Gap.l,
          FilledButton.icon(
            onPressed: _busy ? null : () => _boost(hi),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            icon: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.rocket_launch_rounded),
            label: Text('${hi ? 'Boost करें' : 'Boost now'} · ₹$_total'),
          ),
          Gap.s,
          // The ad is created PAUSED — nothing is charged until the artisan
          // resumes it in Ads Manager. Saying "secure payment" would imply a
          // charge that never happens.
          Text(
              hi
                  ? 'विज्ञापन रुका हुआ बनेगा — आपकी मंज़ूरी तक कोई खर्च नहीं'
                  : "Created paused — nothing is charged until you resume it",
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }

  Widget _label(String s) => Text(s, style: Theme.of(context).textTheme.titleSmall);

  /// Row of equal-width choice chips (Expanded must be a direct Row child, so we
  /// interleave SizedBox spacers here — never wrap an Expanded in a Padding).
  Widget _choiceRow(List<(String, bool, VoidCallback)> opts) {
    final children = <Widget>[];
    for (var i = 0; i < opts.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 8));
      children.add(Expanded(child: _choice(opts[i].$1, opts[i].$2, opts[i].$3)));
    }
    return Row(children: children);
  }

  Widget _choice(String label, bool sel, VoidCallback onTap) => InkWell(
        borderRadius: BorderRadius.circular(Radii.md),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: sel ? AppColors.primary.withValues(alpha: 0.10) : AppColors.surface,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: sel ? AppColors.primary : AppColors.line, width: sel ? 1.6 : 1.2),
          ),
          child: Text(label,
              textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: sel ? AppColors.primary : AppColors.text,
                  fontWeight: sel ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13.5)),
        ),
      );
}
