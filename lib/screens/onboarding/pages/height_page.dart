import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/widgets/onboarding/tooltip_icon.dart';
import 'package:macrotracker/widgets/onboarding/unit_selector.dart';
import 'package:numberpicker/numberpicker.dart';
import 'dart:math'; // For min/max

class HeightPage extends StatelessWidget {
  final double currentHeightCm;
  final bool isMetric;
  final ValueChanged<double> onHeightChanged;
  final ValueChanged<bool> onUnitChanged;

  const HeightPage({
    super.key,
    required this.currentHeightCm,
    required this.isMetric,
    required this.onHeightChanged,
    required this.onUnitChanged,
  });

  // Calculate imperial height locally for the picker
  int get _imperialHeightFeet {
    double totalInches = currentHeightCm / 2.54;
    return (totalInches / 12).floor();
  }

  int get _imperialHeightInches {
    double totalInches = currentHeightCm / 2.54;
    return (totalInches % 12).round();
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'What\'s your height?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: customColors?.textPrimary ??
                  theme.textTheme.headlineSmall?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Used to calculate your BMI and BMR',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: customColors?.textSecondary ??
                      theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(width: 4),
              const TooltipIcon(
                  message:
                      'Your height is used to calculate your BMI and base metabolic rate'),
            ],
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
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
              children: [
                UnitSelector(
                  isMetric: isMetric,
                  metricUnit: 'cm',
                  imperialUnit: 'ft',
                  onChanged: (isMetricSelected) {
                    HapticFeedback.heavyImpact();
                    onUnitChanged(isMetricSelected);
                  },
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isMetric) ...[
                      // Metric (cm) picker
                      NumberPicker(
                        value: currentHeightCm.round(),
                        minValue: 90,
                        maxValue: 220,
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                          onHeightChanged(value.toDouble());
                        },
                        selectedTextStyle: TextStyle(
                            color: customColors?.textPrimary ??
                                theme.textTheme.bodyLarge?.color,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                        textStyle: TextStyle(
                            color: customColors?.textSecondary ??
                                theme.textTheme.bodyMedium?.color,
                            fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Text('cm',
                          style: TextStyle(
                              color: customColors?.textPrimary ??
                                  theme.textTheme.bodyLarge?.color,
                              fontSize: 20,
                              fontWeight: FontWeight.w500)),
                    ] else ...[
                      // Imperial (ft & in) pickers
                      NumberPicker(
                        value: _imperialHeightFeet,
                        minValue: 3,
                        maxValue: 7,
                        onChanged: (feet) {
                          HapticFeedback.mediumImpact();
                          onHeightChanged(
                              (feet * 30.48) + (_imperialHeightInches * 2.54));
                        },
                        selectedTextStyle: TextStyle(
                            color: customColors?.textPrimary ??
                                theme.textTheme.bodyLarge?.color,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                        textStyle: TextStyle(
                            color: customColors?.textSecondary ??
                                theme.textTheme.bodyMedium?.color,
                            fontSize: 20),
                      ),
                      Text('ft',
                          style: TextStyle(
                              color: customColors?.textPrimary ??
                                  theme.textTheme.bodyLarge?.color,
                              fontSize: 20,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(width: 16),
                      NumberPicker(
                        value: _imperialHeightInches,
                        minValue: 0,
                        maxValue: 11,
                        onChanged: (inches) {
                          HapticFeedback.lightImpact();
                          onHeightChanged(
                              (_imperialHeightFeet * 30.48) + (inches * 2.54));
                        },
                        selectedTextStyle: TextStyle(
                            color: customColors?.textPrimary ??
                                theme.textTheme.bodyLarge?.color,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                        textStyle: TextStyle(
                            color: customColors?.textSecondary ??
                                theme.textTheme.bodyMedium?.color,
                            fontSize: 20),
                      ),
                      const SizedBox(width: 8),
                      Text('in',
                          style: TextStyle(
                              color: customColors?.textPrimary ??
                                  theme.textTheme.bodyLarge?.color,
                              fontSize: 20,
                              fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
