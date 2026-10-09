import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/screens/onboarding/pages/adaptive_page.dart';
import 'package:macrotracker/screens/onboarding/pages/goal_page.dart';
import 'package:macrotracker/screens/onboarding/pages/set_new_goal_page.dart';
import 'package:macrotracker/screens/onboarding/pages/weight_page.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

void main() {
  late GoalsProvider goals;

  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('nutrition_goals');
    await StorageService().delete('unit_system');
    goals = GoalsProvider();
  });

  /// A home screen that opens [screen], as Settings opens Recalculate Goals.
  Future<void> pumpFromHome(WidgetTester tester, Widget screen,
      {WeightUnitProvider? units}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(detailedStatsProvider: DetailedStatsProvider(showDetailedStats: true),
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => screen)),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
      goalsProvider: goals,
      weightUnitProvider: units,
    ));
    await tester.tap(find.text('Open'));
    await pumpFrames(tester, seconds: 1);
  }

  Finder visible(Type page) => find.byType(page).hitTestable();

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Next'));
    await pumpFrames(tester, seconds: 1);
  }

  testWidgets('Recalculate Goals starts with Cancel, which closes it', (tester) async {
    await pumpFromHome(tester, const OnboardingScreen(recalculateOnly: true));
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Back'), findsNothing);

    await tester.tap(find.text('Cancel'));
    await pumpFrames(tester, seconds: 1);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('after the first step, Cancel becomes Back', (tester) async {
    await pumpFromHome(tester, const OnboardingScreen(recalculateOnly: true));
    await next(tester);
    expect(find.text('Back'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);

    await tester.tap(find.text('Back'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('new users get no Cancel on the welcome step', (tester) async {
    await pumpFromHome(tester, const OnboardingScreen());
    expect(find.text('Cancel'), findsNothing);
    expect(find.text('Back'), findsNothing);
  });

  for (final metric in [true, false]) {
    testWidgets('the weight unit starts as the ${metric ? 'metric' : 'imperial'} setting',
        (tester) async {
      final units = WeightUnitProvider()..setMetric(metric);
      await pumpFromHome(tester, const OnboardingScreen(recalculateOnly: true),
          units: units);
      // Recalculating starts at the weight.
      expect(visible(WeightPage), findsOneWidget);
      expect(tester.widget<WeightPage>(find.byType(WeightPage)).isMetric, metric);
    });
  }

  testWidgets('maintaining skips the goal-weight step both ways', (tester) async {
    goals.goalType = MacroCalculatorService.GOAL_MAINTAIN;
    await pumpFromHome(tester, const OnboardingScreen(recalculateOnly: true));
    // weight -> activity -> goal
    for (var i = 0; i < 2; i++) {
      await next(tester);
    }
    expect(visible(GoalPage), findsOneWidget);

    await next(tester);
    expect(visible(AdaptivePage), findsOneWidget);
    expect(visible(SetNewGoalPage), findsNothing);

    await tester.tap(find.text('Back'));
    await pumpFrames(tester, seconds: 1);
    expect(visible(GoalPage), findsOneWidget);
  });

  testWidgets('losing weight asks for a goal weight after the goal', (tester) async {
    goals.goalType = MacroCalculatorService.GOAL_LOSE;
    await pumpFromHome(tester, const OnboardingScreen(recalculateOnly: true));
    for (var i = 0; i < 3; i++) {
      await next(tester);
    }
    expect(visible(SetNewGoalPage), findsOneWidget);
  });

  for (final metric in [true, false]) {
    testWidgets(
        'a saved goal weight past the current weight is brought back in range '
        '(${metric ? 'kg' : 'lbs'})', (tester) async {
      goals
        ..currentWeightKg = 70.5
        ..goalWeightKg = 75
        ..goalType = MacroCalculatorService.GOAL_LOSE;
      await pumpFromHome(tester, const OnboardingScreen(recalculateOnly: true),
          units: WeightUnitProvider()..setMetric(metric));
      for (var i = 0; i < 3; i++) {
        await next(tester);
      }
      expect(visible(SetNewGoalPage), findsOneWidget);
      final page = tester.widget<SetNewGoalPage>(find.byType(SetNewGoalPage));
      expect(page.currentWeightKg, 70.5);
      expect(page.goalWeightKg, lessThan(70.5));
      expect(tester.takeException(), isNull);
    });
  }

  // New user picks "lose", sees the goal-weight step, then goes back and
  // lowers their weight. The goal weight chosen for the old weight is now
  // above the new one; it must be pulled back below it instead of crashing
  // the goal-weight wheel (value above its maximum).
  for (final metric in [true, false]) {
    testWidgets(
        'lowering your weight after choosing to lose keeps the goal below it '
        '(${metric ? 'kg' : 'lbs'})', (tester) async {
      await pumpFromHome(tester, const OnboardingScreen(),
          units: WeightUnitProvider()..setMetric(metric));

      // welcome -> gender -> weight
      await next(tester);
      await next(tester);
      expect(visible(WeightPage), findsOneWidget);
      tester.widget<WeightPage>(find.byType(WeightPage)).onWeightChanged(90);
      await pumpFrames(tester, seconds: 1);

      // weight -> height -> age -> activity -> goal
      for (var i = 0; i < 4; i++) {
        await next(tester);
      }
      expect(visible(GoalPage), findsOneWidget);
      tester.widget<GoalPage>(find.byType(GoalPage))
          .onGoalChanged(MacroCalculatorService.GOAL_LOSE);
      await pumpFrames(tester, seconds: 1);

      await next(tester);
      expect(visible(SetNewGoalPage), findsOneWidget);
      final firstGoal =
          tester.widget<SetNewGoalPage>(find.byType(SetNewGoalPage)).goalWeightKg;
      expect(firstGoal, lessThan(90));

      // Back to the weight step and drop well below that goal.
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('Back'));
        await pumpFrames(tester, seconds: 1);
      }
      expect(visible(WeightPage), findsOneWidget);
      tester.widget<WeightPage>(find.byType(WeightPage)).onWeightChanged(firstGoal - 15);
      await pumpFrames(tester, seconds: 1);

      // Forward to the goal-weight step again.
      for (var i = 0; i < 5; i++) {
        await next(tester);
      }
      expect(visible(SetNewGoalPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      final page = tester.widget<SetNewGoalPage>(find.byType(SetNewGoalPage));
      // In pounds the weight is kept to a whole pound.
      expect(page.currentWeightKg, closeTo(firstGoal - 15, 0.5));
      expect(page.goalWeightKg, lessThan(page.currentWeightKg));
    });
  }

  group('pace picker', () {
    Future<SetNewGoalPage> openGoalDetails(WidgetTester tester) async {
      await pumpFromHome(tester, const OnboardingScreen(recalculateOnly: true));
      for (var i = 0; i < 3; i++) {
        await next(tester);
      }
      expect(visible(SetNewGoalPage), findsOneWidget);
      return tester.widget<SetNewGoalPage>(find.byType(SetNewGoalPage));
    }

    testWidgets('losing offers four paces with 0.5% picked and recommended', (tester) async {
      goals
        ..currentWeightKg = 80
        ..goalWeightKg = 72
        ..goalType = MacroCalculatorService.GOAL_LOSE;
      final page = await openGoalDetails(tester);
      expect(page.paceChoices.map((c) => c.target.pacePct), [0.25, 0.5, 0.75, 1.0]);
      expect(page.pacePct, 0.5);
      expect(page.recommendedPacePct, 0.5);
      for (final label in ['0.25% a week', '0.5% a week', '0.75% a week', '1% a week']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.text('Recommended'), findsOneWidget);
      // Every option shows its cals and about how many weeks to the goal.
      for (final choice in page.paceChoices) {
        expect(choice.weeks, isNotNull);
      }
      expect(find.textContaining('weeks'), findsNWidgets(4));

      // A slower pace means more cals.
      final before = page.targetCalories!;
      await tester.tap(find.text('0.25% a week'));
      await pumpFrames(tester, seconds: 1);
      final after = tester.widget<SetNewGoalPage>(find.byType(SetNewGoalPage));
      expect(after.pacePct, 0.25);
      expect(after.targetCalories!, greaterThan(before));
    });

    testWidgets('gaining offers three paces with 0.25% picked', (tester) async {
      goals
        ..currentWeightKg = 70
        ..goalWeightKg = 75
        ..goalType = MacroCalculatorService.GOAL_GAIN;
      final page = await openGoalDetails(tester);
      expect(page.paceChoices.map((c) => c.target.pacePct), [0.1, 0.25, 0.5]);
      expect(page.pacePct, 0.25);
    });

    testWidgets('recalculating starts from the saved pace', (tester) async {
      goals
        ..currentWeightKg = 80
        ..goalWeightKg = 72
        ..goalType = MacroCalculatorService.GOAL_LOSE
        ..pacePctPerWeek = 0.75;
      final page = await openGoalDetails(tester);
      expect(page.pacePct, 0.75);
    });
  });

  group('pace limit explanation', () {
    PaceTarget clamped(SafetyLimit limit, double effective, double cals) => PaceTarget(
        pacePct: 1.0, cals: cals, effectivePacePct: effective, limitsHit: [limit]);

    test('is empty when no limit applied', () {
      expect(
          paceLimitExplanation(const PaceTarget(
              pacePct: 0.5, cals: 2000, effectivePacePct: 0.5, limitsHit: [])),
          isNull);
    });

    test('says plainly which limit slowed the pace', () {
      expect(paceLimitExplanation(clamped(SafetyLimit.floor, 0.6, 1200)),
          "We've set your pace to 0.6%/week so your target doesn't go below 1,200 cals, our minimum.");
      expect(paceLimitExplanation(clamped(SafetyLimit.floor, 0, 1200)),
          contains('kept your target at 1,200 cals, our minimum'));
      expect(paceLimitExplanation(clamped(SafetyLimit.maxDeficit, 0.42, 1900)),
          "We've set your pace to 0.4%/week so you eat no more than 25% below what you burn.");
      expect(paceLimitExplanation(clamped(SafetyLimit.maxSurplus, 0.38, 3000)),
          contains('no more than 15% above what you burn'));
      expect(paceLimitExplanation(clamped(SafetyLimit.maxLossPace, 1.0, 2000)),
          contains('the fastest we recommend for losing weight'));
      expect(paceLimitExplanation(clamped(SafetyLimit.maxGainPace, 0.5, 3000)),
          contains('the fastest we recommend for gaining weight'));
    });
  });

  testWidgets('a clamped pace shows why on the page', (tester) async {
    await tester.pumpWidget(testApp(detailedStatsProvider: DetailedStatsProvider(showDetailedStats: true),
      Scaffold(
        body: SetNewGoalPage(
          currentGoal: MacroCalculatorService.GOAL_LOSE,
          currentWeightKg: 110,
          goalWeightKg: 90,
          paceChoices: const [
            PaceChoice(
              target: PaceTarget(
                  pacePct: 0.5, cals: 2100, effectivePacePct: 0.5, limitsHit: []),
              weeks: 36,
            ),
            PaceChoice(
              target: PaceTarget(
                  pacePct: 1.0,
                  cals: 1950,
                  effectivePacePct: 0.62,
                  limitsHit: [SafetyLimit.maxDeficit]),
              weeks: 29,
            ),
          ],
          pacePct: 1.0,
          recommendedPacePct: 0.5,
          isMetricWeight: true,
          targetCalories: 1950,
          onGoalWeightChanged: (_) {},
          onPaceChanged: (_) {},
          onWeightUnitChanged: (_) {},
        ),
      ),
      goalsProvider: goals,
    ));
    await pumpFrames(tester, seconds: 1);
    expect(find.textContaining('Capped at 0.6%'), findsOneWidget);
    expect(find.text(
            "We've set your pace to 0.6%/week so you eat no more than 25% below what you burn."),
        findsOneWidget);
  });

  testWidgets('"How did you hear about us?" can be skipped', (tester) async {
    await pumpFromHome(tester, const AcquisitionSourceStep());
    expect(find.byType(AcquisitionSourceStep), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Skip'));
    await pumpFrames(tester, seconds: 1);
    expect(find.byType(AcquisitionSourceStep), findsNothing);
  });
}
