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

class KalaSetuApp extends ConsumerWidget {
  const KalaSetuApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final api = ref.read(apiProvider);
    final scale = ref.watch(textScaleProvider);
    return MaterialApp.router(
      title: 'KalaSetu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: buildRouter(api),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
    );
  }
}
