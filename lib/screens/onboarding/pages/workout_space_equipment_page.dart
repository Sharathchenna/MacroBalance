import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';

class WorkoutSpaceEquipmentPage extends StatefulWidget {
  final String workoutSpace;
  final List<String> availableEquipment;
  final ValueChanged<String> onWorkoutSpaceChanged;
  final ValueChanged<List<String>> onAvailableEquipmentChanged;

  const WorkoutSpaceEquipmentPage({
    super.key,
    required this.workoutSpace,
    required this.availableEquipment,
    required this.onWorkoutSpaceChanged,
    required this.onAvailableEquipmentChanged,
  });

  @override
  State<WorkoutSpaceEquipmentPage> createState() =>
      _WorkoutSpaceEquipmentPageState();
}

class _WorkoutSpaceEquipmentPageState extends State<WorkoutSpaceEquipmentPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollIndicator = true;

  @override
  void initState() {
    super.initState();
    // Set default selections if none are made
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.workoutSpace.isEmpty) {
        widget.onWorkoutSpaceChanged('medium');
      }
      if (widget.availableEquipment.isEmpty) {
        widget.onAvailableEquipmentChanged(['Bodyweight', 'Yoga Mat']);
      }
    });

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
                'Tell us about your workout space',
                style: PremiumTypography.h2.copyWith(
                  color: customColors?.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us recommend suitable exercises',
                style: PremiumTypography.bodyMedium.copyWith(
                  color: customColors?.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

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
