import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../core/format.dart';
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
  final _recorder = AudioRecorder();

  Product? _product;
  bool _busy = false;
  bool _recording = false;
  String _status = '';
  PriceSuggestion? _price;

  Api get _api => ref.read(apiProvider);

  @override
  void dispose() {
    _recorder.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureProduct() async {
    _product ??= await _api.createProduct();
  }

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _takePhotoFrom(ImageSource source) async {
    final lang = ref.read(langProvider);
    String path = '';
    if (!_api.demoMode) {
      final file = await _picker.pickImage(source: source, imageQuality: 90);
      if (file == null) return;
      path = file.path;
    }
    setState(() { _busy = true; _status = T.of(context, lang, 'enhancing'); });
    try {
      await _ensureProduct();
      await _api.enhanceImage(_product!.id, path); // demo ignores path, returns sample before/after
      final ready = await _api.pollUntilReady(_product!.id);
      setState(() => _product = ready);
    } catch (_) {
      _snack(lang == AppLang.hi ? 'फ़ोटो सुधार नहीं हो सका — फिर कोशिश करें' : 'Enhancement failed — please try again');
    } finally {
      if (mounted) setState(() { _busy = false; _status = ''; });
    }
  }

  /// Voice entry point. Demo mode simulates; real mode records the mic and sends
  /// the audio to the backend Vertex multimodal speech->listing job.
  Future<void> _onVoiceTap() async {
    if (_api.demoMode) {
      await _simulateVoice();
      return;
    }
    if (_recording) {
      await _stopAndCatalog();
    } else {
      await _startRecording();
    }
  }

  /// Demo-mode voice: simulate listening, fill a canned transcript, then catalog.
  Future<void> _simulateVoice() async {
    final uiLang = ref.read(langProvider);
    setState(() { _busy = true; _status = uiLang == AppLang.hi ? 'सुन रहा है…' : 'Listening…'; });
    await Future.delayed(const Duration(milliseconds: 1300));
    _textCtrl.text = uiLang == AppLang.hi
        ? 'यह हाथ से बुनी बनारसी रेशम साड़ी है, सुनहरी ज़री के साथ'
        : 'This is a handwoven Banarasi silk saree with golden zari work';
    if (mounted) setState(() {});
    await _catalogFromText();
  }

  /// Start recording the artisan's spoken description to a temp WAV file.
  Future<void> _startRecording() async {
    final uiLang = ref.read(langProvider);
    try {
      if (!await _recorder.hasPermission()) {
        _snack(uiLang == AppLang.hi
            ? 'माइक की अनुमति चाहिए — सेटिंग्स में चालू करें'
            : 'Microphone permission needed — enable it in Settings');
        return;
      }
      await _ensureProduct();
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav), path: path);
      if (mounted) setState(() => _recording = true);
    } catch (_) {
      if (mounted) setState(() => _recording = false);
      _snack(uiLang == AppLang.hi ? 'रिकॉर्डिंग शुरू नहीं हुई' : 'Could not start recording');
    }
  }

  /// Stop recording, upload the clip, and poll until the AI listing is ready.
  Future<void> _stopAndCatalog() async {
    final uiLang = ref.read(langProvider);
    final lang = uiLang == AppLang.hi ? 'hi' : 'en';
    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {/* fall through to null-path handling */}
    if (mounted) setState(() => _recording = false);
    if (path == null) {
      _snack(uiLang == AppLang.hi ? 'आवाज़ रिकॉर्ड नहीं हुई' : 'No audio captured — try again');
      return;
    }
    setState(() { _busy = true; _status = T.of(context, uiLang, 'writing_listing'); });
    try {
      await _ensureProduct();
      await _api.catalogFromVoice(_product!.id, path, sourceLang: lang);
      final ready = await _api.pollUntilReady(_product!.id);
      setState(() => _product = ready);
      if ((ready.titleEn ?? '').isEmpty && (ready.titleHi ?? '').isEmpty) {
        _snack(uiLang == AppLang.hi
            ? 'साफ़ सुनाई नहीं दिया — फिर बोलें या नीचे टाइप करें'
            : "Couldn't hear clearly — speak again or type below");
      }
    } on DioException catch (e) {
      if (_isOffline(e)) {
        _snack(uiLang == AppLang.hi
            ? 'इंटरनेट नहीं — नीचे टाइप करके ऑफ़लाइन सहेजें'
            : 'No internet — type below to save offline');
      } else {
        _snack(uiLang == AppLang.hi
            ? 'आवाज़ प्रोसेस नहीं हुई — फिर कोशिश करें'
            : 'Voice processing failed — please try again');
      }
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
                    Row(children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _busy ? null : () => _takePhotoFrom(ImageSource.camera),
                          icon: const Icon(Icons.photo_camera_rounded, size: 20),
                          label: Text(T.of(context, lang, 'take_photo')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => _takePhotoFrom(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_rounded, size: 20),
                          label: Text(T.of(context, lang, 'gallery')),
                        ),
                      ),
                    ]),
                    Gap.xs,
                    Text(T.of(context, lang, 'photo_hint'),
                        textAlign: TextAlign.center, style: text.labelSmall),
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
                    FilledButton.icon(
                      onPressed: _busy ? null : _onVoiceTap,
                      icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
                      label: Text(_recording
                          ? (lang == AppLang.hi ? 'रोकें और लिखवाएं' : 'Stop & generate')
                          : T.of(context, lang, 'record_voice')),
                      style: _recording
                          ? FilledButton.styleFrom(backgroundColor: AppColors.danger)
                          : null,
                    ),
                    if (_recording) ...[
                      Gap.s,
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const _RecDot(),
                        const SizedBox(width: 8),
                        Text(lang == AppLang.hi ? 'सुन रहा है… बोलिए' : 'Listening… speak now',
                            style: text.labelMedium?.copyWith(color: AppColors.danger)),
                      ]),
                    ],
                    Gap.m,
                    Row(children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(lang == AppLang.hi ? 'या टाइप करें' : 'or type', style: text.labelSmall),
                      ),
                      const Expanded(child: Divider()),
                    ]),
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
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _catalogFromText,
                      icon: const Icon(Icons.edit_note_rounded),
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
                            // Primary title in the artisan's selected language.
                            Text(p!.titleFor(lang == AppLang.hi) ?? '', style: text.titleMedium),
                            if (((lang == AppLang.hi ? p.titleEn : p.titleHi) ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text((lang == AppLang.hi ? p.titleEn : p.titleHi)!, style: text.bodyMedium),
                            ],
                            if ((p.descFor(lang == AppLang.hi) ?? '').isNotEmpty) ...[
                              Gap.s,
                              // Description in the artisan's selected language.
                              Text(p.descFor(lang == AppLang.hi) ?? '', style: text.bodyMedium),
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
                              '${rupees(_price!.min)} – ${rupees(_price!.max)}',
                              textAlign: TextAlign.center,
                              style: text.displaySmall?.copyWith(color: AppColors.success),
                            ),
                            Gap.s,
                            Text(_price!.reasoning,
                                textAlign: TextAlign.center, style: text.bodyMedium),
                            if (_price!.comparables.isNotEmpty) ...[
                              Gap.m,
                              const Divider(),
                              Gap.s,
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(lang == AppLang.hi ? 'तुलना (बाज़ार)' : 'Comparable listings',
                                    style: text.labelSmall),
                              ),
                              Gap.xs,
                              for (final c in _price!.comparables)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(children: [
                                    const Icon(Icons.circle, size: 5, color: AppColors.muted),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(c.title, style: text.bodyMedium, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    Text(rupees(c.price),
                                        style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSoft)),
                                  ]),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Gap.m,
              FilledButton.icon(
                // Only publish a complete listing: title + image + price.
                onPressed: (p != null &&
                        (p.titleFor(lang == AppLang.hi)?.isNotEmpty ?? false) &&
                        (p.enhancedImageUrl != null || p.rawImageUrl != null) &&
                        _price != null &&
                        !_busy)
                    ? _publish
                    : null,
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

/// A small pulsing red dot shown while the mic is actively recording.
class _RecDot extends StatefulWidget {
  const _RecDot();
  @override
  State<_RecDot> createState() => _RecDotState();
}

class _RecDotState extends State<_RecDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(
        width: 12,
        height: 12,
        decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
      ),
    );
  }
}

