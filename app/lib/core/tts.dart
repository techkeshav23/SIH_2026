import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'l10n.dart';
import 'theme.dart';

/// Text-to-speech for low-literacy accessibility: users can tap a speaker to
/// hear any screen/label read aloud in Hindi or English.
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _busy = false;

  Future<void> speak(String text, AppLang lang) async {
    if (text.trim().isEmpty) return;
    try {
      if (_busy) await _tts.stop();
      _busy = true;
      await _tts.setLanguage(lang == AppLang.hi ? 'hi-IN' : 'en-US');
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      await _tts.speak(text);
    } catch (_) {
      // TTS may be unavailable on some devices/emulators — fail silently.
    } finally {
      _busy = false;
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// A small speaker button that reads [text] aloud in the current language.
/// Place next to any content that a low-literacy user should be able to hear.
class KSpeak extends ConsumerWidget {
  const KSpeak(this.text, {super.key, this.color, this.size = 22});
  final String text;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.read(langProvider);
    return IconButton(
      tooltip: T.of(context, lang, 'read_aloud'),
      visualDensity: VisualDensity.compact,
      onPressed: () => TtsService.instance.speak(text, lang),
      icon: Icon(Icons.volume_up_rounded, size: size, color: color ?? AppColors.primary),
    );
  }
}
