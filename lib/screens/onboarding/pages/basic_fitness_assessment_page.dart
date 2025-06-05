import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/widgets/onboarding/onboarding_selection_card.dart';
import 'package:macrotracker/theme/app_theme.dart';

class BasicFitnessAssessmentPage extends StatefulWidget {
  final String currentFitnessLevel;
  final ValueChanged<String> onFitnessLevelChanged;

  const BasicFitnessAssessmentPage({
    super.key,
    required this.currentFitnessLevel,
    required this.onFitnessLevelChanged,
  });

  @override
  State<BasicFitnessAssessmentPage> createState() =>
      _BasicFitnessAssessmentPageState();
}

class _BasicFitnessAssessmentPageState
    extends State<BasicFitnessAssessmentPage> {
  @override
  void initState() {
    super.initState();
    // Set default selection to beginner if no selection has been made
    if (widget.currentFitnessLevel.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onFitnessLevelChanged('beginner');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = Theme.of(context).extension<CustomColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s your fitness level?',
            style: PremiumTypography.h2.copyWith(
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us create workouts that match your current abilities',
            style: PremiumTypography.bodyMedium.copyWith(
              color: customColors?.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Fitness Level Selection
          OnboardingSelectionCard(
            isSelected: widget.currentFitnessLevel == 'beginner',
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onFitnessLevelChanged('beginner');
            },
            icon: Icons.directions_walk,
            label: 'Beginner',
            description: 'New to exercise or getting back into it',
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            isSelected: widget.currentFitnessLevel == 'intermediate',
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onFitnessLevelChanged('intermediate');
            },
            icon: Icons.directions_run,
            label: 'Intermediate',
            description: 'Regular exercise routine for 6+ months',
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            isSelected: widget.currentFitnessLevel == 'advanced',
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onFitnessLevelChanged('advanced');
            },
            icon: Icons.fitness_center,
            label: 'Advanced',
            description: 'Consistent training for 2+ years',
          ),
        ],
      ),
    );
  }
}
