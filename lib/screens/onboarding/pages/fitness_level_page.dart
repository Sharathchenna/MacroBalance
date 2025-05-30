import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/widgets/onboarding/onboarding_selection_card.dart';
import 'package:macrotracker/theme/app_theme.dart';

class FitnessLevelPage extends StatelessWidget {
  final String currentFitnessLevel;
  final int yearsOfExperience;
  final List<String> previousExerciseTypes;
  final ValueChanged<String> onFitnessLevelChanged;
  final ValueChanged<int> onYearsOfExperienceChanged;
  final ValueChanged<List<String>> onPreviousExerciseTypesChanged;

  const FitnessLevelPage({
    super.key,
    required this.currentFitnessLevel,
    required this.yearsOfExperience,
    required this.previousExerciseTypes,
    required this.onFitnessLevelChanged,
    required this.onYearsOfExperienceChanged,
    required this.onPreviousExerciseTypesChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = Theme.of(context).extension<CustomColors>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What\'s your fitness level?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us create workouts that match your current abilities',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: customColors?.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Fitness Level Selection
          OnboardingSelectionCard(
            isSelected: currentFitnessLevel == 'beginner',
            onTap: () {
              HapticFeedback.lightImpact();
              onFitnessLevelChanged('beginner');
            },
            icon: Icons.directions_walk,
            label: 'Beginner',
            description: 'New to exercise or getting back into it',
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            isSelected: currentFitnessLevel == 'intermediate',
            onTap: () {
              HapticFeedback.lightImpact();
              onFitnessLevelChanged('intermediate');
            },
            icon: Icons.directions_run,
            label: 'Intermediate',
            description: 'Regular exercise routine for 6+ months',
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            isSelected: currentFitnessLevel == 'advanced',
            onTap: () {
              HapticFeedback.lightImpact();
              onFitnessLevelChanged('advanced');
            },
            icon: Icons.fitness_center,
            label: 'Advanced',
            description: 'Consistent training for 2+ years',
          ),

          const SizedBox(height: 40),

          // Years of Experience
          Text(
            'Years of exercise experience',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: customColors?.cardBackground ?? Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: PremiumColors.slate300,
                width: 1.5,
              ),
            ),
            child: Slider(
              value: yearsOfExperience.toDouble(),
              min: 0,
              max: 20,
              divisions: 20,
              activeColor: PremiumColors.slate900,
              inactiveColor: PremiumColors.slate300,
              label: yearsOfExperience == 0
                  ? 'Just starting'
                  : yearsOfExperience >= 20
                      ? '20+ years'
                      : '$yearsOfExperience ${yearsOfExperience == 1 ? 'year' : 'years'}',
              onChanged: (value) {
                HapticFeedback.selectionClick();
                onYearsOfExperienceChanged(value.round());
              },
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Just starting',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: customColors?.textSecondary,
                  ),
                ),
                Text(
                  '20+ years',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: customColors?.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Previous Exercise Types
          Text(
            'What types of exercise have you done?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select all that apply (optional)',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: customColors?.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Exercise Type Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.5,
            children: [
              _buildExerciseTypeChip('Weight Training', Icons.fitness_center),
              _buildExerciseTypeChip('Running', Icons.directions_run),
              _buildExerciseTypeChip('Yoga', Icons.self_improvement),
              _buildExerciseTypeChip('Swimming', Icons.pool),
              _buildExerciseTypeChip('Cycling', Icons.directions_bike),
              _buildExerciseTypeChip('Sports', Icons.sports_tennis),
              _buildExerciseTypeChip('Dancing', Icons.music_note),
              _buildExerciseTypeChip('Hiking', Icons.terrain),
              _buildExerciseTypeChip('Martial Arts', Icons.sports_kabaddi),
              _buildExerciseTypeChip('CrossFit', Icons.fitness_center),
              _buildExerciseTypeChip('Pilates', Icons.accessibility_new),
              _buildExerciseTypeChip('Rock Climbing', Icons.landscape),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseTypeChip(String type, IconData icon) {
    final isSelected = previousExerciseTypes.contains(type);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        final updatedTypes = List<String>.from(previousExerciseTypes);
        if (isSelected) {
          updatedTypes.remove(type);
        } else {
          updatedTypes.add(type);
        }
        onPreviousExerciseTypesChanged(updatedTypes);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected ? PremiumColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? PremiumColors.slate900 : PremiumColors.slate300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: PremiumColors.slate900.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : PremiumColors.slate600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  type,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : PremiumColors.slate700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
