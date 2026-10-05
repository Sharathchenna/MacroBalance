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

    test('recalculating skips welcome and Apple Health but keeps the order', () {
      final steps = onboardingStepsFor(recalculateOnly: true);
      expect(steps, isNot(contains(OnboardingStep.welcome)));
      expect(steps, isNot(contains(OnboardingStep.appleHealth)));
      expect(steps.first, OnboardingStep.gender);
      expect(steps.last, OnboardingStep.summary);
      final full = onboardingStepsFor(recalculateOnly: false);
      expect(steps, full.where(steps.contains).toList());
    });
  });

  group('isOnboardingStepSkipped', () {
    test('maintaining skips the goal-weight step', () {
      expect(isOnboardingStepSkipped(
              OnboardingStep.setNewGoal, MacroCalculatorService.GOAL_MAINTAIN),
          isTrue);
    });

    test('losing or gaining asks for a goal weight', () {
      for (final goal in [MacroCalculatorService.GOAL_LOSE, MacroCalculatorService.GOAL_GAIN]) {
        expect(isOnboardingStepSkipped(OnboardingStep.setNewGoal, goal), isFalse,
            reason: goal);
      }
    });

    test('no other step is ever skipped', () {
      for (final step in OnboardingStep.values.where((s) => s != OnboardingStep.setNewGoal)) {
        expect(isOnboardingStepSkipped(step, MacroCalculatorService.GOAL_MAINTAIN), isFalse,
            reason: step.name);
      }
    });
  });
}
