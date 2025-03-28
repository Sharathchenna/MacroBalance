import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../Health/Health.dart';
import '../theme/app_theme.dart';

class StepTrackingScreen extends StatefulWidget {
  final bool hideAppBar;

  const StepTrackingScreen({
    Key? key,
    this.hideAppBar = false,
  }) : super(key: key);

  @override
  State<StepTrackingScreen> createState() => _StepTrackingScreenState();
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
  List<Map<String, dynamic>> _yearlyStepsData = [];

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

      // Load data for all time frames at once for smoother UX when switching
      final weeklyStepsData = await _healthService.getStepsForLastWeek();
      final monthlyStepsData = await _healthService.getStepsForLastMonth();
      final yearlyStepsData = await _healthService.getStepsForLastYear();

      setState(() {
        _todaySteps = todaySteps;
        _weeklyStepsData = weeklyStepsData;
        _monthlyStepsData = monthlyStepsData;
        _yearlyStepsData = yearlyStepsData;

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
      case 'Year':
        _stepsData = _yearlyStepsData;
        break;
      default:
        _stepsData = _weeklyStepsData;
    }
  }

  // Calculate nice rounded values for the y-axis based on time frame
  List<double> _calculateYAxisValues(double maxValue, int stepCount) {
    // Find a nice rounded maximum that's at least 10% higher than the actual max
    final double adjustedMax = maxValue * 1.1;

    // Round up to a nice number based on scale
    double roundedMax;
    if (adjustedMax < 50) {
      roundedMax = (adjustedMax / 5).ceil() * 5; // Round to nearest 5
    } else if (adjustedMax < 100) {
      roundedMax = (adjustedMax / 10).ceil() * 10; // Round to nearest 10
    } else if (adjustedMax < 1000) {
      roundedMax = (adjustedMax / 100).ceil() * 100; // Round to nearest 100
    } else if (adjustedMax < 10000) {
      roundedMax = (adjustedMax / 1000).ceil() * 1000; // Round to nearest 1000
    } else {
      roundedMax = (adjustedMax / 5000).ceil() * 5000; // Round to nearest 5000
    }

    // Calculate step values
    final step = roundedMax / stepCount;
    return List.generate(stepCount + 1, (i) => step * i);
  }

