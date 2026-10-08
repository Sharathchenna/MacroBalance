import 'dart:convert';
import 'dart:ui' show SemanticsFlag;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/screens/accountdashboard.dart';
import 'package:macrotracker/screens/energy/goals_card.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/screens/onboarding/pages/adaptive_page.dart';
import 'package:macrotracker/screens/onboarding/pages/advanced_settings_page.dart';
import 'package:macrotracker/screens/onboarding/pages/summary_page.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/widgets/adaptive_choice.dart';

import '../helpers/test_app.dart';

void main() {
  late GoalsProvider goals;
  final events = <MethodCall>[];

  setUp(() async {
    await setUpTestEnvironment();
    for (final key in ['nutrition_goals', 'goal_settings', 'unit_system']) {
      await StorageService().delete(key);
    }
    await StorageService().put('unit_system', 'metric');
    goals = GoalsProvider();
    events.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('posthog_flutter'),
            (call) async {
      if (call.method == 'capture') events.add(call);
      return null;
    });
  });

  List<Map> captured(String name) => [
        for (final c in events)
          if ((c.arguments as Map)['eventName'] == name) c.arguments as Map,
      ];

  Map<String, Object?> choiceEvent(Map event) {
    final props = Map<String, Object?>.from(event['properties'] as Map);
    return {'choice': props['choice'], 'context': props['context']};
  }

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pump(WidgetTester tester, Widget child, {bool dark = true}) async {
    phone(tester);
    await tester.pumpWidget(testApp(child, goalsProvider: goals, dark: dark));
    await pumpFrames(tester, seconds: 1);
  }

  Finder visible(Type page) => find.byType(page).hitTestable();

  bool selected(WidgetTester tester, Key key) => tester
      .getSemantics(find.byKey(key))
      .getSemanticsData()
      .hasFlag(SemanticsFlag.isSelected);

  group('onboarding step', () {
    for (final dark in [true, false]) {
      testWidgets('Yes is picked and recommended by default (${dark ? 'dark' : 'light'})',
          (tester) async {
        var adaptive = true;
        await pump(
          tester,
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: AdaptivePage(
                adaptive: adaptive,
                onChanged: (v) => setState(() => adaptive = v),
              ),
            ),
          ),
          dark: dark,
        );
        expect(find.text(AdaptiveChoiceCopy.question), findsOneWidget);
        expect(find.text(AdaptiveChoiceCopy.yesTitle), findsOneWidget);
        expect(find.text(AdaptiveChoiceCopy.noTitle), findsOneWidget);
        expect(find.text('Recommended'), findsOneWidget);
        expect(selected(tester, const Key('adaptive_yes')), isTrue);
        expect(selected(tester, const Key('adaptive_no')), isFalse);

        await tester.tap(find.text(AdaptiveChoiceCopy.noTitle));
        await tester.pump();
        expect(adaptive, isFalse);
        expect(selected(tester, const Key('adaptive_no')), isTrue);
      });
    }

    Future<void> next(WidgetTester tester) async {
      await tester.tap(find.text('Next'));
      await pumpFrames(tester, seconds: 1);
    }

    testWidgets(
        'new users answer it after the goal and before advanced settings; '
        'the choice is saved, shown and tracked', (tester) async {
      await pump(tester, const OnboardingScreen());
      // welcome, sex, weight, height, age, activity, goal (maintain skips the
      // goal-weight step) -> adaptive
      for (var i = 0; i < 7; i++) {
        await next(tester);
      }
      expect(visible(AdaptivePage), findsOneWidget);

      await tester.tap(find.text(AdaptiveChoiceCopy.noTitle));
      await tester.pump();
      await next(tester);
      expect(visible(AdvancedSettingsPage), findsOneWidget);

      // advanced -> Apple Health (its own buttons) -> summary
      await next(tester);
      await tester.tap(find.text('Not now').hitTestable());
      await pumpFrames(tester, seconds: 1);
      expect(visible(SummaryPage), findsOneWidget);
      expect(find.text('Fixed'), findsOneWidget);

      await tester.tap(find.text('Calculate'));
      await pumpFrames(tester, seconds: 2);
      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(find.textContaining('Fixed target', findRichText: true), findsOneWidget);

      final saved =
          jsonDecode(StorageService().get('nutrition_goals') as String) as Map;
      expect(saved['adaptive_goals'], isFalse);
      expect(saved['checkin_weekday'], DateTime.now().weekday);
      expect(saved.containsKey('protein_g_per_kg'), isFalse); // device name
      expect(saved.containsKey('protein_ratio'), isTrue);
      await goals.load();
      expect(goals.adaptiveGoals, isFalse);
      expect(goals.checkinWeekday, DateTime.now().weekday);

      expect(captured('adaptive_choice_made').map(choiceEvent),
          [{'choice': 'fixed', 'context': 'onboarding'}]);
    });

    testWidgets('recalculating keeps the saved choice and check-in day', (tester) async {
      goals
        ..currentWeightKg = 80
        ..goalType = MacroCalculatorService.GOAL_MAINTAIN
        ..adaptiveGoals = false
        ..checkinWeekday = DateTime.friday;
      goals.startLearning(DateTime(2026, 9, 7));
      await pump(tester, const OnboardingScreen(recalculateOnly: true));
      // weight, activity, goal (maintain), advanced -> summary
      for (var i = 0; i < 4; i++) {
        await next(tester);
      }
      expect(visible(SummaryPage), findsOneWidget);
      expect(find.text('Fixed'), findsOneWidget);
      await tester.tap(find.text('Calculate'));
      await pumpFrames(tester, seconds: 2);
      expect(find.textContaining('Fixed target', findRichText: true), findsOneWidget);

      await tester.tap(find.text('Save New Goals'));
      await pumpFrames(tester, seconds: 2);
      final saved =
          jsonDecode(StorageService().get('nutrition_goals') as String) as Map;
      expect(saved['adaptive_goals'], isFalse);
      expect(saved['checkin_weekday'], DateTime.friday);
      expect(saved['learning_started_on'], '2026-09-07');
      // Not asked, so no choice was made.
      expect(captured('adaptive_choice_made'), isEmpty);
    });
  });

  group('results line', () {
    for (final adaptive in [true, false]) {
      testWidgets(adaptive ? 'adaptive: updates weekly' : 'fixed target', (tester) async {
        await pump(
          tester,
          ResultsScreen(
            results: MacroCalculatorService().calculateAll(
              gender: MacroCalculatorService.MALE,
              weightKg: 80,
              heightCm: 180,
              age: 30,
              activityLevel: 3,
              goal: MacroCalculatorService.GOAL_MAINTAIN,
            ),
            adaptiveGoals: adaptive,
          ),
        );
        expect(
            find.textContaining(adaptive
                ? 'Updates weekly as we learn your metabolism'
                : 'Fixed target', findRichText: true),
            findsOneWidget);
      });
    }
  });

  group('Energy goals card', () {
    Future<void> pumpCard(WidgetTester tester, {bool dark = true}) => pump(
        tester,
        const Scaffold(
            body: SingleChildScrollView(
                padding: EdgeInsets.all(16), child: GoalsCard())),
        dark: dark);

    setUp(() {
      goals.updateGoals(
          calories: 2150, protein: 140, carbs: 230, fat: 70, steps: 10000,
          bmr: 1700, tdee: 2400);
    });

    for (final dark in [true, false]) {
      testWidgets('adaptive on: the target and next check-in (${dark ? 'dark' : 'light'})',
          (tester) async {
        goals.startLearning(DateTime(2026, 1, 5)); // long ago, a Monday
        await pumpCard(tester, dark: dark);
        expect(find.text('2,150'), findsOneWidget);
        expect(find.text('Protein 140 g · Carbs 230 g · Fat 70 g'), findsOneWidget);
        expect(find.textContaining('Next check-in: '), findsOneWidget);
        expect(find.textContaining(checkinDayText(goals.nextCheckinDay, DateTime.now())),
            findsOneWidget);
        expect(find.textContaining('fixed at'), findsNothing);
      });

      testWidgets('adaptive off: the fixed target (${dark ? 'dark' : 'light'})',
          (tester) async {
        goals.adaptiveGoals = false;
        await pumpCard(tester, dark: dark);
        expect(
            find.text('Your targets are fixed at 2,150 cals. Turn on weekly '
                'updates to have them follow your real expenditure.'),
            findsOneWidget);
        expect(find.textContaining('Next check-in'), findsNothing);
      });
    }

    testWidgets('turning it on confirms with the onboarding copy', (tester) async {
      goals.adaptiveGoals = false;
      await pumpCard(tester);
      await tester.tap(find.text('Weekly updates'));
      await pumpFrames(tester, seconds: 1);
      expect(find.text(AdaptiveChoiceCopy.question), findsOneWidget);
      expect(find.text(AdaptiveChoiceCopy.yesBody), findsOneWidget);
      expect(selected(tester, const Key('adaptive_yes')), isTrue);
      expect(goals.adaptiveGoals, isFalse); // nothing changes before confirming

      await tester.tap(find.text('Turn on weekly updates'));
      await pumpFrames(tester, seconds: 1);
      expect(goals.adaptiveGoals, isTrue);
      expect(find.textContaining('Next check-in: '), findsOneWidget);
      expect(captured('adaptive_choice_made').map(choiceEvent),
          [{'choice': 'adaptive', 'context': 'settings'}]);
    });

    testWidgets('turning it off confirms too', (tester) async {
      await pumpCard(tester);
      await tester.tap(find.byKey(const Key('energy_adaptive_toggle')));
      await pumpFrames(tester, seconds: 1);
      expect(selected(tester, const Key('adaptive_no')), isTrue);
      await tester.tap(find.text('Keep my targets fixed'));
      await pumpFrames(tester, seconds: 1);
      expect(goals.adaptiveGoals, isFalse);
      expect(GoalsProvider().adaptiveGoals, isFalse); // saved
      expect(captured('adaptive_choice_made').map(choiceEvent),
          [{'choice': 'fixed', 'context': 'settings'}]);
    });

    testWidgets('dismissing the sheet, or confirming the current choice, changes nothing',
        (tester) async {
      goals.adaptiveGoals = false;
      await pumpCard(tester);
      await tester.tap(find.text('Weekly updates'));
      await pumpFrames(tester, seconds: 1);
      await tester.tapAt(const Offset(200, 40)); // the scrim
      await pumpFrames(tester, seconds: 1);
      expect(find.text(AdaptiveChoiceCopy.question), findsNothing);
      expect(goals.adaptiveGoals, isFalse);

      await tester.tap(find.text('Weekly updates'));
      await pumpFrames(tester, seconds: 1);
      await tester.tap(find.text(AdaptiveChoiceCopy.noTitle));
      await tester.pump();
      await tester.tap(find.text('Keep my targets fixed'));
      await pumpFrames(tester, seconds: 1);
      expect(goals.adaptiveGoals, isFalse);
      expect(captured('adaptive_choice_made'), isEmpty);
    });
  });

  test('check-in days read as Today, Tomorrow or the weekday and date', () {
    final now = DateTime(2026, 10, 7, 21);
    expect(checkinDayText(DateTime(2026, 10, 7), now), 'Today');
    expect(checkinDayText(DateTime(2026, 10, 8), now), 'Tomorrow');
    expect(checkinDayText(DateTime(2026, 10, 12), now), 'Monday, Oct 12');
    expect(weekdayName(DateTime.monday), 'Monday');
    expect(weekdayName(DateTime.sunday), 'Sunday');
  });

  group('Settings', () {
    Future<void> openGoalsSection(WidgetTester tester) async {
      await pump(tester, const AccountDashboard());
      await tester.scrollUntilVisible(find.text('Adaptive Goals'), 200,
          scrollable: find.byType(Scrollable).first);
      await pumpFrames(tester, seconds: 1);
    }

    testWidgets('the check-in day can be changed while adaptive is on', (tester) async {
      goals.startLearning(DateTime(2026, 10, 7)); // a Wednesday
      await openGoalsSection(tester);
      expect(find.text('Wednesday'), findsOneWidget);

      await tester.tap(find.text('Check-in Day'));
      await pumpFrames(tester, seconds: 1);
      await tester.tap(find.text('Friday'));
      await pumpFrames(tester, seconds: 1);
      expect(goals.checkinWeekday, DateTime.friday);
      expect(find.text('Friday'), findsOneWidget);
      expect(GoalsProvider().checkinWeekday, DateTime.friday);
    });

    testWidgets('the switch confirms, and the check-in day hides when off', (tester) async {
      await openGoalsSection(tester);
      expect(find.text('Check-in Day'), findsOneWidget);
      await tester.tap(find.descendant(
          of: find.ancestor(
              of: find.text('Adaptive Goals'), matching: find.byType(ListTile)),
          matching: find.byType(CupertinoSwitch)));
      await pumpFrames(tester, seconds: 1);
      expect(find.text(AdaptiveChoiceCopy.question), findsOneWidget);
      await tester.tap(find.text('Keep my targets fixed'));
      await pumpFrames(tester, seconds: 1);
      expect(goals.adaptiveGoals, isFalse);
      expect(find.text('Check-in Day'), findsNothing);
      expect(find.text('Targets stay as calculated'), findsOneWidget);
    });
  });
}
