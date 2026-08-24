import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/api.dart';

/// Kala — the real-time voice agent. Streams mic PCM (16 kHz) to the backend
/// relay over a WebSocket and plays Kala's PCM (24 kHz) reply as it arrives.
/// Kala speaks Hindi and can call backend tools (orders, earnings, products).
enum _Kala { idle, connecting, live, error }

class KalaScreen extends ConsumerStatefulWidget {
  const KalaScreen({super.key});
  @override
  ConsumerState<KalaScreen> createState() => _KalaScreenState();
}

class _KalaScreenState extends ConsumerState<KalaScreen> {
  final _recorder = AudioRecorder();
  WebSocketChannel? _ws;
  StreamSubscription<dynamic>? _wsSub;
  StreamSubscription<Uint8List>? _micSub;
  final List<Uint8List> _pcmQueue = [];
  bool _speaking = false;
  _Kala _state = _Kala.idle;
  String _status = '';
  String _caption = ''; // live transcript of what Kala is saying

  Api get _api => ref.read(apiProvider);
  bool get _hi => ref.read(langProvider) == AppLang.hi;

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      setState(() {
        _state = _Kala.error;
        _status = _hi ? 'माइक की अनुमति दें — सेटिंग्स में चालू करें' : 'Allow microphone in Settings';
      });
      return;
    }
    setState(() {
      _state = _Kala.connecting;
      _status = _hi ? 'कला आ रही है…' : 'Kala is joining…';
    });
    try {
      // playback engine: 24 kHz mono PCM16
      await FlutterPcmSound.setup(sampleRate: 24000, channelCount: 1);
      FlutterPcmSound.setFeedThreshold(8000);
      FlutterPcmSound.setFeedCallback(_onFeed);

      _ws = WebSocketChannel.connect(Uri.parse(_api.voiceWsUrl));
      await _ws!.ready;
      _wsSub = _ws!.stream.listen(_onMessage, onDone: _teardown, onError: (_) => _fail());

      // mic: 16 kHz mono PCM16 stream -> WebSocket. echoCancel/noiseSuppress are
      // essential for hands-free SPEAKER mode — otherwise the mic picks up Kala's
      // own voice from the speaker and feeds it back (echo). autoGain evens out
      // soft/loud speakers.
      final mic = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        echoCancel: true,
        noiseSuppress: true,
        autoGain: true,
      ));
      _micSub = mic.listen((chunk) => _ws?.sink.add(chunk));

      FlutterPcmSound.start();
      if (mounted) {
        setState(() {
          _state = _Kala.live;
          _status = _hi ? 'बोलिए… कला सुन रही है' : 'Speak… Kala is listening';
        });
      }
    } catch (_) {
      _fail();
    }
  }

  void _onMessage(dynamic msg) {
    if (msg is List<int>) {
      // Kala's voice (PCM 24 kHz) — queue for the feed loop.
      _pcmQueue.add(msg is Uint8List ? msg : Uint8List.fromList(msg));
      if (!_speaking && mounted) {
        setState(() {
          _speaking = true;
          _caption = ''; // fresh turn
          _status = _hi ? 'कला बोल रही है…' : 'Kala is speaking…';
        });
      }
    } else if (msg is String) {
      final ev = jsonDecode(msg) as Map<String, dynamic>;
      switch (ev['type']) {
        case 'tool':
          if (mounted) setState(() => _status = _hi ? 'देख रही हूँ…' : 'Checking…');
          break;
        case 'caption':
          if (mounted) setState(() => _caption += (ev['text'] as String?) ?? '');
          break;
        case 'interrupted':
          _pcmQueue.clear(); // barge-in: drop queued audio
          break;
        case 'turn_complete':
          if (mounted) {
            setState(() {
              _speaking = false;
              _status = _hi ? 'बोलिए…' : 'Speak…';
            });
          }
          break;
        case 'error':
          _fail();
          break;
      }
    }
  }

  /// Pull-based playback: feed queued audio, or a little silence to keep the
  /// engine's feed loop alive while waiting for the next chunk.
  void _onFeed(int remainingFrames) {
    if (_pcmQueue.isNotEmpty) {
      final chunk = _pcmQueue.removeAt(0);
      FlutterPcmSound.feed(PcmArrayInt16(bytes: ByteData.sublistView(chunk)));
    } else {
      FlutterPcmSound.feed(PcmArrayInt16(bytes: ByteData(2880))); // ~60ms silence
    }
  }

  void _fail() {
    if (mounted) {
      setState(() {
        _state = _Kala.error;
        _status = _hi ? 'कनेक्शन टूटा — फिर कोशिश करें' : 'Connection lost — try again';
      });
    }
    _teardown(keepError: true);
  }

  Future<void> _teardown({bool keepError = false}) async {
    try { await _micSub?.cancel(); } catch (_) {}
    try { await _recorder.stop(); } catch (_) {}
    try { await _wsSub?.cancel(); } catch (_) {}
    try { await _ws?.sink.close(); } catch (_) {}
    try { await FlutterPcmSound.release(); } catch (_) {}
    _pcmQueue.clear();
    _ws = null;
    if (mounted && !keepError) {
      setState(() { _state = _Kala.idle; _speaking = false; _status = ''; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hi = _hi;
    final text = Theme.of(context).textTheme;
    final live = _state == _Kala.live || _state == _Kala.connecting;
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Kala', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            _Orb(active: live, speaking: _speaking),
            const SizedBox(height: 36),
            Text(
              _status.isEmpty
                  ? (hi ? 'आवाज़ से पूछें — ऑर्डर, कमाई, या मदद' : 'Ask by voice — orders, earnings, or help')
                  : _status,
              textAlign: TextAlign.center,
              style: text.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              hi ? 'उदाहरण: "आज कितने ऑर्डर आए?"' : 'e.g. "How many orders today?"',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: Colors.white70),
            ),
            if (_caption.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(_caption,
                      textAlign: TextAlign.center,
                      style: text.bodyLarge?.copyWith(color: Colors.white, height: 1.4)),
                ),
              ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.paddingOf(context).bottom),
              child: FilledButton.icon(
                onPressed: _state == _Kala.connecting
                    ? null
                    : (live ? () => _teardown() : _start),
                style: FilledButton.styleFrom(
                  backgroundColor: live ? AppColors.danger : Colors.white,
                  foregroundColor: live ? Colors.white : AppColors.primaryDark,
                  minimumSize: const Size.fromHeight(58),
                ),
                icon: Icon(live ? Icons.stop_rounded : Icons.mic_rounded),
                label: Text(
                  live
                      ? (hi ? 'बंद करें' : 'End')
                      : (hi ? 'कला से बात करें' : 'Talk to Kala'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A soft glowing orb that pulses while Kala is active / speaking.
class _Orb extends StatefulWidget {
  const _Orb({required this.active, required this.speaking});
  final bool active;
  final bool speaking;
  @override
  State<_Orb> createState() => _OrbState();
}

class _OrbState extends State<_Orb> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final t = widget.active ? _c.value : 0.0;
        final size = 150.0 + (widget.speaking ? 26 : 12) * t;
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                Colors.white.withValues(alpha: 0.95),
                AppColors.accent.withValues(alpha: 0.85),
                AppColors.primary.withValues(alpha: 0.6),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.4 + 0.3 * t),
                blurRadius: 40 + 30 * t,
                spreadRadius: 4 + 8 * t,
              ),
            ],
          ),
          child: Icon(
            widget.speaking ? Icons.graphic_eq_rounded : Icons.auto_awesome_rounded,
            size: 48,
            color: AppColors.primaryDark,
          ),
        );
      },
    );
  }
}
