import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/services/macro_calculator_service.dart'; // For gender constants
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/widgets/onboarding/tooltip_icon.dart';

class AdvancedSettingsPage extends StatelessWidget {
  final bool isAthlete;
  final bool showBodyFatInput;
  final double bodyFatPercentage;
  final double proteinRatio;
  final double fatRatio;
  final String gender; // Needed for body fat range display
  final ValueChanged<bool> onAthleteChanged;
  final ValueChanged<bool> onShowBodyFatChanged;
  final ValueChanged<double> onBodyFatChanged;
  final ValueChanged<double> onProteinRatioChanged;
  final ValueChanged<double> onFatRatioChanged;

  const AdvancedSettingsPage({
    super.key,
    required this.isAthlete,
    required this.showBodyFatInput,
    required this.bodyFatPercentage,
    required this.proteinRatio,
    required this.fatRatio,
    required this.gender,
    required this.onAthleteChanged,
    required this.onShowBodyFatChanged,
    required this.onBodyFatChanged,
    required this.onProteinRatioChanged,
    required this.onFatRatioChanged,
  });

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Advanced Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: customColors?.textPrimary ?? theme.textTheme.headlineSmall?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fine-tune your macro distribution and calculation details',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: customColors?.textPrimary ?? theme.textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 32),

          // Athletic status selection
          _buildSectionHeader(context, 'Are you an athlete?', 'Select "Yes" if you regularly engage in intense sports or training'),
          const SizedBox(height: 16),
          _buildToggleContainer(context, [
            _buildToggleOption(context: context, label: 'No', isSelected: !isAthlete, onTap: () => onAthleteChanged(false)),
            _buildToggleOption(context: context, label: 'Yes', isSelected: isAthlete, onTap: () => onAthleteChanged(true)),
          ]),

          // Body Fat Percentage Input (Optional)
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Body Fat Percentage (Optional)', 'If you know your body fat percentage, enter it here for more accurate calculations'),
          const SizedBox(height: 8),
          _buildToggleContainer(context, [
             _buildToggleOption(context: context, label: 'Skip', isSelected: !showBodyFatInput, onTap: () => onShowBodyFatChanged(false)),
             _buildToggleOption(context: context, label: 'Enter', isSelected: showBodyFatInput, onTap: () => onShowBodyFatChanged(true)),
          ]),

          // Body fat percentage slider if selected
          if (showBodyFatInput) ...[
            const SizedBox(height: 16),
            _buildSliderContainer(
              context: context,
              label: '${bodyFatPercentage.round()}%',
              value: bodyFatPercentage,
              min: 5, max: 50, divisions: 45,
              onChanged: onBodyFatChanged,
              onDecrement: () { if (bodyFatPercentage > 5) onBodyFatChanged(bodyFatPercentage - 1); },
              onIncrement: () { if (bodyFatPercentage < 50) onBodyFatChanged(bodyFatPercentage + 1); },
              rangeText: gender == MacroCalculatorService.MALE ? 'Athletic: 6-13% | Healthy: 14-24%' : 'Athletic: 14-20% | Healthy: 21-31%',
            ),
          ],

          const SizedBox(height: 32),

          // Protein ratio slider
          _buildSectionHeader(context, 'Protein (g per kg of bodyweight)', 'Higher protein intake supports muscle maintenance and growth'),
          const SizedBox(height: 8),
           _buildSliderContainer(
              context: context,
              label: '${proteinRatio.toStringAsFixed(1)} g/kg',
              value: proteinRatio,
              min: 1.2, max: 2.4, divisions: 12, // 0.1 increments
              onChanged: onProteinRatioChanged,
              onDecrement: () { if (proteinRatio > 1.2) onProteinRatioChanged(double.parse((proteinRatio - 0.1).toStringAsFixed(1))); },
              onIncrement: () { if (proteinRatio < 2.4) onProteinRatioChanged(double.parse((proteinRatio + 0.1).toStringAsFixed(1))); },
              rangeText: 'Recommended: 1.6-2.2 g/kg',
            ),

          const SizedBox(height: 24),

          // Fat ratio slider
          _buildSectionHeader(context, 'Fat (% of total calories)', 'Fat is essential for hormone production and vitamin absorption'),
          const SizedBox(height: 8),
           _buildSliderContainer(
              context: context,
              label: '${(fatRatio * 100).round()}%',
              value: fatRatio,
              min: 0.20, max: 0.40, divisions: 20, // 0.01 increments
              onChanged: onFatRatioChanged,
              onDecrement: () { if (fatRatio > 0.20) onFatRatioChanged(double.parse((fatRatio - 0.01).toStringAsFixed(2))); },
              onIncrement: () { if (fatRatio < 0.40) onFatRatioChanged(double.parse((fatRatio + 0.01).toStringAsFixed(2))); },
              rangeText: 'Recommended: 20-35%',
            ),
        ],
      ),
    );
  }

  // Helper for section headers with tooltips
  Widget _buildSectionHeader(BuildContext context, String title, String tooltipMessage) {
     final customColors = Theme.of(context).extension<CustomColors>();
     final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: customColors?.textPrimary ?? theme.textTheme.titleMedium?.color,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        TooltipIcon(message: tooltipMessage),
      ],
    );
  }

  // Helper for toggle button containers
  Widget _buildToggleContainer(BuildContext context, List<Widget> children) {
     final customColors = Theme.of(context).extension<CustomColors>();
     final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: customColors?.cardBackground ?? theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(children: children),
    );
  }

  // Helper for toggle options
  Widget _buildToggleOption({ required BuildContext context, required String label, required bool isSelected, required VoidCallback onTap }) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);
    return Expanded( // Ensure options take equal space
      child: GestureDetector(
        onTap: () { HapticFeedback.lightImpact(); onTap(); },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(8)), // Simplified decoration
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? (customColors?.textPrimary ?? theme.colorScheme.primary) : Colors.transparent,
                  border: Border.all(color: isSelected ? (customColors?.textPrimary ?? theme.colorScheme.primary) : Colors.grey.withOpacity(0.5), width: 2),
                ),
                child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
              ),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 15, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: customColors?.textPrimary ?? theme.textTheme.bodyLarge?.color)),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for slider containers
  Widget _buildSliderContainer({
    required BuildContext context,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
    String? rangeText,
  }) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);
    final Color primaryColor = customColors?.textPrimary ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customColors?.cardBackground ?? theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: onDecrement, icon: Icon(Icons.remove_circle_outline, color: value > min ? primaryColor : Colors.grey.withOpacity(0.3))),
              Text(label, style: theme.textTheme.headlineSmall?.copyWith(color: customColors?.textPrimary ?? theme.textTheme.headlineSmall?.color, fontWeight: FontWeight.bold)),
              IconButton(onPressed: onIncrement, icon: Icon(Icons.add_circle_outline, color: value < max ? primaryColor : Colors.grey.withOpacity(0.3))),
            ],
          ),
          Slider(
            value: value, min: min, max: max, divisions: divisions,
            label: label, // Use the formatted label
            onChanged: (newValue) { HapticFeedback.lightImpact(); onChanged(newValue); },
            activeColor: primaryColor,
            inactiveColor: primaryColor.withOpacity(0.3),
          ),
          if (rangeText != null)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                rangeText,
                style: theme.textTheme.bodySmall?.copyWith(color: customColors?.textSecondary ?? theme.textTheme.bodySmall?.color),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
