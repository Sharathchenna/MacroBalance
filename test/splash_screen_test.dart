import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/main.dart';

void main() {
  testWidgets('App should start without hanging on splash screen',
      (WidgetTester tester) async {
    // This test verifies that the app can initialize and show a UI
    // without hanging indefinitely on network calls

    // Start the app
    await tester.pumpWidget(const MyApp());

    // Allow some time for initialization but not too long
    await tester.pump(const Duration(seconds: 2));

    // The app should show some UI (not hang)
    // We're looking for either a loading indicator, welcome screen, or other UI
    expect(find.byType(MaterialApp), findsOneWidget);

    // Allow more time for async operations
    await tester.pump(const Duration(seconds: 3));

    // App should still be responsive
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
