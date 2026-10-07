import 'dart:math' show max;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/widgets/onboarding/unit_selector.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:intl/intl.dart';

/// One pace on offer: its target after the safety limits, and about how many
/// weeks it takes to reach the goal weight (null if it doesn't get there).
class PaceChoice {
  const PaceChoice({required this.target, this.weeks});

  final PaceTarget target;
  final double? weeks;
}

/// Plain words for why a pace was slowed down, or null if it wasn't.
String? paceLimitExplanation(PaceTarget target) {
  final limit = target.limitHit;
  if (limit == null) return null;
  final pace = '${_pctText(target.effectivePacePct)}%/week';
  final cals = NumberFormat.decimalPattern().format(target.cals.round());
  return switch (limit) {
    SafetyLimit.floor => target.effectivePacePct < 0.05
        ? 'We\'ve kept your target at $cals cals, our minimum, so you may lose little weight at this activity level.'
        : 'We\'ve set your pace to $pace so your target doesn\'t go below $cals cals, our minimum.',
    SafetyLimit.maxDeficit =>
      'We\'ve set your pace to $pace so you eat no more than ${(kMaxDeficitFrac * 100).round()}% below what you burn.',
    SafetyLimit.maxLossPace =>
      'We\'ve set your pace to $pace, the fastest we recommend for losing weight.',
    SafetyLimit.maxSurplus =>
      'We\'ve set your pace to $pace so you eat no more than ${(kMaxSurplusFrac * 100).round()}% above what you burn.',
    SafetyLimit.maxGainPace =>
      'We\'ve set your pace to $pace, the fastest we recommend for gaining weight.',
    SafetyLimit.checkinStep => 'We\'ve changed your target gradually, to $cals cals.',
  };
}

