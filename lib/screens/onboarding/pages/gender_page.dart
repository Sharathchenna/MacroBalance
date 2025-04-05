import 'package:flutter/material.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/widgets/onboarding/onboarding_selection_card.dart';

class GenderPage extends StatelessWidget {
  final String currentGender;
  final ValueChanged<String> onGenderSelected;

  const GenderPage({
    super.key,
    required this.currentGender,
    required this.onGenderSelected,
  });

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s your biological sex?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: customColors?.textPrimary ?? theme.textTheme.headlineSmall?.color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We use this for calculating your basal metabolic rate.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: customColors?.textPrimary ?? theme.textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              Expanded(
                child: OnboardingSelectionCard(
                  isSelected: currentGender == MacroCalculatorService.MALE,
                  onTap: () => onGenderSelected(MacroCalculatorService.MALE),
                  icon: Icons.male,
                  label: 'Male',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: OnboardingSelectionCard(
                  isSelected: currentGender == MacroCalculatorService.FEMALE,
                  onTap: () => onGenderSelected(MacroCalculatorService.FEMALE),
                  icon: Icons.female,
                  label: 'Female',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
