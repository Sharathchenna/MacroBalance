import 'package:macrotracker/services/macro_calculator_service.dart';

/// Steps of the onboarding flow, named so pages can link to each other
/// without depending on their position. The intro (hello and stories) comes
/// before these, and the plan reveal after.
enum OnboardingStep {
  goal,
  aboutYou, // sex, age and height
  weight,
  activity,
  goalWeight,
  pace,
  planStyle,
  obstacles,
  insight,
  adaptive,
  advanced,
  appleHealth,
  notifications,
  summary,
}

/// The steps shown, in order. Recalculating goals from Settings asks only
/// what changes over time (spec 7.6): it skips the permission primers, the
/// obstacles and their reply, and the static facts (sex, height, age), which
/// are edited on the account screen. New users reach [OnboardingStep.summary]
/// only from the plan reveal's "Review answers"; "How did you hear about
/// us?" is asked after the plan.
List<OnboardingStep> onboardingStepsFor({required bool recalculateOnly}) =>
    recalculateOnly
        ? const [
            OnboardingStep.weight,
            OnboardingStep.activity,
            OnboardingStep.goal,
            OnboardingStep.goalWeight,
            OnboardingStep.pace,
            OnboardingStep.planStyle,
            OnboardingStep.adaptive,
            OnboardingStep.advanced,
            OnboardingStep.summary,
          ]
        : OnboardingStep.values;

/// Steps passed over for the answers so far: maintaining ([goal]) needs no
/// goal weight or pace, only losing has a plan style (spec 7.5), and planning
/// from a confident learned expenditure ([usesLearnedExpenditure], adaptive
/// goals only) needs no activity level.
bool isOnboardingStepSkipped(
  OnboardingStep step, {
  required String goal,
  bool usesLearnedExpenditure = false,
  bool showDetailedStats = true,
}) =>
    switch (step) {
      OnboardingStep.goalWeight ||
      OnboardingStep.pace =>
        goal == MacroCalculatorService.GOAL_MAINTAIN,
      OnboardingStep.planStyle => !showDetailedStats || goal != MacroCalculatorService.GOAL_LOSE,
      OnboardingStep.activity => usesLearnedExpenditure,
      OnboardingStep.advanced => !showDetailedStats,
      _ => false,
    };

/// How far through the quiz [step] is, 0–1, for the progress bar. Skipped
/// steps still count, so the bar never jumps backwards when the goal changes.
double onboardingProgress(List<OnboardingStep> steps, OnboardingStep step) {
  final asked = steps.where((s) => s != OnboardingStep.summary).toList();
  final i = asked.indexOf(step);
  if (i < 0) return 1;
  return (i + 1) / asked.length;
}