  double _getMaxSteps() {
    if (_stepsData.isEmpty)
      return _stepGoal * 1.2; // Default value with padding

    // Get the maximum step value from the data
    final maxSteps = _stepsData
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
      case 'Year':
        // For yearly view, calculate average daily steps per month (daily goal * average days in month)
        return _stepGoal * 30.4; // Average days in a month (365/12)
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
      case 'Year':
        return 'Monthly Goal';
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
        // For monthly view, we now use individual days
        final monthlyData = _getTransformedStepsData();
        for (int i = 0; i < monthlyData.length; i++) {
          final date = monthlyData[i]['date'] as DateTime;
          final dateFormatted = DateFormat('yyyy-MM-dd').format(date);
          if (dateFormatted == todayFormatted) {
            return i;
          }
        }
        // If today is not found, return the last index
        return monthlyData.length - 1;

      case 'Year':
        // For yearly view, find the index of the current month
        final currentMonth = today.month;
        final currentYear = today.year;

        final yearlyData = _getTransformedStepsData();
        for (int i = 0; i < yearlyData.length; i++) {
          final date = yearlyData[i]['date'] as DateTime;
          if (date.month == currentMonth && date.year == currentYear) {
            return i;
          }
        }
        // If current month is not found, return the last index
        return yearlyData.length - 1;

      default:
        return _weeklyStepsData.length - 1;
    }
  }

  String _getDateRangeText() {
    if (_stepsData.isEmpty) return '';

    final startDate = _stepsData.first['date'] as DateTime;
    final endDate = _stepsData.last['date'] as DateTime;

    if (_selectedTimeFrame == 'Year') {
      return '${DateFormat('MMM yyyy').format(startDate)} - ${DateFormat('MMM yyyy').format(endDate)}';
    } else {
      return '${DateFormat('MMM d').format(startDate)} - ${DateFormat('MMM d').format(endDate)}';
    }
  }

  List<Map<String, dynamic>> _getTransformedStepsData() {
    if (_selectedTimeFrame == 'Year') {
      // Rewrite logic to calculate monthly averages for yearly chart
      final monthlyData = <Map<String, dynamic>>[];

      // Group data by month and calculate average daily steps
      final Map<String, Map<String, dynamic>> monthlyGroups = {};

      for (final data in _stepsData) {
        final date = data['date'] as DateTime;
        final steps = data['steps'] as int? ?? 0; // Add null safety
        final monthKey =
            '${date.year}-${date.month.toString().padLeft(2, '0')}';

        if (!monthlyGroups.containsKey(monthKey)) {
          monthlyGroups[monthKey] = {
            'month': DateFormat('MMM').format(date),
            'totalSteps': 0,
            'daysCount': 0,
            'date': DateTime(date.year, date.month, 1),
          };
        }

        final currentTotal = monthlyGroups[monthKey]!['totalSteps'] as int? ??
            0; // Add null safety
        final currentCount = monthlyGroups[monthKey]!['daysCount'] as int? ??
            0; // Add null safety

        monthlyGroups[monthKey]!['totalSteps'] = currentTotal + steps;
        monthlyGroups[monthKey]!['daysCount'] = currentCount + 1;
      }

      // Calculate averages and prepare data for the chart
      for (final entry in monthlyGroups.entries) {
        final monthData = entry.value;
        final totalSteps =
            monthData['totalSteps'] as int? ?? 0; // Add null safety
        final daysCount =
            monthData['daysCount'] as int? ?? 0; // Add null safety
        final averageSteps =
            daysCount > 0 ? (totalSteps / daysCount).round() : 0;

        monthlyData.add({
          'month': monthData['month'],
          'steps': averageSteps,
          'date': monthData['date'],
          'daysCount': daysCount,
          'totalSteps': totalSteps, // Include this for detailed view
        });
      }

      // Sort data by date
      monthlyData.sort(
          (a, b) => (a['date'] as DateTime).compareTo(b['date'] as DateTime));

      return monthlyData;
    }

    return _stepsData;
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
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: customColors.dateNavigatorBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['Week', 'Month', 'Year'].map((timeFrame) {
          final isSelected = _selectedTimeFrame == timeFrame;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: TextButton(
                onPressed: () {
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
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  overlayColor: MaterialStateProperty.all(
                    customColors.accentPrimary.withOpacity(0.05),
                  ),
                ),
                child: Text(
                  timeFrame,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? customColors.accentPrimary
                        : customColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStepsChart(CustomColors customColors) {
    String chartTitle;
    String labelExtractorField;

    // Set appropriate chart title and label extractor based on time frame
    switch (_selectedTimeFrame) {
      case 'Week':
        chartTitle = 'Daily Steps';
        labelExtractorField = 'day';
        break;
      case 'Month':
        chartTitle = 'Daily Activity (30 Days)';
        labelExtractorField = 'day';
        break;
      case 'Year':
        chartTitle = 'Monthly Average Daily Steps';
        labelExtractorField = 'month';
        break;
      default:
        chartTitle = 'Step History';
        labelExtractorField = 'day';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
              Text(
                chartTitle,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: customColors.textPrimary,
                ),
              ),
              // Add date range display
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
            height: 220,
            child: CustomBarChart(
              data: _getTransformedStepsData(),
              primaryColor: customColors.accentPrimary,
              textColor: customColors.textPrimary,
              secondaryTextColor: customColors.textSecondary,
              maxValue: _getMaxSteps(),
              labelExtractor: (data) => data[labelExtractorField] as String,
              valueExtractor: (data) => (data['steps'] as int).toDouble(),
              todayIndex: _getTodayIndex(),
              showGoalLine: true,
              goalValue: _getGoalValueForTimeFrame(),
              goalLineColor: Colors.red.withOpacity(0.5),
              enableColorCoding: true,
              timeFrame: _selectedTimeFrame,
              goalLabel: _getGoalLabelForTimeFrame(),
              onBarTap: (index) {
                // Show detailed information for the selected period
                final data = _getTransformedStepsData()[index];
                final steps = data['steps'] as int;
                final date = data['date'] as DateTime;

                String message;
                if (_selectedTimeFrame == 'Year') {
                  // For yearly view: Average daily steps in this month
                  final daysCount = data['daysCount'] as int;
                  final totalSteps = data['totalSteps'] as int;

                  message =
                      'Average ${NumberFormat.decimalPattern().format(steps)} steps per day in ${DateFormat('MMMM yyyy').format(date)}.\n'
                      'Total ${NumberFormat.decimalPattern().format(totalSteps)} steps over $daysCount days.';
                } else if (_selectedTimeFrame == 'Month' &&
                    data['isDay'] == true) {
                  // For monthly view: Daily steps on this specific day
                  message =
                      '${NumberFormat.decimalPattern().format(steps)} steps on ${DateFormat('EEEE, MMMM d').format(date)}';
                } else {
                  // For weekly view: Total steps on this day
                  message =
                      '${NumberFormat.decimalPattern().format(steps)} steps on ${DateFormat('EEEE, MMMM d').format(date)}';
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    backgroundColor: customColors.accentPrimary,
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
        listTitle = 'Daily Activity (Last 30 Days)';
        break;
      case 'Year':
        listTitle = 'Monthly Average Steps';
        break;
      default:
        listTitle = 'Activity History';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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

            if (_selectedTimeFrame == 'Year') {
              // For yearly view, show month and year
              dateDisplay = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('MMM').format(date),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: customColors.textPrimary,
                    ),
                  ),
                  Text(
                    DateFormat('yyyy').format(date),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: customColors.textSecondary,
                    ),
                  ),
                ],
              );
              periodLabel = DateFormat('MMMM yyyy').format(date);
              stepsLabel = 'avg/day';

              // Add days count to the label for context
              if (data['daysCount'] != null) {
                int daysCount = data['daysCount'] as int;
                periodLabel += ' (${daysCount} days)';
              }
            } else {
              // For week and month views, show day and month
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
              periodLabel = isToday ? 'Today' : DateFormat('EEEE').format(date);
              stepsLabel = 'steps';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: customColors.dateNavigatorBackground,
                      borderRadius: BorderRadius.circular(8),
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
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: percentage > 1.0 ? 1.0 : percentage,
                          backgroundColor: Colors.grey.withOpacity(0.2),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            percentage >= 1.0
                                ? Colors.green
                                : customColors.accentPrimary,
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
                        '$steps',
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
              child: TextButton(
                onPressed: () {
                  // Could implement a "view all" screen here
                },
                child: Text(
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
    // Calculate average steps based on timeframe
    double avgSteps = 0;
    if (!_stepsData.isEmpty) {
      if (_selectedTimeFrame == 'Year') {
        // For yearly view, calculate the average of the monthly averages
        // We're using the transformed data to ensure we're getting the correct averages
        final yearlyData = _getTransformedStepsData();
        int totalAvgSteps = 0;
        for (final data in yearlyData) {
          totalAvgSteps +=
              data['steps'] as int; // These are already daily averages
        }
        avgSteps = yearlyData.isEmpty ? 0 : totalAvgSteps / yearlyData.length;
      } else {
        // For weekly and monthly views, direct average
        avgSteps = _stepsData
                .map((data) => data['steps'] as int)
                .reduce((a, b) => a + b) /
            _stepsData.length;
      }
    }

    // Determine if trending up or down
    bool? trendingUp;
    String trendMessage = '';

    // Customize trend message based on timeframe
    if (_stepsData.length >= 3) {
      if (_selectedTimeFrame == 'Year') {
        // For yearly view, compare the last 3 months from the transformed data
        final yearlyData = _getTransformedStepsData();
        if (yearlyData.length >= 3) {
          // Sort chronologically to ensure we're comparing oldest to newest
          final recentMonths = yearlyData.length > 3
              ? List.from(yearlyData.sublist(yearlyData.length - 3))
              : List.from(yearlyData);

          recentMonths.sort((a, b) =>
              (a['date'] as DateTime).compareTo(b['date'] as DateTime));

          final firstMonth = recentMonths.first['steps'] as int;
          final lastMonth = recentMonths.last['steps'] as int;

          trendingUp = lastMonth > firstMonth;
          final percentChange = firstMonth > 0
              ? ((lastMonth - firstMonth) / firstMonth * 100).abs()
              : 0;

          if (percentChange >= 5) {
            // Only show trend if there's at least 5% change
            if (trendingUp) {
              trendMessage =
                  'Your daily steps are trending up! ${percentChange.toStringAsFixed(0)}% increase over the last 3 months.';
            } else {
              trendMessage =
                  'Your daily steps have decreased by ${percentChange.toStringAsFixed(0)}% over the last 3 months.';
            }
          }
        }
      } else if (_selectedTimeFrame == 'Month') {
        // For monthly view, compare the first and last weeks (average of 7 days)
        // Make sure data is sorted chronologically
        List<Map<String, dynamic>> sortedData = List.from(_stepsData)
          ..sort((a, b) =>
              (a['date'] as DateTime).compareTo(b['date'] as DateTime));

        if (sortedData.length >= 14) {
          // Need at least 14 days to compare first and last week
          final firstWeekAvg = sortedData
                  .sublist(0, 7)
                  .map((data) => data['steps'] as int)
                  .reduce((a, b) => a + b) /
              7;

          final lastWeekAvg = sortedData
                  .sublist(sortedData.length - 7)
                  .map((data) => data['steps'] as int)
                  .reduce((a, b) => a + b) /
              7;

          trendingUp = lastWeekAvg > firstWeekAvg;
          final percentChange = firstWeekAvg > 0
              ? ((lastWeekAvg - firstWeekAvg) / firstWeekAvg * 100).abs()
              : 0;

          if (percentChange >= 5) {
            // Only show trend if there's at least 5% change
            if (trendingUp) {
              trendMessage =
                  'Your daily steps are trending up! ${percentChange.toStringAsFixed(0)}% increase from earlier this month.';
            } else {
              trendMessage =
                  'Your daily steps have decreased by ${percentChange.toStringAsFixed(0)}% from earlier this month.';
            }
          }
        }
      } else {
        // For weekly view, compare first and last days
        // Make sure data is sorted chronologically
        List<Map<String, dynamic>> sortedData = List.from(_stepsData)
          ..sort((a, b) =>
              (a['date'] as DateTime).compareTo(b['date'] as DateTime));

        if (sortedData.length >= 3) {
          final firstDay = sortedData.first['steps'] as int;
          final lastDay = sortedData.last['steps'] as int;

          trendingUp = lastDay > firstDay;
          final percentChange =
              firstDay > 0 ? ((lastDay - firstDay) / firstDay * 100).abs() : 0;

          if (percentChange >= 10) {
            // Only show trend if there's at least 10% change
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
    }

    // Calculate appropriate average based on timeframe
    String avgPeriod;
    int displayedAvg = avgSteps.toInt();

    switch (_selectedTimeFrame) {
      case 'Year':
        avgPeriod = 'Average Daily Steps (Year)';
        break;
      case 'Month':
        avgPeriod = 'Average Daily Steps (30 Days)';
        break;
      case 'Week':
      default:
        avgPeriod = 'Average Daily Steps (Week)';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
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
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: customColors.accentPrimary.withOpacity(0.1),
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
                      '$displayedAvg steps',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: customColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (trendMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (trendingUp ?? false)
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              // Show edit goal dialog
              _showEditGoalDialog(context, customColors);
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.edit,
                  size: 16,
                  color: customColors.accentPrimary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Edit Step Goal',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: customColors.accentPrimary,
                  ),
                ),
              ],
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
          content: TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter your daily step goal',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              if (value.isNotEmpty) {
                newGoal = int.tryParse(value) ?? _stepGoal;
              }
            },
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(
                  color: customColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _stepGoal = newGoal;
                  _progressPercentage = _todaySteps / _stepGoal;
                  if (_progressPercentage > 1.0) _progressPercentage = 1.0;
                });
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: customColors.accentPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Save',
                style: GoogleFonts.inter(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

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
  final String? goalLabel; // Added goal label parameter

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
    this.goalLabel, // Added to constructor
  }) : super(key: key);

  @override
  State<CustomBarChart> createState() => _CustomBarChartState();
}

class _CustomBarChartState extends State<CustomBarChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  int? _highlightedIndex;
  double? _hoverX;
  double? _hoverY;
  bool _showTooltip = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Format large numbers with K suffix
  String _formatYAxisValue(double value) {
    if (value >= 10000) {
      return '${(value / 1000).toStringAsFixed(0)}k';
    } else if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toInt().toString();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate bar width based on available space
    final barSpacing = 10.0;
    final chartWidth = MediaQuery.of(context).size.width -
        40 -
        (2 * 20); // screen width - padding - container padding
    final numBars = widget.data.length;
    final barWidth = (chartWidth - (barSpacing * (numBars - 1))) / numBars;

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight =
            constraints.maxHeight - 35; // Reserve more space for labels
        final yAxisLabelWidth = 45.0; // Width reserved for y-axis labels

        // Generate y-axis label values with more granular divisions
        final yAxisSteps = 5; // 5 steps for better granularity
        final yAxisLabels = List.generate(yAxisSteps + 1, (i) {
          if (i == 0) return null; // Skip the bottom label (0)
          final value = (i / yAxisSteps * widget.maxValue);
          return _formatYAxisValue(value);
        });

        return Column(
          children: [
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Y-axis labels with better alignment and styling
                  SizedBox(
                    width: yAxisLabelWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ...List.generate(yAxisSteps, (i) {
                          final value = widget.maxValue -
                              (i / yAxisSteps * widget.maxValue);
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

                  // Chart area with interactive gesture detection
                  Expanded(
                    child: GestureDetector(
                      onPanUpdate: (details) {
                        final RenderBox box =
                            context.findRenderObject() as RenderBox;
                        final localPosition =
                            box.globalToLocal(details.globalPosition);

                        if (localPosition.dx >= 0 &&
                            localPosition.dx <=
                                constraints.maxWidth - yAxisLabelWidth &&
                            localPosition.dy >= 0 &&
                            localPosition.dy <= chartHeight) {
                          // Calculate which bar is being hovered
                          final barArea =
                              constraints.maxWidth - yAxisLabelWidth;
                          final barIndex =
                              ((localPosition.dx / barArea) * numBars).floor();

                          if (barIndex >= 0 && barIndex < widget.data.length) {
                            setState(() {
                              _highlightedIndex = barIndex;
                              _hoverX = localPosition.dx;
                              _hoverY = localPosition.dy;
                              _showTooltip = true;
                            });
                          }
                        } else {
                          setState(() {
                            _showTooltip = false;
                          });
                        }
                      },
                      onPanEnd: (_) {
                        setState(() {
                          _showTooltip = false;
                        });
                      },
                      child: Stack(
                        children: [
                          // Grid lines with improved styling
                          CustomPaint(
                            size: Size(constraints.maxWidth - yAxisLabelWidth,
                                chartHeight),
                            painter: GridPainter(
                              maxValue: widget.maxValue,
                              lineColor: Colors.grey.withOpacity(0.15),
                              textColor: widget.secondaryTextColor,
                              steps: yAxisSteps,
                              showGoalLine: widget.showGoalLine,
                              goalValue: widget.goalValue,
                              goalLineColor: widget.goalLineColor,
                              goalLabel: widget.goalLabel,
                            ),
                          ),

                          // Bars with animation and hover state
                          Padding(
                            padding: const EdgeInsets.only(right: 10.0),
                            child: AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                final animationValue = Curves.easeOut
                                    .transform(_animationController.value);

                                return Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: List.generate(widget.data.length,
                                      (index) {
                                    final value = widget
                                        .valueExtractor(widget.data[index]);
                                    final normalized = value / widget.maxValue;
                                    final barHeight = chartHeight *
                                        normalized *
                                        animationValue;
                                    final isToday = index == widget.todayIndex;
                                    final isHighlighted =
                                        _highlightedIndex == index;

                                    // Determine bar color based on progress
                                    Color barColor;
                                    if (widget.enableColorCoding) {
                                      final percentOfGoal =
                                          value / widget.goalValue;
                                      if (percentOfGoal >= 1.0) {
                                        // Achieved or exceeded goal
                                        barColor = Colors.green;
                                      } else if (percentOfGoal >= 0.7) {
                                        // Good progress (70-99% of goal)
                                        barColor = Colors.orange;
                                      } else {
                                        // Below target (less than 70% of goal)
                                        barColor = Colors.red;
                                      }
                                    } else {
                                      barColor = widget.primaryColor;
                                    }

                                    return GestureDetector(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _highlightedIndex = index;
                                          _showTooltip = true;
                                        });
                                        widget.onBarTap?.call(index);
                                      },
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          // Value label above bar when highlighted
                                          if (isHighlighted && _showTooltip)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 3),
                                              margin: const EdgeInsets.only(
                                                  bottom: 4),
                                              decoration: BoxDecoration(
                                                color: widget.primaryColor,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                _formatYAxisValue(value),
                                                style: GoogleFonts.inter(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 150),
                                            width: barWidth,
                                            height: barHeight,
                                            decoration: BoxDecoration(
                                              color: isToday
                                                  ? barColor
                                                  : barColor.withOpacity(
                                                      isHighlighted
                                                          ? 0.9
                                                          : 0.7),
                                              borderRadius:
                                                  const BorderRadius.only(
                                                topLeft: Radius.circular(4),
                                                topRight: Radius.circular(4),
                                              ),
                                              boxShadow: isHighlighted
                                                  ? [
                                                      BoxShadow(
                                                        color: barColor
                                                            .withOpacity(0.4),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 2),
                                                      ),
                                                    ]
                                                  : null,
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

                          // Zero line indicator
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 1,
                              color: widget.textColor.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // X-axis labels with improved styling
            SizedBox(
              height: 35,
              child: Padding(
                padding: EdgeInsets.only(left: yAxisLabelWidth, top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(widget.data.length, (index) {
                    final label = widget.labelExtractor(widget.data[index]);
                    final isToday = index == widget.todayIndex;
                    final isHighlighted = _highlightedIndex == index;

                    return SizedBox(
                      width: barWidth,
                      child: Text(
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
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

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
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final dashArray = [4, 4]; // Smaller, more elegant dash pattern

    // Draw horizontal grid lines with tick marks
    for (int i = 0; i <= steps; i++) {
      final y = size.height - (i / steps * size.height);

      // Skip the bottom line
      if (i == 0) continue;

      // Draw dashed horizontal line
      double startX = 0;
      final stopX = size.width;
      final path = Path();

      path.moveTo(startX, y);

      bool isDash = true;
      while (startX < stopX) {
        final nextX = startX + (isDash ? dashArray[0] : dashArray[1]);
        if (isDash) {
          path.lineTo(math.min(nextX, stopX), y);
        } else {
          path.moveTo(math.min(nextX, stopX), y);
        }

        startX = nextX;
        isDash = !isDash;
      }

      canvas.drawPath(path, paint);

      // Add tick mark on y-axis
      canvas.drawLine(
          Offset(-2, y),
          Offset(0, y),
          Paint()
            ..color = textColor.withOpacity(0.7)
            ..strokeWidth = 1.5
            ..style = PaintingStyle.stroke);
    }

    // Draw vertical axis line
    final axisLinePaint = Paint()
      ..color = textColor.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axisLinePaint);

    // Draw x-axis line with subtle gradient
    final xAxisPaint = Paint()
      ..shader = LinearGradient(
        colors: [textColor.withOpacity(0.6), textColor.withOpacity(0.2)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, 2))
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
        Offset(0, size.height), Offset(size.width, size.height), xAxisPaint);

    // Draw goal line if enabled
    if (showGoalLine && goalValue > 0) {
      final goalY = size.height - (goalValue / maxValue * size.height);

      // Draw goal line with dash pattern
      final goalPaint = Paint()
        ..color = goalLineColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

      // Create dashed line for goal
      double startX = 0;
      final stopX = size.width;
      final goalPath = Path();
      goalPath.moveTo(startX, goalY);

      final goalDashArray = [6, 4]; // Different dash pattern for goal line
      bool isDash = true;

      while (startX < stopX) {
        final nextX = startX + (isDash ? goalDashArray[0] : goalDashArray[1]);
        if (isDash) {
          goalPath.lineTo(math.min(nextX, stopX), goalY);
        } else {
          goalPath.moveTo(math.min(nextX, stopX), goalY);
        }

        startX = nextX;
        isDash = !isDash;
      }

      canvas.drawPath(goalPath, goalPaint);

      // Add goal label next to the line
      final labelText = goalLabel ?? 'Goal';
      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            color: goalLineColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.rtl,
      );
      textPainter.layout();
      textPainter.paint(
          canvas,
          Offset(size.width - textPainter.width - 4,
              goalY - textPainter.height - 2));

      // Format goal value appropriately based on size
      final String formattedGoal;
      if (goalValue >= 10000) {
        formattedGoal = '${(goalValue / 1000).toStringAsFixed(0)}k';
      } else {
        formattedGoal = goalValue.toInt().toString();
      }

      // Add goal value label
      final valueTextPainter = TextPainter(
        text: TextSpan(
          text: formattedGoal,
          style: TextStyle(
            color: goalLineColor,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: ui.TextDirection.rtl,
      );
      valueTextPainter.layout();
      valueTextPainter.paint(
          canvas, Offset(4, goalY - valueTextPainter.height - 2));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
