import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/app_shell.dart';

import '../helpers/test_app.dart';

void main() {
  late FoodEntryProvider provider;

  setUp(() async {
    await setUpTestEnvironment();
    provider = FoodEntryProvider();
    await provider.ensureInitialized();
  });

  Future<void> pumpShell(WidgetTester tester, {AppTab tab = AppTab.home}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        testApp(AppShell(initialTab: tab), foodEntryProvider: provider));
    await pumpFrames(tester);
  }

  AppTab current(WidgetTester tester) =>
      tester.state<AppShellState>(find.byType(AppShell)).currentTab;

  testWidgets('bottom bar has Home, Progress and Profile; Home starts selected',
      (tester) async {
    await pumpShell(tester);
    for (final tab in AppTab.values) {
      expect(find.bySemanticsLabel(tab.label), findsOneWidget);
    }
    expect(current(tester), AppTab.home);
    // Only the selected tab shows its name.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Profile'), findsNothing);
    // The old camera and plus icons are gone from the bar; logging is the
    // single add button.
    expect(find.bySemanticsLabel('Log food'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('switching tabs keeps the bar and marks the current tab',
      (tester) async {
    await pumpShell(tester);
    for (final tab in [AppTab.progress, AppTab.profile, AppTab.home, AppTab.progress]) {
      await tester.tap(find.bySemanticsLabel(tab.label));
      await pumpFrames(tester, seconds: 1);
      expect(current(tester), tab);
      expect(find.text(tab.label), findsWidgets, reason: 'selected tab shows its name');
      expect(tester.takeException(), isNull, reason: tab.label);
    }
  });

  testWidgets('add button only shows on Home', (tester) async {
    await pumpShell(tester);
    expect(find.bySemanticsLabel('Log food'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Progress'));
    await pumpFrames(tester, seconds: 1);
    expect(find.bySemanticsLabel('Log food'), findsNothing);
    await tester.tap(find.bySemanticsLabel('Profile'));
    await pumpFrames(tester, seconds: 1);
    expect(find.bySemanticsLabel('Log food'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('add button opens Log food with Scan first, and it closes',
      (tester) async {
    await pumpShell(tester);
    await tester.tap(find.bySemanticsLabel('Log food'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Scan a meal'), findsOneWidget);
    for (final option in ['Search', 'Saved', 'Describe']) {
      expect(find.text(option), findsOneWidget);
    }
    // Scan sits above the other options.
    expect(tester.getTopLeft(find.text('Scan a meal')).dy,
        lessThan(tester.getTopLeft(find.text('Search')).dy));
    await tester.tapAt(const Offset(200, 100));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Scan a meal'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Scan in the sheet opens the camera', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.bySemanticsLabel('Log food'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Scan a meal'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Scan a meal'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search and Describe open their screens', (tester) async {
    await pumpShell(tester);
    for (final option in ['Search', 'Describe']) {
      await tester.tap(find.bySemanticsLabel('Log food'));
      await pumpFrames(tester, seconds: 1);
      await tester.tap(find.text(option));
      await pumpFrames(tester, seconds: 1);
      expect(find.text('Scan a meal'), findsNothing);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await pumpFrames(tester, seconds: 1);
      expect(tester.takeException(), isNull, reason: option);
    }
  });

  testWidgets('Progress has its tabs at the top and no back button',
      (tester) async {
    await pumpShell(tester, tab: AppTab.progress);
    for (final t in ['Weight', 'Calories', 'Steps', 'Workouts']) {
      expect(find.widgetWithText(Tab, t), findsOneWidget);
    }
    expect(find.byType(BackButton), findsNothing);
    final tabBarTop = tester.getTopLeft(find.byType(TabBar)).dy;
    expect(tabBarTop, lessThan(300), reason: 'tabs sit at the top');
    for (final t in ['Calories', 'Steps', 'Workouts', 'Weight']) {
      await tester.tap(find.widgetWithText(Tab, t));
      await pumpFrames(tester, seconds: 1);
      expect(tester.takeException(), isNull, reason: t);
    }
  });

  testWidgets('Profile tab has no back button and is titled Profile',
      (tester) async {
    await pumpShell(tester, tab: AppTab.profile);
    expect(find.text('Settings'), findsNothing);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tab keeps its state when you come back to it', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Yesterday'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Profile'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.bySemanticsLabel('Home'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('moving between days and back to today works', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.byIcon(Icons.chevron_left).first);
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Back to today'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
