import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/api.dart';
import '../../data/models.dart';

/// The hero flow: photo -> AI enhance -> voice/text -> AI listing -> price -> publish.
class CreateProductScreen extends ConsumerStatefulWidget {
  const CreateProductScreen({super.key});
  @override
  ConsumerState<CreateProductScreen> createState() => _CreateProductScreenState();
}

class _CreateProductScreenState extends ConsumerState<CreateProductScreen> {
  final _picker = ImagePicker();
  final _recorder = AudioRecorder();
  final _textCtrl = TextEditingController();

  Product? _product;
  bool _busy = false;
  String _status = '';
  bool _recording = false;
  PriceSuggestion? _price;

  Api get _api => ref.read(apiProvider);

  Future<void> _ensureProduct() async {
    _product ??= await _api.createProduct();
  }

  Future<void> _takePhoto() async {
    final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 90);
    if (file == null) return;
    setState(() { _busy = true; _status = 'AI enhancing photo…'; });
    try {
      await _ensureProduct();
      await _api.enhanceImage(_product!.id, file.path);
      final ready = await _api.pollUntilReady(_product!.id);
      setState(() => _product = ready);
    } finally {
      setState(() { _busy = false; _status = ''; });
    }
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path != null) await _catalogFromVoice(path);
    } else {
      if (await _recorder.hasPermission()) {
        final dir = await getTempDir();
        await _recorder.start(const RecordConfig(), path: '$dir/note.m4a');
        setState(() => _recording = true);
      }
    }
  }

  Future<String> getTempDir() async {
    // path_provider is imported transitively via record on device; fallback:
    return Directory.systemTemp.path;
  }

  Future<void> _catalogFromVoice(String path) async {
    setState(() { _busy = true; _status = 'Listening & writing listing…'; });
    try {
      await _ensureProduct();
      final lang = ref.read(langProvider) == AppLang.hi ? 'hi' : 'en';
      await _api.catalogFromVoice(_product!.id, path, sourceLang: lang);
      final ready = await _api.pollUntilReady(_product!.id);
      setState(() => _product = ready);
    } finally {
      setState(() { _busy = false; _status = ''; });
    }
  }

  Future<void> _catalogFromText() async {
    if (_textCtrl.text.trim().isEmpty) return;
    setState(() { _busy = true; _status = 'Writing listing…'; });
    try {
      await _ensureProduct();
      final lang = ref.read(langProvider) == AppLang.hi ? 'hi' : 'en';
      final p = await _api.catalogFromText(_product!.id, _textCtrl.text.trim(), sourceLang: lang);
      setState(() => _product = p);
    } finally {
      setState(() { _busy = false; _status = ''; });
    }
  }

  Future<void> _suggestPrice() async {
    setState(() { _busy = true; _status = 'Analysing market…'; });
    try {
      await _ensureProduct();
      final price = await _api.suggestPrice(_product!.id);
      final p = await _api.getProduct(_product!.id);
      setState(() { _price = price; _product = p; });
    } finally {
      setState(() { _busy = false; _status = ''; });
    }
  }

  Future<void> _publish() async {
    await _api.updateProduct(_product!.id, {'status': 'listed'});
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final p = _product;
    return Scaffold(
      appBar: AppBar(title: Text(T.of(context, lang, 'add_product'))),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StepCard(
                icon: Icons.camera_alt,
                title: T.of(context, lang, 'take_photo'),
                child: Column(
                  children: [
                    if (p?.enhancedImageUrl != null)
                      _BeforeAfter(api: _api, product: p!)
                    else if (p?.rawImageUrl != null)
                      Image.network(_api.mediaUrl(p!.rawImageUrl!), height: 180),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: _busy ? null : _takePhoto,
                      icon: const Icon(Icons.auto_fix_high),
                      label: Text(T.of(context, lang, 'enhance')),
                    ),
                  ],
                ),
              ),
              _StepCard(
                icon: Icons.mic,
                title: T.of(context, lang, 'record_voice'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy ? null : _toggleRecord,
                      style: FilledButton.styleFrom(
                          backgroundColor: _recording ? Colors.red : AppColors.primary),
                      icon: Icon(_recording ? Icons.stop : Icons.mic),
                      label: Text(_recording ? 'Stop' : T.of(context, lang, 'record_voice')),
                    ),
                    const SizedBox(height: 8),
                    const Text('— या टाइप करें / or type —',
                        textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _textCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'हाथ से बुनी सूती साड़ी…',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton(onPressed: _busy ? null : _catalogFromText, child: const Text('Generate listing')),
                    if (p?.titleEn != null) ...[
                      const Divider(height: 24),
                      Text(p!.titleHi ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(p.titleEn ?? '', style: const TextStyle(color: AppColors.muted)),
                      const SizedBox(height: 8),
                      Text(p.descHi ?? '', style: const TextStyle(fontSize: 14)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, children: [for (final t in p.tags) Chip(label: Text('#$t'))]),
                    ],
                  ],
                ),
              ),
              _StepCard(
                icon: Icons.currency_rupee,
                title: T.of(context, lang, 'suggest_price'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FilledButton.icon(
                      onPressed: _busy || p == null ? null : _suggestPrice,
                      icon: const Icon(Icons.trending_up),
                      label: Text(T.of(context, lang, 'suggest_price')),
                    ),
                    if (_price != null) ...[
                      const SizedBox(height: 12),
                      Text('₹${_price!.min.toStringAsFixed(0)} – ₹${_price!.max.toStringAsFixed(0)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.success)),
                      const SizedBox(height: 8),
                      Text(_price!.reasoning, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: (p != null && _price != null && !_busy) ? _publish : null,
                icon: const Icon(Icons.storefront),
                label: Text(T.of(context, lang, 'publish')),
              ),
              const SizedBox(height: 40),
            ],
          ),
          if (_busy)
            Container(
              color: Colors.black26,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(_status),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                CircleAvatar(backgroundColor: AppColors.bg, child: Icon(icon, color: AppColors.primary)),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              ]),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}

/// Simple before/after: shows enhanced image with a label. A draggable slider
/// can be added later (before_after_slider pkg) — kept minimal for scaffold.
class _BeforeAfter extends StatelessWidget {
  const _BeforeAfter({required this.api, required this.product});
  final Api api;
  final Product product;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(api.mediaUrl(product.enhancedImageUrl!), height: 200, fit: BoxFit.cover),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.auto_awesome, size: 16, color: AppColors.success),
            SizedBox(width: 4),
            Text('AI enhanced', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
