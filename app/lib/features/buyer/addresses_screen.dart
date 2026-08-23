import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';
import '../../data/models.dart';

/// Buyer delivery addresses. When [selectMode] is true, tapping an address
/// returns it to the caller (used at checkout).
class AddressesScreen extends ConsumerStatefulWidget {
  const AddressesScreen({super.key, this.selectMode = false});
  final bool selectMode;

  @override
  ConsumerState<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends ConsumerState<AddressesScreen> {
  List<Address> _addrs = [];
  bool _loading = true;

  Api get _api => ref.read(apiProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _addrs = await _api.listAddresses();
    } catch (_) {
      _addrs = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _addFlow() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddressForm(api: _api),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    String t(String k) => T.of(context, lang, k);

    return Scaffold(
      appBar: AppBar(title: Text(widget.selectMode ? t('select_address') : t('addresses'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addFlow,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: Text(t('add_address')),
      ),
      body: _loading
          ? const Center(child: KLoading())
          : _addrs.isEmpty
              ? KEmpty(icon: Icons.location_off_outlined, title: t('no_address'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: _addrs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, i) {
                    final a = _addrs[i];
                    return KCard(
                      onTap: widget.selectMode ? () => context.pop(a) : null,
                      child: Row(children: [
                        const Icon(Icons.location_on_outlined, color: AppColors.primary),
                        Gap.m,
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Text(a.name, style: Theme.of(context).textTheme.titleMedium),
                              if (a.isDefault) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(Radii.pill)),
                                  child: Text(t('set_default').split(' ').first,
                                      style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                                ),
                              ],
                            ]),
                            const SizedBox(height: 2),
                            Text(a.oneLine, style: Theme.of(context).textTheme.bodyMedium),
                            Text(a.phone, style: Theme.of(context).textTheme.bodySmall),
                          ]),
                        ),
                        if (!widget.selectMode)
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                            onPressed: () async {
                              await _api.deleteAddress(a.id);
                              await _load();
                            },
                          )
                        else
                          const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
                      ]),
                    );
                  },
                ),
    );
  }
}

class _AddressForm extends ConsumerStatefulWidget {
  const _AddressForm({required this.api});
  final Api api;
  @override
  ConsumerState<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends ConsumerState<_AddressForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _line1 = TextEditingController();
  final _line2 = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pin = TextEditingController();
  bool _default = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _line1, _line2, _city, _state, _pin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.api.addAddress({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'line1': _line1.text.trim(),
        'line2': _line2.text.trim().isEmpty ? null : _line2.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim(),
        'pincode': _pin.text.trim(),
        'is_default': _default,
      });
      if (mounted) context.pop(true);
    } catch (_) {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    String t(String k) => T.of(context, lang, k);
    String? req(String? v) => (v == null || v.trim().isEmpty) ? t('required_field') : null;

    Widget field(TextEditingController c, String label,
            {String? Function(String?)? v, TextInputType? kb}) =>
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: c,
            validator: v,
            keyboardType: kb,
            decoration: InputDecoration(labelText: label),
          ),
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t('add_address'), style: Theme.of(context).textTheme.titleLarge),
            Gap.m,
            field(_name, t('full_name'), v: req),
            field(_phone, t('phone'), v: req, kb: TextInputType.phone),
            field(_line1, t('address_line1'), v: req),
            field(_line2, t('address_line2')),
            Row(children: [
              Expanded(child: field(_city, t('city'), v: req)),
              const SizedBox(width: 12),
              Expanded(child: field(_state, t('state'), v: req)),
            ]),
            field(_pin, t('pincode'), v: req, kb: TextInputType.number),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _default,
              activeThumbColor: AppColors.primary,
              title: Text(t('set_default')),
              onChanged: (x) => setState(() => _default = x),
            ),
            Gap.s,
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined),
              label: Text(t('save')),
            ),
          ]),
        ),
      ),
    );
  }
}
