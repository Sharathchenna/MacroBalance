import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/screens/onboarding/pages/advanced_settings_page.dart';
import 'package:macrotracker/screens/onboarding/pages/goal_page.dart';
import 'package:macrotracker/screens/onboarding/pages/set_new_goal_page.dart';
import 'package:macrotracker/screens/onboarding/pages/weight_page.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
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
    await tester.pumpWidget(testApp(
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
      await next(tester); // gender -> weight
      expect(visible(WeightPage), findsOneWidget);
      expect(tester.widget<WeightPage>(find.byType(WeightPage)).isMetric, metric);
    });
  }

  testWidgets('maintaining skips the goal-weight step both ways', (tester) async {
    goals.goalType = MacroCalculatorService.GOAL_MAINTAIN;
    await pumpFromHome(tester, const OnboardingScreen(recalculateOnly: true));
    // gender -> weight -> height -> age -> activity -> goal
    for (var i = 0; i < 5; i++) {
      await next(tester);
    }
    expect(visible(GoalPage), findsOneWidget);

    await next(tester);
    expect(visible(AdvancedSettingsPage), findsOneWidget);
    expect(visible(SetNewGoalPage), findsNothing);

    await tester.tap(find.text('Back'));
    await pumpFrames(tester, seconds: 1);
    expect(visible(GoalPage), findsOneWidget);
  });

  testWidgets('losing weight asks for a goal weight after the goal', (tester) async {
    goals.goalType = MacroCalculatorService.GOAL_LOSE;
    await pumpFromHome(tester, const OnboardingScreen(recalculateOnly: true));
    for (var i = 0; i < 6; i++) {
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
      for (var i = 0; i < 6; i++) {
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

  testWidgets('"How did you hear about us?" can be skipped', (tester) async {
    await pumpFromHome(tester, const AcquisitionSourceStep());
    expect(find.byType(AcquisitionSourceStep), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Skip'));
    await pumpFrames(tester, seconds: 1);
    expect(find.byType(AcquisitionSourceStep), findsNothing);
  });
}
