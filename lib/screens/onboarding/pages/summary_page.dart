import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/theme/typography.dart';
import 'package:macrotracker/widgets/plan_style_choice.dart';
import 'package:macrotracker/widgets/targets_change.dart';
import '../onboarding_steps.dart';

class SummaryPage extends StatelessWidget {
  final String gender;
  final double weightKg;
  final double heightCm;
  final int age;
  final int activityLevel;
  final String goal;
  final double pacePct; // % of body weight a week
  final double proteinRatio;
  final double fatRatio;
  final double goalWeightKg;
  final double? bodyFatPercentage; // only when the user entered one
  final bool adaptiveGoals;
  final void Function(OnboardingStep step) onEdit; // Jumps back to a step to edit it
  /// The steps that can be jumped to; rows for other steps are read-only.
  /// Null means all of them.
  final Set<OnboardingStep>? editableSteps;

  /// Recalculating: the targets now and what these answers give, shown old →
  /// new at the top. Null for new users.
  final GoalTargets? currentTargets;
  final GoalTargets? newTargets;

  /// The learned expenditure the new targets come from instead of the
  /// activity level (spec 7.6); null when they come from the formula.
  final double? learnedTdee;

  /// Lose goals: the plan style, and how a phased plan unfolds ("3 loss
  /// phases + 2 breaks · about 34 weeks").
  final PlanStyle? planStyle;
  final String? planLine;

  const SummaryPage({
    super.key,
    required this.gender,
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.activityLevel,
    required this.goal,
    required this.pacePct,
    required this.proteinRatio,
    required this.fatRatio,
    required this.goalWeightKg,
    this.bodyFatPercentage,
    this.adaptiveGoals = true,
    required this.onEdit,
    this.editableSteps,
    this.currentTargets,
    this.newTargets,
    this.learnedTdee,
    this.planStyle,
    this.planLine,
  });

  /// The line under the targets when activity wasn't asked (plan 10.4).
  static String learnedExpenditureLine(double tdee) =>
      'Using your learned expenditure (${NumberFormat('#,###').format(tdee.round())} cals) '
      'instead of an activity estimate.';

  String _getActivityLevelText() {
    switch (activityLevel) {
      case MacroCalculatorService.SEDENTARY:
        return 'Sedentary';
      case MacroCalculatorService.LIGHTLY_ACTIVE:
        return 'Lightly Active';
      case MacroCalculatorService.MODERATELY_ACTIVE:
        return 'Moderately Active';
      case MacroCalculatorService.VERY_ACTIVE:
        return 'Very Active';
      case MacroCalculatorService.EXTRA_ACTIVE:
        return 'Extra Active';
      default:
        return 'Unknown';
    }
  }

  String _getGoalText() {
    switch (goal) {
      case MacroCalculatorService.GOAL_LOSE:
        return 'Lose Weight';
      case MacroCalculatorService.GOAL_MAINTAIN:
        return 'Maintain Weight';
      case MacroCalculatorService.GOAL_GAIN:
        return 'Gain Weight';
      default:
        return 'Unknown';
    }
  }

  String _paceText() =>
      pacePct == pacePct.roundToDouble() ? pacePct.toStringAsFixed(0) : '$pacePct';

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    const genderPageIndex = OnboardingStep.gender;
    const weightPageIndex = OnboardingStep.weight;
    const heightPageIndex = OnboardingStep.height;
    const agePageIndex = OnboardingStep.age;
    const activityLevelPageIndex = OnboardingStep.activity;
    const goalPageIndex = OnboardingStep.goal;
    const advancedSettingsPageIndex = OnboardingStep.advanced;

    final personalInfoItems = [
      {
        'label': 'Gender',
        'value': gender == MacroCalculatorService.MALE ? 'Male' : 'Female',
        'page': genderPageIndex
      },
      {
        'label': 'Weight',
        'value': '${weightKg.toStringAsFixed(1)} kg',
        'page': weightPageIndex
      },
      {
        'label': 'Height',
        'value': '${heightCm.round()} cm',
        'page': heightPageIndex
      },
      {'label': 'Age', 'value': '$age years', 'page': agePageIndex},
      if (bodyFatPercentage != null)
        {
          'label': 'Body Fat %',
          'value': '${bodyFatPercentage!.round()}%',
          'page': advancedSettingsPageIndex
        },
    ];

