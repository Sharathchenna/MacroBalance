import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';

class WorkoutSchedulePreferencesPage extends StatefulWidget {
  final int workoutsPerWeek;
  final int workoutDuration;
  final String preferredTime;
  final ValueChanged<int> onWorkoutsPerWeekChanged;
  final ValueChanged<int> onWorkoutDurationChanged;
  final ValueChanged<String> onPreferredTimeChanged;

  const WorkoutSchedulePreferencesPage({
    super.key,
    required this.workoutsPerWeek,
    required this.workoutDuration,
    required this.preferredTime,
    required this.onWorkoutsPerWeekChanged,
    required this.onWorkoutDurationChanged,
    required this.onPreferredTimeChanged,
  });

  @override
  State<WorkoutSchedulePreferencesPage> createState() =>
      _WorkoutSchedulePreferencesPageState();
}

class _WorkoutSchedulePreferencesPageState
    extends State<WorkoutSchedulePreferencesPage> {
  @override
  void initState() {
    super.initState();
    // Set default selections if none are made
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.workoutsPerWeek == 0) {
        widget.onWorkoutsPerWeekChanged(3);
      }
      if (widget.workoutDuration == 0) {
        widget.onWorkoutDurationChanged(30);
      }
      if (widget.preferredTime.isEmpty) {
        widget.onPreferredTimeChanged('morning');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = Theme.of(context).extension<CustomColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Plan your workout schedule',
            style: PremiumTypography.h2.copyWith(
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Help us create a sustainable routine for you',
            style: PremiumTypography.bodyMedium.copyWith(
              color: customColors?.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Workouts Per Week
          Text(
            'How many days per week can you work out?',
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
                color: isDark ? PremiumColors.slate700 : PremiumColors.slate300,
                width: 1.5,
              ),
            ),
            child: Slider(
              value: widget.workoutsPerWeek.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              activeColor:
                  isDark ? PremiumColors.blue400 : PremiumColors.slate900,
              inactiveColor:
                  isDark ? PremiumColors.slate700 : PremiumColors.slate300,
              label:
                  '${widget.workoutsPerWeek} ${widget.workoutsPerWeek == 1 ? 'day' : 'days'} per week',
              onChanged: (value) {
                HapticFeedback.selectionClick();
                widget.onWorkoutsPerWeekChanged(value.round());
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
                  '1 day',
                  style: PremiumTypography.caption.copyWith(
                    color: customColors?.textSecondary,
                  ),
                ),
                Text(
                  '7 days',
                  style: PremiumTypography.caption.copyWith(
                    color: customColors?.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Workout Duration
          Text(
            'How long can you work out each session?',
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
                color: isDark ? PremiumColors.slate700 : PremiumColors.slate300,
                width: 1.5,
              ),
            ),
            child: Slider(
              value: widget.workoutDuration.toDouble(),
              min: 15,
              max: 90,
              divisions: 5,
              activeColor:
                  isDark ? PremiumColors.blue400 : PremiumColors.slate900,
              inactiveColor:
                  isDark ? PremiumColors.slate700 : PremiumColors.slate300,
              label: '${widget.workoutDuration} minutes',
              onChanged: (value) {
                HapticFeedback.selectionClick();
                widget.onWorkoutDurationChanged(value.round());
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
                  '15 min',
                  style: PremiumTypography.caption.copyWith(
                    color: customColors?.textSecondary,
                  ),
                ),
                Text(
                  '90 min',
                  style: PremiumTypography.caption.copyWith(
                    color: customColors?.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Preferred Time
          Text(
            'When do you prefer to work out?',
            style: PremiumTypography.subtitle.copyWith(
              fontWeight: FontWeight.w600,
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildTimeOption(
                  'morning',
                  'Morning',
                  'Before work/school',
                  Icons.wb_sunny,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeOption(
                  'afternoon',
                  'Afternoon',
                  'During lunch/break',
                  Icons.wb_cloudy,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeOption(
                  'evening',
                  'Evening',
                  'After work/school',
                  Icons.nights_stay,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeOption(
      String value, String title, String subtitle, IconData icon, bool isDark) {
    final isSelected = widget.preferredTime == value;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onPreferredTimeChanged(value);
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
}
