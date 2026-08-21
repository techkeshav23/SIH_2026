import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../data/api.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  Future<void> _sendOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      final devOtp = await ref.read(apiProvider).requestOtp(_phone.text.trim());
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
      await ref.read(apiProvider).verifyOtp(_phone.text.trim(), _otp.text.trim());
      if (mounted) context.go('/home');
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Icon(Icons.storefront_rounded, size: 88, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(T.of(context, lang, 'app_name'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const SizedBox(height: 6),
              Text(T.of(context, lang, 'tagline'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, color: AppColors.muted)),
              const SizedBox(height: 40),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: T.of(context, lang, 'phone'),
                  prefixIcon: const Icon(Icons.phone),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (_otpSent) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _otp,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'OTP',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : (_otpSent ? _verify : _sendOtp),
                child: _loading
                    ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(T.of(context, lang, _otpSent ? 'verify' : 'send_otp')),
              ),
              const Spacer(),
              // language toggle
              TextButton(
                onPressed: () => ref.read(langProvider.notifier).state =
                    lang == AppLang.hi ? AppLang.en : AppLang.hi,
                child: Text(lang == AppLang.hi ? 'English' : 'हिंदी'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
