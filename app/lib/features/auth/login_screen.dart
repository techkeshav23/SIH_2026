import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Timer? _timer;
  int _resendIn = 0;

  Api get _api => ref.read(apiProvider);
  String get _home => _role == Role.artisan ? '/home' : '/buyer/home';

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendIn = 30);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendIn <= 1) {
        t.cancel();
        setState(() => _resendIn = 0);
      } else {
        setState(() => _resendIn -= 1);
      }
    });
  }

  Future<void> _sendOtp() async {
    if (_phone.text.trim().length != 10) {
      final lang = ref.read(langProvider);
      setState(() => _error = T.of(context, lang, 'invalid_phone'));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final devOtp = _role == Role.artisan
          ? await _api.requestOtp(_phone.text.trim())
          : await _api.buyerRequestOtp(_phone.text.trim());
      setState(() { _otpSent = true; if (devOtp != null) _otp.text = devOtp; });
      _startResendTimer();
    } catch (e) {
      final lang = ref.read(langProvider);
      setState(() => _error = lang == AppLang.hi
          ? 'सर्वर से संपर्क नहीं हो सका। इंटरनेट जाँचें और फिर कोशिश करें।'
          : 'Could not reach server. Check your internet and try again.');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verify() async {
    if (_otp.text.trim().length != 6) {
      final lang = ref.read(langProvider);
      setState(() => _error = T.of(context, lang, 'invalid_otp'));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      if (_role == Role.artisan) {
        await _api.verifyOtp(_phone.text.trim(), _otp.text.trim());
      } else {
        await _api.buyerVerifyOtp(_phone.text.trim(), _otp.text.trim());
      }
      if (mounted) context.go(_home);
    } catch (e) {
      final lang = ref.read(langProvider);
      setState(() => _error = lang == AppLang.hi ? 'ग़लत OTP' : 'Invalid OTP');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _changeNumber() {
    _timer?.cancel();
    setState(() { _otpSent = false; _otp.clear(); _error = null; _resendIn = 0; });
  }

  String _maskedPhone() {
    final p = _phone.text.trim();
    if (p.length != 10) return '+91 $p';
    return '+91 ${p.substring(0, 2)}xxxx${p.substring(8)}';
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final hi = lang == AppLang.hi;
    final text = Theme.of(context).textTheme;
    String t(String k) => T.of(context, lang, k);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- top bar: wordmark left, language pill right ---
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
              child: Row(children: [
                Container(
                  width: 34, height: 34,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(Radii.sm),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Image.asset('assets/icon/logo.png', fit: BoxFit.contain),
                ),
                const SizedBox(width: 10),
                Text(t('app_name'),
                    style: text.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                const Spacer(),
                _LangPill(hi: hi, onTap: () => ref.read(langProvider.notifier).state = hi ? AppLang.en : AppLang.hi),
              ]),
            ),
            const SizedBox(height: 2),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(_otpSent ? (hi ? 'OTP डालें' : 'Enter the OTP') : t('enter_mobile'),
                        style: text.displaySmall),
                    const SizedBox(height: 6),
                    Text(_otpSent ? '${t('otp_sent_to')} ${_maskedPhone()}' : t('otp_subline'),
                        style: text.bodyMedium),
                    const SizedBox(height: 26),

                    // --- role choice (hidden once OTP requested) ---
                    if (!_otpSent) ...[
                      Text(t('i_am'),
                          style: text.labelSmall?.copyWith(letterSpacing: 0.6, color: AppColors.muted)),
                      const SizedBox(height: 8),
                      _RoleCard(
                        selected: _role == Role.artisan,
                        icon: Icons.store_outlined,
                        title: t('artisan'),
                        subtitle: t('role_artisan_pitch'),
                        onTap: () => setState(() => _role = Role.artisan),
                      ),
                      const SizedBox(height: 10),
                      _RoleCard(
                        selected: _role == Role.buyer,
                        icon: Icons.handshake_outlined,
                        title: t('buyer'),
                        subtitle: t('role_buyer_pitch'),
                        onTap: () => setState(() => _role = Role.buyer),
                      ),
                      const SizedBox(height: 22),
                    ],

                    // --- phone / otp field ---
                    if (!_otpSent)
                      TextField(
                        controller: _phone,
                        autofocus: true,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          hintText: '98765 43210',
                          counterText: '',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 8, 0),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Text('+91',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                              const SizedBox(width: 8),
                              Container(width: 1, height: 22, color: AppColors.line),
                            ]),
                          ),
                          prefixIconConstraints: const BoxConstraints(minWidth: 0),
                        ),
                      )
                    else
                      TextField(
                        controller: _otp,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 8),
                        textAlign: TextAlign.center,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(hintText: '••••••', counterText: ''),
                      ),

                    if (_otpSent) ...[
                      const SizedBox(height: 10),
                      Row(children: [
                        TextButton.icon(
                          onPressed: _changeNumber,
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: Text(t('change')),
                          style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                        ),
                        const Spacer(),
                        if (_resendIn > 0)
                          Text('${t('resend_in')} 0:${_resendIn.toString().padLeft(2, '0')}',
                              style: text.labelSmall)
                        else
                          TextButton(
                            onPressed: _sendOtp,
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            child: Text(t('resend_otp')),
                          ),
                      ]),
                    ],

                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Row(children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                        const SizedBox(width: 6),
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.danger))),
                      ]),
                    ],

                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _loading ? null : (_otpSent ? _verify : _sendOtp),
                      child: _loading
                          ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text(t(_otpSent ? 'verify_continue' : 'send_otp')),
                    ),
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => context.push('/privacy'),
                      child: Text(t('terms_agree'),
                          textAlign: TextAlign.center,
                          style: text.labelSmall?.copyWith(color: AppColors.muted, height: 1.4)),
                    ),
                  ],
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }
}

/// Compact language toggle pill in the top bar.
class _LangPill extends StatelessWidget {
  const _LangPill({required this.hi, required this.onTap});
  final bool hi;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(Radii.pill),
            border: Border.all(color: AppColors.line),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.language_rounded, size: 15, color: AppColors.textSoft),
            const SizedBox(width: 5),
            Text(hi ? 'English' : 'हिंदी',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.text)),
          ]),
        ),
      );
}

/// Tappable value-prop card for choosing artisan vs buyer.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.md),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
          borderRadius: BorderRadius.circular(Radii.md),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.line,
            width: selected ? 1.6 : 1.2,
          ),
        ),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: selected ? AppColors.primary.withValues(alpha: 0.12) : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(Radii.sm),
            ),
            child: Icon(icon, color: selected ? AppColors.primary : AppColors.textSoft, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 1),
              Text(subtitle, style: text.bodyMedium),
            ]),
          ),
          Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
            color: selected ? AppColors.primary : AppColors.muted,
            size: 22,
          ),
        ]),
      ),
    );
  }
}
