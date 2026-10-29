import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/auth/auth_gate.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/screens/intro/hello_screen.dart';
import 'package:macrotracker/screens/onboarding/building_screen.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/screens/onboarding/onboarding_steps.dart';
import 'package:macrotracker/screens/onboarding/pages/goal_page.dart';
import 'package:macrotracker/screens/onboarding/pages/goal_weight_page.dart';
import 'package:macrotracker/screens/onboarding/pages/insight_page.dart';
import 'package:macrotracker/screens/onboarding/pages/pace_page.dart';
import 'package:macrotracker/screens/onboarding/pages/summary_page.dart';
import 'package:macrotracker/screens/onboarding/pages/weight_page.dart';
import 'package:macrotracker/screens/onboarding/save_screen.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../../helpers/test_app.dart';

void main() {
  late GoalsProvider goals;

  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('nutrition_goals');
    goals = GoalsProvider();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpRecalculate(WidgetTester tester) async {
    phone(tester);
    await tester.pumpWidget(testApp(
      const OnboardingScreen(recalculateOnly: true),
      goalsProvider: goals,
      detailedStatsProvider: DetailedStatsProvider(showDetailedStats: true),
    ));
    await pumpFrames(tester, seconds: 1);
  }

  Finder visible(Type page) => find.byType(page).hitTestable();

  Future<void> next(WidgetTester tester, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.text('Continue'));
      await pumpFrames(tester, seconds: 1);
    }
  }

  Future<void> edit(WidgetTester tester, OnboardingStep step) async {
    tester.widget<SummaryPage>(find.byType(SummaryPage)).onEdit(step);
    await pumpFrames(tester, seconds: 1);
  }

  group('Editing from the summary', () {
    testWidgets('returns to the summary after the changed answer', (tester) async {
      goals.goalType = MacroCalculatorService.GOAL_MAINTAIN;
      await pumpRecalculate(tester);
      // weight -> activity -> goal -> adaptive -> advanced -> summary
      await next(tester, 5);
      expect(visible(SummaryPage), findsOneWidget);

      await edit(tester, OnboardingStep.weight);
      expect(visible(WeightPage), findsOneWidget);
      await next(tester);
      expect(visible(SummaryPage), findsOneWidget);
    });

    testWidgets('a new goal asks its goal weight and pace, then returns', (tester) async {
      goals.goalType = MacroCalculatorService.GOAL_MAINTAIN;
      await pumpRecalculate(tester);
      await next(tester, 5);

      await edit(tester, OnboardingStep.goal);
      tester
          .widget<GoalPage>(find.byType(GoalPage))
          .onGoalChanged(MacroCalculatorService.GOAL_LOSE);
      await pumpFrames(tester, seconds: 1);
      await next(tester);
      expect(visible(GoalWeightPage), findsOneWidget);
      await next(tester);
      expect(visible(PacePage), findsOneWidget);
      await next(tester);
      expect(visible(SummaryPage), findsOneWidget);
    });
  });

  testWidgets('a heavy user gaining gets goal weights above today\'s', (tester) async {
    goals.goalType = MacroCalculatorService.GOAL_MAINTAIN;
    goals.currentWeightKg = 160;
    await pumpRecalculate(tester);
    await next(tester, 2); // weight -> activity -> goal
    tester
        .widget<GoalPage>(find.byType(GoalPage))
        .onGoalChanged(MacroCalculatorService.GOAL_GAIN);
    await pumpFrames(tester, seconds: 1);
    await next(tester);

    final page = tester.widget<GoalWeightPage>(find.byType(GoalWeightPage));
    expect(page.currentWeightKg, 160);
    expect(page.minKg, greaterThan(160));
    expect(page.goalWeightKg, greaterThan(160));
    expect(page.maxKg, lessThanOrEqualTo(kMaxWeightKg));
  });

  testWidgets('a heavy user losing can pick a goal above 150 kg', (tester) async {
    goals.goalType = MacroCalculatorService.GOAL_MAINTAIN;
    goals.currentWeightKg = 190;
    await pumpRecalculate(tester);
    await next(tester, 2);
    tester
        .widget<GoalPage>(find.byType(GoalPage))
        .onGoalChanged(MacroCalculatorService.GOAL_LOSE);
    await pumpFrames(tester, seconds: 1);
    await next(tester);

    final page = tester.widget<GoalWeightPage>(find.byType(GoalWeightPage));
    expect(page.maxKg, closeTo(189.9, 0.01));
    expect(page.goalWeightKg, closeTo(171, 0.01)); // 10% off
  });

  testWidgets('maintaining gets its own insight line', (tester) async {
    phone(tester);
    await tester.pumpWidget(testApp(const InsightPage(
        goal: MacroCalculatorService.GOAL_MAINTAIN, obstacles: {})));
    await pumpFrames(tester, seconds: 2);
    expect(find.textContaining('drifts away'), findsOneWidget);
    expect(find.textContaining('As you lose weight'), findsNothing);
  });

  testWidgets('Building names Katch–McArdle when body fat is known', (tester) async {
    phone(tester);
    await tester.pumpWidget(testApp(BuildingScreen(
        work: () async {}, onDone: () {}, bodyFatKnown: true)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('Katch–McArdle'), findsOneWidget);
    await pumpFrames(tester, seconds: 10);
  });

  testWidgets('Building can\'t be swiped back', (tester) async {
    phone(tester);
    await tester.pumpWidget(testApp(BuildingScreen(work: () async {}, onDone: () {})));
    await tester.pump();
    final scope = tester.widget<PopScope>(find.byType(PopScope).first);
    expect(scope.canPop, isFalse);
    await pumpFrames(tester, seconds: 10);
  });

  testWidgets('"I already have an account" clears the signed-out onboarding hold',
      (tester) async {
    phone(tester);
    AuthGate.signedOutOnboarding = true;
    addTearDown(() => AuthGate.signedOutOnboarding = false);
    await tester.pumpWidget(testApp(const HelloScreen()));
    await tester.pump();
    await tester.tap(find.text('I already have an account'));
    await tester.pump();
    expect(AuthGate.signedOutOnboarding, isFalse);
    await pumpFrames(tester, seconds: 2);
  });

  test('keeping the account plan replaces the new plan on the device', () async {
    await StorageService().put(
        'nutrition_goals',
        jsonEncode({
          'macro_targets': {'calories': 2600, 'protein': 180, 'carbs': 300, 'fat': 80},
          'goal_type': MacroCalculatorService.GOAL_GAIN,
        }));
    await StorageService().put('macro_results', jsonEncode({'target_calories': 2600}));

    await SaveScreen.keepAccountPlan({
      'calories_goal': 1800,
      'protein_goal': 150,
      'carbs_goal': 160,
      'fat_goal': 60,
      'goal_type': MacroCalculatorService.GOAL_LOSE,
    });

    final loaded = GoalsProvider();
    await loaded.load();
    expect(loaded.caloriesGoal, 1800);
    expect(loaded.goalType, MacroCalculatorService.GOAL_LOSE);
    expect(StorageService().get('macro_results'), isNull);
  });
}
