import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/observability.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'data/api.dart';

Future<void> main() async {
  Observability.install();
  Observability.runGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
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
    return MaterialApp.router(
      title: 'KalaSetu',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: buildRouter(api),
    );
  }
}
