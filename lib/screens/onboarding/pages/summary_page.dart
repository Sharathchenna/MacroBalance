import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/ob_theme.dart';
import 'package:macrotracker/widgets/plan_style_choice.dart';
import '../onboarding_steps.dart';

/// "Your answers" (docs/onboarding-redesign/mock/Review.dc.html): every
/// answer in a row that jumps back to its step. When recalculating, the old
/// and new targets sit at the top.
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
  final DateTime? projectedDate;
  final bool isMetricWeight;
  final double? effectivePacePct;

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
    this.projectedDate,
    this.isMetricWeight = true,
    this.effectivePacePct,
  });

  /// The line under the targets when activity wasn't asked (plan 10.4).
  static String learnedExpenditureLine(double tdee) =>
      'Using your learned expenditure (${NumberFormat('#,###').format(tdee.round())} cals) '
      'instead of an activity estimate.';

  String _activityText() {
    switch (activityLevel) {
      case MacroCalculatorService.SEDENTARY:
        return 'Sedentary';
      case MacroCalculatorService.LIGHTLY_ACTIVE:
        return 'Lightly active';
      case MacroCalculatorService.MODERATELY_ACTIVE:
        return 'Moderately active';
      case MacroCalculatorService.VERY_ACTIVE:
        return 'Very active';
      case MacroCalculatorService.EXTRA_ACTIVE:
        return 'Extra active';
      default:
        return 'Unknown';
    }
  }

  String _goalText() {
    switch (goal) {
      case MacroCalculatorService.GOAL_LOSE:
        return 'Lose fat';
      case MacroCalculatorService.GOAL_MAINTAIN:
        return 'Maintain weight';
      case MacroCalculatorService.GOAL_GAIN:
        return 'Build muscle';
      default:
        return 'Unknown';
    }
  }

  String _weight(double kg) =>
      isMetricWeight ? '${kg.toStringAsFixed(1)} kg' : '${(kg * 2.20462).round()} lb';

  String _paceText() {
    final unit = isMetricWeight ? 'kg' : 'lb';
    final weekly = (effectivePacePct ?? pacePct) /
        100 *
        weightKg *
        (isMetricWeight ? 1 : 2.20462);
    return 'About ${weekly.toStringAsFixed(weekly < 0.1 ? 2 : 1)} $unit a week';
  }

  @override
  Widget build(BuildContext context) {
    final c = ObColors.of(context);
    final maintain = goal == MacroCalculatorService.GOAL_MAINTAIN;

    final plan = <_Row>[
      _Row('Goal', _goalText(), OnboardingStep.goal),
      if (!maintain) ...[
        _Row('Goal weight', _weight(goalWeightKg), OnboardingStep.goalWeight),
        _Row('Pace', _paceText(), OnboardingStep.pace),
      ],
      if (planStyle != null) ...[
        _Row('Plan', PlanStyleCopy.title(planStyle!), OnboardingStep.planStyle),
        if (planLine != null)
          _Row('Plan length', planLine!, OnboardingStep.planStyle),
      ],
      _Row('Targets', adaptiveGoals ? 'Adjust as I go' : 'Fixed', OnboardingStep.adaptive),
    ];
    final you = <_Row>[
      _Row('Sex', gender == MacroCalculatorService.MALE ? 'Male' : 'Female',
          OnboardingStep.aboutYou),
      _Row('Age', '$age', OnboardingStep.aboutYou),
      _Row('Height', '${heightCm.round()} cm', OnboardingStep.aboutYou),
      _Row('Weight', _weight(weightKg), OnboardingStep.weight),
      // The learned expenditure stands in for the activity level.
      if (learnedTdee == null)
        _Row('Activity', _activityText(), OnboardingStep.activity),
      if (bodyFatPercentage != null)
        _Row('Body fat', '${bodyFatPercentage!.round()}%', OnboardingStep.advanced),
    ];
    final macros = <_Row>[
      _Row('Protein', '${proteinRatio.toStringAsFixed(1)} g/kg', OnboardingStep.advanced),
      _Row('Fat', '${(fatRatio * 100).round()}% of cals', OnboardingStep.advanced),
    ];
    final detailed = context.watch<DetailedStatsProvider>().showDetailedStats;

    return ObPageBody(
      top: 18,
      children: [
        const ObHeader(
          title: 'Your answers',
          subtitle: 'Tap anything to change it. Your plan updates right away.',
        ),
        if (currentTargets != null && newTargets != null) ...[
          const SizedBox(height: 20),
          ObRise(index: 1, child: _targets(c)),
        ],
        const SizedBox(height: 20),
        _label(c, 'YOUR PLAN', c.leafText),
        ObRise(index: 1, child: _card(context, plan)),
        const SizedBox(height: 18),
        _label(c, 'ABOUT YOU', c.text2),
        ObRise(index: 2, child: _card(context, you)),
        if (detailed) ...[
          const SizedBox(height: 18),
          _label(c, 'MACROS', c.text2),
          ObRise(index: 3, child: _card(context, macros)),
        ],
      ],
    );
  }

  Widget _label(ObColors c, String text, Color color) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: ObText.eyebrow(color)),
      );

  /// Each target old → new, and where the new ones come from.
  Widget _targets(ObColors c) {
    final fmt = NumberFormat('#,###');
    Widget row(String label, double before, double after, String unit) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Expanded(child: Text(label, style: ObText.body(c.text2))),
              Text(
                '${fmt.format(before.round())} → ${fmt.format(after.round())} $unit',
                style: ObText.body(c.text, weight: FontWeight.w600),
              ),
            ],
          ),
        );
    final a = currentTargets!;
    final b = newTargets!;
    return ObCard(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('YOUR TARGETS', style: ObText.eyebrow(c.leafText)),
          const SizedBox(height: 6),
          row('Cals', a.calories, b.calories, 'cals'),
          row('Protein', a.protein, b.protein, 'g'),
          row('Carbs', a.carbs, b.carbs, 'g'),
          row('Fat', a.fat, b.fat, 'g'),
          if (learnedTdee != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: Icon(Icons.autorenew_rounded, size: 16, color: c.muted),
                ),
                Expanded(
                  child: Text(learnedExpenditureLine(learnedTdee!),
                      style: ObText.body(c.muted, size: 13)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _card(BuildContext context, List<_Row> rows) {
    final c = ObColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: c.surface,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++)
              _line(context, rows[i], last: i == rows.length - 1),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, _Row r, {required bool last}) {
    final c = ObColors.of(context);
    final editable = editableSteps?.contains(r.step) ?? true;
    return InkWell(
      onTap: !editable
          ? null
          : () {
              HapticFeedback.selectionClick();
              onEdit(r.step);
            },
      child: Container(
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.raised)),
        ),
        child: Row(
          children: [
            Text(r.label, style: ObText.body(c.text2)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(r.value,
                  textAlign: TextAlign.right,
                  style: ObText.body(c.text, weight: FontWeight.w600)),
            ),
            if (editable) ...[
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, size: 18, color: c.muted),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row {
  const _Row(this.label, this.value, this.step);
  final String label;
  final String value;
  final OnboardingStep step;
}
