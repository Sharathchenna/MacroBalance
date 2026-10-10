import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/screens/onboarding/onboarding_steps.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';

void main() {
  group('onboardingStepsFor', () {
    test('new users see every step, from welcome to the summary', () {
      final steps = onboardingStepsFor(recalculateOnly: false);
      expect(steps, OnboardingStep.values);
      expect(steps.first, OnboardingStep.welcome);
      expect(steps.last, OnboardingStep.summary);
    });

    test('the goal weight comes right after the goal, and Apple Health before the summary', () {
      final steps = onboardingStepsFor(recalculateOnly: false);
      expect(steps.indexOf(OnboardingStep.setNewGoal),
          steps.indexOf(OnboardingStep.goal) + 1);
      expect(steps.indexOf(OnboardingStep.appleHealth),
          steps.indexOf(OnboardingStep.summary) - 1);
    });

    test('the adaptive question comes after the goal details, before advanced settings', () {
      final steps = onboardingStepsFor(recalculateOnly: false);
      expect(steps.indexOf(OnboardingStep.adaptive),
          steps.indexOf(OnboardingStep.planStyle) + 1);
      expect(steps.indexOf(OnboardingStep.advanced),
          steps.indexOf(OnboardingStep.adaptive) + 1);
    });

    test('the plan style comes right after the goal weight and pace, before adaptive (both flows)',
        () {
      for (final recalculateOnly in [false, true]) {
        final steps = onboardingStepsFor(recalculateOnly: recalculateOnly);
        expect(steps.indexOf(OnboardingStep.planStyle),
            steps.indexOf(OnboardingStep.setNewGoal) + 1);
        expect(steps.indexOf(OnboardingStep.adaptive),
            steps.indexOf(OnboardingStep.planStyle) + 1);
      }
    });

    test('recalculating asks the adaptive choice after the goal details', () {
      final steps = onboardingStepsFor(recalculateOnly: true);
      expect(steps.indexOf(OnboardingStep.adaptive),
          steps.indexOf(OnboardingStep.planStyle) + 1);
      expect(steps.indexOf(OnboardingStep.advanced),
          steps.indexOf(OnboardingStep.adaptive) + 1);
    });

    test('recalculating skips welcome and Apple Health but keeps the order', () {
      final steps = onboardingStepsFor(recalculateOnly: true);
      expect(steps, isNot(contains(OnboardingStep.welcome)));
      expect(steps, isNot(contains(OnboardingStep.appleHealth)));
      expect(steps.first, OnboardingStep.weight);
      expect(steps.last, OnboardingStep.summary);
      final full = onboardingStepsFor(recalculateOnly: false);
      expect(steps, full.where(steps.contains).toList());
    });
  });

  test('recalculating no longer asks sex, height or age', () {
    final steps = onboardingStepsFor(recalculateOnly: true);
    for (final step in [OnboardingStep.gender, OnboardingStep.height, OnboardingStep.age]) {
      expect(steps, isNot(contains(step)), reason: step.name);
    }
    expect(steps, [
      OnboardingStep.weight,
      OnboardingStep.activity,
      OnboardingStep.goal,
      OnboardingStep.setNewGoal,
      OnboardingStep.planStyle,
      OnboardingStep.adaptive,
      OnboardingStep.advanced,
      OnboardingStep.summary,
    ]);
  });

  test('new users are still asked sex, height and age', () {
    final steps = onboardingStepsFor(recalculateOnly: false);
    expect(steps, containsAll([OnboardingStep.gender, OnboardingStep.height, OnboardingStep.age]));
  });

  group('isOnboardingStepSkipped', () {
    test('simple mode skips plan style and nutrition fine tuning only', () {
      for (final step in OnboardingStep.values) {
        expect(isOnboardingStepSkipped(step, goal: MacroCalculatorService.GOAL_LOSE, showDetailedStats: false), step == OnboardingStep.planStyle || step == OnboardingStep.advanced, reason: step.name);
      }
    });
    test('the plan style is asked only for a lose goal', () {
      expect(isOnboardingStepSkipped(OnboardingStep.planStyle,
              goal: MacroCalculatorService.GOAL_LOSE),
          isFalse);
      for (final goal in [MacroCalculatorService.GOAL_MAINTAIN, MacroCalculatorService.GOAL_GAIN]) {
        expect(isOnboardingStepSkipped(OnboardingStep.planStyle, goal: goal), isTrue,
            reason: goal);
      }
    });

    test('maintaining skips the goal-weight step', () {
      expect(isOnboardingStepSkipped(OnboardingStep.setNewGoal,
              goal: MacroCalculatorService.GOAL_MAINTAIN),
          isTrue);
    });

    test('the adaptive question is asked for every goal', () {
      for (final goal in [
        MacroCalculatorService.GOAL_LOSE,
        MacroCalculatorService.GOAL_MAINTAIN,
        MacroCalculatorService.GOAL_GAIN,
      ]) {
        expect(isOnboardingStepSkipped(OnboardingStep.adaptive, goal: goal), isFalse,
            reason: goal);
      }
    });

    test('losing or gaining asks for a goal weight', () {
      for (final goal in [MacroCalculatorService.GOAL_LOSE, MacroCalculatorService.GOAL_GAIN]) {
        expect(isOnboardingStepSkipped(OnboardingStep.setNewGoal, goal: goal), isFalse,
            reason: goal);
      }
    });

    test('activity is skipped when planning from the learned expenditure', () {
      for (final goal in [
        MacroCalculatorService.GOAL_LOSE,
        MacroCalculatorService.GOAL_MAINTAIN,
        MacroCalculatorService.GOAL_GAIN,
      ]) {
        expect(
            isOnboardingStepSkipped(OnboardingStep.activity,
                goal: goal, usesLearnedExpenditure: true),
            isTrue,
            reason: goal);
        expect(isOnboardingStepSkipped(OnboardingStep.activity, goal: goal), isFalse,
            reason: goal);
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
      for (final step in OnboardingStep.values.where(
          (s) => s != OnboardingStep.setNewGoal && s != OnboardingStep.planStyle)) {
        expect(isOnboardingStepSkipped(step, goal: MacroCalculatorService.GOAL_MAINTAIN),
            isFalse,
            reason: step.name);
      }
    });
  });
}
