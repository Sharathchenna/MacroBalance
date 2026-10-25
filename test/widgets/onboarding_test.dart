import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/screens/onboarding/pages/adaptive_page.dart';
import 'package:macrotracker/screens/onboarding/pages/goal_page.dart';
import 'package:macrotracker/screens/onboarding/pages/goal_weight_page.dart';
import 'package:macrotracker/screens/onboarding/pages/pace_page.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
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

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byType(ObBackButton));
    await pumpFrames(tester, seconds: 1);
  }

  Finder closeButton() =>
      find.byWidgetPredicate((w) => w is ObBackButton && w.close);

  Future<void> next(WidgetTester tester) async {
    await tester.tap(find.text('Continue'));
    await pumpFrames(tester, seconds: 1);
  }

  testWidgets('Recalculate Goals starts with a Close button, which closes it', (tester) async {
    await pumpFromHome(tester, const OnboardingScreen(recalculateOnly: true));
    expect(closeButton(), findsOneWidget);

    await tester.tap(closeButton());
    await pumpFrames(tester, seconds: 1);
    expect(find.byType(OnboardingScreen), findsNothing);
    expect(find.text('Open'), findsOneWidget);
  });

  testWidgets('after the first step, Close becomes Back', (tester) async {
    await pumpFromHome(tester, const OnboardingScreen(recalculateOnly: true));
    await next(tester);
    expect(find.byType(ObBackButton), findsOneWidget);
    expect(closeButton(), findsNothing);

    await back(tester);
    expect(closeButton(), findsOneWidget);
    expect(visible(WeightPage), findsOneWidget);
  });

  testWidgets('new users start on the goal step with a plain Back button', (tester) async {
    await pumpFromHome(tester, const OnboardingScreen());
    expect(visible(GoalPage), findsOneWidget);
    expect(closeButton(), findsNothing);
    expect(find.byType(ObBackButton), findsOneWidget);
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
    expect(visible(GoalWeightPage), findsNothing);
    expect(visible(PacePage), findsNothing);

    await back(tester);
    expect(visible(GoalPage), findsOneWidget);
  });

  testWidgets('losing weight asks for a goal weight after the goal', (tester) async {
    goals.goalType = MacroCalculatorService.GOAL_LOSE;
    await pumpFromHome(tester, const OnboardingScreen(recalculateOnly: true));
    // weight -> activity -> goal -> goal weight
    for (var i = 0; i < 3; i++) {
      await next(tester);
    }
    expect(visible(GoalWeightPage), findsOneWidget);
    await next(tester);
    expect(visible(PacePage), findsOneWidget);
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
      expect(visible(GoalWeightPage), findsOneWidget);
      final page = tester.widget<GoalWeightPage>(find.byType(GoalWeightPage));
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

      // goal: lose
      expect(visible(GoalPage), findsOneWidget);
      tester.widget<GoalPage>(find.byType(GoalPage))
          .onGoalChanged(MacroCalculatorService.GOAL_LOSE);
      await pumpFrames(tester, seconds: 1);

      // goal -> about you -> weight
      await next(tester);
      await next(tester);
      expect(visible(WeightPage), findsOneWidget);
      tester.widget<WeightPage>(find.byType(WeightPage)).onWeightChanged(90);
      await pumpFrames(tester, seconds: 1);

      // weight -> activity -> goal weight
      await next(tester);
      await next(tester);
      expect(visible(GoalWeightPage), findsOneWidget);
      final firstGoal =
          tester.widget<GoalWeightPage>(find.byType(GoalWeightPage)).goalWeightKg;
      expect(firstGoal, lessThan(90));

      // Back to the weight step and drop well below that goal.
      for (var i = 0; i < 2; i++) {
        await back(tester);
      }
      expect(visible(WeightPage), findsOneWidget);
      tester.widget<WeightPage>(find.byType(WeightPage)).onWeightChanged(firstGoal - 15);
      await pumpFrames(tester, seconds: 1);

      // Forward to the goal-weight step again.
      for (var i = 0; i < 2; i++) {
        await next(tester);
      }
      expect(visible(GoalWeightPage), findsOneWidget);
      expect(tester.takeException(), isNull);
      final page = tester.widget<GoalWeightPage>(find.byType(GoalWeightPage));
      // In pounds the weight is kept to a whole pound.
      expect(page.currentWeightKg, closeTo(firstGoal - 15, 0.5));
      expect(page.goalWeightKg, lessThan(page.currentWeightKg));
      expect(page.goalWeightKg, lessThanOrEqualTo(page.maxKg));
    });
  }

  group('pace picker', () {
    Future<PacePage> openGoalDetails(WidgetTester tester) async {
      await pumpFromHome(tester, const OnboardingScreen(recalculateOnly: true));
      // weight -> activity -> goal -> goal weight -> pace
      for (var i = 0; i < 4; i++) {
        await next(tester);
      }
      expect(visible(PacePage), findsOneWidget);
      return tester.widget<PacePage>(find.byType(PacePage));
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
        expect(find.textContaining(label), findsOneWidget, reason: label);
      }
      expect(find.text('Recommended'), findsOneWidget);
      // Every option knows its weeks to the goal and shows its weekly change.
      for (final choice in page.paceChoices) {
        expect(choice.weeks, isNotNull);
      }
      expect(find.textContaining(RegExp(r'a week · about [\d.]+ (kg|lb)$')), findsNWidgets(4));

      // A slower pace means more cals, shown on every row.
      final cals = {for (final c in page.paceChoices) c.target.pacePct: c.target.cals};
      expect(cals[0.25]!, greaterThan(cals[0.5]!));
      expect(find.text('cals a day'), findsNWidgets(4));
      await tester.tap(find.textContaining('0.25% a week'));
      await pumpFrames(tester, seconds: 1);
      final after = tester.widget<PacePage>(find.byType(PacePage));
      expect(after.pacePct, 0.25);
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
        body: PacePage(
          goal: MacroCalculatorService.GOAL_LOSE,
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
          onPaceChanged: (_) {},
        ),
      ),
      goalsProvider: goals,
    ));
    await pumpFrames(tester, seconds: 1);
    expect(find.text(
            "We've set your pace to 0.6%/week so you eat no more than 25% below what you burn."),
        findsOneWidget);
  });

  testWidgets('"How did you hear about us?" can be skipped', (tester) async {
    await pumpFromHome(tester, const AcquisitionSourceStep());
    expect(find.byType(AcquisitionSourceStep), findsOneWidget);
    await tester.tap(find.byKey(const Key('source_cta')));
    await pumpFrames(tester, seconds: 1);
    expect(find.byType(AcquisitionSourceStep), findsNothing);
  });
}
