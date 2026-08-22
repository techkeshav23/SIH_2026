import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/tts.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/local_store.dart';
import '../../data/models.dart';

/// The hero flow: photo -> AI enhance -> voice/text -> AI listing -> price -> publish.
class CreateProductScreen extends ConsumerStatefulWidget {
  const CreateProductScreen({super.key});
  @override
  ConsumerState<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends ConsumerState<CreateProductScreen> {
  final _picker = ImagePicker();
  final _textCtrl = TextEditingController();

  Product? _product;
  bool _busy = false;
  String _status = '';
  PriceSuggestion? _price;

  Api get _api => ref.read(apiProvider);

  Future<void> _ensureProduct() async {
    _product ??= await _api.createProduct();
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(
        source: ImageSource.camera, imageQuality: 90);
    if (file == null) return;
    final lang = ref.read(langProvider);
    setState(() { _busy = true; _status = T.of(context, lang, 'enhancing'); });
    try {
      await _ensureProduct();
      await _api.enhanceImage(_product!.id, file.path);
      final ready = await _api.pollUntilReady(_product!.id);
      setState(() => _product = ready);
    } catch (_) {
      _snack(lang == AppLang.hi ? 'फ़ोटो सुधार नहीं हो सका — फिर कोशिश करें' : 'Enhancement failed — please try again');
    } finally {
      if (mounted) setState(() { _busy = false; _status = ''; });
    }
  }

  Future<void> _catalogFromText() async {
    final uiLang = ref.read(langProvider);
    if (_textCtrl.text.trim().isEmpty) {
      _snack(uiLang == AppLang.hi ? 'पहले उत्पाद के बारे में बताएं' : 'Describe your product first');
      return;
    }
    final lang = uiLang == AppLang.hi ? 'hi' : 'en';
    setState(() { _busy = true; _status = T.of(context, uiLang, 'writing_listing'); });
    try {
      await _ensureProduct();
      final p = await _api.catalogFromText(_product!.id, _textCtrl.text.trim(), sourceLang: lang);
      setState(() => _product = p);
    } on DioException catch (e) {
      if (_isOffline(e)) {
        // No internet — queue the draft locally, sync later from Home.
        await LocalStore.addPendingDraft(PendingDraft(
          category: _product?.category ?? '',
          material: _product?.material ?? '',
          text: _textCtrl.text.trim(),
          lang: lang,
        ));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(uiLang == AppLang.hi
                ? 'इंटरनेट नहीं — ऑफ़लाइन सहेजा, बाद में सिंक होगा'
                : 'No internet — saved offline, will sync later')),
          );
          context.pop();
        }
      } else {
        rethrow;
      }
    } finally {
      if (mounted) setState(() { _busy = false; _status = ''; });
    }
  }

  bool _isOffline(DioException e) =>
      e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout ||
      e.type == DioExceptionType.unknown;

  Future<void> _suggestPrice() async {
    final lang = ref.read(langProvider);
    setState(() { _busy = true; _status = T.of(context, lang, 'analysing_market'); });
    try {
      await _ensureProduct();
      final price = await _api.suggestPrice(_product!.id);
      final p = await _api.getProduct(_product!.id);
      setState(() { _price = price; _product = p; });
    } catch (_) {
      _snack(lang == AppLang.hi ? 'क़ीमत नहीं मिली — फिर कोशिश करें' : 'Could not fetch price — please try again');
    } finally {
      if (mounted) setState(() { _busy = false; _status = ''; });
    }
  }

  Future<void> _publish() async {
    final lang = ref.read(langProvider);
    final ok = await confirmDialog(context,
        title: T.of(context, lang, 'list_q'),
        message: T.of(context, lang, 'list_msg'),
        confirm: T.of(context, lang, 'publish'));
    if (!ok) return;
    setState(() { _busy = true; _status = T.of(context, lang, 'processing'); });
    try {
      await _api.updateProduct(_product!.id, {'status': 'listed'});
      if (mounted) context.pop();
    } catch (_) {
      _snack(lang == AppLang.hi ? 'लिस्ट नहीं हो सका — फिर कोशिश करें' : 'Could not list — please try again');
    } finally {
      if (mounted) setState(() { _busy = false; _status = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final text = Theme.of(context).textTheme;
    final p = _product;
    return Scaffold(
      appBar: AppBar(
        title: Text(T.of(context, lang, 'add_product')),
        actions: [
          KSpeak(lang == AppLang.hi
              ? 'फ़ोटो खींचें, आवाज़ या टाइप करके बताएं, फिर क़ीमत सुझाएं'
              : 'Take a photo, describe by voice or typing, then suggest a price'),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              _StepCard(
                step: 1,
                icon: Icons.camera_alt_rounded,
                title: T.of(context, lang, 'take_photo'),
                isLast: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (p?.enhancedImageUrl != null)
                      _BeforeAfter(api: _api, product: p!, lang: lang)
                    else if (p?.rawImageUrl != null)
                      KNetImage(_api.mediaUrl(p!.rawImageUrl!), height: 180, radius: Radii.md),
                    if (p?.enhancedImageUrl != null || p?.rawImageUrl != null) Gap.m,
                    FilledButton.icon(
                      onPressed: _busy ? null : _takePhoto,
                      icon: const Icon(Icons.auto_fix_high),
                      label: Text(T.of(context, lang, 'enhance')),
                    ),
                  ],
                ),
              ),
              _StepCard(
                step: 2,
                icon: Icons.mic_rounded,
                title: T.of(context, lang, 'record_voice'),
                isLast: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(Radii.md),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: Row(children: [
                        const Icon(Icons.mic_none_rounded, size: 18, color: AppColors.muted),
                        const SizedBox(width: 8),
                        Expanded(child: Text(T.of(context, lang, 'voice_soon'),
                            style: text.labelSmall)),
                      ]),
                    ),
                    Gap.m,
                    TextField(
                      controller: _textCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: lang == AppLang.hi
                            ? 'हाथ से बुनी सूती साड़ी…'
                            : 'Handwoven cotton saree…',
                      ),
                    ),
                    Gap.s,
                    FilledButton.icon(
                      onPressed: _busy ? null : _catalogFromText,
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: Text(T.of(context, lang, 'generate_listing')),
                    ),
                    if (p?.titleEn != null) ...[
                      Gap.m,
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(Radii.md),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p!.titleHi ?? '', style: text.titleMedium),
                            if ((p.titleEn ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(p.titleEn ?? '', style: text.bodyMedium),
                            ],
                            if ((p.descHi ?? '').isNotEmpty) ...[
                              Gap.s,
                              Text(p.descHi ?? '', style: text.bodyMedium),
                            ],
                            if (p.tags.isNotEmpty) ...[
                              Gap.s,
                              Wrap(spacing: 6, runSpacing: 6, children: [
                                for (final t in p.tags) Chip(label: Text('#$t')),
                              ]),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _StepCard(
                step: 3,
                icon: Icons.currency_rupee_rounded,
                title: T.of(context, lang, 'suggest_price'),
                isLast: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy || p == null ? null : _suggestPrice,
                      icon: const Icon(Icons.trending_up),
                      label: Text(T.of(context, lang, 'suggest_price')),
                    ),
                    if (_price != null) ...[
                      Gap.m,
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(Radii.lg),
                          border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.local_offer_rounded,
                                    size: 15, color: AppColors.success),
                                const SizedBox(width: 6),
                                Text(lang == AppLang.hi ? 'सुझाई गई क़ीमत' : 'Suggested price',
                                    style: text.labelSmall
                                        ?.copyWith(color: AppColors.success)),
                              ],
                            ),
                            Gap.s,
                            Text(
                              '₹${_price!.min.toStringAsFixed(0)} – ₹${_price!.max.toStringAsFixed(0)}',
                              textAlign: TextAlign.center,
                              style: text.displaySmall?.copyWith(color: AppColors.success),
                            ),
                            Gap.s,
                            Text(_price!.reasoning,
                                textAlign: TextAlign.center, style: text.bodyMedium),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Gap.m,
              FilledButton.icon(
                onPressed: (p != null && _price != null && !_busy) ? _publish : null,
                icon: const Icon(Icons.storefront),
                label: Text(T.of(context, lang, 'publish')),
              ),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black.withValues(alpha: 0.28),
              child: Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 40),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(Radii.lg),
                    boxShadow: Decor.lift,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const KLoading(),
                      Gap.m,
                      Text(_status,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single step in the vertical stepper: numbered gradient badge + connector
/// line on the left, titled KCard on the right.
class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.icon,
    required this.title,
    required this.child,
    required this.isLast,
  });
  final int step;
  final IconData icon;
  final String title;
  final Widget child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: Decor.warmGradient,
                  shape: BoxShape.circle,
                  boxShadow: Decor.soft,
                ),
                child: Text('$step',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: AppColors.line,
                  ),
                ),
            ],
          ),
          Gap.m,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
              child: KCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(title, style: text.titleLarge)),
                      ],
                    ),
                    Gap.m,
                    child,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the AI-enhanced image with a rounded frame and a success "AI enhanced"
/// pill overlaid in the corner. A draggable slider can be added later.
class _BeforeAfter extends StatelessWidget {
  const _BeforeAfter({required this.api, required this.product, required this.lang});
  final Api api;
  final Product product;
  final AppLang lang;
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        KNetImage(
          api.mediaUrl(product.enhancedImageUrl!),
          height: 200,
          width: double.infinity,
          radius: Radii.md,
        ),
        Positioned(
          top: 10,
          left: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(Radii.pill),
              boxShadow: Decor.soft,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_awesome, size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Text(T.of(context, lang, 'ai_enhanced'),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
