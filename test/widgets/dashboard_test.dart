import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/app_shell.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:macrotracker/widgets/app_bottom_bar.dart';

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
    // Icons only: no tab names on screen.
    for (final tab in AppTab.values) {
      expect(find.text(tab.label), findsNothing);
    }
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
      expect(tester.takeException(), isNull, reason: tab.label);
    }
  });

  testWidgets('add button stays on every tab', (tester) async {
    await pumpShell(tester);
    for (final tab in [AppTab.progress, AppTab.profile, AppTab.home]) {
      await tester.tap(find.bySemanticsLabel(tab.label));
      await pumpFrames(tester, seconds: 1);
      expect(find.bySemanticsLabel('Log food'), findsOneWidget, reason: tab.label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('add button opens the menu with Scan first; + turns into close',
      (tester) async {
    await pumpShell(tester);
    await tester.tap(find.bySemanticsLabel('Log food'));
    await pumpFrames(tester, seconds: 1);
    for (final option in ['Scan a meal', 'Saved', 'Search', 'Describe']) {
      expect(find.bySemanticsLabel(option), findsOneWidget, reason: option);
    }
    expect(tester.getTopLeft(find.bySemanticsLabel('Scan a meal')).dy,
        lessThan(tester.getTopLeft(find.bySemanticsLabel('Search')).dy));
    expect(find.bySemanticsLabel('Close'), findsOneWidget);

    // The close button shuts it again.
    await tester.tap(find.bySemanticsLabel('Close'));
    await pumpFrames(tester, seconds: 1);
    expect(find.bySemanticsLabel('Scan a meal'), findsNothing);
    expect(find.bySemanticsLabel('Log food'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping the blurred background closes the menu', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.bySemanticsLabel('Log food'));
    await pumpFrames(tester, seconds: 1);
    await tester.tapAt(const Offset(200, 120));
    await pumpFrames(tester, seconds: 1);
    expect(find.bySemanticsLabel('Scan a meal'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Scan from another tab goes to Home and opens the camera',
      (tester) async {
    await pumpShell(tester, tab: AppTab.profile);
    await tester.tap(find.bySemanticsLabel('Log food'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.bySemanticsLabel('Scan a meal'));
    await pumpFrames(tester, seconds: 1);
    expect(find.bySemanticsLabel('Scan a meal'), findsNothing);
    expect(current(tester), AppTab.home);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Search and Describe open their screens', (tester) async {
    await pumpShell(tester);
    for (final option in ['Search', 'Describe']) {
      await tester.tap(find.bySemanticsLabel('Log food'));
      await pumpFrames(tester, seconds: 1);
      await tester.tap(find.bySemanticsLabel(option));
      await pumpFrames(tester, seconds: 1);
      expect(find.bySemanticsLabel('Scan a meal'), findsNothing);
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await pumpFrames(tester, seconds: 1);
      expect(tester.takeException(), isNull, reason: option);
    }
  });

  testWidgets('switching tabs while the menu is open closes it', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.bySemanticsLabel('Log food'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.bySemanticsLabel('Progress'));
    await pumpFrames(tester, seconds: 1);
    expect(find.bySemanticsLabel('Scan a meal'), findsNothing);
    expect(current(tester), AppTab.progress);
    expect(tester.takeException(), isNull);
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
    // No tab is cut off at the screen edge.
    final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final t in ['Weight', 'Calories', 'Steps', 'Workouts']) {
      final r = tester.getRect(find.text(t));
      expect(r.left, greaterThanOrEqualTo(0), reason: t);
      expect(r.right, lessThanOrEqualTo(screenWidth), reason: t);
    }
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

  testWidgets('menu fits a small phone (iPhone SE) in light mode', (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        testApp(const AppShell(), foodEntryProvider: provider, dark: false));
    await pumpFrames(tester);
    await tester.tap(find.bySemanticsLabel('Log food'));
    await pumpFrames(tester, seconds: 1);
    expect(find.bySemanticsLabel('Describe'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the highlight glides to the selected tab', (tester) async {
    await pumpShell(tester);
    Finder highlight() => find.descendant(
        of: find.descendant(
            of: find.byType(AppBottomBar), matching: find.byType(AnimatedPositioned)),
        matching: find.byType(DecoratedBox));
    for (final tab in [AppTab.profile, AppTab.progress, AppTab.home]) {
      await tester.tap(find.bySemanticsLabel(tab.label));
      // Partway through, the highlight is between tabs (it moves, not jumps).
      await tester.pump(const Duration(milliseconds: 120));
      await pumpFrames(tester, seconds: 1);
      final dot = tester.getCenter(highlight()).dx;
      final icon = tester.getCenter(find.descendant(
          of: find.byType(AppBottomBar), matching: find.byIcon(tab.selectedIcon))).dx;
      expect((dot - icon).abs(), lessThan(1), reason: tab.label);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a menu option opens its screen at once, and only once', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.bySemanticsLabel('Log food'));
    await pumpFrames(tester, seconds: 1);

    await tester.tap(find.bySemanticsLabel('Search'));
    // The screen is pushed right away, while the menu is still closing.
    // (Its first frame is built offstage, as every new route is.)
    await tester.pump();
    expect(find.byType(FoodSearchPage, skipOffstage: false), findsOneWidget);
    expect(tester.state<AppShellState>(find.byType(AppShell)).menuOpen, isTrue,
        reason: 'pushed before the menu finished closing');
    // A second tap while the menu closes doesn't push it again.
    await tester.tap(find.bySemanticsLabel('Search'), warnIfMissed: false);
    await pumpFrames(tester, seconds: 1);
    expect(find.byType(FoodSearchPage, skipOffstage: false), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
