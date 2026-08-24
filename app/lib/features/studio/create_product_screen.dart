import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// The hero flow as a step-by-step wizard: photo -> AI enhance -> describe
/// (voice/text) -> AI listing -> price (AI suggestion the artisan can edit) ->
/// review -> publish. One step per screen with Back/Next navigation.
class CreateProductScreen extends ConsumerStatefulWidget {
  const CreateProductScreen({super.key});
  @override
  ConsumerState<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends ConsumerState<CreateProductScreen> {
  final _picker = ImagePicker();
  final _textCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _recorder = AudioRecorder();

  static const _steps = 4; // 0 photo, 1 details, 2 price, 3 review
  int _step = 0;

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
    _priceCtrl.dispose();
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
      setState(() {
        _price = price;
        _product = p;
        // Pre-fill the editable price with the AI's upper estimate — the artisan
        // can accept it or type their own. Don't overwrite a manual entry.
        if (_priceValue == null) _priceCtrl.text = price.max.round().toString();
      });
    } catch (_) {
      _snack(lang == AppLang.hi ? 'क़ीमत नहीं मिली — फिर कोशिश करें' : 'Could not fetch price — please try again');
    } finally {
      if (mounted) setState(() { _busy = false; _status = ''; });
    }
  }

  /// The artisan's chosen final price, or null if not a valid positive number.
  double? get _priceValue {
    final v = double.tryParse(_priceCtrl.text.trim());
    return (v != null && v > 0) ? v : null;
  }

  bool _stepComplete(int step, bool hi) {
    final p = _product;
    switch (step) {
      case 0:
        return p != null && (p.enhancedImageUrl != null || p.rawImageUrl != null);
      case 1:
        return p != null && (p.titleFor(hi)?.isNotEmpty ?? false);
      case 2:
        return _priceValue != null;
      default:
        return true;
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
      // Persist the artisan's chosen final price along with going live.
      await _api.updateProduct(_product!.id, {'status': 'listed', 'final_price': _priceValue});
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
    final hi = lang == AppLang.hi;
    final labels = hi
        ? const ['फ़ोटो', 'जानकारी', 'क़ीमत', 'समीक्षा']
        : const ['Photo', 'Details', 'Price', 'Review'];
    final isLast = _step == _steps - 1;
    final canNext = _stepComplete(_step, hi);

    return Scaffold(
      appBar: AppBar(
        title: Text(T.of(context, lang, 'add_product')),
        actions: [
          KSpeak(hi
              ? 'फ़ोटो खींचें, आवाज़ या टाइप करके बताएं, फिर क़ीमत तय करें'
              : 'Take a photo, describe by voice or typing, then set a price'),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _WizardProgress(step: _step, labels: labels),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [_buildStep(context, lang, _step)],
                ),
              ),
              // --- Back / Next / Publish bar ---
              Container(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + MediaQuery.paddingOf(context).bottom),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    if (_step > 0) ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _busy ? null : () => setState(() => _step--),
                          icon: const Icon(Icons.arrow_back_rounded, size: 18),
                          label: Text(hi ? 'पीछे' : 'Back'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: _step > 0 ? 1 : 2,
                      child: FilledButton.icon(
                        onPressed: (_busy || !canNext)
                            ? null
                            : (isLast ? _publish : () => setState(() => _step++)),
                        icon: Icon(isLast ? Icons.storefront : Icons.arrow_forward_rounded, size: 20),
                        label: Text(isLast
                            ? T.of(context, lang, 'publish')
                            : (hi ? 'आगे' : 'Next')),
                      ),
                    ),
                  ],
                ),
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

  Widget _buildStep(BuildContext context, AppLang lang, int step) {
    switch (step) {
      case 0:
        return _photoStep(context, lang);
      case 1:
        return _detailsStep(context, lang);
      case 2:
        return _priceStep(context, lang);
      default:
        return _reviewStep(context, lang);
    }
  }

  Widget _stepHeader(BuildContext context, IconData icon, String title, String subtitle) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 40, height: 40, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: text.titleLarge)),
        ]),
        const SizedBox(height: 4),
        Text(subtitle, style: text.bodyMedium?.copyWith(color: AppColors.textSoft)),
        Gap.m,
      ],
    );
  }

  // --- Step 1: photo + AI enhance ---
  Widget _photoStep(BuildContext context, AppLang lang) {
    final hi = lang == AppLang.hi;
    final text = Theme.of(context).textTheme;
    final p = _product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(context, Icons.camera_alt_rounded, T.of(context, lang, 'take_photo'),
            hi ? 'फ़ोटो खींचें — AI इसे अपने आप स्टूडियो जैसा बना देगा' : 'Add a photo — AI turns it into a studio shot'),
        if (p?.enhancedImageUrl != null)
          _BeforeAfter(api: _api, product: p!, lang: lang)
        else if (p?.rawImageUrl != null)
          KNetImage(_api.mediaUrl(p!.rawImageUrl!), height: 200, radius: Radii.md),
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
    );
  }

  // --- Step 2: voice / text -> AI listing ---
  Widget _detailsStep(BuildContext context, AppLang lang) {
    final hi = lang == AppLang.hi;
    final text = Theme.of(context).textTheme;
    final p = _product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(context, Icons.mic_rounded, T.of(context, lang, 'record_voice'),
            hi ? 'बोलकर या टाइप करके बताएं — AI लिस्टिंग लिख देगा' : 'Speak or type — AI writes the listing'),
        FilledButton.icon(
          onPressed: _busy ? null : _onVoiceTap,
          icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
          label: Text(_recording
              ? (hi ? 'रोकें और लिखवाएं' : 'Stop & generate')
              : T.of(context, lang, 'record_voice')),
          style: _recording ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
        ),
        if (_recording) ...[
          Gap.s,
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const _RecDot(),
            const SizedBox(width: 8),
            Text(hi ? 'सुन रहा है… बोलिए' : 'Listening… speak now',
                style: text.labelMedium?.copyWith(color: AppColors.danger)),
          ]),
        ],
        Gap.m,
        Row(children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(hi ? 'या टाइप करें' : 'or type', style: text.labelSmall),
          ),
          const Expanded(child: Divider()),
        ]),
        Gap.m,
        TextField(
          controller: _textCtrl,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: hi ? 'हाथ से बुनी सूती साड़ी…' : 'Handwoven cotton saree…',
          ),
        ),
        Gap.s,
        OutlinedButton.icon(
          onPressed: _busy ? null : _catalogFromText,
          icon: const Icon(Icons.edit_note_rounded),
          label: Text(T.of(context, lang, 'generate_listing')),
        ),
        if (p?.titleEn != null || p?.titleHi != null) ...[
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
                Text(p!.titleFor(hi) ?? '', style: text.titleMedium),
                if (((hi ? p.titleEn : p.titleHi) ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text((hi ? p.titleEn : p.titleHi)!, style: text.bodyMedium),
                ],
                if ((p.descFor(hi) ?? '').isNotEmpty) ...[
                  Gap.s,
                  Text(p.descFor(hi) ?? '', style: text.bodyMedium),
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
    );
  }

  // --- Step 3: price (AI suggestion + editable final price) ---
  Widget _priceStep(BuildContext context, AppLang lang) {
    final hi = lang == AppLang.hi;
    final text = Theme.of(context).textTheme;
    final p = _product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(context, Icons.currency_rupee_rounded, hi ? 'क़ीमत तय करें' : 'Set your price',
            hi ? 'अपनी क़ीमत लिखें, या AI से सुझाव लेकर बदलें' : 'Enter your price, or get an AI suggestion and adjust'),
        // The editable final price — the artisan is always in control.
        TextField(
          controller: _priceCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: hi ? 'आपकी क़ीमत' : 'Your price',
            prefixText: '₹  ',
            prefixStyle: const TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.text),
            helperText: hi ? 'यही क़ीमत खरीदारों को दिखेगी' : 'This is the price buyers will see',
          ),
        ),
        Gap.m,
        OutlinedButton.icon(
          onPressed: _busy || p == null ? null : _suggestPrice,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(hi ? 'AI से क़ीमत सुझाएं' : 'Suggest price with AI'),
        ),
        if (_price != null) ...[
          Gap.m,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(Radii.lg),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
            ),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.local_offer_rounded, size: 15, color: AppColors.success),
                  const SizedBox(width: 6),
                  Text(hi ? 'AI सुझाव' : 'AI suggestion',
                      style: text.labelSmall?.copyWith(color: AppColors.success)),
                ]),
                Gap.s,
                Text('${rupees(_price!.min)} – ${rupees(_price!.max)}',
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(color: AppColors.success)),
                Gap.xs,
                // Quick-apply chips for the low/high ends of the AI range.
                Wrap(spacing: 8, alignment: WrapAlignment.center, children: [
                  ActionChip(
                    label: Text('${hi ? 'कम' : 'Low'} ${rupees(_price!.min)}'),
                    onPressed: () => setState(() => _priceCtrl.text = _price!.min.round().toString()),
                  ),
                  ActionChip(
                    label: Text('${hi ? 'ज़्यादा' : 'High'} ${rupees(_price!.max)}'),
                    onPressed: () => setState(() => _priceCtrl.text = _price!.max.round().toString()),
                  ),
                ]),
                Gap.s,
                Text(_price!.reasoning, textAlign: TextAlign.center, style: text.bodyMedium),
                if (_price!.comparables.isNotEmpty) ...[
                  Gap.m,
                  const Divider(),
                  Gap.s,
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(hi ? 'तुलना (बाज़ार)' : 'Comparable listings', style: text.labelSmall),
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
    );
  }

  // --- Step 4: review everything before going live ---
  Widget _reviewStep(BuildContext context, AppLang lang) {
    final hi = lang == AppLang.hi;
    final text = Theme.of(context).textTheme;
    final p = _product;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _stepHeader(context, Icons.fact_check_rounded, hi ? 'समीक्षा करें' : 'Review',
            hi ? 'सब ठीक है? फिर नीचे लिस्ट करें' : 'Looks good? Publish below'),
        if (p?.enhancedImageUrl != null || p?.rawImageUrl != null)
          KNetImage(_api.mediaUrl(p!.enhancedImageUrl ?? p.rawImageUrl!),
              height: 200, radius: Radii.md),
        Gap.m,
        Text(p?.titleFor(hi) ?? '', style: text.titleLarge),
        if ((p?.descFor(hi) ?? '').isNotEmpty) ...[
          Gap.s,
          Text(p!.descFor(hi) ?? '', style: text.bodyMedium),
        ],
        Gap.m,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(hi ? 'क़ीमत' : 'Price', style: text.titleMedium),
              Text(rupees(_priceValue ?? 0),
                  style: text.titleLarge?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Gap.s,
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
          const SizedBox(width: 6),
          Text(T.of(context, lang, 'ondc_ready'),
              style: text.labelSmall?.copyWith(color: AppColors.success)),
        ]),
      ],
    );
  }
}

/// Top-of-wizard progress: a labelled dot per step with a connecting bar that
/// fills as the artisan advances.
class _WizardProgress extends StatelessWidget {
  const _WizardProgress({required this.step, required this.labels});
  final int step;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 30, height: 30, alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i < step
                        ? AppColors.primary
                        : (i == step ? AppColors.primary : AppColors.surfaceAlt),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: i <= step ? AppColors.primary : AppColors.line, width: 1.5),
                  ),
                  child: i < step
                      ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                      : Text('${i + 1}',
                          style: TextStyle(
                              color: i == step ? Colors.white : AppColors.muted,
                              fontWeight: FontWeight.w800,
                              fontSize: 13)),
                ),
                const SizedBox(height: 4),
                Text(labels[i],
                    style: text.labelSmall?.copyWith(
                        color: i <= step ? AppColors.text : AppColors.muted,
                        fontWeight: i == step ? FontWeight.w700 : FontWeight.w500)),
              ],
            ),
            if (i < labels.length - 1)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.only(bottom: 18),
                  color: i < step ? AppColors.primary : AppColors.line,
                ),
              ),
          ],
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
