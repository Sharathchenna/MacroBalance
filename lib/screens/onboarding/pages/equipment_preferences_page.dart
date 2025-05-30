import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/widgets/onboarding/onboarding_selection_card.dart';
import 'package:macrotracker/theme/app_theme.dart';

class EquipmentPreferencesPage extends StatelessWidget {
  final String workoutLocation;
  final List<String> availableEquipment;
  final bool hasGymAccess;
  final String workoutSpace;
  final ValueChanged<String> onWorkoutLocationChanged;
  final ValueChanged<List<String>> onAvailableEquipmentChanged;
  final ValueChanged<bool> onGymAccessChanged;
  final ValueChanged<String> onWorkoutSpaceChanged;

  const EquipmentPreferencesPage({
    super.key,
    required this.workoutLocation,
    required this.availableEquipment,
    required this.hasGymAccess,
    required this.workoutSpace,
    required this.onWorkoutLocationChanged,
    required this.onAvailableEquipmentChanged,
    required this.onGymAccessChanged,
    required this.onWorkoutSpaceChanged,
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
            'Where do you prefer to work out?',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us recommend workouts that fit your environment',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: customColors?.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Workout Location Selection
          OnboardingSelectionCard(
            isSelected: workoutLocation == 'home',
            onTap: () {
              HapticFeedback.lightImpact();
              onWorkoutLocationChanged('home');
            },
            icon: Icons.home,
            label: 'At Home',
            description: 'Convenience and privacy in your own space',
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            isSelected: workoutLocation == 'gym',
            onTap: () {
              HapticFeedback.lightImpact();
              onWorkoutLocationChanged('gym');
              onGymAccessChanged(true);
            },
            icon: Icons.fitness_center,
            label: 'At the Gym',
            description: 'Full equipment access and gym atmosphere',
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            isSelected: workoutLocation == 'outdoor',
            onTap: () {
              HapticFeedback.lightImpact();
              onWorkoutLocationChanged('outdoor');
            },
            icon: Icons.park,
            label: 'Outdoors',
            description: 'Parks, trails, and fresh air workouts',
          ),
          const SizedBox(height: 16),
          OnboardingSelectionCard(
            isSelected: workoutLocation == 'mixed',
            onTap: () {
              HapticFeedback.lightImpact();
              onWorkoutLocationChanged('mixed');
            },
            icon: Icons.shuffle,
            label: 'Mixed',
            description: 'Variety of locations depending on the day',
          ),

          const SizedBox(height: 40),

          // Available Space
          Text(
            'How much space do you have?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSpaceOption(
                  'small',
                  'Small',
                  'Apartment/limited space',
                  Icons.crop_square,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSpaceOption(
                  'medium',
                  'Medium',
                  'Living room/bedroom',
                  Icons.crop_landscape,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSpaceOption(
                  'large',
                  'Large',
                  'Garage/basement/yard',
                  Icons.crop_free,
                ),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Equipment Selection
          Text(
            'What equipment do you have access to?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select all that apply',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: customColors?.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Equipment Grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.2,
            children: [
              _buildEquipmentChip('Bodyweight', Icons.accessibility_new),
              _buildEquipmentChip('Dumbbells', Icons.fitness_center),
              _buildEquipmentChip('Resistance Bands', Icons.linear_scale),
              _buildEquipmentChip('Yoga Mat', Icons.crop_landscape),
              _buildEquipmentChip('Pull-up Bar', Icons.view_headline),
              _buildEquipmentChip('Kettlebells', Icons.sports_handball),
              _buildEquipmentChip('Barbell', Icons.remove),
              _buildEquipmentChip('Bench', Icons.weekend),
              _buildEquipmentChip('Jump Rope', Icons.cable),
              _buildEquipmentChip('Exercise Ball', Icons.sports_volleyball),
              _buildEquipmentChip('Foam Roller', Icons.waves),
              _buildEquipmentChip('Full Gym', Icons.business),
            ],
          ),

          const SizedBox(height: 32),

          // Gym Access Toggle
          if (workoutLocation != 'gym') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: PremiumColors.slate50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: PremiumColors.slate200,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.fitness_center,
                    color: PremiumColors.slate600,
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Do you have gym access?',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: PremiumColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'For occasional gym-based workouts',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: PremiumColors.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: hasGymAccess,
                    onChanged: (value) {
                      HapticFeedback.lightImpact();
                      onGymAccessChanged(value);
                    },
                    activeColor: PremiumColors.slate900,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpaceOption(
      String value, String title, String subtitle, IconData icon) {
    final isSelected = workoutSpace == value;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onWorkoutSpaceChanged(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
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
        child: Column(
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected ? Colors.white : PremiumColors.slate600,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : PremiumColors.slate700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: isSelected
                    ? Colors.white.withOpacity(0.8)
                    : PremiumColors.slate500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEquipmentChip(String equipment, IconData icon) {
    final isSelected = availableEquipment.contains(equipment);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        final updatedEquipment = List<String>.from(availableEquipment);
        if (isSelected) {
          updatedEquipment.remove(equipment);
        } else {
          updatedEquipment.add(equipment);
        }
        onAvailableEquipmentChanged(updatedEquipment);
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                  equipment,
                  style: TextStyle(
                    fontSize: 13,
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
