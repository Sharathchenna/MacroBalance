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
  advanced,
  appleHealth,
  summary,
}

/// The steps shown, in order. Recalculating goals from Settings skips the
/// welcome and Apple Health steps, and the static facts (sex, height, age):
/// those are edited on the account screen. "How did you hear about us?" is not a step:
/// new users are asked it after the results screen.
List<OnboardingStep> onboardingStepsFor({required bool recalculateOnly}) =>
    recalculateOnly
        ? const [
            OnboardingStep.weight,
            OnboardingStep.activity,
            OnboardingStep.goal,
            OnboardingStep.setNewGoal,
            OnboardingStep.advanced,
            OnboardingStep.summary,
          ]
        : OnboardingStep.values;

/// Steps passed over for the chosen [goal]: maintaining needs no goal weight.
bool isOnboardingStepSkipped(OnboardingStep step, String goal) =>
    step == OnboardingStep.setNewGoal && goal == MacroCalculatorService.GOAL_MAINTAIN;
