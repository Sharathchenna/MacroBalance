import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/theme/typography.dart';

class SummaryPage extends StatelessWidget {
  final String gender;
  final double weightKg;
  final double heightCm;
  final int age;
  final int activityLevel;
  final String goal;
  final int deficit;
  final double proteinRatio;
  final double fatRatio;
  final double goalWeightKg;
  final bool isAthlete;
  final bool showBodyFatInput;
  final double bodyFatPercentage;
  final String fitnessLevel;
  final int yearsOfExperience;
  final List<String> previousExerciseTypes;
  final String workoutLocation;
  final List<String> availableEquipment;
  final bool hasGymAccess;
  final String workoutSpace;
  final int workoutsPerWeek;
  final int maxWorkoutDuration;
  final String preferredTimeOfDay;
  final List<String> preferredDays;
  final Function(int) onEdit;

  const SummaryPage({
    super.key,
    required this.gender,
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.activityLevel,
    required this.goal,
    required this.deficit,
    required this.proteinRatio,
    required this.fatRatio,
    required this.goalWeightKg,
    required this.isAthlete,
    required this.showBodyFatInput,
    required this.bodyFatPercentage,
    required this.fitnessLevel,
    required this.yearsOfExperience,
    required this.previousExerciseTypes,
    required this.workoutLocation,
    required this.availableEquipment,
    required this.hasGymAccess,
    required this.workoutSpace,
    required this.workoutsPerWeek,
    required this.maxWorkoutDuration,
    required this.preferredTimeOfDay,
    required this.preferredDays,
    required this.onEdit,
  });

  String _getActivityLevelText() {
    switch (activityLevel) {
      case MacroCalculatorService.SEDENTARY:
        return 'Sedentary';
      case MacroCalculatorService.LIGHTLY_ACTIVE:
        return 'Lightly Active';
      case MacroCalculatorService.MODERATELY_ACTIVE:
        return 'Moderately Active';
      case MacroCalculatorService.VERY_ACTIVE:
        return 'Very Active';
      case MacroCalculatorService.EXTRA_ACTIVE:
        return 'Extra Active';
      default:
        return 'Unknown';
    }
  }

