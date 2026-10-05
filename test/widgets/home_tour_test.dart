import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/app_shell.dart';
import 'package:macrotracker/widgets/home_tour.dart';

import '../helpers/test_app.dart';

void main() {
  late FoodEntryProvider provider;

  setUp(() async {
    await setUpTestEnvironment();
    provider = FoodEntryProvider();
    await provider.ensureInitialized();
  });

  group('who sees the tour', () {
    test('a signed-in account sees it until it is marked seen', () async {
      expect(HomeTour.shouldShow('user-a'), isTrue);
      await HomeTour.markSeen('user-a');
      expect(HomeTour.shouldShow('user-a'), isFalse);
      // Per account: another account on the same phone still gets it.
      expect(HomeTour.shouldShow('user-b'), isTrue);
    });

    test('nobody signed in: no tour', () {
      expect(HomeTour.shouldShow(null), isFalse);
    });

    test('every step has a target and some text', () {
      expect(HomeTour.steps, isNotEmpty);
      expect(HomeTour.steps.map((s) => s.target).toSet(), hasLength(HomeTour.steps.length));
      for (final s in HomeTour.steps) {
        expect(s.title, isNotEmpty);
        expect(s.body, isNotEmpty);
      }
    });
  });

  Future<AppShellState> pumpTour(WidgetTester tester,
      {Size size = const Size(1179, 2556), double ratio = 3, bool dark = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = ratio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(const AppShell(), foodEntryProvider: provider, dark: dark));
    await pumpFrames(tester);
    final shell = tester.state<AppShellState>(find.byType(AppShell));
    shell.startTour();
    await pumpFrames(tester, seconds: 1);
    return shell;
  }

  testWidgets('not shown automatically when signed out', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(const AppShell(), foodEntryProvider: provider));
    await pumpFrames(tester, seconds: 2);
    expect(find.byType(HomeTourOverlay), findsNothing);
  });

  testWidgets('walks through every step and finishes with Got it', (tester) async {
    final shell = await pumpTour(tester);
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;

    for (final step in HomeTour.steps) {
      expect(find.text(step.title), findsOneWidget, reason: step.title);
      // The card is fully on screen.
      final card = tester.getRect(find.ancestor(
          of: find.text(step.title), matching: find.byType(ClipRRect)).first);
      expect(card.top, greaterThanOrEqualTo(0), reason: step.title);
      expect(card.bottom, lessThanOrEqualTo(screen.height), reason: step.title);
      expect(tester.takeException(), isNull, reason: step.title);

      final last = step == HomeTour.steps.last;
      expect(find.text('Skip'), last ? findsNothing : findsOneWidget);
      await tester.tap(find.text(last ? 'Got it' : 'Next'));
      await pumpFrames(tester, seconds: 1);
    }
    expect(find.byType(HomeTourOverlay), findsNothing);
    expect(shell.touring, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Skip ends the tour at once', (tester) async {
    final shell = await pumpTour(tester);
    await tester.tap(find.text('Skip'));
    await pumpFrames(tester, seconds: 1);
    expect(find.byType(HomeTourOverlay), findsNothing);
    expect(shell.touring, isFalse);
  });

  testWidgets('tapping the dimmed area moves to the next step', (tester) async {
    await pumpTour(tester);
    expect(find.text(HomeTour.steps[0].title), findsOneWidget);
    await tester.tapAt(const Offset(30, 300));
    await pumpFrames(tester, seconds: 1);
    expect(find.text(HomeTour.steps[1].title), findsOneWidget);
  });

  testWidgets('starting from another tab brings you to Home first', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(const AppShell(initialTab: AppTab.profile),
        foodEntryProvider: provider));
    await pumpFrames(tester);
    final shell = tester.state<AppShellState>(find.byType(AppShell));
    shell.startTour();
    await pumpFrames(tester, seconds: 1);
    expect(shell.currentTab, AppTab.home);
    expect(find.text(HomeTour.steps.first.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile has a row to replay the tour', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(const AppShell(initialTab: AppTab.profile),
        foodEntryProvider: provider));
    await pumpFrames(tester);
    await tester.scrollUntilVisible(find.text('Show app tour'), 300,
        scrollable: find.byType(Scrollable).first);
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Show app tour'));
    await pumpFrames(tester, seconds: 1);
    expect(find.byType(HomeTourOverlay), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fits a small phone in light mode', (tester) async {
    await pumpTour(tester, size: const Size(750, 1334), ratio: 2, dark: false);
    for (var i = 0; i < HomeTour.steps.length; i++) {
      expect(tester.takeException(), isNull, reason: HomeTour.steps[i].title);
      await tester.tap(find.text(i == HomeTour.steps.length - 1 ? 'Got it' : 'Next'));
      await pumpFrames(tester, seconds: 1);
    }
    expect(find.byType(HomeTourOverlay), findsNothing);
  });
}
