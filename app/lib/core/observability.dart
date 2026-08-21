import 'dart:async';

import 'package:flutter/foundation.dart';

/// Global error handling. Currently logs; wire Sentry here for production.
///
/// To enable Sentry: add `sentry_flutter` to pubspec, then in [reportError]
/// call `Sentry.captureException(error, stackTrace: stack)` and wrap the
/// forwarded init. Kept dependency-free for now so the app builds anywhere.
class Observability {
  static void install() {
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      reportError(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      reportError(error, stack);
      return true;
    };
  }

  static void reportError(Object error, StackTrace? stack) {
    // TODO(prod): forward to Sentry when SENTRY_DSN is configured.
    debugPrint('[error] $error');
    if (stack != null) debugPrint(stack.toString());
  }

  /// Run [body] inside a guarded zone so async errors are captured too.
  static void runGuarded(void Function() body) {
    runZonedGuarded(body, reportError);
  }
}
