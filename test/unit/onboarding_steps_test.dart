import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/screens/onboarding/onboarding_steps.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';

void main() {
  group('onboardingStepsFor', () {
    test('new users see every step, from the goal to the summary', () {
      final steps = onboardingStepsFor(recalculateOnly: false);
      expect(steps, OnboardingStep.values);
      expect(steps.first, OnboardingStep.goal);
      expect(steps.last, OnboardingStep.summary);
    });

    test('new users answer every input the maths uses', () {
      final steps = onboardingStepsFor(recalculateOnly: false);
      expect(
          steps,
          containsAll([
            OnboardingStep.goal,
            OnboardingStep.aboutYou,
            OnboardingStep.weight,
            OnboardingStep.activity,
            OnboardingStep.goalWeight,
            OnboardingStep.pace,
            OnboardingStep.planStyle,
            OnboardingStep.adaptive,
            OnboardingStep.advanced,
          ]));
    });

    test('goal weight and pace follow the activity, then the plan style', () {
      final steps = onboardingStepsFor(recalculateOnly: false);
      expect(steps.indexOf(OnboardingStep.goalWeight), steps.indexOf(OnboardingStep.activity) + 1);
      expect(steps.indexOf(OnboardingStep.pace), steps.indexOf(OnboardingStep.goalWeight) + 1);
      expect(steps.indexOf(OnboardingStep.planStyle), steps.indexOf(OnboardingStep.pace) + 1);
    });

    test('the obstacles reply leads into the adaptive choice, then fine tuning', () {
      final steps = onboardingStepsFor(recalculateOnly: false);
      expect(steps.indexOf(OnboardingStep.insight), steps.indexOf(OnboardingStep.obstacles) + 1);
      expect(steps.indexOf(OnboardingStep.adaptive), steps.indexOf(OnboardingStep.insight) + 1);
      expect(steps.indexOf(OnboardingStep.advanced), steps.indexOf(OnboardingStep.adaptive) + 1);
    });

    test('the permission primers come last, before the summary', () {
      final steps = onboardingStepsFor(recalculateOnly: false);
      expect(steps.indexOf(OnboardingStep.notifications), steps.length - 2);
      expect(steps.indexOf(OnboardingStep.appleHealth), steps.length - 3);
    });

    test('recalculating keeps the plan style after the pace and before adaptive', () {
      final steps = onboardingStepsFor(recalculateOnly: true);
      expect(steps.indexOf(OnboardingStep.planStyle), steps.indexOf(OnboardingStep.pace) + 1);
      expect(steps.indexOf(OnboardingStep.adaptive), steps.indexOf(OnboardingStep.planStyle) + 1);
      expect(steps.indexOf(OnboardingStep.advanced), steps.indexOf(OnboardingStep.adaptive) + 1);
    });

    test('recalculating skips the primers and obstacles but keeps the order of the rest', () {
      final steps = onboardingStepsFor(recalculateOnly: true);
      for (final step in [
        OnboardingStep.appleHealth,
        OnboardingStep.notifications,
        OnboardingStep.obstacles,
        OnboardingStep.insight,
      ]) {
        expect(steps, isNot(contains(step)), reason: step.name);
      }
      expect(steps.first, OnboardingStep.weight);
      expect(steps.last, OnboardingStep.summary);
    });
  });

  test('recalculating no longer asks sex, height or age', () {
    final steps = onboardingStepsFor(recalculateOnly: true);
    expect(steps, isNot(contains(OnboardingStep.aboutYou)));
    expect(steps, [
      OnboardingStep.weight,
      OnboardingStep.activity,
      OnboardingStep.goal,
      OnboardingStep.goalWeight,
      OnboardingStep.pace,
      OnboardingStep.planStyle,
      OnboardingStep.adaptive,
      OnboardingStep.advanced,
      OnboardingStep.summary,
    ]);
  });

  group('onboardingProgress', () {
    test('runs from the first step to full at the last asked step', () {
      final steps = onboardingStepsFor(recalculateOnly: false);
      expect(onboardingProgress(steps, OnboardingStep.goal), greaterThan(0));
      expect(onboardingProgress(steps, OnboardingStep.notifications), 1);
      expect(onboardingProgress(steps, OnboardingStep.summary), 1);
    });

    test('only ever grows through the flow', () {
      final steps = onboardingStepsFor(recalculateOnly: false);
      var last = 0.0;
      for (final s in steps) {
        final p = onboardingProgress(steps, s);
        expect(p, greaterThanOrEqualTo(last), reason: s.name);
        last = p;
      }
    });
  });

  group('isOnboardingStepSkipped', () {
    test('simple mode skips plan style and nutrition fine tuning only', () {
      for (final step in OnboardingStep.values) {
        expect(
            isOnboardingStepSkipped(step,
                goal: MacroCalculatorService.GOAL_LOSE, showDetailedStats: false),
            step == OnboardingStep.planStyle || step == OnboardingStep.advanced,
            reason: step.name);
      }
    });

    test('the plan style is asked only for a lose goal', () {
      expect(isOnboardingStepSkipped(OnboardingStep.planStyle, goal: MacroCalculatorService.GOAL_LOSE),
          isFalse);
      for (final goal in [MacroCalculatorService.GOAL_MAINTAIN, MacroCalculatorService.GOAL_GAIN]) {
        expect(isOnboardingStepSkipped(OnboardingStep.planStyle, goal: goal), isTrue, reason: goal);
      }
    });

    test('maintaining skips the goal weight and pace', () {
      for (final step in [OnboardingStep.goalWeight, OnboardingStep.pace]) {
        expect(isOnboardingStepSkipped(step, goal: MacroCalculatorService.GOAL_MAINTAIN), isTrue,
            reason: step.name);
      }
    });

    test('losing or gaining asks for a goal weight and pace', () {
      for (final goal in [MacroCalculatorService.GOAL_LOSE, MacroCalculatorService.GOAL_GAIN]) {
        for (final step in [OnboardingStep.goalWeight, OnboardingStep.pace]) {
          expect(isOnboardingStepSkipped(step, goal: goal), isFalse, reason: '$goal ${step.name}');
        }
      }
    });

    test('the adaptive question is asked for every goal', () {
      for (final goal in [
        MacroCalculatorService.GOAL_LOSE,
        MacroCalculatorService.GOAL_MAINTAIN,
        MacroCalculatorService.GOAL_GAIN,
      ]) {
        expect(isOnboardingStepSkipped(OnboardingStep.adaptive, goal: goal), isFalse, reason: goal);
      }
    });

    test('activity is skipped when planning from the learned expenditure', () {
      for (final goal in [
        MacroCalculatorService.GOAL_LOSE,
        MacroCalculatorService.GOAL_MAINTAIN,
        MacroCalculatorService.GOAL_GAIN,
      ]) {
        expect(
            isOnboardingStepSkipped(OnboardingStep.activity, goal: goal, usesLearnedExpenditure: true),
            isTrue,
            reason: goal);
        expect(isOnboardingStepSkipped(OnboardingStep.activity, goal: goal), isFalse, reason: goal);
      }
    });

    test('the learned expenditure skips nothing but activity', () {
      for (final step in OnboardingStep.values.where((s) => s != OnboardingStep.activity)) {
        expect(
            isOnboardingStepSkipped(step,
                goal: MacroCalculatorService.GOAL_LOSE, usesLearnedExpenditure: true),
            isFalse,
            reason: step.name);
      }
    });

    test('no other step is ever skipped', () {
      for (final step in OnboardingStep.values.where((s) =>
          s != OnboardingStep.goalWeight &&
          s != OnboardingStep.pace &&
          s != OnboardingStep.planStyle)) {
        expect(isOnboardingStepSkipped(step, goal: MacroCalculatorService.GOAL_MAINTAIN), isFalse,
            reason: step.name);
      }
    });
  });
}
