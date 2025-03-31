import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

// Weight data point model
class WeightPoint {
  final DateTime date;
  final double weight;

  WeightPoint({required this.date, required this.weight});
}

// Touch interaction model
class TouchData {
  final Offset position;
  final WeightPoint point;

  TouchData({required this.position, required this.point});
}

class WeightTrackingScreen extends StatefulWidget {
  final bool hideAppBar;

  const WeightTrackingScreen({
    Key? key,
    this.hideAppBar = false,
  }) : super(key: key);

  @override
  State<WeightTrackingScreen> createState() => _WeightTrackingScreenState();
}

class _WeightTrackingScreenState extends State<WeightTrackingScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  double _currentWeight = 70.0;
  double _targetWeight = 65.0;
  String _selectedTimeFrame = 'Month';
  List<Map<String, dynamic>> _weightData = [];
  bool _isMetric = true;
  late AnimationController _pageController;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _pageController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadWeightData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadWeightData() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load cached data first for instant display
      final String? cachedData = prefs.getString('weight_data_cache');
      if (cachedData != null) {
        final cached = json.decode(cachedData);
        setState(() {
          _currentWeight = cached['current_weight'] ?? _currentWeight;
          _targetWeight = cached['target_weight'] ?? _targetWeight;
          _weightData =
              List<Map<String, dynamic>>.from(cached['weight_data'] ?? []);
        });
      }

      // Get stored weight history
      final String? weightHistoryJson = prefs.getString('weight_history');
      if (weightHistoryJson != null && weightHistoryJson.isNotEmpty) {
        final List<dynamic> weightHistory = json.decode(weightHistoryJson);
        if (weightHistory.isNotEmpty) {
          setState(() {
            _weightData = List<Map<String, dynamic>>.from(weightHistory);

            // Set current weight to the latest entry
            if (_weightData.isNotEmpty) {
              final latestEntry = _weightData.reduce((a, b) =>
                  DateTime.parse(a['date'] as String)
                          .isAfter(DateTime.parse(b['date'] as String))
                      ? a
                      : b);
              _currentWeight = latestEntry['weight'] as double;
            }
          });
        }
      }

      // Try to get the current weight from macro_results
      final String? macroResultsJson = prefs.getString('macro_results');
      if (macroResultsJson != null) {
        final macroResults = json.decode(macroResultsJson);
        if (macroResults['weight_kg'] != null) {
          _currentWeight = macroResults['weight_kg'].toDouble();

          // If we have the current weight but no history, create first entry
          if (_weightData.isEmpty) {
            _weightData.add({
              'date': DateTime.now().toIso8601String(),
              'weight': _currentWeight,
            });
          }
        }
      }

      _targetWeight = prefs.getDouble('goal_weight_kg') ?? _currentWeight;

      // If user is authenticated, fetch from Supabase
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        final response = await Supabase.instance.client
            .from('user_macros')
            .select('weight') // Removed goal_weight_kg
            .eq('id', currentUser.id)
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (response != null) {
          if (response['weight'] != null) {
            _currentWeight = response['weight'].toDouble();
          }
          // Removed check for goal_weight_kg as it's loaded from prefs
        }

        // Removed fetching weight history from Supabase as it's stored locally
        // try { ... } catch (e) { ... } block removed
      }

      // Create sample data only if we have no actual data
      if (_weightData.isEmpty) {
        _weightData = List.generate(30, (index) {
          final date = DateTime.now().subtract(Duration(days: 29 - index));
          final randomFluctuation = (math.Random().nextDouble() - 0.5);
          return {
            'date': date.toIso8601String(),
            'weight': _currentWeight + randomFluctuation,
          };
        });
      }

      // Cache the new data
      await prefs.setString(
          'weight_data_cache',
          json.encode({
            'current_weight': _currentWeight,
            'target_weight': _targetWeight,
            'weight_data': _weightData,
            'timestamp': DateTime.now().toIso8601String(),
          }));

      // Also save to weight_history for persistence
      await prefs.setString('weight_history', json.encode(_weightData));
    } catch (e) {
      print('Error loading weight data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      _pageController.forward();
    }
  }

  double _getProgressPercentage() {
    if (_currentWeight == _targetWeight) return 1.0;
    final totalChange = (_currentWeight - _targetWeight).abs();
    final remainingChange = (_currentWeight - _targetWeight).abs();
    return 1 - (remainingChange / totalChange);
  }

  String _formatWeight(double weight) {
    return _isMetric
        ? '${weight.toStringAsFixed(1)} kg'
        : '${(weight * 2.20462).toStringAsFixed(1)} lbs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;

    Widget body = _isLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(customColors.accentPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading your progress...',
                  style: GoogleFonts.inter(
                    color: customColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          )
        : SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadWeightData,
              color: customColors.accentPrimary,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          _buildWeightStatusCard(context, customColors),
                          const SizedBox(height: 24),
                          _buildTimeFrameSelector(customColors),
                          const SizedBox(height: 24),
                          _buildWeightChart(customColors),
                          const SizedBox(height: 24),
                          _buildWeightHistory(customColors),
                          const SizedBox(height: 24),
                          _buildWeightGoalCard(customColors),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

    if (!widget.hideAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Weight Tracking',
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
          actions: [
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isMetric = !_isMetric;
                });
              },
              icon: Icon(
                Icons.scale,
                color: customColors.textPrimary,
                size: 20,
              ),
              label: Text(
                _isMetric ? 'kg' : 'lbs',
                style: TextStyle(
                  color: customColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        body: body,
      );
    }

    return body;
  }

  Widget _buildWeightStatusCard(
      BuildContext context, CustomColors customColors) {
    final progress = _getProgressPercentage();

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 50 * (1 - _pageController.value)),
          child: Opacity(
            opacity: _pageController.value,
            child: Container(
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
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Current Weight',
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
                      _buildAddWeightButton(context, customColors),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Hero(
                        tag: 'weight_progress',
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Background circle
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.grey.shade50
                                          : customColors
                                              .dateNavigatorBackground,
                                      Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.grey.shade100
                                          : customColors.cardBackground,
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                              ),

                              // Animated progress indicator
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: progress),
                                duration: const Duration(milliseconds: 1500),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return Stack(
                                    children: [
                                      CircularProgressIndicator(
                                        value: value,
                                        backgroundColor:
                                            Theme.of(context).brightness ==
                                                    Brightness.light
                                                ? Colors.grey.shade200
                                                    .withOpacity(0.5)
                                                : customColors
                                                    .dateNavigatorBackground
                                                    .withOpacity(0.3),
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          value >= 1.0
                                              ? Colors.green.withOpacity(0.8)
                                              : customColors.accentPrimary
                                                  .withOpacity(0.8),
                                        ),
                                        strokeWidth: 12,
                                        strokeCap: StrokeCap.round,
                                      ),
                                      CircularProgressIndicator(
                                        value: value,
                                        backgroundColor: Colors.transparent,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          value >= 1.0
                                              ? Colors.green
                                              : customColors.accentPrimary,
                                        ),
                                        strokeWidth: 8,
                                        strokeCap: StrokeCap.round,
                                      ),
                                    ],
                                  );
                                },
                              ),

                              // Animated weight display
                              TweenAnimationBuilder<double>(
                                tween: Tween(begin: 0, end: _currentWeight),
                                duration: const Duration(milliseconds: 1500),
                                curve: Curves.easeOutCubic,
                                builder: (context, value, child) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.transparent,
                                      shape: BoxShape.circle,
                                      // boxShadow: [
                                      //   BoxShadow(
                                      //     color: customColors.accentPrimary
                                      //         .withOpacity(0.1),
                                      //     blurRadius: 8,
                                      //     spreadRadius: 2,
                                      //     offset: const Offset(0, 2),
                                      //   ),
                                      // ],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _formatWeight(value),
                                          style: GoogleFonts.inter(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: customColors.textPrimary,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildProgressItem(
                              context,
                              'Target',
                              _formatWeight(_targetWeight),
                              Icons.flag_rounded,
                              customColors,
                            ),
                            const SizedBox(height: 20),
                            _buildProgressItem(
                              context,
                              'To Go',
                              _formatWeight(
                                  (_currentWeight - _targetWeight).abs()),
                              Icons.trending_down,
                              customColors,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddWeightButton(
      BuildContext context, CustomColors customColors) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showAddWeightDialog(context, customColors);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: customColors.accentPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline,
                color: customColors.accentPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Add Weight',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: customColors.accentPrimary,
                ),
              ),
            ],
          ),
        ),
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
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _pageController.value)),
          child: Opacity(
            opacity: _pageController.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: customColors.dateNavigatorBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
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
                      duration: const Duration(milliseconds: 200),
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedTimeFrame = timeFrame;
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
                            const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                          ),
                          overlayColor: MaterialStateProperty.all(
                            customColors.accentPrimary.withOpacity(0.1),
                          ),
                        ),
                        child: Text(
                          timeFrame,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeightChart(CustomColors customColors) {
    // Calculate statistics
    double weightChange = 0;
    String timeDescription = '';

    if (_weightData.length > 1) {
      // Sort by date to ensure we're comparing oldest with newest
      _weightData.sort((a, b) => DateTime.parse(a['date'] as String)
          .compareTo(DateTime.parse(b['date'] as String)));

      // Get first and last entries based on selected time frame
      final firstEntry = _filterWeightDataByTimeFrame(_weightData).first;
      final lastEntry = _filterWeightDataByTimeFrame(_weightData).last;

      // Calculate change
      final startWeight = firstEntry['weight'] as double;
      final endWeight = lastEntry['weight'] as double;
      weightChange = endWeight - startWeight;

      // Format time description
      final startDate = DateTime.parse(firstEntry['date'] as String);
      final endDate = DateTime.parse(lastEntry['date'] as String);
      final days = endDate.difference(startDate).inDays;

      if (days < 7) {
        timeDescription = days == 0
            ? 'today'
            : 'in the last $days day${days == 1 ? '' : 's'}';
      } else if (days < 30) {
        final weeks = (days / 7).floor();
        timeDescription = 'in the last $weeks week${weeks == 1 ? '' : 's'}';
      } else if (days < 365) {
        final months = (days / 30).floor();
        timeDescription = 'in the last $months month${months == 1 ? '' : 's'}';
      } else {
        final years = (days / 365).floor();
        timeDescription = 'in the last $years year${years == 1 ? '' : 's'}';
      }
    }

    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _pageController.value)),
          child: Opacity(
            opacity: _pageController.value,
            child: Card(
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
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
                    // Header with title and add button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Weight Trend',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: customColors.textPrimary,
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _showAddWeightDialog(context, customColors),
                          icon: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color:
                                  customColors.accentPrimary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.add,
                              size: 16,
                              color: customColors.accentPrimary,
                            ),
                          ),
                          tooltip: 'Add weight entry',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),

                    // Weight change information
                    if (_weightData.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        child: Row(
                          children: [
                            Icon(
                              weightChange > 0
                                  ? Icons.arrow_upward
                                  : weightChange < 0
                                      ? Icons.arrow_downward
                                      : Icons.remove,
                              size: 16,
                              color: weightChange > 0
                                  ? Colors.redAccent
                                  : weightChange < 0
                                      ? Colors.greenAccent.shade700
                                      : customColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${weightChange.abs().toStringAsFixed(1)} ${_isMetric ? 'kg' : 'lbs'} ${weightChange > 0 ? 'gained' : weightChange < 0 ? 'lost' : 'maintained'} $timeDescription',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: weightChange > 0
                                    ? Colors.redAccent
                                    : weightChange < 0
                                        ? Colors.greenAccent.shade700
                                        : customColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Chart
                    SizedBox(
                      height: 240,
                      child: CustomWeightChart(
                        weightPoints: _weightData
                            .map((data) => WeightPoint(
                                  date: DateTime.parse(data['date'] as String),
                                  weight: data['weight'] as double,
                                ))
                            .toList(),
                        isMetric: _isMetric,
                        customColors: customColors,
                        targetWeight: _targetWeight,
                        timeFrame: _selectedTimeFrame,
                      ),
                    ),

                    // Chart instructions
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: 14,
                            color: customColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Touch to see details • Pinch to zoom',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: customColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _filterWeightDataByTimeFrame(
      List<Map<String, dynamic>> data) {
    if (data.isEmpty) return [];

    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    final oneMonthAgo = DateTime(now.year, now.month - 1, now.day);
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
    final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
    final yearAgo = DateTime(now.year - 1, now.month, now.day);

    // Make a copy to avoid modifying the original
    final filteredData = List<Map<String, dynamic>>.from(data);

    // Filter based on selected timeframe
    switch (_selectedTimeFrame) {
      case 'Week':
        return filteredData.where((entry) {
          final date = DateTime.parse(entry['date'] as String);
          return date.isAfter(oneWeekAgo) || date.isAtSameMomentAs(oneWeekAgo);
        }).toList();
      case 'Month':
        return filteredData.where((entry) {
          final date = DateTime.parse(entry['date'] as String);
          return date.isAfter(oneMonthAgo) ||
              date.isAtSameMomentAs(oneMonthAgo);
        }).toList();
      case '3 Months':
        return filteredData.where((entry) {
          final date = DateTime.parse(entry['date'] as String);
          return date.isAfter(threeMonthsAgo) ||
              date.isAtSameMomentAs(threeMonthsAgo);
        }).toList();
      case '6 Months':
        return filteredData.where((entry) {
          final date = DateTime.parse(entry['date'] as String);
          return date.isAfter(sixMonthsAgo) ||
              date.isAtSameMomentAs(sixMonthsAgo);
        }).toList();
      case 'Year':
        return filteredData.where((entry) {
          final date = DateTime.parse(entry['date'] as String);
          return date.isAfter(yearAgo) || date.isAtSameMomentAs(yearAgo);
        }).toList();
      default:
        return filteredData;
    }
  }

  Widget _buildWeightHistory(CustomColors customColors) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 10 * (1 - _pageController.value)),
          child: Opacity(
            opacity: _pageController.value,
            child: Container(
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
                    'Weight History',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: customColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: math.min(5, _weightData.length),
                    itemBuilder: (context, index) {
                      final data = _weightData[_weightData.length - 1 - index];
                      final weight = data['weight'] as double;
                      final date = DateTime.parse(data['date'] as String);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // Show detailed view or edit options
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color:
                                          customColors.dateNavigatorBackground,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
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
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          DateFormat('EEEE').format(date),
                                          style: GoogleFonts.inter(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: customColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          _formatWeight(weight),
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            color: customColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    color: customColors.textSecondary,
                                    size: 20,
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
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeightGoalCard(CustomColors customColors) {
    return AnimatedBuilder(
      animation: _pageController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 5 * (1 - _pageController.value)),
          child: Opacity(
            opacity: _pageController.value,
            child: Container(
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
                    'Weight Goal',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: customColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Target Weight:',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: customColors.textPrimary,
                        ),
                      ),
                      Text(
                        _formatWeight(_targetWeight),
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: customColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () =>
                          _showEditGoalDialog(context, customColors),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: customColors.accentPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                      ),
                      child: Text(
                        'Edit Goal',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveWeightChanges() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save current and target weights
      await prefs.setDouble('current_weight', _currentWeight);
      await prefs.setDouble('goal_weight_kg', _targetWeight);

      // Save the full weight history
      await prefs.setString('weight_history', json.encode(_weightData));

      // Update macro_results with new current weight
      final String? macroResultsJson = prefs.getString('macro_results');
      if (macroResultsJson != null) {
        final macroResults = json.decode(macroResultsJson);
        macroResults['weight_kg'] = _currentWeight;
        await prefs.setString('macro_results', json.encode(macroResults));
      }

      // Cache the data for quicker loading
      await prefs.setString(
          'weight_data_cache',
          json.encode({
            'current_weight': _currentWeight,
            'target_weight': _targetWeight,
            'weight_data': _weightData,
            'timestamp': DateTime.now().toIso8601String(),
          }));

      // If user is authenticated, sync to Supabase
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        // Update current weight and goal
        await Supabase.instance.client.from('user_macros').upsert({
          'id': currentUser.id,
          'weight': _currentWeight,
          // 'goal_weight_kg': _targetWeight, // Removed as it's stored locally
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Removed syncing weight history to Supabase as it's stored locally
        // try { ... } catch (e) { ... } block removed
      }
    } catch (e) {
      print('Error saving weight changes: $e');
    }
  }

  Future<void> _showAddWeightDialog(
      BuildContext context, CustomColors customColors) async {
    double newWeight = _currentWeight;
    DateTime selectedDate = DateTime.now(); // Initialize with today's date
    final customColors = Theme.of(context).extension<CustomColors>();
    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          // Use StatefulBuilder to manage date state
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'Add Weight Entry',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: customColors!.textPrimary,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min, // Prevent excessive height
                children: [
                  TextField(
                    keyboardType:
                        TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      hintText: 'Enter your weight',
                      suffix: Text(_isMetric ? 'kg' : 'lbs'),
                    ),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        try {
                          newWeight = double.parse(value);
                          if (!_isMetric) {
                            newWeight = newWeight / 2.20462; // Convert to kg
                          }
                        } catch (e) {
                          // Handle invalid input
                          print('Invalid weight input: $e');
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  // Date Picker Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date:',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          color: customColors.textSecondary,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (BuildContext builder) {
                              return Container(
                                height: 250,
                                color: customColors.cardBackground,
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: Text(
                                            'Cancel',
                                            style: TextStyle(
                                                color:
                                                    customColors.textSecondary),
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.pop(context);
                                          },
                                          child: Text(
                                            'Done',
                                            style: TextStyle(
                                                color:
                                                    customColors.accentPrimary),
                                          ),
                                        ),
                                      ],
                                    ),
                                    Expanded(
                                      child: CupertinoDatePicker(
                                        mode: CupertinoDatePickerMode.date,
                                        initialDateTime: selectedDate,
                                        maximumDate: DateTime.now(),
                                        minimumDate: DateTime(2000),
                                        onDateTimeChanged: (DateTime newDate) {
                                          setDialogState(() {
                                            selectedDate = newDate;
                                          });
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                        child: Text(
                          DateFormat('MMM d, yyyy').format(selectedDate),
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: customColors.accentPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: customColors.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Basic validation: ensure weight is positive
                    if (newWeight <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please enter a valid weight.'),
                          backgroundColor: Colors.redAccent,
                        ),
                      );
                      return;
                    }

                    setState(() {
                      // Format the selected date to ignore time for comparison
                      final selectedDay =
                          DateFormat('yyyy-MM-dd').format(selectedDate);

                      // Remove any existing entry for the selected date
                      _weightData.removeWhere((entry) {
                        final entryDate =
                            DateTime.parse(entry['date'] as String);
                        return DateFormat('yyyy-MM-dd').format(entryDate) ==
                            selectedDay;
                      });

                      // Add the new weight entry with the selected date
                      _weightData.add({
                        'date': selectedDate
                            .toIso8601String(), // Use selected date (with time)
                        'weight': newWeight,
                      });

                      // Sort the data by date after adding/replacing
                      _weightData.sort((a, b) =>
                          DateTime.parse(a['date'] as String)
                              .compareTo(DateTime.parse(b['date'] as String)));

                      // Update current weight to the latest entry's weight after sorting
                      if (_weightData.isNotEmpty) {
                        _currentWeight = _weightData.last['weight'] as double;
                      }

                      // Optional: Limit history size if needed (e.g., keep last 100)
                      // if (_weightData.length > 100) {
                      //   _weightData = _weightData.sublist(_weightData.length - 100);
                      // }
                    });
                    // Save the changes (Note: _saveWeightChanges only saves current/goal)
                    // A separate mechanism would be needed to persist the full history
                    Navigator.pop(context);
                    await _saveWeightChanges();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: customColors.accentPrimary,
                  ),
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: customColors.textPrimary,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showEditGoalDialog(
      BuildContext context, CustomColors customColors) async {
    double newTarget = _targetWeight;

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Edit Weight Goal',
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: customColors.textPrimary,
          ),
        ),
        content: TextField(
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Enter target weight',
            suffix: Text(_isMetric ? 'kg' : 'lbs'),
          ),
          onChanged: (value) {
            if (value.isNotEmpty) {
              try {
                newTarget = double.parse(value);
                if (!_isMetric) {
                  newTarget = newTarget / 2.20462; // Convert to kg
                }
              } catch (e) {
                // Handle invalid input
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: customColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() {
                _targetWeight = newTarget;
              });
              // Save the changes
              await _saveWeightChanges();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: customColors.accentPrimary,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class CustomWeightChart extends StatefulWidget {
  final List<WeightPoint> weightPoints;
  final bool isMetric;
  final CustomColors customColors;
  final double targetWeight;
  final String timeFrame;

  const CustomWeightChart({
    Key? key,
    required this.weightPoints,
    required this.isMetric,
    required this.customColors,
    required this.targetWeight,
    required this.timeFrame,
  }) : super(key: key);

  @override
  State<CustomWeightChart> createState() => _CustomWeightChartState();
}

class _CustomWeightChartState extends State<CustomWeightChart> {
  // Removed SingleTickerProviderStateMixin
  // late AnimationController _animationController; // Removed AnimationController
  TouchData? _touchData;
  // final List<Offset> _animatedPoints = []; // This is calculated in paint now

  double _zoomLevel = 1.0; // Default zoom level
  double _zoomFactor = 1.0; // Current zoom factor
  Offset? _lastFocalPoint;
  late double _panOffset = 0.0; // Horizontal panning offset
  final double _maxPanOffset = 100.0; // Maximum pan offset

  // Removed initState, dispose, and didUpdateWidget related to AnimationController

  @override
  void didUpdateWidget(CustomWeightChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weightPoints != widget.weightPoints ||
        oldWidget.timeFrame != widget.timeFrame) {
      // Reset zoom and pan when data or timeframe changes
      _zoomLevel = 1.0;
      _panOffset = 0.0;
    }
  }

  List<WeightPoint> _getFilteredData() {
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    final oneMonthAgo = DateTime(now.year, now.month - 1, now.day);
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
    final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
    final yearAgo = DateTime(now.year - 1, now.month, now.day);

    List<WeightPoint> filteredPoints;

    switch (widget.timeFrame) {
      case 'Week':
        filteredPoints = widget.weightPoints
            .where((point) =>
                point.date.isAfter(oneWeekAgo) ||
                point.date.isAtSameMomentAs(oneWeekAgo))
            .toList();
        break;
      case 'Month':
        filteredPoints = widget.weightPoints
            .where((point) =>
                point.date.isAfter(oneMonthAgo) ||
                point.date.isAtSameMomentAs(oneMonthAgo))
            .toList();
        break;
      case '3 Months':
        filteredPoints = widget.weightPoints
            .where((point) =>
                point.date.isAfter(threeMonthsAgo) ||
                point.date.isAtSameMomentAs(threeMonthsAgo))
            .toList();
        break;
      case '6 Months':
        filteredPoints = widget.weightPoints
            .where((point) =>
                point.date.isAfter(sixMonthsAgo) ||
                point.date.isAtSameMomentAs(sixMonthsAgo))
            .toList();
        break;
      case 'Year':
        filteredPoints = widget.weightPoints
            .where((point) =>
                point.date.isAfter(yearAgo) ||
                point.date.isAtSameMomentAs(yearAgo))
            .toList();
        break;
      default:
        filteredPoints = widget.weightPoints;
    }

    // Sort points by date just to be sure
    filteredPoints.sort((a, b) => a.date.compareTo(b.date));

    return filteredPoints;
  }

  String _formatWeight(double weight) {
    return widget.isMetric
        ? '${weight.toStringAsFixed(1)} kg'
        : '${(weight * 2.20462).toStringAsFixed(1)} lbs';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onScaleStart: (details) {
            _lastFocalPoint = details.focalPoint;
            _zoomFactor = 1.0;
            // Handle touch interaction at start
            _updateTouch(details.localFocalPoint);
          },
          onScaleUpdate: (details) {
            if (details.scale != 1.0) {
              setState(() {
                // Calculate new zoom level with limits
                final newZoom =
                    (_zoomLevel * details.scale / _zoomFactor).clamp(1.0, 3.5);
                _zoomFactor = details.scale;
                _zoomLevel = newZoom;

                // Clear touch data when zooming
                _touchData = null;
              });
            } else if (_lastFocalPoint != null) {
              // Handle panning
              final delta = details.focalPoint.dx - _lastFocalPoint!.dx;
              setState(() {
                // Update pan offset with limits based on zoom level
                final maxOffset = _maxPanOffset * (_zoomLevel - 1);
                _panOffset =
                    (_panOffset + delta / 5).clamp(-maxOffset, maxOffset);
                _lastFocalPoint = details.focalPoint;
              });
            }
          },
          onScaleEnd: (details) {
            _lastFocalPoint = null;
          },
          onTapDown: (details) {
            _updateTouch(details.localPosition);
          },
          onTapUp: (details) {
            // Optional: Hide touch data after a delay
            // Future.delayed(Duration(seconds: 2), () {
            //   if (mounted) setState(() => _touchData = null);
            // });
          },
          child: CustomPaint(
            painter: _WeightChartPainter(
              weightPoints: _getFilteredData(),
              customColors: widget.customColors,
              targetWeight: widget.targetWeight,
              // animation: _animationController.value, // Removed animation parameter
              touchData: _touchData,
              isMetric: widget.isMetric,
              zoomLevel: _zoomLevel,
              panOffset: _panOffset,
              timeFrame: widget.timeFrame, // Pass the time frame to the painter
            ),
            size: Size.infinite,
          ),
        ),

        // Zoom indicator
        Positioned(
          right: 10,
          bottom: 10,
          child: AnimatedOpacity(
            opacity: _zoomLevel > 1.0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 200),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: widget.customColors.cardBackground.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.zoom_in,
                    size: 14,
                    color: widget.customColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(_zoomLevel).toStringAsFixed(1)}x',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: widget.customColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _zoomLevel = 1.0;
                        _panOffset = 0.0;
                      });
                    },
                    child: Icon(
                      Icons.refresh,
                      size: 14,
                      color: widget.customColors.accentPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _updateTouch(Offset position) {
    final size = context.size;
    if (size == null) return;

    final filteredData = _getFilteredData();
    if (filteredData.isEmpty) return;

    final chartWidth = size.width - 60; // Accounting for padding
    final chartHeight = size.height - 50; // Accounting for padding

    // Calculate min and max values
    final weights = filteredData.map((p) => p.weight).toList();
    final double minWeight = weights.reduce(math.min) - 1;
    final double maxWeight = weights.reduce(math.max) + 1;

    // Find closest point, accounting for zoom and pan
    double minDistance = double.infinity;
    WeightPoint? closestPoint;
    Offset? closestPos;

    // Calculate visible range based on zoom and pan
    final visibleRange = _getVisiblePointsIndices(filteredData.length);

    for (int i = visibleRange.start; i <= visibleRange.end; i++) {
      final point = filteredData[i];
      final pointX =
          _getXPositionForIndex(i, filteredData.length, chartWidth, size);
      final pointY = size.height -
          40 -
          ((point.weight - minWeight) / (maxWeight - minWeight)) * chartHeight;

      final distance = (Offset(pointX, pointY) - position).distance;
      if (distance < minDistance && distance < 30) {
        minDistance = distance;
        closestPoint = point;
        closestPos = Offset(pointX, pointY);
      }
    }

    setState(() {
      if (closestPoint != null && closestPos != null) {
        _touchData = TouchData(
          position: closestPos,
          point: closestPoint,
        );
      } else {
        _touchData = null;
      }
    });
  }

  // Calculate which points are visible based on zoom and pan
  _VisibleRange _getVisiblePointsIndices(int totalPoints) {
    if (totalPoints <= 1) return _VisibleRange(0, 0);

    // Calculate visible range based on zoom level and pan offset
    final visiblePortion = 1.0 / _zoomLevel;
    final center = 0.5 + (_panOffset / (_maxPanOffset * 2));

    // Calculate start and end indices
    int start = ((center - visiblePortion / 2) * (totalPoints - 1)).floor();
    int end = ((center + visiblePortion / 2) * (totalPoints - 1)).ceil();

    // Ensure indices are within bounds
    start = math.max(0, start);
    end = math.min(totalPoints - 1, end);

    return _VisibleRange(start, end);
  }

  // Calculate x position for point at index, accounting for zoom and pan
  double _getXPositionForIndex(
      int index, int totalPoints, double chartWidth, Size size) {
    final visibleRange = _getVisiblePointsIndices(totalPoints);
    final visibleCount = visibleRange.end - visibleRange.start;

    if (visibleCount <= 0 || totalPoints <= 1)
      return 30 + chartWidth / 2; // Center if no range or single point
    if (totalPoints > 1 && visibleCount == 0 && index == 0)
      return 30; // Handle edge case for single visible point at start
    if (totalPoints > 1 && visibleCount == 0 && index == totalPoints - 1)
      return 30 +
          chartWidth; // Handle edge case for single visible point at end

    if (visibleCount <= 0)
      return 30 +
          (totalPoints > 1
              ? (index / (totalPoints - 1)) * chartWidth
              : chartWidth / 2);

    // Map index to position within visible range
    final relativeIndex = index - visibleRange.start;
    return 30 + (relativeIndex / visibleCount) * chartWidth;
  }
}

// Class to track visible range of points
class _VisibleRange {
  final int start;
  final int end;

  _VisibleRange(this.start, this.end);
}

class _WeightChartPainter extends CustomPainter {
  final List<WeightPoint> weightPoints;
  final CustomColors customColors;
  final double targetWeight;
  // final double animation; // Removed animation field
  final TouchData? touchData;
  final bool isMetric;
  final double zoomLevel;
  final double panOffset;
  final String timeFrame;
  // Removed late final size, minWeight, maxWeight, visibleRange, animatedPoints
  // Paints and text painters will be initialized directly or within paint

  // Initialize paints that don't depend on size directly
  final Paint gridPaint = Paint()
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.round;

  final Paint linePaint = Paint()
    ..strokeWidth = 3.0
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  final Paint pointPaint = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  final Paint pointBorderPaint = Paint()
    ..strokeWidth = 2.5
    ..style = PaintingStyle.stroke
    ..isAntiAlias = true;

  final TextPainter labelPainter = TextPainter(
    textDirection: ui.TextDirection.ltr,
    textAlign: TextAlign.center,
  );

  _WeightChartPainter({
    required this.weightPoints,
    required this.customColors,
    required this.targetWeight,
    // required this.animation, // Removed animation parameter
    this.touchData,
    required this.isMetric,
    this.zoomLevel = 1.0,
    this.panOffset = 0.0,
    required this.timeFrame,
  });

  // Removed _initializeValues method

  List<WeightPoint> _getFilteredData() {
    // Similar to the method in CustomWeightChart
    final now = DateTime.now();
    final oneWeekAgo = now.subtract(const Duration(days: 7));
    final oneMonthAgo = DateTime(now.year, now.month - 1, now.day);
    final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
    final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
    final yearAgo = DateTime(now.year - 1, now.month, now.day);

    List<WeightPoint> filteredPoints;

    switch (timeFrame) {
      case 'Week':
        filteredPoints = weightPoints
            .where((point) =>
                point.date.isAfter(oneWeekAgo) ||
                point.date.isAtSameMomentAs(oneWeekAgo))
            .toList();
        break;
      case 'Month':
        filteredPoints = weightPoints
            .where((point) =>
                point.date.isAfter(oneMonthAgo) ||
                point.date.isAtSameMomentAs(oneMonthAgo))
            .toList();
        break;
      case '3 Months':
        filteredPoints = weightPoints
            .where((point) =>
                point.date.isAfter(threeMonthsAgo) ||
                point.date.isAtSameMomentAs(threeMonthsAgo))
            .toList();
        break;
      case '6 Months':
        filteredPoints = weightPoints
            .where((point) =>
                point.date.isAfter(sixMonthsAgo) ||
                point.date.isAtSameMomentAs(sixMonthsAgo))
            .toList();
        break;
      case 'Year':
        filteredPoints = weightPoints
            .where((point) =>
                point.date.isAfter(yearAgo) ||
                point.date.isAtSameMomentAs(yearAgo))
            .toList();
        break;
      default:
        filteredPoints = weightPoints;
    }

    // Sort points by date just to be sure
    filteredPoints.sort((a, b) => a.date.compareTo(b.date));

    return filteredPoints;
  }

  String getTimeFrame() {
    return timeFrame;
  }

  // Made this method static as it doesn't depend on instance state anymore
  static _VisibleRange _getVisiblePointsIndices(
      int totalPoints, double zoomLevel, double panOffset) {
    if (totalPoints <= 1) return _VisibleRange(0, 0);

    // Calculate visible range based on zoom level and pan offset
    // Note: Using fixed maxPanOffset here, consider passing if needed
    final visiblePortion = 1.0 / zoomLevel;
    final center =
        0.5 + (panOffset / (100.0 * 2)); // Assuming maxPanOffset is 100

    // Calculate start and end indices
    int start = ((center - visiblePortion / 2) * (totalPoints - 1)).floor();
    int end = ((center + visiblePortion / 2) * (totalPoints - 1)).ceil();

    // Ensure indices are within bounds
    start = math.max(0, start);
    end = math.min(totalPoints - 1, end);

    return _VisibleRange(start, end);
  }

  // Made this method static
  static double _getXPositionForIndex(int index, int totalPoints,
      double chartWidth, Size size, double zoomLevel, double panOffset) {
    final visibleRange =
        _getVisiblePointsIndices(totalPoints, zoomLevel, panOffset);
    final visibleCount = visibleRange.end - visibleRange.start;

    if (visibleCount <= 0 || totalPoints <= 1)
      return 30 + chartWidth / 2; // Center if no range or single point
    if (totalPoints > 1 && visibleCount == 0 && index == 0)
      return 30; // Handle edge case for single visible point at start
    if (totalPoints > 1 && visibleCount == 0 && index == totalPoints - 1)
      return 30 +
          chartWidth; // Handle edge case for single visible point at end

    if (visibleCount <= 0)
      return 30 +
          (totalPoints > 1
              ? (index / (totalPoints - 1)) * chartWidth
              : chartWidth / 2);

    // Map index to position within visible range
    final relativeIndex = index - visibleRange.start;
    return 30 + (relativeIndex / visibleCount) * chartWidth;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (weightPoints.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    // --- Start: Calculations moved from _initializeValues ---
    final weights = weightPoints.map((p) => p.weight).toList();
    final double minWeight = weights.isEmpty ? 0 : weights.reduce(math.min) - 1;
    final double maxWeight = weights.isEmpty ? 0 : weights.reduce(math.max) + 1;
    final _VisibleRange visibleRange =
        _getVisiblePointsIndices(weightPoints.length, zoomLevel, panOffset);

    final chartWidth = size.width - 60; // Accounting for padding
    final chartHeight = size.height - 50; // Height excluding bottom labels

    final List<Offset> animatedPoints = [];
    if (weightPoints.isNotEmpty) {
      final filteredPoints =
          _getFilteredData(); // Use filtered data based on timeFrame
      for (int i = visibleRange.start; i <= visibleRange.end; i++) {
        if (i < filteredPoints.length) {
          final point = filteredPoints[i];
          final pointX = _getXPositionForIndex(i, filteredPoints.length,
              chartWidth, size, zoomLevel, panOffset); // Pass zoom/pan
          final pointY = size.height -
              40 -
              ((point.weight - minWeight) / (maxWeight - minWeight)) *
                  chartHeight; // Removed * animation
          animatedPoints.add(Offset(pointX, pointY));
        }
      }
    }

    // Initialize paints that depend on size or customColors
    final Paint fillPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        [
          customColors.accentPrimary.withOpacity(0.4),
          customColors.accentPrimary.withOpacity(0.05),
        ],
      )
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final TextStyle labelStyle = TextStyle(
      color: customColors.textPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w500,
    );

    // Update colors for existing paints
    gridPaint.color = customColors.textSecondary.withOpacity(0.12);
    linePaint.color = customColors.accentPrimary;
    pointPaint.color = customColors.cardBackground;
    pointBorderPaint.color = customColors.accentPrimary;
    // --- End: Calculations moved from _initializeValues ---

    // Draw grid lines and labels
    _drawGrid(canvas, size, chartWidth, chartHeight, minWeight, maxWeight,
        labelStyle, visibleRange, animatedPoints); // Pass calculated values

    // Draw target weight line if in range
    if (targetWeight >= minWeight && targetWeight <= maxWeight) {
      _drawTargetLine(canvas, size, chartWidth, chartHeight, minWeight,
          maxWeight, labelStyle); // Pass calculated values
    }

    // Draw data points and connecting lines
    if (animatedPoints.length > 1) {
      // Draw area fill first (behind the line)
      _drawAreaFill(canvas, size, chartWidth, chartHeight, animatedPoints,
          fillPaint); // Pass calculated values

      // Draw connecting line
      _drawConnectingLine(canvas, size, chartWidth, chartHeight,
          animatedPoints); // Pass calculated values
    }

    // Draw individual data points
    _drawDataPoints(canvas, size, chartWidth, chartHeight,
        animatedPoints); // Pass calculated values

    // Draw touch interaction elements
    if (touchData != null) {
      _drawTouchInteraction(canvas, size, chartWidth, chartHeight,
          labelStyle); // Pass calculated values
    }
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final textStyle = TextStyle(
      color: customColors.textSecondary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );

    const text = 'No weight data available';
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout(maxWidth: size.width);
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height / 2 - 10),
    );
  }

  // Updated to accept calculated values
  void _drawGrid(
      Canvas canvas,
      Size size,
      double chartWidth,
      double chartHeight,
      double minWeight,
      double maxWeight,
      TextStyle labelStyle,
      _VisibleRange visibleRange,
      List<Offset> animatedPoints) {
    // Draw horizontal grid lines with improved spacing
    final gridLineCount = 5;
    for (int i = 0; i <= gridLineCount; i++) {
      final y = 20 + (i / gridLineCount) * chartHeight;

      // Draw grid line
      canvas.drawLine(
        Offset(30, y),
        Offset(size.width - 20, y),
        gridPaint,
      );

      // Draw weight labels
      if (i < gridLineCount) {
        final weight =
            maxWeight - (i / gridLineCount) * (maxWeight - minWeight);
        final formattedWeight = isMetric
            ? '${weight.toStringAsFixed(1)} kg'
            : '${(weight * 2.20462).toStringAsFixed(1)} lbs';

        labelPainter // Use the instance painter
          ..text = TextSpan(
            text: formattedWeight,
            style: labelStyle, // Use the passed labelStyle
          )
          ..layout(minWidth: 0, maxWidth: 60);

        labelPainter.paint(
          canvas,
          Offset(
              size.width - labelPainter.width - 5, y - labelPainter.height / 2),
        );
      }
    }

    // Draw date labels at the bottom if we have enough points
    if (animatedPoints.length > 1) {
      final filteredPoints =
          _getFilteredData(); // Still need filtered points for dates

      // Show appropriate number of date labels based on available width
      final maxLabels = math.max(3, (chartWidth / 100).floor());
      final step = filteredPoints.isEmpty
          ? 1
          : math.max(
              1, (visibleRange.end - visibleRange.start + 1) ~/ maxLabels);

      for (int i = visibleRange.start; i <= visibleRange.end; i += step) {
        if (i < filteredPoints.length) {
          final point = filteredPoints[i];
          final xPos = _getXPositionForIndex(i, filteredPoints.length,
              chartWidth, size, zoomLevel, panOffset); // Pass zoom/pan

          // Format date based on time frame
          String dateLabel;
          final timeFrame = getTimeFrame();
          if (timeFrame == 'Week') {
            dateLabel = DateFormat('E').format(point.date);
          } else if (timeFrame == 'Month') {
            dateLabel = DateFormat('d').format(point.date);
          } else {
            dateLabel = DateFormat('MMM d').format(point.date);
          }

          labelPainter // Use the instance painter
            ..text = TextSpan(
              text: dateLabel,
              style: labelStyle.copyWith(
                // Use the passed labelStyle
                fontSize: 10,
                color: customColors.textSecondary,
              ),
            )
            ..layout(minWidth: 0, maxWidth: 50);

          labelPainter.paint(
            canvas,
            Offset(xPos - labelPainter.width / 2,
                size.height - labelPainter.height),
          );
        }
      }
    }
  }

  // Updated to accept calculated values
  void _drawTargetLine(
      Canvas canvas,
      Size size,
      double chartWidth,
      double chartHeight,
      double minWeight,
      double maxWeight,
      TextStyle labelStyle) {
    final targetY = size.height -
        40 -
        ((targetWeight - minWeight) / (maxWeight - minWeight)) * chartHeight;

    // Target line
    final targetLinePaint = Paint()
      ..color = customColors.accentPrimary.withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw dashed line
    final dashWidth = 6;
    final dashSpace = 4;
    double startX = 30;
    final endX = size.width - 20;

    while (startX < endX) {
      final endDash = math.min(startX + dashWidth, endX);
      canvas.drawLine(
        Offset(startX, targetY),
        Offset(endDash, targetY),
        targetLinePaint,
      );
      startX = endDash + dashSpace;
    }

    // Target label
    labelPainter // Use the instance painter
      ..text = TextSpan(
        text: 'Target',
        style: labelStyle.copyWith(
          // Use the passed labelStyle
          color: customColors.accentPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      )
      ..layout(minWidth: 0, maxWidth: 50);

    // Draw small rectangle background
    final labelRect = Rect.fromLTWH(30, targetY - labelPainter.height / 2 - 2,
        labelPainter.width + 8, labelPainter.height + 4);

    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, const Radius.circular(4)),
      Paint()..color = customColors.cardBackground.withOpacity(0.8),
    );

    labelPainter.paint(
      canvas,
      Offset(34, targetY - labelPainter.height / 2),
    );
  }

  // Updated to accept calculated values
  void _drawAreaFill(Canvas canvas, Size size, double chartWidth,
      double chartHeight, List<Offset> animatedPoints, Paint fillPaint) {
    if (animatedPoints.length < 2) return;

    final path = Path();

    // Start from bottom left of the first point
    path.moveTo(animatedPoints.first.dx, size.height - 40);

    // Go to the first actual point
    path.lineTo(animatedPoints.first.dx, animatedPoints.first.dy);

    // Add all points using straight lines
    for (int i = 1; i < animatedPoints.length; i++) {
      path.lineTo(animatedPoints[i].dx, animatedPoints[i].dy);
    }

    // Close the path by going to the bottom right and then back to start
    path.lineTo(animatedPoints.last.dx, size.height - 40);
    path.lineTo(animatedPoints.first.dx, size.height - 40);

    canvas.drawPath(path, fillPaint); // Use the passed fillPaint
  }

  // Updated to accept calculated values
  void _drawConnectingLine(Canvas canvas, Size size, double chartWidth,
      double chartHeight, List<Offset> animatedPoints) {
    if (animatedPoints.length < 2) return;

    final path = Path();
    path.moveTo(animatedPoints.first.dx, animatedPoints.first.dy);

    // Draw straight lines between points
    for (int i = 1; i < animatedPoints.length; i++) {
      path.lineTo(animatedPoints[i].dx, animatedPoints[i].dy);
    }
    canvas.drawPath(path, linePaint); // Use the instance linePaint
  }

  // Updated to accept calculated values
  void _drawDataPoints(Canvas canvas, Size size, double chartWidth,
      double chartHeight, List<Offset> animatedPoints) {
    for (final point in animatedPoints) {
      // Draw outer stroke circle
      canvas.drawCircle(point, 5, pointBorderPaint); // Use instance paint

      // Draw inner fill circle
      canvas.drawCircle(point, 3.5, pointPaint); // Use instance paint
    }
  }

  // Updated to accept calculated values
  void _drawTouchInteraction(Canvas canvas, Size size, double chartWidth,
      double chartHeight, TextStyle labelStyle) {
    final touchPoint = touchData!.position;
    final weightPoint = touchData!.point;

    // Draw highlight circle
    canvas.drawCircle(
      touchPoint,
      8,
      Paint()
        ..color = customColors.accentPrimary.withOpacity(0.3)
        ..style = PaintingStyle.fill,
    );

    canvas.drawCircle(
      touchPoint,
      6,
      Paint()
        ..color = customColors.accentPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Draw tooltip background
    final weightText = isMetric
        ? '${weightPoint.weight.toStringAsFixed(1)} kg'
        : '${(weightPoint.weight * 2.20462).toStringAsFixed(1)} lbs';
    final dateText = DateFormat('MMM d, yyyy').format(weightPoint.date);

    // Prepare text painters
    final weightPainter = TextPainter(
      text: TextSpan(
        text: weightText,
        style: labelStyle.copyWith(
          // Use passed labelStyle
          fontWeight: FontWeight.w600,
          fontSize: 14,
          color: customColors.textPrimary,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final datePainter = TextPainter(
      text: TextSpan(
        text: dateText,
        style: labelStyle.copyWith(
          // Use passed labelStyle
          fontSize: 12,
          color: customColors.textSecondary,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    // Calculate tooltip dimensions and position
    final tooltipWidth = math.max(weightPainter.width, datePainter.width) + 20;
    final tooltipHeight = weightPainter.height + datePainter.height + 16;

    // Position tooltip to avoid going off-screen
    double tooltipX = touchPoint.dx - tooltipWidth / 2;
    if (tooltipX < 10) tooltipX = 10;
    if (tooltipX + tooltipWidth > size.width - 10) {
      tooltipX = size.width - tooltipWidth - 10;
    }

    // Position tooltip above or below the point depending on space
    final tooltipAbove = touchPoint.dy > tooltipHeight + 20;
    final tooltipY =
        tooltipAbove ? touchPoint.dy - tooltipHeight - 15 : touchPoint.dy + 15;

    // Draw tooltip background
    final tooltipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
      const Radius.circular(8),
    );

    canvas.drawRRect(
      tooltipRect,
      Paint()
        ..color = customColors.cardBackground
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    canvas.drawRRect(
      tooltipRect,
      Paint()
        ..color = customColors.textSecondary.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Draw tooltip text
    weightPainter.paint(
      canvas,
      Offset(tooltipX + (tooltipWidth - weightPainter.width) / 2, tooltipY + 8),
    );

    datePainter.paint(
      canvas,
      Offset(
        tooltipX + (tooltipWidth - datePainter.width) / 2,
        tooltipY + 8 + weightPainter.height + 4,
      ),
    );

    // Draw connecting line between tooltip and point
    final path = Path();
    if (tooltipAbove) {
      path.moveTo(touchPoint.dx, touchPoint.dy - 8);
      path.lineTo(tooltipX + tooltipWidth / 2, tooltipY + tooltipHeight);
    } else {
      path.moveTo(touchPoint.dx, touchPoint.dy + 8);
      path.lineTo(tooltipX + tooltipWidth / 2, tooltipY);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = customColors.textSecondary.withOpacity(0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_WeightChartPainter oldDelegate) {
    return oldDelegate.weightPoints != weightPoints ||
        // oldDelegate.animation != animation || // Removed animation check
        oldDelegate.touchData != touchData ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.panOffset != panOffset ||
        oldDelegate.isMetric != isMetric ||
        oldDelegate.timeFrame != timeFrame;
  }
}
