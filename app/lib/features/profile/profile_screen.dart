import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _craft = TextEditingController();
  final _region = TextEditingController();
  String _phone = '';
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final u = await ref.read(apiProvider).getMe();
      _name.text = u.name ?? '';
      _craft.text = u.craftType ?? '';
      _region.text = u.region ?? '';
      setState(() { _phone = u.phone; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final lang = ref.read(langProvider);
    try {
      await ref.read(apiProvider).updateMe({
        'name': _name.text.trim(),
        'craft_type': _craft.text.trim(),
        'region': _region.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(T.of(context, lang, 'saved'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(T.of(context, lang, 'try_again'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    String t(String k) => T.of(context, lang, k);
    return Scaffold(
      appBar: AppBar(title: Text(t('shop_profile'))),
      body: _loading
          ? const KLoading()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Center(
                  child: Column(children: [
                    Container(
                      width: 92, height: 92, padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: Decor.heroGradient, borderRadius: BorderRadius.circular(Radii.xl),
                        boxShadow: Decor.soft),
                      child: Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(Radii.lg)),
                        child: const Icon(Icons.person_rounded, size: 44, color: AppColors.primary),
                      ),
                    ),
                    Gap.s,
                    Text(_phone, style: Theme.of(context).textTheme.bodyMedium),
                  ]),
                ),
                Gap.l,
                _field(t('your_name'), _name, Icons.badge_outlined),
                _field(t('craft_type'), _craft, Icons.brush_outlined),
                _field(t('region'), _region, Icons.place_outlined),
                Gap.m,
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check_rounded),
                  label: Text(t('save')),
                ),
              ],
            ),
    );
  }

  Widget _field(String label, TextEditingController c, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          controller: c,
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
        ),
      );
}
