import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/dashboard_screen.dart';

import '../helpers/test_app.dart';

void main() {
  late FoodEntryProvider provider;

  setUp(() async {
    await setUpTestEnvironment();
    provider = FoodEntryProvider();
    await provider.ensureInitialized();
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(const Dashboard(), foodEntryProvider: provider));
    await pumpFrames(tester);
  }

  testWidgets('nav bar is icons only; labels are for VoiceOver', (tester) async {
    await pumpDashboard(tester);
    for (final label in ['Add', 'Scan', 'Progress', 'Profile']) {
      expect(find.text(label), findsNothing, reason: '$label text should not show');
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Add opens the add-food menu and it closes again', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.bySemanticsLabel('Add'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Add Food'), findsOneWidget);
    await tester.tapAt(const Offset(200, 100));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Add Food'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Progress and Profile open and go back cleanly', (tester) async {
    await pumpDashboard(tester);
    for (final label in ['Progress', 'Profile']) {
      await tester.tap(find.bySemanticsLabel(label));
      await pumpFrames(tester, seconds: 2);
      expect(tester.takeException(), isNull, reason: label);
      final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
      nav.pop();
      await pumpFrames(tester, seconds: 1);
      expect(tester.takeException(), isNull, reason: '$label back');
    }
  });

  testWidgets('moving between days and back to today works', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Yesterday'), findsOneWidget);
    await tester.tap(find.text('Back to today'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
