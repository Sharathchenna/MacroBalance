import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';

class WorkoutSchedulePage extends StatefulWidget {
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
  State<WorkoutSchedulePage> createState() => _WorkoutSchedulePageState();
}

class _WorkoutSchedulePageState extends State<WorkoutSchedulePage> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollIndicator = true;

  @override
  void initState() {
    super.initState();
    // Set default selections if none are made
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.workoutsPerWeek == 0) {
        widget.onWorkoutsPerWeekChanged(3); // Default to 3 workouts per week
      }
      if (widget.maxWorkoutDuration == 0) {
        widget.onMaxWorkoutDurationChanged(30); // Default to 30 minutes
      }
      if (widget.preferredTimeOfDay.isEmpty) {
        widget.onPreferredTimeOfDayChanged(
            'flexible'); // Default to flexible timing
      }
      if (widget.preferredDays.isEmpty) {
        // Default to flexible schedule with some specific days
        widget.onPreferredDaysChanged(
            ['Monday', 'Wednesday', 'Friday', 'Flexible']);
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
                'Let\'s plan your workout schedule',
                style: PremiumTypography.h2.copyWith(
                  color: customColors?.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We\'ll create a schedule that fits your lifestyle',
                style: PremiumTypography.bodyMedium.copyWith(
                  color: customColors?.textSecondary,
                ),
              ),
              const SizedBox(height: 32),

              // Workouts per week
              Text(
                'How many workouts per week?',
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
                  value: widget.workoutsPerWeek.toDouble(),
                  min: 1,
                  max: 7,
                  divisions: 6,
                  activeColor:
                      isDark ? PremiumColors.blue400 : PremiumColors.slate900,
                  inactiveColor:
                      isDark ? PremiumColors.slate700 : PremiumColors.slate300,
                  label:
                      '${widget.workoutsPerWeek} ${widget.workoutsPerWeek == 1 ? 'workout' : 'workouts'} per week',
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
                      '1 workout',
                      style: PremiumTypography.caption.copyWith(
                        color: customColors?.textSecondary,
                      ),
                    ),
                    Text(
                      '7 workouts',
                      style: PremiumTypography.caption.copyWith(
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
                style: PremiumTypography.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: customColors?.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildDurationOption(
                        15, '15 min', 'Quick & effective', isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDurationOption(
                        30, '30 min', 'Most popular', isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDurationOption(
                        45, '45 min', 'Standard length', isDark),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDurationOption(
                        60, '60+ min', 'Extended sessions', isDark),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Preferred time of day
              Text(
                'When do you prefer to work out?',
                style: PremiumTypography.subtitle.copyWith(
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
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildTimeOfDayCard(
                    'afternoon',
                    'Afternoon',
                    'Lunch break or mid-day boost',
                    Icons.wb_cloudy,
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildTimeOfDayCard(
                    'evening',
                    'Evening',
                    'Unwind after work',
                    Icons.nights_stay,
                    isDark,
                  ),
                  const SizedBox(height: 12),
                  _buildTimeOfDayCard(
                    'flexible',
                    'Flexible',
                    'Whenever I have time',
                    Icons.schedule,
                    isDark,
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Preferred days
              Text(
                'Which days work best for you?',
                style: PremiumTypography.subtitle.copyWith(
                  fontWeight: FontWeight.w600,
                  color: customColors?.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select your preferred workout days',
                style: PremiumTypography.bodyMedium.copyWith(
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
                  _buildDayChip('Monday', 'Mon', isDark),
                  _buildDayChip('Tuesday', 'Tue', isDark),
                  _buildDayChip('Wednesday', 'Wed', isDark),
                  _buildDayChip('Thursday', 'Thu', isDark),
                  _buildDayChip('Friday', 'Fri', isDark),
                  _buildDayChip('Saturday', 'Sat', isDark),
                  _buildDayChip('Sunday', 'Sun', isDark),
                  _buildDayChip('Flexible', 'Any', isDark),
                ],
              ),

              const SizedBox(height: 32),

              // Schedule summary
              if (widget.workoutsPerWeek > 0) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              PremiumColors.trueDarkCard,
                              PremiumColors.trueDarkCard.withOpacity(0.8),
                            ]
                          : [
                              PremiumColors.slate50,
                              PremiumColors.slate100
                                  .withAlpha((0.5 * 255).round()),
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? PremiumColors.slate700
                          : PremiumColors.slate200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Workout Plan',
                        style: PremiumTypography.subtitle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: customColors?.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildSummaryRow(
                        Icons.fitness_center,
                        'Frequency',
                        '${widget.workoutsPerWeek} ${widget.workoutsPerWeek == 1 ? 'workout' : 'workouts'} per week',
                        isDark,
                      ),
                      _buildSummaryRow(
                        Icons.schedule,
                        'Duration',
                        'Up to ${widget.maxWorkoutDuration} minutes each',
                        isDark,
                      ),
                      _buildSummaryRow(
                        Icons.access_time,
                        'Timing',
                        _getTimeOfDayDisplayText(widget.preferredTimeOfDay),
                        isDark,
                      ),
                      if (widget.preferredDays.isNotEmpty) ...[
                        _buildSummaryRow(
                          Icons.calendar_today,
                          'Days',
                          widget.preferredDays.contains('Flexible')
                              ? 'Flexible schedule'
                              : widget.preferredDays.take(3).join(', ') +
                                  (widget.preferredDays.length > 3
                                      ? '...'
                                      : ''),
                          isDark,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
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

  Widget _buildDurationOption(
      int duration, String title, String subtitle, bool isDark) {
    final isSelected = widget.maxWorkoutDuration == duration;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        widget.onMaxWorkoutDurationChanged(duration);
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
            Text(
              title,
              style: PremiumTypography.label.copyWith(
                fontSize: 16,
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

  Widget _buildTimeOfDayCard(String value, String title, String description,
      IconData icon, bool isDark) {
    final isSelected = widget.preferredTimeOfDay == value;

    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        widget.onPreferredTimeOfDayChanged(value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? PremiumColors.blue400 : PremiumColors.slate900)
              : (isDark ? PremiumColors.trueDarkCard : Colors.white),
          borderRadius: BorderRadius.circular(16),
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
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark
                        ? PremiumColors.slate900.withOpacity(0.2)
                        : Colors.white.withOpacity(0.2))
                    : (isDark
                        ? PremiumColors.slate800
                        : PremiumColors.slate100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? (isDark ? PremiumColors.slate900 : Colors.white)
                    : (isDark
                        ? PremiumColors.slate300
                        : PremiumColors.slate600),
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
                    style: PremiumTypography.subtitle.copyWith(
                      fontSize: 16,
                      color: isSelected
                          ? (isDark ? PremiumColors.slate900 : Colors.white)
                          : (isDark
                              ? PremiumColors.slate300
                              : PremiumColors.slate700),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: PremiumTypography.bodySmall.copyWith(
                      color: isSelected
                          ? (isDark
                              ? PremiumColors.slate900.withOpacity(0.8)
                              : Colors.white.withOpacity(0.8))
                          : (isDark
                              ? PremiumColors.slate400
                              : PremiumColors.slate500),
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

  Widget _buildDayChip(String day, String shortDay, bool isDark) {
    final isSelected = widget.preferredDays.contains(day);

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        final updatedDays = List<String>.from(widget.preferredDays);

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

        widget.onPreferredDaysChanged(updatedDays);
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
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                shortDay,
                style: PremiumTypography.label.copyWith(
                  fontSize: 14,
                  color: isSelected
                      ? (isDark ? PremiumColors.slate900 : Colors.white)
                      : (isDark
                          ? PremiumColors.slate300
                          : PremiumColors.slate700),
                ),
              ),
              if (day != 'Flexible') ...[
                const SizedBox(height: 2),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? (isDark
                            ? PremiumColors.slate900.withOpacity(0.6)
                            : Colors.white.withOpacity(0.6))
                        : (isDark
                            ? PremiumColors.slate500
                            : PremiumColors.slate400),
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

  Widget _buildSummaryRow(
      IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: isDark ? PremiumColors.slate300 : PremiumColors.slate600,
          ),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: PremiumTypography.label.copyWith(
              fontSize: 14,
              color: isDark ? PremiumColors.slate300 : PremiumColors.slate600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: PremiumTypography.label.copyWith(
                fontSize: 14,
                color: isDark ? PremiumColors.slate50 : PremiumColors.slate900,
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
