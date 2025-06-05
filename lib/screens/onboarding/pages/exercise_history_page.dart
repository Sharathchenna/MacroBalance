import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';

class ExerciseHistoryPage extends StatefulWidget {
  final int yearsOfExperience;
  final List<String> previousExerciseTypes;
  final ValueChanged<int> onYearsOfExperienceChanged;
  final ValueChanged<List<String>> onPreviousExerciseTypesChanged;

  const ExerciseHistoryPage({
    super.key,
    required this.yearsOfExperience,
    required this.previousExerciseTypes,
    required this.onYearsOfExperienceChanged,
    required this.onPreviousExerciseTypesChanged,
  });

  @override
  State<ExerciseHistoryPage> createState() => _ExerciseHistoryPageState();
}

class _ExerciseHistoryPageState extends State<ExerciseHistoryPage> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollIndicator = true;

  @override
  void initState() {
    super.initState();
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
                'Tell us about your exercise history',
                style: PremiumTypography.h2.copyWith(
                  color: customColors?.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us understand your experience level',
                style: PremiumTypography.bodyMedium.copyWith(
                  color: customColors?.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Years of Experience
              Text(
                'Years of exercise experience',
                style: PremiumTypography.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: customColors?.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? PremiumColors.trueDarkCard
                      : customColors?.cardBackground,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? PremiumColors.slate700
                        : PremiumColors.slate300,
                    width: 1.5,
                  ),
                ),
                child: Slider(
                  value: widget.yearsOfExperience.toDouble(),
                  min: 0,
                  max: 20,
                  divisions: 20,
                  activeColor: customColors?.textPrimary ??
                      (isDark ? Colors.white : PremiumColors.slate900),
                  inactiveColor:
                      isDark ? PremiumColors.slate700 : PremiumColors.slate300,
                  label: widget.yearsOfExperience == 0
                      ? 'Just starting'
                      : widget.yearsOfExperience >= 20
                          ? '20+ years'
                          : '${widget.yearsOfExperience} ${widget.yearsOfExperience == 1 ? 'year' : 'years'}',
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    widget.onYearsOfExperienceChanged(value.round());
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
                      style: PremiumTypography.caption.copyWith(
                        color: customColors?.textSecondary,
                      ),
                    ),
                    Text(
                      '20+ years',
                      style: PremiumTypography.caption.copyWith(
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
                style: PremiumTypography.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: customColors?.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select all that apply (optional)',
                style: PremiumTypography.bodyMedium.copyWith(
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
                  _buildExerciseTypeChip(
                      'Weight Training', Icons.fitness_center, isDark),
                  _buildExerciseTypeChip(
                      'Running', Icons.directions_run, isDark),
                  _buildExerciseTypeChip(
                      'Yoga', Icons.self_improvement, isDark),
                  _buildExerciseTypeChip('Swimming', Icons.pool, isDark),
                  _buildExerciseTypeChip(
                      'Cycling', Icons.directions_bike, isDark),
                  _buildExerciseTypeChip('Sports', Icons.sports_tennis, isDark),
                  _buildExerciseTypeChip('Dancing', Icons.music_note, isDark),
                  _buildExerciseTypeChip('Hiking', Icons.terrain, isDark),
                  _buildExerciseTypeChip(
                      'Martial Arts', Icons.sports_kabaddi, isDark),
                  _buildExerciseTypeChip(
                      'CrossFit', Icons.fitness_center, isDark),
                  _buildExerciseTypeChip(
                      'Pilates', Icons.accessibility_new, isDark),
                  _buildExerciseTypeChip(
                      'Rock Climbing', Icons.landscape, isDark),
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

  Widget _buildExerciseTypeChip(String type, IconData icon, bool isDark) {
    final isSelected = widget.previousExerciseTypes.contains(type);
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>();

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        final updatedTypes = List<String>.from(widget.previousExerciseTypes);
        if (isSelected) {
          updatedTypes.remove(type);
        } else {
          updatedTypes.add(type);
        }
        widget.onPreviousExerciseTypesChanged(updatedTypes);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? (customColors?.textPrimary ??
                  (isDark ? Colors.white : PremiumColors.slate900))
              : (isDark ? PremiumColors.trueDarkCard : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (customColors?.textPrimary ??
                    (isDark ? Colors.white : PremiumColors.slate900))
                : (isDark ? PremiumColors.slate700 : PremiumColors.slate300),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (customColors?.textPrimary ??
                            (isDark ? Colors.white : PremiumColors.slate900))
                        .withAlpha((0.1 * 255).round()),
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
                color: isSelected
                    ? (customColors?.cardBackground ??
                        (isDark ? PremiumColors.slate900 : Colors.white))
                    : (isDark
                        ? PremiumColors.slate300
                        : PremiumColors.slate600),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  type,
                  style: PremiumTypography.label.copyWith(
                    fontSize: 14,
                    color: isSelected
                        ? (customColors?.cardBackground ??
                            (isDark ? PremiumColors.slate900 : Colors.white))
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