  String _getGoalText() {
    switch (goal) {
      case MacroCalculatorService.GOAL_LOSE:
        return 'Lose Weight';
      case MacroCalculatorService.GOAL_MAINTAIN:
        return 'Maintain Weight';
      case MacroCalculatorService.GOAL_GAIN:
        return 'Gain Weight';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);

    // Define page indices based on the new structure
    const int genderPageIndex = 1;
    const int weightPageIndex = 2;
    const int heightPageIndex = 3;
    const int agePageIndex = 4;
    const int activityLevelPageIndex = 5;
    const int goalPageIndex = 6;
    const int advancedSettingsPageIndex = 7;
    const int fitnessLevelPageIndex = 8;
    const int equipmentPageIndex = 9;
    const int schedulePageIndex = 10;

    final personalInfoItems = [
      {
        'label': 'Gender',
        'value': gender == MacroCalculatorService.MALE ? 'Male' : 'Female',
        'page': genderPageIndex
      },
      {
        'label': 'Weight',
        'value': '${weightKg.toStringAsFixed(1)} kg',
        'page': weightPageIndex
      },
      {
        'label': 'Height',
        'value': '${heightCm.round()} cm',
        'page': heightPageIndex
      },
      {'label': 'Age', 'value': '$age years', 'page': agePageIndex},
      {
        'label': 'Athletic Status',
        'value': isAthlete ? 'Athlete' : 'Non-Athlete',
        'page': advancedSettingsPageIndex
      },
      if (showBodyFatInput)
        {
          'label': 'Body Fat %',
          'value': '${bodyFatPercentage.round()}%',
          'page': advancedSettingsPageIndex
        },
    ];

    final List<Map<String, dynamic>> activityGoalsItems = [
      {
        'label': 'Activity Level',
        'value': _getActivityLevelText(),
        'page': activityLevelPageIndex
      },
      {'label': 'Goal', 'value': _getGoalText(), 'page': goalPageIndex},
    ];
    if (goal != MacroCalculatorService.GOAL_MAINTAIN) {
      activityGoalsItems.add({
        'label': goal == MacroCalculatorService.GOAL_LOSE
            ? 'Calorie Deficit'
            : 'Calorie Surplus',
        'value': '$deficit calories/day',
        'page': goalPageIndex
      });
      activityGoalsItems.add({
        'label': 'Target Weight',
        'value': '${goalWeightKg.toStringAsFixed(1)} kg',
        'page': goalPageIndex
      });
    }

    final List<Map<String, dynamic>> macroSettingsItems = [
      {
        'label': 'Protein Ratio',
        'value': '${proteinRatio.toStringAsFixed(1)} g/kg',
        'page': advancedSettingsPageIndex
      },
      {
        'label': 'Fat Ratio',
        'value': '${(fatRatio * 100).round()}% of calories',
        'page': advancedSettingsPageIndex
      },
      // {
      //   'label': 'Carbs',
      //   'value': 'Calculated',
      //   'page': advancedSettingsPageIndex
      // }, // Indicate carbs are calculated
    ];

    final List<Map<String, dynamic>> fitnessItems = [
      {
        'label': 'Fitness Level',
        'value': fitnessLevel.isEmpty
            ? 'Not set'
            : fitnessLevel.substring(0, 1).toUpperCase() +
                fitnessLevel.substring(1),
        'page': fitnessLevelPageIndex
      },
      {
        'label': 'Experience',
        'value': yearsOfExperience == 0
            ? 'Just starting'
            : yearsOfExperience >= 20
                ? '20+ years'
                : '${yearsOfExperience} ${yearsOfExperience == 1 ? 'year' : 'years'}',
        'page': fitnessLevelPageIndex
      },
      if (previousExerciseTypes.isNotEmpty)
        {
          'label': 'Previous Exercise',
          'value': previousExerciseTypes.length > 2
              ? '${previousExerciseTypes.take(2).join(", ")}...'
              : previousExerciseTypes.join(", "),
          'page': fitnessLevelPageIndex
        },
    ];

    final List<Map<String, dynamic>> equipmentItems = [
      {
        'label': 'Workout Location',
        'value': workoutLocation.isEmpty
            ? 'Not set'
            : workoutLocation.substring(0, 1).toUpperCase() +
                workoutLocation.substring(1),
        'page': equipmentPageIndex
      },
      {
        'label': 'Available Space',
        'value': workoutSpace.isEmpty
            ? 'Not set'
            : workoutSpace.substring(0, 1).toUpperCase() +
                workoutSpace.substring(1),
        'page': equipmentPageIndex
      },
      if (availableEquipment.isNotEmpty)
        {
          'label': 'Equipment',
          'value': availableEquipment.length > 2
              ? '${availableEquipment.take(2).join(", ")}...'
              : availableEquipment.join(", "),
          'page': equipmentPageIndex
        },
      if (workoutLocation != 'gym')
        {
          'label': 'Gym Access',
          'value': hasGymAccess ? 'Yes' : 'No',
          'page': equipmentPageIndex
        },
    ];

    final List<Map<String, dynamic>> scheduleItems = [
      {
        'label': 'Workouts per Week',
        'value':
            '$workoutsPerWeek ${workoutsPerWeek == 1 ? 'workout' : 'workouts'}',
        'page': schedulePageIndex
      },
      {
        'label': 'Workout Duration',
        'value': '$maxWorkoutDuration minutes',
        'page': schedulePageIndex
      },
      {
        'label': 'Preferred Time',
        'value': _getTimeOfDayDisplayText(preferredTimeOfDay),
        'page': schedulePageIndex
      },
      {
        'label': 'Preferred Days',
        'value': preferredDays.contains('Flexible')
            ? 'Flexible schedule'
            : preferredDays.length > 2
                ? '${preferredDays.take(2).join(", ")}...'
                : preferredDays.join(", "),
        'page': schedulePageIndex
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Summary',
            style: AppTypography.onboardingSubtitle.copyWith(
              color: customColors?.textPrimary ?? theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review your information before calculating.',
            style: AppTypography.onboardingBody.copyWith(
              color: customColors?.textSecondary ??
                  theme.colorScheme.onSurface.withAlpha((0.7 * 255).round()),
            ),
          ),
          const SizedBox(height: 32),
          _buildSummarySection(context,
              title: 'Personal Information',
              icon: Icons.person,
              items: personalInfoItems),
          const SizedBox(height: 24),
          _buildSummarySection(context,
              title: 'Activity & Goals',
              icon: Icons.fitness_center,
              items: activityGoalsItems),
          const SizedBox(height: 24),
          _buildSummarySection(context,
              title: 'Macro Settings',
              icon: Icons.science,
              items: macroSettingsItems),
          const SizedBox(height: 24),
          _buildSummarySection(context,
              title: 'Fitness Level',
              icon: Icons.directions_run,
              items: fitnessItems),
          const SizedBox(height: 24),
          _buildSummarySection(context,
              title: 'Equipment & Space',
              icon: Icons.fitness_center,
              items: equipmentItems),
          const SizedBox(height: 24),
          _buildSummarySection(context,
              title: 'Workout Schedule',
              icon: Icons.schedule,
              items: scheduleItems),
        ],
      ),
    );
  }

  Widget _buildSummarySection(BuildContext context,
      {required String title,
      required IconData icon,
      required List<Map<String, dynamic>> items}) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
          color: customColors?.cardBackground ?? theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha((0.05 * 255).round()),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 2))
          ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(children: [
                Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: (customColors?.textPrimary ??
                                theme.colorScheme.primary)
                            .withAlpha((0.1 * 255).round()),
                        borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon,
                        color: customColors?.textPrimary ??
                            theme.colorScheme.primary,
                        size: 20)),
                const SizedBox(width: 12),
                Text(title,
                    style: AppTypography.h3.copyWith(
                      color: customColors?.textPrimary ??
                          theme.colorScheme.onSurface,
                    ))
              ])),
          Divider(
              height: 1,
              thickness: 1,
              color: Colors.grey.withAlpha((0.1 * 255).round())),
          ...items.where((item) => item.containsKey('value')).map((item) =>
              _buildSummaryItem(context,
                  label: item['label'],
                  value: item['value'].toString(),
                  page: item['page'])),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context,
      {required String label, required String value, required int page}) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final theme = Theme.of(context);
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onEdit(page);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(children: [
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(label,
                    style: AppTypography.caption.copyWith(
                      color: customColors?.textSecondary ??
                          theme.colorScheme.onSurface
                              .withAlpha((0.7 * 255).round()),
                    )),
                const SizedBox(height: 4),
                Text(value,
                    style: AppTypography.body1.copyWith(
                      fontWeight: FontWeight.w600,
                      color: customColors?.textPrimary ??
                          theme.colorScheme.onSurface,
                    ))
              ])),
          Icon(Icons.edit,
              size: 16,
              color: customColors?.textPrimary ?? theme.colorScheme.primary)
        ]),
      ),
    );
  }

  String _getTimeOfDayDisplayText(String timeOfDay) {
    switch (timeOfDay) {
      case 'morning':
        return 'Morning sessions';
      case 'afternoon':
        return 'Afternoon sessions';
      case 'evening':
        return 'Evening sessions';
      case 'flexible':
        return 'Flexible timing';
      default:
        return 'Not set';
    }
  }
}
