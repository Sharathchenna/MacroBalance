import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/widgets/onboarding/onboarding_selection_card.dart';
// Removed unused imports: unit_selector, numberpicker, intl, math
// Removed TooltipIcon import as it's no longer used here

class GoalPage extends StatelessWidget {
  final String currentGoal;
  // Removed properties related to goal weight, deficit, units, projected date
  final ValueChanged<String> onGoalChanged;

  const GoalPage({
    super.key,
    required this.currentGoal,
    required this.onGoalChanged,
  });

  // Removed imperial weight calculations

  @override
  Widget build(BuildContext context) {
    // Removed customColors variable as it's only used in removed sections
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Removed Projected Date Display

          Text(
            'What\'s your primary goal?',
            style: theme.textTheme.headlineSmall?.copyWith( // Use theme directly
              fontWeight: FontWeight.bold, // Color defaults to theme
            ),
          ),
          const SizedBox(height: 32),
          _buildGoalSelectionCard(
            context: context,
            goal: MacroCalculatorService.GOAL_LOSE,
            title: 'Lose Weight',
            icon: Icons.trending_down,
            description: 'Calorie deficit to lose body fat',
          ),
          const SizedBox(height: 16),
          _buildGoalSelectionCard(
            context: context,
            goal: MacroCalculatorService.GOAL_MAINTAIN,
            title: 'Maintain Weight',
            icon: Icons.balance,
            description: 'Balanced calories for weight maintenance',
          ),
          const SizedBox(height: 16),
          _buildGoalSelectionCard(
            context: context,
            goal: MacroCalculatorService.GOAL_GAIN,
            title: 'Gain Weight',
            icon: Icons.trending_up,
            description: 'Calorie surplus to build muscle',
          ),
          // Removed Target Weight Input section
          // Removed Deficit/Surplus Input section
        ],
      ),
    ); // End SingleChildScrollView
  } // End build

  // Helper to build goal selection cards (remains the same)
  Widget _buildGoalSelectionCard({
    required BuildContext context,
    required String goal,
    required String title,
    required IconData icon,
    required String description,
  }) {
    return OnboardingSelectionCard(
      isSelected: currentGoal == goal,
      onTap: () => onGoalChanged(goal),
      icon: icon,
      label: title,
      description: description,
    );
  } // End _buildGoalSelectionCard

  // Removed _buildProjectedDateCard helper
} // End GoalPage