    final List<Map<String, dynamic>> activityGoalsItems = [
      // The learned expenditure stands in for the activity level.
      if (learnedTdee == null)
        {
          'label': 'Activity Level',
          'value': _getActivityLevelText(),
          'page': activityLevelPageIndex
        },
      {'label': 'Goal', 'value': _getGoalText(), 'page': goalPageIndex},
    ];
    if (goal != MacroCalculatorService.GOAL_MAINTAIN) {
      activityGoalsItems.add({
        'label': 'Pace',
        'value': '${_paceText()}% a week',
        'page': OnboardingStep.setNewGoal
      });
      activityGoalsItems.add({
        'label': 'Target Weight',
        'value': '${goalWeightKg.toStringAsFixed(1)} kg',
        'page': goalPageIndex
      });
    }
    if (planStyle != null) {
      activityGoalsItems.add({
        'label': 'Plan',
        'value': PlanStyleCopy.title(planStyle!),
        'page': OnboardingStep.planStyle
      });
      if (planLine != null) {
        activityGoalsItems.add({
          'label': 'Plan Length',
          'value': planLine!,
          'page': OnboardingStep.planStyle
        });
      }
    }
    activityGoalsItems.add({
      'label': 'Targets',
      'value': adaptiveGoals ? 'Update weekly' : 'Fixed',
      'page': OnboardingStep.adaptive
    });

    final List<Map<String, dynamic>> macroSettingsItems = [
      {
        'label': 'Protein Ratio',
        'value': '${proteinRatio.toStringAsFixed(1)} g/kg',
        'page': advancedSettingsPageIndex
      },
      {
        'label': 'Fat Ratio',
        'value': '${(fatRatio * 100).round()}% of cals',
        'page': advancedSettingsPageIndex
      },
      {
        'label': 'Carbs',
        'value': 'Calculated',
        'page': advancedSettingsPageIndex
      }, // Indicate carbs are calculated
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: AppTypography.onboardingSubtitle.copyWith(
              color:
                  customColors?.textPrimary ?? theme.colorScheme.onBackground,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review your information before calculating.',
            style: AppTypography.onboardingBody.copyWith(
              color: customColors?.textSecondary ??
                  theme.colorScheme.onBackground.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          if (currentTargets != null && newTargets != null) ...[
            _buildTargetsSection(context),
            const SizedBox(height: 24),
          ],
          _buildSummarySection(context,
              title: 'Personal Information',
              icon: Icons.person,
              items: personalInfoItems),
          const SizedBox(height: 24),
          _buildSummarySection(context,
              title: 'Activity & Goals',
              icon: Icons.fitness_center,
              items: activityGoalsItems),
          const SizedBox(height: 24),
          _buildSummarySection(context,
              title: 'Macro Settings',
              icon: Icons.science,
              items: macroSettingsItems),
        ],
      ),
    );
  }

  /// "Your Targets": each target old → new, and where the new ones come from.
  Widget _buildTargetsSection(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);
    return _buildSection(
      context,
      title: 'Your Targets',
      icon: Icons.track_changes,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TargetsChangeRows(before: currentTargets!, after: newTargets!),
        ),
        if (learnedTdee != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1, right: 8),
                  child: Icon(Icons.autorenew_rounded,
                      size: 16, color: customColors?.textSecondary),
                ),
                Expanded(
                  child: Text(
                    learnedExpenditureLine(learnedTdee!),
                    style: AppTypography.caption.copyWith(
                      color: customColors?.textSecondary ??
                          theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildSummarySection(BuildContext context,
          {required String title,
          required IconData icon,
          required List<Map<String, dynamic>> items}) =>
      _buildSection(context, title: title, icon: icon, children: [
        ...items.where((item) => item.containsKey('value')).map((item) =>
            _buildSummaryItem(context,
                label: item['label'],
                value: item['value'].toString(),
                page: item['page'])),
      ]);

  /// A card with an icon header and [children] under a divider.
  Widget _buildSection(BuildContext context,
      {required String title,
      required IconData icon,
      required List<Widget> children}) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
          color: customColors?.cardBackground ?? theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 2))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8)),
                    child:
                        Icon(icon, color: theme.colorScheme.primary, size: 20)),
                const SizedBox(width: 12),
                Text(title,
                    style: AppTypography.h3.copyWith(
                      color: customColors?.textPrimary ??
                          theme.colorScheme.onBackground,
                    ))
              ])),
          Divider(height: 1, thickness: 1, color: Colors.grey.withOpacity(0.1)),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context,
      {required String label, required String value, required OnboardingStep page}) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);
    final editable = editableSteps?.contains(page) ?? true;
    return InkWell(
      onTap: !editable
          ? null
          : () {
              HapticFeedback.selectionClick();
              onEdit(page);
            },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: AppTypography.caption.copyWith(
                      color: customColors?.textSecondary ??
                          theme.colorScheme.onBackground.withOpacity(0.7),
                    )),
                const SizedBox(height: 4),
                Text(value,
                    style: AppTypography.body1.copyWith(
                      fontWeight: FontWeight.w600,
                      color: customColors?.textPrimary ??
                          theme.colorScheme.onBackground,
                    ))
              ])),
          if (editable) Icon(Icons.edit, size: 16, color: theme.colorScheme.primary)
        ]),
      ),
    );
  }
}
