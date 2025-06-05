import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/widgets/onboarding/onboarding_selection_card.dart';
import 'package:macrotracker/theme/app_theme.dart';

class EquipmentPreferencesPage extends StatefulWidget {
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
  State<EquipmentPreferencesPage> createState() =>
      _EquipmentPreferencesPageState();
}

class _EquipmentPreferencesPageState extends State<EquipmentPreferencesPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollIndicator = true;

  @override
  void initState() {
    super.initState();
    // Set default selections if none are made
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.workoutLocation.isEmpty) {
        widget.onWorkoutLocationChanged('home');
      }
      if (widget.workoutSpace.isEmpty) {
        widget.onWorkoutSpaceChanged('medium');
      }
      if (widget.availableEquipment.isEmpty) {
        widget.onAvailableEquipmentChanged(['Bodyweight', 'Yoga Mat']);
      }
    });

    // Listen to scroll to hide indicator when user starts scrolling
    _scrollController.addListener(() {
      if (_showScrollIndicator && _scrollController.offset > 20) {
        setState(() {
          _showScrollIndicator = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = Theme.of(context).extension<CustomColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
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

              const SizedBox(height: 40),

              // Available Space
              Text(
                'How much space do you have?',
                style: PremiumTypography.subtitle.copyWith(
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
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSpaceOption(
                      'medium',
                      'Medium',
                      'Living room/bedroom',
                      Icons.crop_landscape,
                      isDark,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSpaceOption(
                      'large',
                      'Large',
                      'Garage/basement/yard',
                      Icons.crop_free,
                      isDark,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Equipment Selection
              Text(
                'What equipment do you have access to?',
                style: PremiumTypography.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: customColors?.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select all that apply',
                style: PremiumTypography.bodyMedium.copyWith(
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
                  _buildEquipmentChip(
                      'Bodyweight', Icons.accessibility_new, isDark),
                  _buildEquipmentChip(
                      'Dumbbells', Icons.fitness_center, isDark),
                  _buildEquipmentChip(
                      'Resistance Bands', Icons.linear_scale, isDark),
                  _buildEquipmentChip('Yoga Mat', Icons.crop_landscape, isDark),
                  _buildEquipmentChip(
                      'Pull-up Bar', Icons.view_headline, isDark),
                  _buildEquipmentChip(
                      'Kettlebells', Icons.sports_handball, isDark),
                  _buildEquipmentChip('Barbell', Icons.remove, isDark),
                  _buildEquipmentChip('Bench', Icons.weekend, isDark),
                  _buildEquipmentChip('Jump Rope', Icons.cable, isDark),
                  _buildEquipmentChip(
                      'Exercise Ball', Icons.sports_volleyball, isDark),
                  _buildEquipmentChip('Foam Roller', Icons.waves, isDark),
                  _buildEquipmentChip('Full Gym', Icons.business, isDark),
                ],
              ),

              const SizedBox(height: 32),

              // Gym Access Toggle
              if (widget.workoutLocation != 'gym') ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? PremiumColors.trueDarkCard
                        : PremiumColors.slate50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? PremiumColors.slate700
                          : PremiumColors.slate200,
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
                        activeColor: isDark
                            ? PremiumColors.blue400
                            : PremiumColors.slate900,
                      ),
                    ],
                  ),
                ),
              ],
              // Add extra padding at bottom for scroll indicator
              const SizedBox(height: 60),
            ],
          ),
        ),
        // Scroll Indicator
        if (_showScrollIndicator)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Center(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: _showScrollIndicator ? 1.0 : 0.0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? PremiumColors.slate800.withOpacity(0.9)
                        : PremiumColors.slate900.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Scroll for more',
                        style: PremiumTypography.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSpaceOption(
      String value, String title, String subtitle, IconData icon, bool isDark) {
    final isSelected = widget.workoutSpace == value;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onWorkoutSpaceChanged(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? PremiumColors.blue400 : PremiumColors.slate900)
              : (isDark ? PremiumColors.trueDarkCard : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? PremiumColors.blue400 : PremiumColors.slate900)
                : (isDark ? PremiumColors.slate700 : PremiumColors.slate300),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark
                            ? PremiumColors.blue400
                            : PremiumColors.slate900)
                        .withAlpha((0.1 * 255).round()),
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
              color: isSelected
                  ? (isDark ? PremiumColors.slate900 : Colors.white)
                  : (isDark ? PremiumColors.slate300 : PremiumColors.slate600),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: PremiumTypography.label.copyWith(
                fontSize: 14,
                color: isSelected
                    ? (isDark ? PremiumColors.slate900 : Colors.white)
                    : (isDark
                        ? PremiumColors.slate300
                        : PremiumColors.slate700),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: PremiumTypography.caption.copyWith(
                color: isSelected
                    ? (isDark
                        ? PremiumColors.slate900.withOpacity(0.8)
                        : Colors.white.withOpacity(0.8))
                    : (isDark
                        ? PremiumColors.slate400
                        : PremiumColors.slate500),
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

  Widget _buildEquipmentChip(String equipment, IconData icon, bool isDark) {
    final isSelected = widget.availableEquipment.contains(equipment);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        final updatedEquipment = List<String>.from(widget.availableEquipment);
        if (isSelected) {
          updatedEquipment.remove(equipment);
        } else {
          updatedEquipment.add(equipment);
        }
        widget.onAvailableEquipmentChanged(updatedEquipment);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? PremiumColors.blue400 : PremiumColors.slate900)
              : (isDark ? PremiumColors.trueDarkCard : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? PremiumColors.blue400 : PremiumColors.slate900)
                : (isDark ? PremiumColors.slate700 : PremiumColors.slate300),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDark
                            ? PremiumColors.blue400
                            : PremiumColors.slate900)
                        .withAlpha((0.1 * 255).round()),
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
                color: isSelected
                    ? (isDark ? PremiumColors.slate900 : Colors.white)
                    : (isDark
                        ? PremiumColors.slate300
                        : PremiumColors.slate600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  equipment,
                  style: PremiumTypography.label.copyWith(
                    fontSize: 13,
                    color: isSelected
                        ? (isDark ? PremiumColors.slate900 : Colors.white)
                        : (isDark
                            ? PremiumColors.slate300
                            : PremiumColors.slate700),
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
