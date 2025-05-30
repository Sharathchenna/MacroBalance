import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';

class WorkoutSchedulePage extends StatelessWidget {
  final int workoutsPerWeek;
  final int maxWorkoutDuration;
  final String preferredTimeOfDay;
  final List<String> preferredDays;
  final ValueChanged<int> onWorkoutsPerWeekChanged;
  final ValueChanged<int> onMaxWorkoutDurationChanged;
  final ValueChanged<String> onPreferredTimeOfDayChanged;
  final ValueChanged<List<String>> onPreferredDaysChanged;

  const WorkoutSchedulePage({
    super.key,
    required this.workoutsPerWeek,
    required this.maxWorkoutDuration,
    required this.preferredTimeOfDay,
    required this.preferredDays,
    required this.onWorkoutsPerWeekChanged,
    required this.onMaxWorkoutDurationChanged,
    required this.onPreferredTimeOfDayChanged,
    required this.onPreferredDaysChanged,
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
            'Let\'s plan your workout schedule',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll create a schedule that fits your lifestyle',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: customColors?.textSecondary,
            ),
          ),
          const SizedBox(height: 32),

          // Workouts per week
          Text(
            'How many workouts per week?',
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
              value: workoutsPerWeek.toDouble(),
              min: 1,
              max: 7,
              divisions: 6,
              activeColor: PremiumColors.slate900,
              inactiveColor: PremiumColors.slate300,
              label:
                  '$workoutsPerWeek ${workoutsPerWeek == 1 ? 'workout' : 'workouts'} per week',
              onChanged: (value) {
                HapticFeedback.selectionClick();
                onWorkoutsPerWeekChanged(value.round());
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
                  '1 workout',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: customColors?.textSecondary,
                  ),
                ),
                Text(
                  '7 workouts',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: customColors?.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Maximum workout duration
          Text(
            'Maximum workout duration',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDurationOption(15, '15 min', 'Quick & effective'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDurationOption(30, '30 min', 'Most popular'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDurationOption(45, '45 min', 'Standard length'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDurationOption(60, '60+ min', 'Extended sessions'),
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Preferred time of day
          Text(
            'When do you prefer to work out?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              _buildTimeOfDayCard(
                'morning',
                'Morning',
                'Start your day with energy',
                Icons.wb_sunny,
              ),
              const SizedBox(height: 12),
              _buildTimeOfDayCard(
                'afternoon',
                'Afternoon',
                'Lunch break or mid-day boost',
                Icons.wb_cloudy,
              ),
              const SizedBox(height: 12),
              _buildTimeOfDayCard(
                'evening',
                'Evening',
                'Unwind after work',
                Icons.nights_stay,
              ),
              const SizedBox(height: 12),
              _buildTimeOfDayCard(
                'flexible',
                'Flexible',
                'Whenever I have time',
                Icons.schedule,
              ),
            ],
          ),

          const SizedBox(height: 40),

          // Preferred days
          Text(
            'Which days work best for you?',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: customColors?.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select your preferred workout days',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: customColors?.textSecondary,
            ),
          ),
          const SizedBox(height: 16),

          // Days of week grid
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1,
            children: [
              _buildDayChip('Monday', 'Mon'),
              _buildDayChip('Tuesday', 'Tue'),
              _buildDayChip('Wednesday', 'Wed'),
              _buildDayChip('Thursday', 'Thu'),
              _buildDayChip('Friday', 'Fri'),
              _buildDayChip('Saturday', 'Sat'),
              _buildDayChip('Sunday', 'Sun'),
              _buildDayChip('Flexible', 'Any'),
            ],
          ),

          const SizedBox(height: 32),

          // Schedule summary
          if (workoutsPerWeek > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    PremiumColors.slate50,
                    PremiumColors.slate100.withOpacity(0.5),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: PremiumColors.slate200,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your Workout Plan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: PremiumColors.slate900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow(
                    Icons.fitness_center,
                    'Frequency',
                    '$workoutsPerWeek ${workoutsPerWeek == 1 ? 'workout' : 'workouts'} per week',
                  ),
                  _buildSummaryRow(
                    Icons.schedule,
                    'Duration',
                    'Up to $maxWorkoutDuration minutes each',
                  ),
                  _buildSummaryRow(
                    Icons.access_time,
                    'Timing',
                    _getTimeOfDayDisplayText(preferredTimeOfDay),
                  ),
                  if (preferredDays.isNotEmpty) ...[
                    _buildSummaryRow(
                      Icons.calendar_today,
                      'Days',
                      preferredDays.contains('Flexible')
                          ? 'Flexible schedule'
                          : preferredDays.take(3).join(', ') +
                              (preferredDays.length > 3 ? '...' : ''),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDurationOption(int duration, String title, String subtitle) {
    final isSelected = maxWorkoutDuration == duration;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onMaxWorkoutDurationChanged(duration);
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
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : PremiumColors.slate700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
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

  Widget _buildTimeOfDayCard(
      String value, String title, String description, IconData icon) {
    final isSelected = preferredTimeOfDay == value;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPreferredTimeOfDayChanged(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? PremiumColors.slate900 : Colors.white,
          borderRadius: BorderRadius.circular(16),
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
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : PremiumColors.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : PremiumColors.slate600,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : PremiumColors.slate700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white.withOpacity(0.8)
                          : PremiumColors.slate500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayChip(String day, String shortDay) {
    final isSelected = preferredDays.contains(day);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        final updatedDays = List<String>.from(preferredDays);

        if (day == 'Flexible') {
          // If selecting flexible, clear all other days
          if (!isSelected) {
            updatedDays.clear();
            updatedDays.add('Flexible');
          } else {
            updatedDays.remove('Flexible');
          }
        } else {
          // Remove flexible if selecting specific days
          updatedDays.remove('Flexible');

          if (isSelected) {
            updatedDays.remove(day);
          } else {
            updatedDays.add(day);
          }
        }

        onPreferredDaysChanged(updatedDays);
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                shortDay,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : PremiumColors.slate700,
                ),
              ),
              if (day != 'Flexible') ...[
                const SizedBox(height: 2),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.6)
                        : PremiumColors.slate400,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: PremiumColors.slate600,
          ),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: PremiumColors.slate600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: PremiumColors.slate900,
              ),
            ),
          ),
        ],
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
        return 'No preference';
    }
  }
}