/// A single step in the vertical stepper: numbered square badge + connector
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
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(Radii.sm),
                ),
                child: Text('$step',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
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

/// Real before/after: the raw photo next to the AI-enhanced result, so the
/// enhancement is visible. Falls back to just the enhanced image if no raw.
class _BeforeAfter extends StatelessWidget {
  const _BeforeAfter({required this.api, required this.product, required this.lang});
  final Api api;
  final Product product;
  final AppLang lang;

  Widget _framed(BuildContext context, String url, String label, {bool after = false}) {
    return Expanded(
      child: Column(children: [
        Stack(children: [
          KNetImage(api.mediaUrl(url), height: 150, width: double.infinity, radius: Radii.md),
          if (after)
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.success, borderRadius: BorderRadius.circular(Radii.pill), boxShadow: Decor.soft),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.auto_awesome, size: 12, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(T.of(context, lang, 'ai_enhanced'),
                      style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
        ]),
        const SizedBox(height: 6),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final raw = product.rawImageUrl;
    if (raw == null) {
      return _framed(context, product.enhancedImageUrl!, T.of(context, lang, 'ai_enhanced'), after: true);
    }
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _framed(context, raw, lang == AppLang.hi ? 'पहले' : 'Before'),
      const SizedBox(width: 10),
      _framed(context, product.enhancedImageUrl!, lang == AppLang.hi ? 'बाद में' : 'After', after: true),
    ]);
  }
}
