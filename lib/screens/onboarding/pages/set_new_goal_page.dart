import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/widgets/onboarding/unit_selector.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_sliders/sliders.dart';
import 'package:syncfusion_flutter_core/theme.dart';

class SetNewGoalPage extends StatelessWidget {
  final String currentGoal;
  final double currentWeightKg;
  final double goalWeightKg;
  final int deficit;
  final bool isMetricWeight;
  final DateTime? projectedDate;
  final double? targetCalories;
  final ValueChanged<double> onGoalWeightChanged;
  final ValueChanged<int> onDeficitChanged;
  final ValueChanged<bool> onWeightUnitChanged;

  const SetNewGoalPage({
    super.key,
    required this.currentGoal,
    required this.currentWeightKg,
    required this.goalWeightKg,
    required this.deficit,
    required this.isMetricWeight,
    this.projectedDate,
    this.targetCalories,
    required this.onGoalWeightChanged,
    required this.onDeficitChanged,
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
                                  'kcal',
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
                          color: Colors.black.withAlpha((0.05 * 255).round()),
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

                  // Goal Rate Section
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rate',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: customColors?.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isMetricWeight
                                ? (currentGoal ==
                                        MacroCalculatorService.GOAL_LOSE
                                    ? '-${(currentWeightKg - goalWeightKg).toStringAsFixed(1)} kg'
                                    : '+${(goalWeightKg - currentWeightKg).toStringAsFixed(1)} kg')
                                : (currentGoal ==
                                        MacroCalculatorService.GOAL_LOSE
                                    ? '-${(_imperialCurrentWeightLbs - _imperialGoalWeightLbs)} lbs'
                                    : '+${(_imperialGoalWeightLbs - _imperialCurrentWeightLbs)} lbs'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: currentGoal ==
                                      MacroCalculatorService.GOAL_LOSE
                                  ? Colors.red.shade400
                                  : Colors.green.shade500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                    decoration: BoxDecoration(
                      color: customColors?.cardBackground ?? theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.grey.withAlpha((0.1 * 255).round())),
                    ),
                    child: Column(
                      children: [
                        SfSliderTheme(
                          data: SfSliderThemeData(
                            activeTrackHeight: 8.0,
                            inactiveTrackHeight: 8.0,
                            thumbRadius: 14.0,
                            overlayRadius: 24.0,
                            activeTrackColor: customColors?.textPrimary ??
                                theme.colorScheme.primary,
                            inactiveTrackColor: (customColors?.textPrimary ??
                                    theme.colorScheme.primary)
                                .withAlpha((0.2 * 255).round()),
                            thumbColor: customColors?.textPrimary ??
                                theme.colorScheme.primary,
                            overlayColor: (customColors?.textPrimary ??
                                    theme.colorScheme.primary)
                                .withAlpha((0.12 * 255).round()),
                          ),
                          child: SfSlider(
                            min: 250.0,
                            max: 750.0,
                            value: deficit.toDouble(),
                            interval: 50,
                            stepSize: 50,
                            showLabels: false,
                            enableTooltip: false,
                            onChanged: (value) {
                              HapticFeedback.selectionClick();
                              onDeficitChanged(value.round());
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildRateDisplay(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
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

    return NumberPicker(
      value: value,
      minValue: minValue,
      maxValue: maxValue,
      onChanged: onChanged,
      selectedTextStyle: TextStyle(
        color: customColors?.textPrimary,
        fontSize: isLarge ? 32 : 28,
        fontWeight: FontWeight.bold,
      ),
      textStyle: TextStyle(
        color: (customColors?.textSecondary ?? Colors.grey)
            .withAlpha((0.5 * 255).round()),
        fontSize: isLarge ? 20 : 18,
      ),
    );
  }

  Map<String, double> _calculateRates() {
    const kcalPerKg = 7700.0;
    double weeklyKcalChange = deficit * 7.0;
    double weeklyKgChange = weeklyKcalChange / kcalPerKg;
    double weeklyBwChange = (weeklyKgChange / currentWeightKg) * 100;
    double monthlyKgChange = weeklyKgChange * 4.33;
    double monthlyBwChange = weeklyBwChange * 4.33;

    return {
      'weeklyKg': weeklyKgChange.abs(),
      'weeklyBw': weeklyBwChange.abs(),
      'monthlyKg': monthlyKgChange.abs(),
      'monthlyBw': monthlyBwChange.abs(),
    };
  }

  Widget _buildRateDisplay(BuildContext context) {
    final rates = _calculateRates();
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Weekly',
              style: TextStyle(
                color: customColors?.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                _RateValueBox(
                  value: rates['weeklyKg']?.toStringAsFixed(1) ?? '0.0',
                  unit: 'kg',
                ),
                const SizedBox(width: 8),
                _RateValueBox(
                  value: rates['weeklyBw']?.toStringAsFixed(1) ?? '0.0',
                  unit: '% BW',
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Monthly',
              style: TextStyle(
                color: customColors?.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                _RateValueBox(
                  value: rates['monthlyKg']?.toStringAsFixed(1) ?? '0.0',
                  unit: 'kg',
                ),
                const SizedBox(width: 8),
                _RateValueBox(
                  value: rates['monthlyBw']?.toStringAsFixed(1) ?? '0.0',
                  unit: '% BW',
                ),
              ],
            ),
          ],
        ),
      ],
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
            color: Colors.black.withAlpha((0.05 * 255).round()),
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

class _RateValueBox extends StatelessWidget {
  final String value;
  final String unit;

  const _RateValueBox({required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = Theme.of(context).extension<CustomColors>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (customColors?.textPrimary ?? theme.colorScheme.primary)
            .withAlpha((0.1 * 255).round()),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: customColors?.textPrimary ?? theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            unit,
            style: TextStyle(
              color: customColors?.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
