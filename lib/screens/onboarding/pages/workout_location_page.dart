import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/widgets/onboarding/onboarding_selection_card.dart';
import 'package:macrotracker/theme/app_theme.dart';

class WorkoutLocationPage extends StatefulWidget {
  final String workoutLocation;
  final bool hasGymAccess;
  final ValueChanged<String> onWorkoutLocationChanged;
  final ValueChanged<bool> onGymAccessChanged;

  const WorkoutLocationPage({
    super.key,
    required this.workoutLocation,
    required this.hasGymAccess,
    required this.onWorkoutLocationChanged,
    required this.onGymAccessChanged,
  });

  @override
  State<WorkoutLocationPage> createState() => _WorkoutLocationPageState();
}

class _WorkoutLocationPageState extends State<WorkoutLocationPage> {
  @override
  void initState() {
    super.initState();
    // Set default selection if none is made
    if (widget.workoutLocation.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onWorkoutLocationChanged('home');
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
            'Where do you prefer to work out?',
            style: PremiumTypography.h2.copyWith(
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us recommend workouts that fit your environment',
            style: PremiumTypography.bodyMedium.copyWith(
              color: customColors?.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Workout Location Selection
          OnboardingSelectionCard(
            isSelected: widget.workoutLocation == 'home',
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onWorkoutLocationChanged('home');
            },
            icon: Icons.home,
            label: 'At Home',
            description: 'Convenience and privacy in your own space',
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            isSelected: widget.workoutLocation == 'gym',
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onWorkoutLocationChanged('gym');
              widget.onGymAccessChanged(true);
            },
            icon: Icons.fitness_center,
            label: 'At the Gym',
            description: 'Full equipment access and gym atmosphere',
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            isSelected: widget.workoutLocation == 'outdoor',
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onWorkoutLocationChanged('outdoor');
            },
            icon: Icons.park,
            label: 'Outdoors',
            description: 'Parks, trails, and fresh air workouts',
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            isSelected: widget.workoutLocation == 'mixed',
            onTap: () {
              HapticFeedback.lightImpact();
              widget.onWorkoutLocationChanged('mixed');
            },
            icon: Icons.shuffle,
            label: 'Mixed',
            description: 'Variety of locations depending on the day',
          ),

          const SizedBox(height: 32),

          // Gym Access Toggle (only shown if not primarily working out at gym)
          if (widget.workoutLocation != 'gym') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    isDark ? PremiumColors.trueDarkCard : PremiumColors.slate50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isDark ? PremiumColors.slate700 : PremiumColors.slate200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    color: isDark
                        ? PremiumColors.slate300
                        : PremiumColors.slate600,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Do you have gym access?',
                          style: PremiumTypography.subtitle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: customColors?.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'For occasional gym-based workouts',
                          style: PremiumTypography.bodySmall.copyWith(
                            color: customColors?.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: widget.hasGymAccess,
                    onChanged: (value) {
                      HapticFeedback.lightImpact();
                      widget.onGymAccessChanged(value);
                    },
                    activeColor:
                        isDark ? PremiumColors.blue400 : PremiumColors.slate900,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
