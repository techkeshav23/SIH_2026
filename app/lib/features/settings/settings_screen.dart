import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n.dart';
import '../../core/theme.dart';
import '../../core/tts.dart';
import '../../core/widgets.dart';
import '../../data/api.dart';

class _LangTile extends StatelessWidget {
  const _LangTile({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: selected
            ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
            : const Icon(Icons.circle_outlined, color: AppColors.line),
      );
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(langProvider);
    final scale = ref.watch(textScaleProvider);
    String t(String k) => T.of(context, lang, k);

    return Scaffold(
      appBar: AppBar(title: Text(t('settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          KSectionTitle(t('language')),
          Gap.s,
          KCard(
            padding: EdgeInsets.zero,
            child: Column(children: [
              _LangTile(label: 'हिंदी', selected: lang == AppLang.hi,
                  onTap: () => ref.read(langProvider.notifier).state = AppLang.hi),
              const Divider(height: 1),
              _LangTile(label: 'English', selected: lang == AppLang.en,
                  onTap: () => ref.read(langProvider.notifier).state = AppLang.en),
            ]),
          ),
          Gap.l,
          KSectionTitle(t('text_size')),
          Gap.s,
          KCard(
            child: Row(children: [
              const Text('A', style: TextStyle(fontSize: 15, color: AppColors.muted)),
              Expanded(
                child: Slider(
                  value: scale, min: 0.9, max: 1.5, divisions: 6,
                  activeColor: AppColors.primary,
                  label: '${(scale * 100).round()}%',
                  onChanged: (v) => ref.read(textScaleProvider.notifier).state = v,
                ),
              ),
              const Text('A', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            ]),
          ),
          Gap.l,
          KSectionTitle(t('read_aloud_setting')),
          Gap.s,
          KCard(
            child: Row(children: [
              const Icon(Icons.volume_up_rounded, color: AppColors.primary),
              Gap.m,
              Expanded(
                child: Text(
                  lang == AppLang.hi
                      ? 'किसी भी स्क्रीन पर स्पीकर बटन दबाकर सुनें।'
                      : 'Tap the speaker button on any screen to listen.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              KSpeak(lang == AppLang.hi
                  ? 'नमस्ते! कलासेतु में आपका स्वागत है। किसी भी स्क्रीन को सुनने के लिए स्पीकर बटन दबाएं।'
                  : 'Hello! Welcome to KalaSetu. Tap the speaker button to hear any screen.'),
            ]),
          ),
          Gap.l,
          KSectionTitle(t('about')),
          Gap.s,
          KCard(
            onTap: () {},
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: AppColors.indigo),
              Gap.m,
              Expanded(child: Text(t('about_line'), style: Theme.of(context).textTheme.bodyMedium)),
            ]),
          ),
          Gap.m,
          KCard(
            onTap: () {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(t('help')),
                  content: Text(lang == AppLang.hi
                      ? 'मदद के लिए कॉल करें: 1800-000-0000 (टोल-फ्री)'
                      : 'Call for help: 1800-000-0000 (toll-free)'),
                  actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(t('cancel')))],
                ),
              );
            },
            child: Row(children: [
              const Icon(Icons.support_agent_rounded, color: AppColors.success),
              Gap.m,
              Expanded(child: Text(t('help'), style: Theme.of(context).textTheme.titleMedium)),
              const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ]),
          ),
          Gap.l,
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              final ok = await confirmDialog(context,
                  title: t('logout_q'), message: t('logout_msg'), confirm: t('logout'), danger: true);
              if (!ok || !context.mounted) return;
              await ref.read(apiProvider).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(t('logout')),
          ),
        ],
      ),
    );
  }
}
