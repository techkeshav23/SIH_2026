import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n.dart';
import 'core/observability.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/api.dart';

Future<void> main() async {
  Observability.install();
  Observability.runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Transparent status bar with DARK icons so wifi/battery/time are visible
    // on the app's light cream background (they were white -> invisible).
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Android
      statusBarBrightness: Brightness.light, // iOS
      systemNavigationBarColor: AppColors.surface,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    final container = ProviderContainer();
    await container.read(apiProvider).loadToken();
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const KalaSetuApp(),
      ),
    );
  });
}

class KalaSetuApp extends ConsumerStatefulWidget {
  const KalaSetuApp({super.key});

  @override
  ConsumerState<KalaSetuApp> createState() => _KalaSetuAppState();
}

class _KalaSetuAppState extends ConsumerState<KalaSetuApp> {
  // Built once. Rebuilding the router on every widget rebuild (e.g. when the
  // text-size slider changes) threw away the whole navigation stack.
  late final _router = buildRouter(ref.read(apiProvider));

  @override
  Widget build(BuildContext context) {
    final scale = ref.watch(textScaleProvider);
    return MaterialApp.router(
      title: 'KalaSetu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: _router,
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        // Base status-bar style for every route: DARK icons for the light cream
        // UI. Without this, a screen that set light icons (e.g. Home's dark hero)
        // leaves them white when you navigate away, making wifi/battery/time
        // invisible on the cream background. Screens with a dark backdrop assert
        // their own AnnotatedRegion, which sits above this and wins while shown.
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    );
  }
}
