import 'package:macrotracker/services/macro_calculator_service.dart';

/// Steps of the onboarding flow, named so pages can link to each other
/// without depending on their position.
enum OnboardingStep {
  welcome,
  gender,
  weight,
  height,
  age,
  activity,
  goal,
  setNewGoal,
  adaptive,
  advanced,
  appleHealth,
  summary,
}

/// The steps shown, in order. Recalculating goals from Settings asks only
/// what changes over time (spec 7.6): it skips the welcome and Apple Health
/// steps and the static facts (sex, height, age), which are edited on the
/// account screen. "How did you hear about us?" is not a step: new users are
/// asked it after the results screen.
List<OnboardingStep> onboardingStepsFor({required bool recalculateOnly}) =>
    recalculateOnly
        ? const [
            OnboardingStep.weight,
            OnboardingStep.activity,
            OnboardingStep.goal,
            OnboardingStep.setNewGoal,
            OnboardingStep.adaptive,
            OnboardingStep.advanced,
            OnboardingStep.summary,
          ]
        : OnboardingStep.values;

/// Steps passed over for the answers so far: maintaining ([goal]) needs no
/// goal weight, and planning from a confident learned expenditure
/// ([usesLearnedExpenditure], adaptive goals only) needs no activity level.
bool isOnboardingStepSkipped(
  OnboardingStep step, {
  required String goal,
  bool usesLearnedExpenditure = false,
}) =>
    switch (step) {
      OnboardingStep.setNewGoal => goal == MacroCalculatorService.GOAL_MAINTAIN,
      OnboardingStep.activity => usesLearnedExpenditure,
      _ => false,
    };