/// 0.25 → "0.25", 0.5 → "0.5", 0.42 → "0.4", 1.0 → "1".
String _pctText(double pct) {
  final rounded = pct >= 0.2 ? (pct * 10).round() / 10 : (pct * 100).round() / 100;
  final options = [...kLosePaceOptions, ...kGainPaceOptions];
  final value = options.contains(pct) ? pct : rounded;
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

class SetNewGoalPage extends StatelessWidget {
  final String currentGoal;
  final double currentWeightKg;
  final double goalWeightKg;
  /// The paces on offer for the goal, slowest first.
  final List<PaceChoice> paceChoices;
  /// The chosen pace, % of body weight a week.
  final double pacePct;
  final double recommendedPacePct;
  final bool isMetricWeight;
  final DateTime? projectedDate;
  final double? targetCalories;
  final ValueChanged<double> onGoalWeightChanged;
  final ValueChanged<double> onPaceChanged;
  final ValueChanged<bool> onWeightUnitChanged;

  const SetNewGoalPage({
    super.key,
    required this.currentGoal,
    required this.currentWeightKg,
    required this.goalWeightKg,
    required this.paceChoices,
    required this.pacePct,
    required this.recommendedPacePct,
    required this.isMetricWeight,
    this.projectedDate,
    this.targetCalories,
    required this.onGoalWeightChanged,
    required this.onPaceChanged,
    required this.onWeightUnitChanged,
  });

  int get _imperialGoalWeightLbs => (goalWeightKg * 2.20462).round();
  int get _imperialCurrentWeightLbs => (currentWeightKg * 2.20462).round();

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    if (currentGoal == MacroCalculatorService.GOAL_MAINTAIN) {
      return Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.balance,
              size: 48,
              color: customColors?.accentPrimary ?? theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Maintain Current Weight',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: customColors?.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Your calories will be set to maintain your current weight.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: customColors?.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Container(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Top Cards with animated transitions
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 300),
                    tween: Tween<double>(begin: 0, end: 1),
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(0, 20 * (1 - value)),
                        child: Opacity(
                          opacity: value,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  context,
                                  '${targetCalories?.round() ?? '...'}',
                                  'Daily Budget',
                                  'cals',
                                  Icons.local_fire_department_rounded,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoCard(
                                  context,
                                  projectedDate != null
                                      ? DateFormat('MMM dd')
                                          .format(projectedDate!)
                                      : 'N/A',
                                  'Target Date',
                                  projectedDate != null
                                      ? DateFormat('yyyy')
                                          .format(projectedDate!)
                                      : '',
                                  Icons.calendar_today_rounded,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Target Weight Section
                  Row(
                    children: [
                      Text(
                        'Target Weight',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: customColors?.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      UnitSelector(
                        isMetric: isMetricWeight,
                        metricUnit: 'kg',
                        imperialUnit: 'lbs',
                        onChanged: (isMetricSelected) {
                          HapticFeedback.mediumImpact();
                          onWeightUnitChanged(isMetricSelected);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        vertical: 16, horizontal: 20),
                    decoration: BoxDecoration(
                      color: customColors?.cardBackground ?? theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isMetricWeight) ...[
                          _buildNumberWheel(
                            context,
                            value: goalWeightKg.floor(),
                            minValue:
                                currentGoal == MacroCalculatorService.GOAL_LOSE
                                    ? 40
                                    : (currentWeightKg.floor() + 1),
                            maxValue:
                                currentGoal == MacroCalculatorService.GOAL_LOSE
                                    ? (currentWeightKg.floor() - 1)
                                    : 150,
                            onChanged: (value) {
                              HapticFeedback.mediumImpact();
                              onGoalWeightChanged(value +
                                  (goalWeightKg - goalWeightKg.floor()));
                            },
                            isLarge: true,
                          ),
                          Text(
                            '.',
                            style: TextStyle(
                              color: customColors?.textPrimary,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _buildNumberWheel(
                            context,
                            value: ((goalWeightKg - goalWeightKg.floor()) * 10)
                                .round()
                                .clamp(0, 9),
                            minValue: 0,
                            maxValue: 9,
                            onChanged: (value) {
                              HapticFeedback.selectionClick();
                              onGoalWeightChanged(
                                  goalWeightKg.floor() + (value / 10));
                            },
                            isLarge: false,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'kg',
                            style: TextStyle(
                              color: customColors?.textSecondary,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else ...[
                          _buildNumberWheel(
                            context,
                            value: _imperialGoalWeightLbs,
                            minValue:
                                currentGoal == MacroCalculatorService.GOAL_LOSE
                                    ? 88
                                    : (_imperialCurrentWeightLbs + 1),
                            maxValue:
                                currentGoal == MacroCalculatorService.GOAL_LOSE
                                    ? (_imperialCurrentWeightLbs - 1)
                                    : 330,
                            onChanged: (value) {
                              HapticFeedback.mediumImpact();
                              onGoalWeightChanged(value / 2.20462);
                            },
                            isLarge: true,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'lbs',
                            style: TextStyle(
                              color: customColors?.textSecondary,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Pace Section
                  Text(
                    'Pace',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: customColors?.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'How fast to ${currentGoal == MacroCalculatorService.GOAL_LOSE ? 'lose' : 'gain'} '
                    '${isMetricWeight ? (goalWeightKg - currentWeightKg).abs().toStringAsFixed(1) : (_imperialGoalWeightLbs - _imperialCurrentWeightLbs).abs()} '
                    '${isMetricWeight ? 'kg' : 'lbs'}, as a share of your body weight each week',
                    style: TextStyle(
                      fontSize: 14,
                      color: customColors?.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: customColors?.cardBackground ?? theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Column(
                      children: [
                        for (var i = 0; i < paceChoices.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: 52,
                              color: Colors.grey.withValues(alpha: 0.15),
                            ),
                          _PaceOptionTile(
                            choice: paceChoices[i],
                            selected: paceChoices[i].target.pacePct == pacePct,
                            recommended:
                                paceChoices[i].target.pacePct == recommendedPacePct,
                            weeklyChange: _weeklyChangeText(paceChoices[i].target),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onPaceChanged(paceChoices[i].target.pacePct);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_selectedExplanation != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: customColors?.textSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _selectedExplanation!,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: customColors?.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String? get _selectedExplanation {
    for (final choice in paceChoices) {
      if (choice.target.pacePct == pacePct) {
        return paceLimitExplanation(choice.target);
      }
    }
    return null;
  }

  /// The weight a pace really moves a week, in the user's unit.
  String _weeklyChangeText(PaceTarget target) {
    final kg = target.effectivePacePct / 100 * currentWeightKg;
    return isMetricWeight
        ? '${kg.toStringAsFixed(2)} kg a week'
        : '${(kg * 2.20462).toStringAsFixed(1)} lbs a week';
  }

  Widget _buildNumberWheel(
    BuildContext context, {
    required int value,
    required int minValue,
    required int maxValue,
    required ValueChanged<int> onChanged,
    required bool isLarge,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();

    // Rounding (kg to whole lbs) can put a valid goal just outside the wheel's
    // range, which NumberPicker asserts against; show the nearest value.
    return NumberPicker(
      value: value.clamp(minValue, max(minValue, maxValue)),
      minValue: minValue,
      maxValue: maxValue,
      onChanged: onChanged,
      selectedTextStyle: TextStyle(
        color: customColors?.textPrimary,
        fontSize: isLarge ? 32 : 28,
        fontWeight: FontWeight.bold,
      ),
      textStyle: TextStyle(
        color: (customColors?.textSecondary ?? Colors.grey).withOpacity(0.5),
        fontSize: isLarge ? 20 : 18,
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String value,
    String label,
    String unit,
    IconData icon,
  ) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: customColors?.cardBackground ?? theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon(
          //   icon,
          //   color: customColors?.accentPrimary ?? theme.colorScheme.primary,
          //   size: 24,
          // ),
          // const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: customColors?.textPrimary,
                  ),
                ),
                const TextSpan(text: ' '),
                TextSpan(
                  text: unit,
                  style: TextStyle(
                    fontSize: 14,
                    color: customColors?.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: customColors?.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaceOptionTile extends StatelessWidget {
  final PaceChoice choice;
  final bool selected;
  final bool recommended;
  final String weeklyChange;
  final VoidCallback onTap;

  const _PaceOptionTile({
    required this.choice,
    required this.selected,
    required this.recommended,
    required this.weeklyChange,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();
    final accent = customColors?.accentPrimary ?? theme.colorScheme.primary;
    final target = choice.target;
    final weeks = choice.weeks;
    final details = [
      target.clamped
          ? 'Capped at ${_pctText(target.effectivePacePct)}%'
          : weeklyChange,
      if (weeks != null) 'about ${max(1, weeks.round())} weeks',
    ].join(' · ');

    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 22,
                color: selected
                    ? accent
                    : (customColors?.textSecondary ?? Colors.grey).withValues(alpha: 0.6),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${_pctText(target.pacePct)}% a week',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: customColors?.textPrimary,
                          ),
                        ),
                        if (recommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Recommended',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details,
                      style: TextStyle(
                        fontSize: 13,
                        color: customColors?.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: NumberFormat.decimalPattern()
                          .format(target.cals.round()),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: customColors?.textPrimary,
                      ),
                    ),
                    TextSpan(
                      text: ' cals',
                      style: TextStyle(
                        fontSize: 13,
                        color: customColors?.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
