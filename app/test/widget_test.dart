import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kalasetu/core/theme.dart';

void main() {
  testWidgets('App theme builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Center(child: Text('KalaSetu'))),
      ),
    );
    expect(find.text('KalaSetu'), findsOneWidget);
  });
}
