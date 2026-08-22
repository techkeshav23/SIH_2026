import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/api.dart';
import 'l10n.dart';
import 'theme.dart';
import 'widgets.dart';

/// Primary artisan destinations: (route, icon, EN, HI).
const List<(String, IconData, String, String)> artisanTabs = [
  ('/home', Icons.inventory_2_rounded, 'Products', 'उत्पाद'),
  ('/orders', Icons.receipt_long_rounded, 'Orders', 'ऑर्डर'),
  ('/dashboard', Icons.dashboard_rounded, 'Dashboard', 'डैशबोर्ड'),
  ('/market', Icons.storefront_rounded, 'Market', 'बाज़ार'),
];

/// Scaffold with a shared sidebar (drawer) + bottom navigation bar for the
/// artisan app. [current] is the active tab index; [fab] is optional.
class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.current, required this.body, this.fab});
  final int current;
  final Widget body;
  final Widget? fab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hi = ref.watch(langProvider) == AppLang.hi;
    return Scaffold(
      drawer: const AppDrawer(),
      floatingActionButton: fab,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: current,
        onDestinationSelected: (i) {
          if (i != current) context.go(artisanTabs[i].$1);
        },
        destinations: [
          for (final t in artisanTabs)
            NavigationDestination(icon: Icon(t.$2), label: hi ? t.$4 : t.$3),
        ],
      ),
    );
  }
}

/// White hamburger button that opens the drawer — pass as KHeader `leading`.
Widget drawerButton() => Builder(
      builder: (c) => InkWell(
        onTap: () => Scaffold.of(c).openDrawer(),
        borderRadius: BorderRadius.circular(10),
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.menu_rounded, color: Colors.white, size: 26),
        ),
      ),
    );

/// The sidebar. Brand header + primary destinations + language + logout.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hi = ref.watch(langProvider) == AppLang.hi;
    final api = ref.read(apiProvider);
    final loc = GoRouterState.of(context).uri.path;

    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // brand header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 22),
              decoration: const BoxDecoration(gradient: Decor.heroGradient),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56, height: 56, padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: Image.asset('assets/icon/logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 14),
                  const Text('KalaSetu',
                      style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  const SizedBox(height: 2),
                  Text(api.demoMode ? (hi ? 'डेमो · कारीगर' : 'Demo · Artisan') : (hi ? 'कारीगर खाता' : 'Artisan account'),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // destinations
            for (final t in artisanTabs)
              _DrawerItem(
                icon: t.$2,
                label: hi ? t.$4 : t.$3,
                active: loc == t.$1,
                onTap: () { Navigator.pop(context); if (loc != t.$1) context.go(t.$1); },
              ),
            const Divider(height: 24, indent: 16, endIndent: 16),
            _DrawerItem(
              icon: Icons.person_rounded,
              label: hi ? 'दुकान प्रोफ़ाइल' : 'Shop Profile',
              onTap: () { Navigator.pop(context); context.push('/profile'); },
            ),
            _DrawerItem(
              icon: Icons.settings_rounded,
              label: hi ? 'सेटिंग्स' : 'Settings',
              onTap: () { Navigator.pop(context); context.push('/settings'); },
            ),
            _DrawerItem(
              icon: Icons.translate_rounded,
              label: hi ? 'भाषा: हिंदी' : 'Language: English',
              onTap: () => ref.read(langProvider.notifier).state = hi ? AppLang.en : AppLang.hi,
            ),
            const Spacer(),
            _DrawerItem(
              icon: Icons.logout_rounded,
              label: hi ? 'लॉग आउट' : 'Logout',
              danger: true,
              onTap: () async {
                Navigator.pop(context);
                final ok = await confirmDialog(context,
                    title: hi ? 'लॉग आउट करें?' : 'Logout?',
                    message: hi ? 'KalaSetu से साइन आउट करें?' : 'Sign out of KalaSetu?',
                    confirm: hi ? 'लॉग आउट' : 'Logout', danger: true);
                if (!ok || !context.mounted) return;
                await api.logout();
                if (context.mounted) context.go('/login');
              },
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('SIH 2026 · PS 26090',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  const _DrawerItem({required this.icon, required this.label, required this.onTap, this.active = false, this.danger = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : (active ? AppColors.primary : AppColors.textSoft);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: active ? AppColors.primary.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 16),
                Text(label,
                    style: TextStyle(color: danger ? AppColors.danger : AppColors.text,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w600, fontSize: 15.5)),
                if (active) ...[
                  const Spacer(),
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
