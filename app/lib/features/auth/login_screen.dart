import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/api.dart';

enum Role { artisan, buyer }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  Role _role = Role.artisan;
  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  Api get _api => ref.read(apiProvider);

  Future<void> _sendOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      final devOtp = _role == Role.artisan
          ? await _api.requestOtp(_phone.text.trim())
          : await _api.buyerRequestOtp(_phone.text.trim());
      setState(() { _otpSent = true; if (devOtp != null) _otp.text = devOtp; });
    } catch (e) {
      setState(() => _error = 'Failed to send OTP — is the backend running?');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    setState(() { _loading = true; _error = null; });
    try {
      if (_role == Role.artisan) {
        await _api.verifyOtp(_phone.text.trim(), _otp.text.trim());
        if (mounted) context.go('/home');
      } else {
        await _api.buyerVerifyOtp(_phone.text.trim(), _otp.text.trim());
        if (mounted) context.go('/buyer/home');
      }
    } catch (e) {
      setState(() => _error = 'Invalid OTP');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    return Scaffold(
      body: Column(
        children: [
          // hero
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 56, 24, 48),
            decoration: const BoxDecoration(
              gradient: Decor.heroGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(Radii.xl)),
            ),
            child: Column(
              children: [
                Container(
                  width: 78, height: 78,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(Radii.lg),
                  ),
                  child: const Icon(Icons.storefront_rounded, size: 42, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Text(T.of(context, lang, 'app_name'),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text(T.of(context, lang, 'tagline'),
                    style: TextStyle(fontSize: 15, color: Colors.white.withValues(alpha: 0.92))),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<Role>(
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppColors.primary,
                      selectedForegroundColor: Colors.white,
                      side: const BorderSide(color: AppColors.line),
                    ),
                    segments: const [
                      ButtonSegment(value: Role.artisan, label: Text('Artisan'), icon: Icon(Icons.brush)),
                      ButtonSegment(value: Role.buyer, label: Text('Buyer'), icon: Icon(Icons.shopping_bag)),
                    ],
                    selected: {_role},
                    onSelectionChanged: _otpSent ? null : (s) => setState(() => _role = s.first),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: T.of(context, lang, 'phone'),
                      prefixIcon: const Icon(Icons.phone_outlined),
                    ),
                  ),
                  if (_otpSent) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _otp,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'OTP',
                        prefixIcon: Icon(Icons.lock_outline),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Row(children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
                    ]),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : (_otpSent ? _verify : _sendOtp),
                    child: _loading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(T.of(context, lang, _otpSent ? 'verify' : 'send_otp')),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => ref.read(langProvider.notifier).state =
                          lang == AppLang.hi ? AppLang.en : AppLang.hi,
                      icon: const Icon(Icons.translate, size: 18),
                      label: Text(lang == AppLang.hi ? 'English' : 'हिंदी में'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
