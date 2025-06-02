import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/widgets/onboarding/tooltip_icon.dart';
import 'package:macrotracker/widgets/onboarding/unit_selector.dart';
import 'package:numberpicker/numberpicker.dart';

class WeightPage extends StatelessWidget {
  final double currentWeightKg;
  final bool isMetric;
  final ValueChanged<double> onWeightChanged;
  final ValueChanged<bool> onUnitChanged;

  const WeightPage({
    super.key,
    required this.currentWeightKg,
    required this.isMetric,
    required this.onWeightChanged,
    required this.onUnitChanged,
  });

  // Calculate imperial weight locally for the picker
  int get _imperialWeightLbs => (currentWeightKg * 2.20462).round();

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
            'What\'s your current weight?',
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
                'Used to calculate your daily caloric needs',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: customColors?.textSecondary ??
                      theme.textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(width: 4),
              const TooltipIcon(
                  message:
                      'Your current body weight is used to calculate your daily caloric needs'),
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
                  color: Colors.black.withAlpha((0.05 * 255).round()),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                UnitSelector(
                  isMetric: isMetric,
                  metricUnit: 'kg',
                  imperialUnit: 'lbs',
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
                      // Metric (kg) pickers
                      NumberPicker(
                        value: currentWeightKg.floor(),
                        minValue: 30,
                        maxValue: 200,
                        onChanged: (value) {
                          HapticFeedback.selectionClick();
                          onWeightChanged(value +
                              (currentWeightKg - currentWeightKg.floor()));
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
                      Text('.',
                          style: TextStyle(
                              color: customColors?.textPrimary ??
                                  theme.textTheme.bodyLarge?.color,
                              fontSize: 32,
                              fontWeight: FontWeight.bold)),
                      NumberPicker(
                        value:
                            ((currentWeightKg - currentWeightKg.floor()) * 10)
                                .round(),
                        minValue: 0,
                        maxValue: 9,
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                          onWeightChanged(
                              currentWeightKg.floor() + (value / 10));
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
                      Text('kg',
                          style: TextStyle(
                              color: customColors?.textPrimary ??
                                  theme.textTheme.bodyLarge?.color,
                              fontSize: 20,
                              fontWeight: FontWeight.w500)),
                    ] else ...[
                      // Imperial (lbs) picker
                      NumberPicker(
                        value: _imperialWeightLbs,
                        minValue: 66, // 30kg in lbs
                        maxValue: 441, // 200kg in lbs
                        onChanged: (value) {
                          HapticFeedback.lightImpact();
                          onWeightChanged(value / 2.20462);
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
                      Text('lbs',
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
