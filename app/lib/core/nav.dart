import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/api.dart';
import '../data/cart.dart';
import 'l10n.dart';
import 'theme.dart';
import 'widgets.dart';

/// Primary artisan destinations: (route, icon, EN, HI). A rich home landing,
/// their products, incoming orders, and bulk-quote negotiations. Dashboard and
/// the marketplace preview live in the drawer.
const List<(String, IconData, String, String)> artisanTabs = [
  ('/home', Icons.home_rounded, 'Home', 'होम'),
  ('/products', Icons.inventory_2_rounded, 'Products', 'उत्पाद'),
  ('/orders', Icons.receipt_long_rounded, 'Orders', 'ऑर्डर'),
  ('/marketing', Icons.campaign_rounded, 'Marketing', 'मार्केटिंग'),
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

/// Hamburger button that opens the drawer — pass as KHeader `leading`.
Widget drawerButton() => Builder(
      builder: (c) => IconButton(
        onPressed: () => Scaffold.of(c).openDrawer(),
        icon: const Icon(Icons.menu_rounded, color: AppColors.text, size: 26),
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
            // brand header (flat, real-app style)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(bottom: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44, height: 44, padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(Radii.sm),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Image.asset('assets/icon/logo.png', fit: BoxFit.contain),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('KalaSetu',
                          style: TextStyle(color: AppColors.text, fontSize: 19, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 1),
                      Text(api.demoMode ? (hi ? 'डेमो · कारीगर' : 'Demo · Artisan') : (hi ? 'कारीगर खाता' : 'Artisan account'),
                          style: const TextStyle(color: AppColors.textSoft, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ],
                  ),
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
              icon: Icons.auto_awesome_rounded,
              label: hi ? 'कला — आवाज़ सहायक' : 'Kala — voice assistant',
              onTap: () { Navigator.pop(context); context.push('/kala'); },
            ),
            _DrawerItem(
              icon: Icons.gavel_rounded,
              label: hi ? 'थोक सौदे (Quotes)' : 'Bulk quotes',
              onTap: () { Navigator.pop(context); context.push('/quotes'); },
            ),
            _DrawerItem(
              icon: Icons.dashboard_rounded,
              label: hi ? 'डैशबोर्ड' : 'Dashboard',
              onTap: () { Navigator.pop(context); context.push('/dashboard'); },
            ),
            _DrawerItem(
              icon: Icons.campaign_rounded,
              label: hi ? 'विज्ञापन अभियान' : 'Ad Campaigns',
              onTap: () { Navigator.pop(context); context.push('/campaigns'); },
            ),
            _DrawerItem(
              icon: Icons.storefront_outlined,
              label: hi ? 'बाज़ार झलक' : 'Market preview',
              onTap: () { Navigator.pop(context); context.push('/market'); },
            ),
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
                // Capture the router BEFORE the drawer closes — popping first
                // deactivates this drawer's context, so a later context.mounted
                // check would be false and silently skip the logout.
                final router = GoRouter.of(context);
                final ok = await confirmDialog(context,
                    title: hi ? 'लॉग आउट करें?' : 'Logout?',
                    message: hi ? 'KalaSetu से साइन आउट करें?' : 'Sign out of KalaSetu?',
                    confirm: hi ? 'लॉग आउट' : 'Logout', danger: true);
                if (!ok) return;
                await api.logout();
                ref.invalidate(cartProvider); // don't leak the cart into the next account
                router.go('/login'); // replaces the whole stack (closes the drawer too)
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('KalaSetu v1.0', style: Theme.of(context).textTheme.labelSmall),
                  GestureDetector(
                    onTap: () { Navigator.pop(context); context.push('/privacy'); },
                    child: Text(hi ? 'गोपनीयता नीति' : 'Privacy Policy',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary)),
                  ),
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
