import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../Health/Health.dart';
import '../theme/app_theme.dart';
import 'dart:async'; // Add this import

class StepTrackingScreen extends StatefulWidget {
  final bool hideAppBar;

  const StepTrackingScreen({
    Key? key,
    this.hideAppBar = false,
  }) : super(key: key);

  @override
  State<StepTrackingScreen> createState() => _StepTrackingScreenState();
}

// Helper class for monthly statistics
class _MonthlyStats {
  final DateTime date;
  final String monthName;
  final int year;
  final int month;
  int totalSteps = 0;
  int daysTracked = 0;

  _MonthlyStats({
    required this.date,
    required this.monthName,
    required this.year,
    required this.month,
  });

  void addDayStats(int steps) {
    if (steps > 0) {
      // Only count days with actual steps
      totalSteps += steps;
      daysTracked++;
    }
  }

  int get averageDailySteps =>
      daysTracked > 0 ? (totalSteps / daysTracked).round() : 0;
}

class _StepTrackingScreenState extends State<StepTrackingScreen>
    with AutomaticKeepAliveClientMixin {
  final HealthService _healthService = HealthService();
  bool _isLoading = true;
  List<Map<String, dynamic>> _stepsData = [];
  int _todaySteps = 0;
  int _stepGoal = 10000; // Default step goal
  double _progressPercentage = 0.0;
  String _selectedTimeFrame = 'Week';

  // New variables for tracking different time periods
  List<Map<String, dynamic>> _weeklyStepsData = [];
  List<Map<String, dynamic>> _monthlyStepsData = [];

  @override
  void initState() {
    super.initState();
    _loadStepData();
  }

  Future<void> _loadStepData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load today's steps
      final todaySteps = await _healthService.getSteps();

      // Load data for time frames at once for smoother UX when switching
      final weeklyStepsData = await _healthService.getStepsForLastWeek();
      final monthlyStepsData = await _healthService.getStepsForLastMonth();

      setState(() {
        _todaySteps = todaySteps;
        _weeklyStepsData = weeklyStepsData;
        _monthlyStepsData = monthlyStepsData;

        // Set current data based on selected time frame
        _updateCurrentStepsData();

        _progressPercentage = _todaySteps / _stepGoal;
        if (_progressPercentage > 1.0) _progressPercentage = 1.0;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Error loading step data: $e');
    }
  }

  void _updateCurrentStepsData() {
    switch (_selectedTimeFrame) {
      case 'Week':
        _stepsData = _weeklyStepsData;
        break;
      case 'Month':
        _stepsData = _monthlyStepsData;
        break;
      default:
        _stepsData = _weeklyStepsData;
    }
  }

  double _getMaxSteps() {
    final currentData = _getTransformedStepsData(); // Use transformed data
    if (currentData.isEmpty)
      return _stepGoal * 1.2; // Default value with padding

    // Get the maximum step value from the transformed data
    final maxSteps = currentData
        .map((data) => data['steps'] as int)
        .reduce((a, b) => a > b ? a : b)
        .toDouble();

    // Make sure the y-axis includes the goal line with some padding
    final maxValue = math.max(maxSteps, _getGoalValueForTimeFrame());

    // Add 20% padding at the top for better visualization
    return maxValue * 1.2;
  }

  // Get the appropriate goal value for the selected time frame
  double _getGoalValueForTimeFrame() {
    switch (_selectedTimeFrame) {
      case 'Week':
        return _stepGoal.toDouble(); // Daily goal
      case 'Month':
        return _stepGoal.toDouble(); // Daily goal shown as reference
      default:
        return _stepGoal.toDouble();
    }
  }

  String _getGoalLabelForTimeFrame() {
    switch (_selectedTimeFrame) {
      case 'Week':
        return 'Daily Goal';
      case 'Month':
        return 'Daily Goal';
      default:
        return 'Goal';
    }
  }

  // Gets today's index for the current time frame
  int _getTodayIndex() {
    // Get today's date for comparison
    final today = DateTime.now();
    final todayFormatted = DateFormat('yyyy-MM-dd').format(today);

    switch (_selectedTimeFrame) {
      case 'Week':
        // For weekly view, find the index of today in the data
        for (int i = 0; i < _weeklyStepsData.length; i++) {
          final date = _weeklyStepsData[i]['date'] as DateTime;
          final dateFormatted = DateFormat('yyyy-MM-dd').format(date);
          if (dateFormatted == todayFormatted) {
            return i;
          }
        }
        // If today is not found, return the last index
        return _weeklyStepsData.length - 1;

      case 'Month':
        // For month view, find which week contains today
        final monthlyData = _getTransformedStepsData();

        // If no data, return -1
        if (monthlyData.isEmpty) return -1;

        // First, find which week today belongs to
        for (int i = 0; i < monthlyData.length; i++) {
          final weekStart = monthlyData[i]['date'] as DateTime;
          final weekEnd = weekStart.add(const Duration(days: 6));

          // Check if today falls within this week
          if (today.isAfter(weekStart.subtract(const Duration(days: 1))) &&
              today.isBefore(weekEnd.add(const Duration(days: 1)))) {
            return i;
          }
        }

        // If not found in any week, return the most recent week
        return monthlyData.length - 1;

      default:
        return _weeklyStepsData.length - 1;
    }
  }

  String _getDateRangeText() {
    if (_stepsData.isEmpty) return '';

    // Use transformed data to get correct date range
    final transformedData = _getTransformedStepsData();
    if (transformedData.isEmpty) return '';

    final startDate = transformedData.first['date'] as DateTime;
    final endDate = transformedData.last['date'] as DateTime;

    switch (_selectedTimeFrame) {
      case 'Month':
        // For monthly view (grouped by week), show the range of the month
        final firstDayOfMonth = DateTime(startDate.year, startDate.month, 1);
        final lastDayOfMonth = DateTime(endDate.year, endDate.month + 1, 0);
        return '${DateFormat('MMM d').format(firstDayOfMonth)} - ${DateFormat('MMM d, yyyy').format(lastDayOfMonth)}';
      default: // Week
        return '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)}';
    }
  }

  String _formatBarLabel(Map<String, dynamic> data) {
    final date = data['date'] as DateTime;

    switch (_selectedTimeFrame) {
      case 'Month':
        // For monthly view, just show a clean week number format
        // Get week number of the month
        int weekOfMonth = ((date.day - 1) ~/ 7) + 1;
        return 'W$weekOfMonth';
      default: // Week
        return DateFormat('d').format(date);
    }
  }

  String _getTooltipText(Map<String, dynamic> data) {
    final date = data['date'] as DateTime;

    switch (_selectedTimeFrame) {
      case 'Month':
        // Enhanced tooltip for monthly (weekly average) view
        final avgSteps = data['steps'] as int; // This is the weekly average
        final totalSteps = data['totalSteps'] as int;
        final daysCount = data['daysCount'] as int;
        final weekNumber = data['weekNumber'] as int;
        final weekEnd = date.add(const Duration(days: 6));

        // Calculate the percentage relative to the goal
        final goalPercentage = ((avgSteps / _stepGoal) * 100).round();

        String percentageLabel;
        if (goalPercentage >= 100) {
          percentageLabel = 'Goal achieved! ($goalPercentage%)';
        } else {
          percentageLabel = '$goalPercentage% of daily goal';
        }

        return 'Week $weekNumber: ${DateFormat('MMM d').format(date)} - ${DateFormat('MMM d').format(weekEnd)}\n'
            'Daily Average: ${NumberFormat.decimalPattern().format(avgSteps)} steps\n'
            'Total: ${NumberFormat.decimalPattern().format(totalSteps)} steps\n'
            'Active Days: $daysCount\n'
            '$percentageLabel';

      default: // Week
        final steps = data['steps'] as int;
        // Calculate the percentage relative to the goal
        final goalPercentage = ((steps / _stepGoal) * 100).round();

        String percentageLabel;
        if (goalPercentage >= 100) {
          percentageLabel = 'Goal achieved! ($goalPercentage%)';
        } else {
          percentageLabel = '$goalPercentage% of daily goal';
        }

        return '${DateFormat('EEEE, MMM d').format(date)}\n'
            '${NumberFormat.decimalPattern().format(steps)} steps\n'
            '$percentageLabel';
    }
  }

  String _getChartTitle() {
    switch (_selectedTimeFrame) {
      case 'Year':
        return 'Monthly Average Steps';
      case 'Month':
        return 'Weekly Average Steps';
      default: // Week
        return 'Daily Steps';
    }
  }

  List<Map<String, dynamic>> _getTransformedStepsData() {
    if (_selectedTimeFrame == 'Month') {
      // For monthly view, group by week for clearer visualization
      final weeklyData = <Map<String, dynamic>>[];

      // Sort data chronologically
      final sortedData = List<Map<String, dynamic>>.from(_monthlyStepsData)
        ..sort(
            (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      if (sortedData.isEmpty) {
        return [];
      }

      // Find the first and last dates in the data
      final firstDate = sortedData.first['date'] as DateTime;
      final lastDate = sortedData.last['date'] as DateTime;

      // Get the first day of the month for the first date
      final firstDayOfMonth = DateTime(firstDate.year, firstDate.month, 1);
      // Get last day of the month for visualization
      final lastDayOfMonth = DateTime(lastDate.year, lastDate.month + 1, 0);

      // Group steps data by week of month (weeks starting on Monday)
      // First, adjust firstDayOfMonth to the start of the week (Monday)
      final int firstWeekday =
          firstDayOfMonth.weekday; // 1 = Monday, 7 = Sunday
      final startOfFirstWeek =
          firstDayOfMonth.subtract(Duration(days: firstWeekday - 1));

      // Create map to store data per week
      final Map<int, Map<String, dynamic>> weekGroups = {};

      // Calculate weeks between start and end
      final int totalDays =
          lastDayOfMonth.difference(startOfFirstWeek).inDays + 1;
      final int totalWeeks = (totalDays / 7).ceil();

      // Initialize week groups for the entire month
      for (int i = 0; i < totalWeeks; i++) {
        final weekStart = startOfFirstWeek.add(Duration(days: i * 7));
        final weekNumber = i + 1;

        weekGroups[weekNumber] = {
          'date': weekStart,
          'totalSteps': 0,
          'daysCount': 0,
          'weekOfMonth': ((weekStart.day - 1) ~/ 7) + 1,
          'startDay': weekStart.day,
          'weekNumber': weekNumber,
        };
      }

      // Assign data to the corresponding week
      for (final data in sortedData) {
        final date = data['date'] as DateTime;
        final steps = data['steps'] as int;

        // Calculate which week this date belongs to
        final int daysSinceStart = date.difference(startOfFirstWeek).inDays;
        final int weekIndex = (daysSinceStart / 7).floor() + 1;

        if (weekGroups.containsKey(weekIndex)) {
          weekGroups[weekIndex]!['totalSteps'] =
              (weekGroups[weekIndex]!['totalSteps'] as int) + steps;
          weekGroups[weekIndex]!['daysCount'] =
              (weekGroups[weekIndex]!['daysCount'] as int) + 1;
        }
      }

      // Process all week groups into the final format
      weekGroups.forEach((weekNum, data) {
        final totalSteps = data['totalSteps'] as int;
        final daysCount = data['daysCount'] as int;
        final weekStart = data['date'] as DateTime;
        final weekOfMonth = data['weekOfMonth'] as int;

        // Only include weeks that have data
        if (daysCount > 0) {
          weeklyData.add({
            'date': weekStart,
            'steps': (totalSteps / daysCount)
                .round(), // Average daily steps for this week
            'weekOfMonth': weekOfMonth,
            'totalSteps': totalSteps,
            'daysCount': daysCount,
            'weekNumber': weekNum,
          });
        }
      });

      // Sort by date
      weeklyData.sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      return weeklyData;
    }

    // Default: Return daily data for the 'Week' timeframe
    return _weeklyStepsData;
  }

  @override
  bool get wantKeepAlive => true; // Keep the state alive

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;

    return Scaffold(
      appBar: widget.hideAppBar
          ? null
          : AppBar(
              title: Text(
                'Step Tracking',
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: customColors.textPrimary,
                ),
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
              systemOverlayStyle: theme.brightness == Brightness.light
                  ? SystemUiOverlayStyle.dark
                  : SystemUiOverlayStyle.light,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: customColors.textPrimary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTodayStepsCard(context, customColors),
                      const SizedBox(height: 24),
                      _buildTimeFrameSelector(customColors),
                      const SizedBox(height: 24),
                      _buildStepsChart(customColors),
                      const SizedBox(height: 24),
                      _buildStepsHistoryList(customColors),
                      const SizedBox(height: 16),
                      _buildActivityInsights(customColors),
                      const SizedBox(height: 50)
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildTodayStepsCard(BuildContext context, CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            customColors.cardBackground,
            customColors.cardBackground.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Today',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: customColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('EEEE, MMMM d').format(DateTime.now()),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: customColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _loadStepData();
                  },
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: customColors.accentPrimary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.refresh,
                      color: customColors.accentPrimary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0.0, end: _progressPercentage),
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Backdrop circle
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.grey.shade100
                                    : customColors.cardBackground,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.grey.shade200
                                    : customColors.cardBackground
                                        .withOpacity(0.1),
                                blurRadius: 5,
                                spreadRadius: 2,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                        ),
                        // Progress indicator
                        SizedBox(
                          width: 120,
                          height: 120,
                          child: CircularProgressIndicator(
                            value: value,
                            backgroundColor:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.grey.shade200
                                    : customColors.dateNavigatorBackground,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              value >= 1.0
                                  ? Colors.green
                                  : customColors.accentPrimary,
                            ),
                            strokeWidth: 12,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        // Central content
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: customColors.cardBackground,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.grey.shade200
                                    : customColors.cardBackground
                                        .withOpacity(0.3),
                                blurRadius: 3,
                                spreadRadius: 1,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TweenAnimationBuilder<int>(
                                tween: IntTween(begin: 0, end: _todaySteps),
                                duration: const Duration(seconds: 1),
                                builder: (context, value, child) {
                                  return Text(
                                    '$value',
                                    style: GoogleFonts.inter(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                      color: customColors.textPrimary,
                                    ),
                                  );
                                },
                              ),
                              Text(
                                'steps',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: customColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressItem(
                      context,
                      'Goal',
                      '$_stepGoal steps',
                      Icons.flag_rounded,
                      customColors,
                    ),
                    const SizedBox(height: 20),
                    _buildProgressItem(
                      context,
                      'Remaining',
                      '${(_stepGoal - _todaySteps) > 0 ? (_stepGoal - _todaySteps) : 0} steps',
                      Icons.directions_walk_rounded,
                      customColors,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_progressPercentage >= 1.0)
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.green.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.emoji_events_rounded,
                              color: Colors.green,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Congratulations! You\'ve reached your step goal today!',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    CustomColors customColors,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: customColors.accentPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: customColors.accentPrimary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: customColors.textSecondary,
              ),
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: customColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeFrameSelector(CustomColors customColors) {
    return Container(
      width: double.infinity, // Make container full width
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: customColors.dateNavigatorBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: ['Week', 'Month'].map((timeFrame) {
          final isSelected = _selectedTimeFrame == timeFrame;
          return Expanded(
            // Make each button take equal space
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                child: TextButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedTimeFrame = timeFrame;
                      _updateCurrentStepsData();
                    });
                  },
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all(
                      isSelected
                          ? customColors.cardBackground
                          : Colors.transparent,
                    ),
                    shape: MaterialStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    padding: MaterialStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    overlayColor: MaterialStateProperty.all(
                      customColors.accentPrimary.withOpacity(0.05),
                    ),
                  ),
                  child: Text(
                    timeFrame,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? customColors.accentPrimary
                          : customColors.textPrimary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  double _calculateBarWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 80.0; // Account for padding and y-axis
    final dataLength = _getTransformedStepsData().length;
    if (dataLength == 0) return 24.0; // Default width if no data

    switch (_selectedTimeFrame) {
      case 'Month':
        // For monthly view, use wider bars since there are fewer data points (weeks)
        return math.min((availableWidth / dataLength) - 6.0, 40.0);
      default: // Week
        // For weekly view, balanced width for 7 days
        return math.min((availableWidth / dataLength) - 4.0, 32.0);
    }
  }

  Widget _buildStepsChart(CustomColors customColors) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final transformedData = _getTransformedStepsData();
        final barWidth = _calculateBarWidth(context);
        final spacing = _selectedTimeFrame == 'Month'
            ? 10.0
            : 8.0; // More spacing for month view

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: customColors.cardBackground,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedTimeFrame == 'Month'
                          ? 'Weekly Average Steps'
                          : 'Daily Steps',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: customColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    _getDateRangeText(),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: customColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 300,
                child: CustomBarChart(
                  data: transformedData,
                  primaryColor: customColors.accentPrimary,
                  textColor: customColors.textPrimary,
                  secondaryTextColor: customColors.textSecondary,
                  maxValue: _getMaxSteps(),
                  labelExtractor: (data) => _formatBarLabel(data),
                  valueExtractor: (data) => (data['steps'] as int).toDouble(),
                  todayIndex: _getTodayIndex(),
                  showGoalLine: true,
                  goalValue: _getGoalValueForTimeFrame(),
                  goalLineColor: Colors.red.withOpacity(0.6),
                  enableColorCoding: true,
                  timeFrame: _selectedTimeFrame,
                  goalLabel: _getGoalLabelForTimeFrame(),
                  barWidth: barWidth,
                  barSpacing: spacing,
                  onBarTap: (index) {
                    // Validate that we're accessing the correct index
                    if (index < 0 || index >= transformedData.length) return;

                    // Get data for the tapped index - no adjustment needed
                    final data = transformedData[index];
                    final date = data['date'] as DateTime;
                    print(
                        'Showing data for ${DateFormat('yyyy-MM-dd').format(date)}');

                    HapticFeedback.selectionClick();
                    // ScaffoldMessenger.of(context).clearSnackBars();
                    // ScaffoldMessenger.of(context).showSnackBar(
                    //   SnackBar(
                    //     content: Text(
                    //       _getTooltipText(data),
                    //       style: GoogleFonts.inter(
                    //         fontSize: 14,
                    //         color: Colors.white,
                    //       ),
                    //     ),
                    //     backgroundColor: customColors.accentPrimary,
                    //     duration: const Duration(seconds: 3),
                    //     behavior: SnackBarBehavior.floating,
                    //     shape: RoundedRectangleBorder(
                    //       borderRadius: BorderRadius.circular(10),
                    //     ),
                    //     margin: const EdgeInsets.all(8),
                    //   ),
                    // );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStepsHistoryList(CustomColors customColors) {
    // Get the appropriate data based on selected timeframe
    final List<Map<String, dynamic>> dataToDisplay = _getTransformedStepsData();

    // Sort data to show most recent first
    final sortedData = List<Map<String, dynamic>>.from(dataToDisplay)
      ..sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    // Set appropriate list title based on time frame
    String listTitle;
    switch (_selectedTimeFrame) {
      case 'Week':
        listTitle = 'Daily Activity';
        break;
      case 'Month':
        listTitle = 'Weekly Average Activity';
        break;
      default:
        listTitle = 'Activity History';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            listTitle,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: customColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (sortedData.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.directions_walk_outlined,
                      size: 40,
                      color: customColors.textSecondary.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No step data available for this period.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: customColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...sortedData.take(10).map((data) {
              final date = data['date'] as DateTime;
              final steps = data['steps'] as int;
              final percentage = steps / _stepGoal;

              final isToday = DateFormat('yyyy-MM-dd').format(date) ==
                  DateFormat('yyyy-MM-dd').format(DateTime.now());

              // Format the date display based on the timeframe
              Widget dateDisplay;
              String periodLabel;
              String stepsLabel;

              if (_selectedTimeFrame == 'Month') {
                // For monthly (weekly average) view
                final weekEnd = date.add(const Duration(days: 6));
                dateDisplay = Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('d').format(date),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: customColors.textPrimary,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(date),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: customColors.textSecondary,
                      ),
                    ),
                  ],
                );
                periodLabel =
                    '${DateFormat('MMM d').format(date)} - ${DateFormat('d').format(weekEnd)}';
                stepsLabel = 'avg/day';
              } else {
                // For week (daily) view
                dateDisplay = Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      DateFormat('d').format(date),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: customColors.textPrimary,
                      ),
                    ),
                    Text(
                      DateFormat('MMM').format(date),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: customColors.textSecondary,
                      ),
                    ),
                  ],
                );
                periodLabel =
                    isToday ? 'Today' : DateFormat('EEEE').format(date);
                stepsLabel = 'steps';
              }

              // Define color for progress bar
              Color progressColor;
              if (percentage >= 1.0) {
                progressColor = Colors.green;
              } else if (percentage >= 0.7) {
                progressColor = Colors.orange;
              } else {
                progressColor = Colors.red.shade400;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        color: customColors.dateNavigatorBackground,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: dateDisplay,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            periodLabel,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: customColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          LinearProgressIndicator(
                            value: percentage > 1.0 ? 1.0 : percentage,
                            backgroundColor: Colors.grey.withOpacity(0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              progressColor,
                            ),
                            minHeight: 6,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat.decimalPattern().format(steps),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: customColors.textPrimary,
                          ),
                        ),
                        Text(
                          stepsLabel,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: customColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          if (sortedData.length > 10)
            Align(
              alignment: Alignment.center,
              child: TextButton.icon(
                onPressed: () {
                  // TODO: Implement a "view all" screen or scrollable list
                  HapticFeedback.selectionClick();
                },
                icon: Icon(
                  Icons.visibility_outlined,
                  size: 18,
                  color: customColors.accentPrimary,
                ),
                label: Text(
                  'View all ${sortedData.length} entries',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: customColors.accentPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActivityInsights(CustomColors customColors) {
    // Use transformed data for calculations
    final transformedData = _getTransformedStepsData();
    if (transformedData.isEmpty) {
      // Return an empty container or a placeholder if no data
      return Container();
    }

    // Calculate average steps based on timeframe
    double avgSteps = 0;
    if (_selectedTimeFrame == 'Month') {
      // Average of the weekly daily averages
      int totalAvgSteps = 0;
      for (final data in transformedData) {
        totalAvgSteps += data['steps'] as int; // 'steps' holds weekly avg here
      }
      avgSteps = totalAvgSteps / transformedData.length;
    } else {
      // Direct average for daily steps in 'Week' view
      int totalSteps = 0;
      for (final data in transformedData) {
        totalSteps += data['steps'] as int;
      }
      avgSteps = totalSteps / transformedData.length;
    }

    // Determine if trending up or down
    bool? trendingUp;
    String trendMessage = '';

    // Customize trend message based on timeframe using transformedData
    if (transformedData.length >= 3) {
      if (_selectedTimeFrame == 'Month') {
        // Compare the first and last weeks in the displayed monthly data
        final firstWeekAvg = transformedData.first['steps'] as int;
        final lastWeekAvg = transformedData.last['steps'] as int;

        trendingUp = lastWeekAvg > firstWeekAvg;
        final percentChange = firstWeekAvg > 0
            ? ((lastWeekAvg - firstWeekAvg) / firstWeekAvg * 100).abs()
            : 0;

        if (percentChange >= 5) {
          if (trendingUp) {
            trendMessage =
                'Your weekly average is trending up! ${percentChange.toStringAsFixed(0)}% increase over the last month.';
          } else {
            trendMessage =
                'Your weekly average has decreased by ${percentChange.toStringAsFixed(0)}% over the last month.';
          }
        }
      } else {
        // Week
        // Compare first and last days in the displayed weekly data
        final firstDaySteps = transformedData.first['steps'] as int;
        final lastDaySteps = transformedData.last['steps'] as int;

        trendingUp = lastDaySteps > firstDaySteps;
        final percentChange = firstDaySteps > 0
            ? ((lastDaySteps - firstDaySteps) / firstDaySteps * 100).abs()
            : 0;

        if (percentChange >= 10) {
          if (trendingUp) {
            trendMessage =
                'You\'re walking more! Up ${percentChange.toStringAsFixed(0)}% from earlier this week.';
          } else {
            trendMessage =
                'Your steps are down ${percentChange.toStringAsFixed(0)}% from earlier this week.';
          }
        }
      }
    }

    // Calculate appropriate average label based on timeframe
    String avgPeriod;
    int displayedAvg = avgSteps.round(); // Round the average

    switch (_selectedTimeFrame) {
      case 'Month':
        avgPeriod = 'Avg Daily Steps (Monthly)';
        break;
      case 'Week':
      default:
        avgPeriod = 'Avg Daily Steps (Week)';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Insights',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: customColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: customColors.accentPrimary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.insert_chart_outlined,
                  color: customColors.accentPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      avgPeriod,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: customColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${NumberFormat.decimalPattern().format(displayedAvg)} steps',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: customColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (trendMessage.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (trendingUp ?? false)
                    ? Colors.green.withOpacity(0.12)
                    : Colors.orange.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    (trendingUp ?? false)
                        ? Icons.trending_up
                        : Icons.trending_down,
                    color: (trendingUp ?? false) ? Colors.green : Colors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      trendMessage,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: (trendingUp ?? false)
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: () {
              // Show edit goal dialog
              HapticFeedback.selectionClick();
              _showEditGoalDialog(context, customColors);
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: customColors.accentPrimary.withOpacity(0.08),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: Icon(
              Icons.edit,
              size: 18,
              color: customColors.accentPrimary,
            ),
            label: Text(
              'Edit Step Goal ($_stepGoal)', // Show current goal
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: customColors.accentPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditGoalDialog(
    BuildContext context,
    CustomColors customColors,
  ) async {
    final TextEditingController controller =
        TextEditingController(text: _stepGoal.toString());
    int newGoal = _stepGoal;

    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Edit Step Goal',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: customColors.textPrimary,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Set your daily step goal to keep you motivated and active.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: customColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Enter your daily step goal',
                  prefixIcon: Icon(
                    Icons.directions_walk,
                    color: customColors.accentPrimary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: customColors.accentPrimary.withOpacity(0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: customColors.textSecondary.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: customColors.accentPrimary,
                      width: 2,
                    ),
                  ),
                ),
                onChanged: (value) {
                  newGoal = int.tryParse(value) ?? _stepGoal;
                },
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                autofocus: true,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  color: customColors.textPrimary,
                ),
              ),
            ],
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: customColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (newGoal > 0) {
                  // Ensure goal is positive
                  setState(() {
                    _stepGoal = newGoal;
                    _progressPercentage = _todaySteps / _stepGoal;
                    if (_progressPercentage > 1.0) _progressPercentage = 1.0;
                  });
                  HapticFeedback.lightImpact();
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: customColors.accentPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        );
      },
    );
  }
}

// --- CustomBarChart Widget ---
class CustomBarChart extends StatefulWidget {
  final List<Map<String, dynamic>> data;
  final Color primaryColor;
  final Color textColor;
  final Color secondaryTextColor;
  final double maxValue;
  final String Function(Map<String, dynamic>) labelExtractor;
  final double Function(Map<String, dynamic>) valueExtractor;
  final int todayIndex;
  final Function(int)? onBarTap;
  final bool showGoalLine;
  final double goalValue;
  final Color goalLineColor;
  final bool enableColorCoding;
  final String timeFrame;
  final String? goalLabel;
  final double barWidth;
  final double barSpacing;

  const CustomBarChart({
    Key? key,
    required this.data,
    required this.primaryColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.maxValue,
    required this.labelExtractor,
    required this.valueExtractor,
    required this.todayIndex,
    this.onBarTap,
    this.showGoalLine = false,
    this.goalValue = 0.0,
    this.goalLineColor = Colors.red,
    this.enableColorCoding = true,
    required this.timeFrame,
    this.goalLabel,
    this.barWidth = 20.0,
    this.barSpacing = 10.0,
  }) : super(key: key);

  @override
  State<CustomBarChart> createState() => _BarChartState();
}

class _BarChartState extends State<CustomBarChart>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late AnimationController _animationController;
  int? _highlightedIndex;
  bool _showTooltip = false;
  Timer? _tooltipTimer; // Add this field
  final ScrollController _scrollController = ScrollController();
  final ScrollController _labelsScrollController = ScrollController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _animationController.forward();

    // Set highlighted index to today initially
    if (widget.todayIndex >= 0) {
      _highlightedIndex = widget.todayIndex;
    }

    // Sync scroll controllers
    _scrollController.addListener(() {
      if (_scrollController.hasClients && _labelsScrollController.hasClients) {
        _labelsScrollController.jumpTo(_scrollController.offset);
      }
    });

    // Make sure we're scrolled to a good position initially
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.todayIndex >= 0) {
        final barWidth = widget.barWidth + widget.barSpacing;
        final maxScroll = _scrollController.position.maxScrollExtent;

        // Scroll to position where today is visible, with a few bars before it
        final targetScroll = math.max(
            0.0, math.min(maxScroll, (widget.todayIndex - 1) * barWidth));

        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            targetScroll,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    _labelsScrollController.dispose();
    _tooltipTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  // Format large numbers with K suffix
  String _formatYAxisValue(double value) {
    if (value.isNaN || value.isInfinite) return "0"; // Handle invalid values
    if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;

    // Handle case where maxValue is zero or invalid
    final effectiveMaxValue = (widget.maxValue <= 0 ||
            widget.maxValue.isNaN ||
            widget.maxValue.isInfinite)
        ? widget.goalValue * 1.2 // Use goal as fallback
        : widget.maxValue;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight =
            constraints.maxHeight - 65; // Space for x-axis labels
        final yAxisLabelWidth = 45.0;
        final chartAreaWidth = constraints.maxWidth - yAxisLabelWidth;

        // Generate y-axis label values
        final yAxisSteps = 5;

        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Y-axis labels
                  SizedBox(
                    width: yAxisLabelWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ...List.generate(yAxisSteps, (i) {
                          final value = effectiveMaxValue -
                              (i / yAxisSteps * effectiveMaxValue);
                          final label = _formatYAxisValue(value);
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              label,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: widget.secondaryTextColor,
                              ),
                            ),
                          );
                        }),
                        // Bottom value (0)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            "0",
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: widget.secondaryTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Chart area (Scrollable)
                  Expanded(
                    child: GestureDetector(
                      onTapDown: (details) {
                        final RenderBox box =
                            context.findRenderObject() as RenderBox;
                        final localPosition =
                            box.globalToLocal(details.globalPosition);
                        final scrollOffset = _scrollController.offset;
                        final tapX = localPosition.dx + scrollOffset;

                        if (tapX >= 0 &&
                            localPosition.dy >= 0 &&
                            localPosition.dy <= chartHeight) {
                          // Fix: Calculate the correct bar index
                          // Each bar takes up barWidth + barSpacing horizontal space
                          final totalBarWidth =
                              widget.barWidth + widget.barSpacing;

                          // Calculate which bar was tapped by dividing the x-coordinate by the total width of each bar
                          final barIndex = (tapX / totalBarWidth).floor();

                          // Debug the tap position
                          print('Tap x: $tapX, calculated index: $barIndex');

                          // Ensure the index is valid
                          if (barIndex >= 0 && barIndex < widget.data.length) {
                            HapticFeedback.lightImpact();

                            // Set the highlighted index to the tapped bar
                            setState(() {
                              _highlightedIndex = barIndex - 1;
                              _showTooltip = true;
                            });

                            // Call the onBarTap callback with the correct index
                            widget.onBarTap?.call(barIndex);

                            // Hide tooltip after a delay
                            _tooltipTimer?.cancel(); // Cancel previous timer
                            _tooltipTimer = Timer(const Duration(seconds: 2), () {
                              if (mounted && _highlightedIndex == barIndex) {
                                setState(() {
                                  _showTooltip = false;
                                });
                              }
                            });
                          }
                        }
                      },
                      onHorizontalDragStart: (_) {
                        if (_showTooltip) {
                          setState(() {
                            _showTooltip = false;
                          }); // Hide tooltip on scroll start
                        }
                      },
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Stack(
                          children: [
                            CustomPaint(
                              size: Size(
                                  widget.data.length *
                                      (widget.barWidth +
                                          widget
                                              .barSpacing), // Total width based on data
                                  chartHeight),
                              painter: GridPainter(
                                maxValue: effectiveMaxValue,
                                lineColor: Colors.grey.withOpacity(0.15),
                                textColor: widget.secondaryTextColor,
                                steps: yAxisSteps,
                                showGoalLine: widget.showGoalLine,
                                goalValue: widget.goalValue,
                                goalLineColor: widget.goalLineColor,
                                goalLabel: widget.goalLabel,
                              ),
                            ),
                            Container(
                              height: chartHeight,
                              padding: const EdgeInsets.only(
                                  right: 10.0), // Ensure last bar isn't cut off
                              child: AnimatedBuilder(
                                animation: _animationController,
                                builder: (context, child) {
                                  final animationValue = Curves.easeOutCubic
                                      .transform(_animationController.value);

                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .start, // Align bars to the start
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: List.generate(widget.data.length,
                                        (index) {
                                      final value = widget
                                          .valueExtractor(widget.data[index]);
                                      // Handle potential NaN or infinite values
                                      final safeValue =
                                          (value.isNaN || value.isInfinite)
                                              ? 0.0
                                              : value;
                                      final normalized = effectiveMaxValue > 0
                                          ? safeValue / effectiveMaxValue
                                          : 0.0;
                                      final barHeight = math.max(
                                          0.0,
                                          chartHeight *
                                              normalized *
                                              animationValue); // Ensure non-negative height
                                      final isToday =
                                          index == widget.todayIndex;
                                      final isHighlighted =
                                          _highlightedIndex == index;

                                      // Define color based on steps compared to goal
                                      Color barColor;
                                      Color gradientEndColor;

                                      if (widget.enableColorCoding &&
                                          widget.goalValue > 0) {
                                        final percentOfGoal =
                                            safeValue / widget.goalValue;
                                        if (percentOfGoal >= 1.0) {
                                          barColor = Colors.green;
                                          gradientEndColor =
                                              Colors.green.shade700;
                                        } else if (percentOfGoal >= 0.7) {
                                          barColor = Colors.orange;
                                          gradientEndColor =
                                              Colors.orange.shade800;
                                        } else {
                                          barColor = Colors.red.shade400;
                                          gradientEndColor =
                                              Colors.red.shade700;
                                        }
                                      } else {
                                        barColor = widget.primaryColor;
                                        gradientEndColor = Color.lerp(
                                            widget.primaryColor,
                                            Colors.black,
                                            0.3)!;
                                      }

                                      // Add week number indicator for month view
                                      Widget weekIndicator;
                                      if (widget.timeFrame == 'Month' &&
                                          isHighlighted) {
                                        weekIndicator = Container(
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: barColor.withOpacity(0.2),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            // Use label directly for cleaner look
                                            widget.labelExtractor(
                                                widget.data[index]),
                                            style: GoogleFonts.inter(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: barColor,
                                            ),
                                          ),
                                        );
                                      } else {
                                        weekIndicator = const SizedBox.shrink();
                                      }

                                      return Padding(
                                        padding: EdgeInsets.only(
                                            right: widget
                                                .barSpacing), // Add spacing between bars
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          mainAxisSize: MainAxisSize
                                              .min, // Add this to prevent overflow
                                          children: [
                                            // Week indicator for month view (above tooltip)
                                            weekIndicator,
                                            // Tooltip shown above the bar with constrained height
                                            if (isHighlighted && _showTooltip)
                                              ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxHeight:
                                                      28.0, // Limit tooltip height
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  margin: const EdgeInsets.only(
                                                      bottom: 5),
                                                  decoration: BoxDecoration(
                                                      color: barColor,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withOpacity(0.2),
                                                          blurRadius: 4,
                                                          offset: const Offset(
                                                              0, 2),
                                                        )
                                                      ]),
                                                  child: Text(
                                                    _formatYAxisValue(
                                                        safeValue),
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            // The bar itself with gradient & constraints
                                            ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxHeight:
                                                    chartHeight, // Ensure bar doesn't exceed chart height
                                              ),
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 150),
                                                width: widget.barWidth,
                                                height: math.max(barHeight,
                                                    2.0), // Ensure minimum height for visibility
                                                decoration: BoxDecoration(
                                                  gradient: barHeight <= 2.0 ||
                                                          widget.barWidth <= 2.0
                                                      ? null
                                                      : LinearGradient(
                                                          begin: Alignment
                                                              .bottomCenter,
                                                          end: Alignment
                                                              .topCenter,
                                                          colors: [
                                                            barColor,
                                                            gradientEndColor,
                                                          ],
                                                          stops: const [
                                                            0.0,
                                                            1.0
                                                          ],
                                                        ),
                                                  color: barHeight <= 2.0 ||
                                                          widget.barWidth <= 2.0
                                                      ? barColor
                                                      : null, // Use solid color for tiny bars
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  boxShadow:
                                                      isHighlighted || isToday
                                                          ? [
                                                              BoxShadow(
                                                                color: barColor
                                                                    .withOpacity(
                                                                        0.3),
                                                                blurRadius: 8,
                                                                offset:
                                                                    const Offset(
                                                                        0, 1),
                                                              ),
                                                            ]
                                                          : null,
                                                ),
                                                constraints: BoxConstraints(
                                                  minWidth: 2.0,
                                                  minHeight: 2.0,
                                                ),
                                              ),
                                            ),
                                            // Small indicator for today's bar for better identification
                                            if (isToday)
                                              SizedBox(
                                                height:
                                                    10, // Fixed height for the indicator container
                                                child: Container(
                                                  margin: const EdgeInsets.only(
                                                      top: 4),
                                                  width: 6,
                                                  height: 6,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: barColor,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    }),
                                  );
                                },
                              ),
                            ),
                            // X-axis line (drawn separately to be under bars)
                            // Conditionally render the line only if data exists
                            if (widget.data.isNotEmpty)
                              Positioned(
                                bottom: 0,
                                left: 0,
                                // Use width instead of right: 0 to avoid assertion
                                width: widget.data.length *
                                    (widget.barWidth + widget.barSpacing),
                                child: Container(
                                  height: 1,
                                  color: widget.textColor.withOpacity(0.15),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // X-axis labels (Scrollable, synced with bars)
            SizedBox(
              height: 55, // Increased space for rotated labels
              child: Padding(
                padding: EdgeInsets.only(
                    left: yAxisLabelWidth), // Align with chart area
                child: SingleChildScrollView(
                  controller:
                      _labelsScrollController, // Use the separate controller
                  scrollDirection: Axis.horizontal,
                  physics:
                      const NeverScrollableScrollPhysics(), // Disable direct scrolling on labels
                  child: Container(
                    padding: const EdgeInsets.only(
                        right: 10.0, top: 8), // Match bar padding + top margin
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment:
                          CrossAxisAlignment.start, // Align text to top
                      children: List.generate(widget.data.length, (index) {
                        final label = widget.labelExtractor(widget.data[index]);
                        final isToday = index == widget.todayIndex;
                        final isHighlighted = _highlightedIndex == index;

                        // Enhanced label styling for month view
                        if (widget.timeFrame == 'Month') {
                          final date = widget.data[index]['date'] as DateTime;
                          final weekEnd = date.add(const Duration(days: 6));

                          return Container(
                            width: widget.barWidth +
                                widget.barSpacing, // Width includes spacing
                            padding: EdgeInsets.only(
                                right: widget.barSpacing), // Apply spacing here
                            alignment: Alignment.topCenter,
                            child: Column(
                              children: [
                                Text(
                                  label,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: isToday || isHighlighted
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isToday
                                        ? widget.primaryColor
                                        : isHighlighted
                                            ? widget.textColor
                                            : widget.secondaryTextColor,
                                  ),
                                ),
                                Text(
                                  '${date.day}-${weekEnd.day}',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: isHighlighted || isToday
                                        ? widget.textColor.withOpacity(0.8)
                                        : widget.secondaryTextColor
                                            .withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Default label for week view
                        return Container(
                          width: widget.barWidth +
                              widget.barSpacing, // Width includes spacing
                          padding: EdgeInsets.only(
                              right: widget.barSpacing), // Apply spacing here
                          alignment:
                              Alignment.topCenter, // Center label under the bar
                          child: Text(
                            label,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.visible,
                            style: GoogleFonts.inter(
                              fontSize:
                                  12, // Slightly larger for better readability
                              fontWeight: isToday || isHighlighted
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: isToday
                                  ? widget.primaryColor
                                  : isHighlighted
                                      ? widget.textColor
                                      : widget.secondaryTextColor,
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// --- GridPainter ---
class GridPainter extends CustomPainter {
  final double maxValue;
  final Color lineColor;
  final Color textColor;
  final int steps;
  final bool showGoalLine;
  final double goalValue;
  final Color goalLineColor;
  final String? goalLabel;

  GridPainter({
    required this.maxValue,
    required this.lineColor,
    required this.textColor,
    required this.steps,
    this.showGoalLine = false,
    this.goalValue = 0.0,
    this.goalLineColor = Colors.red,
    this.goalLabel,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0)
      return; // Avoid painting on zero size

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.8 // Thinner lines for a cleaner look
      ..style = PaintingStyle.stroke;

    final dashArray = [3, 4]; // Adjusted dash pattern

    // Draw horizontal grid lines
    for (int i = 0; i <= steps; i++) {
      final y = size.height - (i / steps * size.height);

      // Skip the bottom line (it's drawn separately)
      if (i == 0) continue;

      // Draw dashed horizontal line
      double startX = 0;
      final path = Path()..moveTo(startX, y);
      while (startX < size.width) {
        startX += dashArray[0];
        path.lineTo(math.min(startX, size.width), y);
        startX += dashArray[1];
        path.moveTo(math.min(startX, size.width), y);
      }
      canvas.drawPath(path, paint);
    }

    // Draw vertical axis line (Y-axis)
    final axisLinePaint = Paint()
      ..color = textColor.withOpacity(0.25) // Lighter axis line
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axisLinePaint);

    // Draw goal line if enabled and valid
    if (showGoalLine && goalValue > 0 && maxValue > 0) {
      final goalY = size.height - (goalValue / maxValue * size.height);

      if (goalY >= 0 && goalY <= size.height) {
        // Ensure goal line is within bounds
        final goalPaint = Paint()
          ..color = goalLineColor
          ..strokeWidth = 1.2 // Adjusted goal line thickness
          ..style = PaintingStyle.stroke;

        // Create dashed line for goal
        double startX = 0;
        final goalPath = Path()..moveTo(startX, goalY);
        final goalDashArray = [6, 4]; // Different dash pattern for distinction
        while (startX < size.width) {
          startX += goalDashArray[0];
          goalPath.lineTo(math.min(startX, size.width), goalY);
          startX += goalDashArray[1];
          goalPath.moveTo(math.min(startX, size.width), goalY);
        }
        canvas.drawPath(goalPath, goalPaint);

        // Add a small label for the goal line
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: 'Goal',
            style: TextStyle(
              color: goalLineColor,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        );

        textPainter.layout(minWidth: 0, maxWidth: 40);
        textPainter.paint(
          canvas,
          Offset(5, goalY - textPainter.height - 2),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant GridPainter oldDelegate) =>
      oldDelegate.maxValue != maxValue ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.textColor != textColor ||
      oldDelegate.steps != steps ||
      oldDelegate.showGoalLine != showGoalLine ||
      oldDelegate.goalValue != goalValue ||
      oldDelegate.goalLineColor != goalLineColor;
}
