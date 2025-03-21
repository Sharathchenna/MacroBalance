// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/screens/editGoals.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/Health/Health.dart';
import 'dart:io' show Platform;
import 'package:macrotracker/services/native_chart_service.dart';

class GoalsScreen extends StatefulWidget {
  final String? initialSection;
  const GoalsScreen({super.key, this.initialSection});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _stepsChartKey = GlobalKey();
  bool _isLoadingGraphData = false;

  // Goal values
  int calorieGoal = 2000;
  int proteinGoal = 150;
  int carbGoal = 75;
  int fatGoal = 80;
  int stepsGoal = 9000;
  int bmr = 1500;
  int tdee = 2000;

  // Current values
  int caloriesConsumed = 0;
  int proteinConsumed = 0;
  int carbsConsumed = 0;
  int fatConsumed = 0;
  int stepsCompleted = 0;

  // Weight logging
  final TextEditingController _weightController = TextEditingController();
  String _weightUnit = 'kg';
  DateTime _selectedWeightDate = DateTime.now();

  // Add this variable at class level
  List<Map<String, dynamic>> weeklyStepsData = [];

  // At the top of the _GoalsScreenState class, add the hover state variable
  String? _hoveredCard;

  int _selectedIndex = 0;
  PageController _pageController = PageController();

  // Add this variable to store selected week dates for macros view
  DateTime _macrosStartDate = DateTime.now().subtract(const Duration(days: 6));
  DateTime _macrosEndDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _controller.forward();

    _loadGoals();
    _loadCurrentValues();
    _loadWeightData();
    _loadWeightUnit();
    _loadStepsData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToInitialSection();
    });

    _pageController = PageController();
  }

  void _scrollToInitialSection() {
    if (widget.initialSection == 'steps' &&
        _stepsChartKey.currentContext != null) {
      final RenderBox box =
          _stepsChartKey.currentContext!.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero);
      _scrollController.animateTo(
        position.dy - 100,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _loadGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? resultsString = prefs.getString('macro_results');

      if (resultsString != null && resultsString.isNotEmpty) {
        final Map<String, dynamic> results = jsonDecode(resultsString);
        if (mounted) {
          setState(() {
            calorieGoal = results['calorie_target'] ?? 2000;
            proteinGoal = results['protein'] ?? 150;
            carbGoal = results['carbs'] ?? 75;
            fatGoal = results['fat'] ?? 80;
            stepsGoal = results['recommended_steps'] ?? 9000;
            bmr = results['bmr'] ?? 1500;
            tdee = results['tdee'] ?? 2000;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading nutrition goals: $e');
    }
  }

  Future<void> _loadCurrentValues() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? dailyProgress = prefs.getString('daily_progress');

      if (dailyProgress != null && dailyProgress.isNotEmpty) {
        final Map<String, dynamic> progress = jsonDecode(dailyProgress);
        if (mounted) {
          setState(() {
            caloriesConsumed = progress['calories'] ?? 0;
            proteinConsumed = progress['protein'] ?? 0;
            carbsConsumed = progress['carbs'] ?? 0;
            fatConsumed = progress['fat'] ?? 0;
            stepsCompleted = progress['steps'] ?? 0;
          });
        }
      } else {
        setState(() {
          caloriesConsumed = 0;
          proteinConsumed = 0;
          carbsConsumed = 0;
          fatConsumed = 0;
          stepsCompleted = 0;
        });
      }
    } catch (e) {
      debugPrint('Error loading daily progress: $e');
    }
  }

  Future<void> _loadWeightData() async {
    setState(() {
      _isLoadingGraphData = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? weightHistoryString = prefs.getString('weight_history');

      if (weightHistoryString != null && weightHistoryString.isNotEmpty) {
        final List<dynamic> weightHistory = jsonDecode(weightHistoryString);

        weightHistory.sort((a, b) =>
            DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

        if (mounted) {
          setState(() {
            _isLoadingGraphData = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading weight data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGraphData = false;
        });
      }
    }
  }

  Future<void> _loadWeightUnit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? unit = prefs.getString('weight_unit');
      if (unit != null && (unit == 'kg' || unit == 'lbs')) {
        setState(() {
          _weightUnit = unit;
        });
      }
    } catch (e) {
      debugPrint('Error loading weight unit: $e');
    }
  }

  Future<void> _logWeight(double weight) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? weightHistoryString = prefs.getString('weight_history');

      List<Map<String, dynamic>> weightHistory = [];
      if (weightHistoryString != null && weightHistoryString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(weightHistoryString);
        weightHistory = decoded.cast<Map<String, dynamic>>();
      }

      double weightInKg = weight;
      if (_weightUnit == 'lbs') {
        weightInKg = weight / 2.20462;
      }

      final formattedDate =
          DateFormat('yyyy-MM-dd').format(_selectedWeightDate);

      final existingIndex =
          weightHistory.indexWhere((entry) => entry['date'] == formattedDate);

      if (existingIndex >= 0) {
        weightHistory[existingIndex]['weight'] = weightInKg;
      } else {
        weightHistory.add({
          'date': formattedDate,
          'weight': weightInKg,
        });
      }

      await prefs.setString('weight_history', jsonEncode(weightHistory));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 10),
                Text(
                  'Weight logged for ${DateFormat('MMM d, yyyy').format(_selectedWeightDate)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }

      setState(() {
        _selectedWeightDate = DateTime.now();
      });

      _loadWeightData();
    } catch (e) {
      debugPrint('Error logging weight: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log weight: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _weightController.clear();
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final customColors = Theme.of(context).extension<CustomColors>();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedWeightDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDarkMode
                ? ColorScheme.dark(
                    primary: Theme.of(context).primaryColor,
                    onPrimary: Colors.white,
                    onSurface: customColors!.textPrimary,
                    surface: customColors.cardBackground,
                  )
                : ColorScheme.light(
                    primary: Theme.of(context).primaryColor,
                    onPrimary: Colors.white,
                    onSurface: customColors!.textPrimary,
                  ),
            dialogBackgroundColor: customColors.cardBackground,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedWeightDate) {
      setState(() {
        _selectedWeightDate = picked;
      });
    }
  }

  // Update _loadStepsData to populate weeklyStepsData
  Future<void> _loadStepsData() async {
    setState(() {
      _isLoadingGraphData = true;
    });

    try {
      final healthService = HealthService();
      weeklyStepsData = await healthService.getStepsForLastWeek();

      if (weeklyStepsData.isNotEmpty) {
        setState(() {
          stepsCompleted = weeklyStepsData.last['steps'];
        });
      } else {
        _addDefaultStepsData();
      }
    } catch (e) {
      debugPrint('Error loading steps data: $e');
      _addDefaultStepsData();
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGraphData = false;
        });
      }
    }
  }

  void _addDefaultStepsData() {
    final now = DateTime.now();
    weeklyStepsData = List.generate(7, (index) {
      final day = now.subtract(Duration(days: 6 - index));
      return {
        'date': day.toIso8601String(),
        'steps': 0,
        'goal': stepsGoal,
      };
    });
  }

  Future<String> _getLatestWeight() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? weightHistoryString = prefs.getString('weight_history');

      if (weightHistoryString != null && weightHistoryString.isNotEmpty) {
        final List<dynamic> weightHistory = jsonDecode(weightHistoryString);
        if (weightHistory.isNotEmpty) {
          weightHistory.sort((a, b) =>
              DateTime.parse(b['date']).compareTo(DateTime.parse(a['date'])));

          double weight = weightHistory.first['weight'];
          if (_weightUnit == 'lbs') {
            weight *= 2.20462; // Convert kg to lbs
          }
          return weight.toStringAsFixed(1) + ' ' + _weightUnit;
        }
      }
      return '-- ' + _weightUnit;
    } catch (e) {
      debugPrint('Error getting latest weight: $e');
      return '-- ' + _weightUnit;
    }
  }

  void _showOptionsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _buildOptionsBottomSheet(context),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _weightController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FoodEntryProvider, DateProvider>(
      builder: (context, foodEntryProvider, dateProvider, _) {
        final entries = foodEntryProvider.getAllEntriesForDate(DateTime.now());
        double totalCalories = 0;

        for (var entry in entries) {
          double quantityInGrams = entry.quantity;
          switch (entry.unit) {
            case "oz":
              quantityInGrams *= 28.35;
              break;
            case "kg":
              quantityInGrams *= 1000;
              break;
            case "lbs":
              quantityInGrams *= 453.59;
              break;
          }

          final multiplier = quantityInGrams / 100;
          totalCalories += entry.food.calories * multiplier;
        }

        final displayCalories = totalCalories.round();

        return Theme(
          data: Theme.of(context).copyWith(
            shadowColor: Colors.transparent,
          ),
          child: Scaffold(
            body: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor,
                    Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[900]!.withOpacity(0.8)
                        : Colors.grey[50]!.withOpacity(0.8),
                  ],
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    _buildNavigationHeader(context),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _selectedIndex = index);
                          HapticFeedback.selectionClick();
                        },
                        children: [
                          AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double value = 1.0;
                              if (_pageController.position.haveDimensions) {
                                value = (_pageController.page! - 0).abs();
                                value = (1 - (value.clamp(0.0, 1.0)))
                                    .clamp(0.7, 1.0);
                              }
                              return Transform.scale(
                                scale: value,
                                child: Opacity(
                                  opacity: value,
                                  child: _buildWeightPage(context),
                                ),
                              );
                            },
                          ),
                          AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double value = 1.0;
                              if (_pageController.position.haveDimensions) {
                                value = (_pageController.page! - 1).abs();
                                value = (1 - (value.clamp(0.0, 1.0)))
                                    .clamp(0.7, 1.0);
                              }
                              return Transform.scale(
                                scale: value,
                                child: Opacity(
                                  opacity: value,
                                  child: _buildStepsPage(context),
                                ),
                              );
                            },
                          ),
                          AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double value = 1.0;
                              if (_pageController.position.haveDimensions) {
                                value = (_pageController.page! - 2).abs();
                                value = (1 - (value.clamp(0.0, 1.0)))
                                    .clamp(0.7, 1.0);
                              }
                              return Transform.scale(
                                scale: value,
                                child: Opacity(
                                  opacity: value,
                                  child: _buildCaloriesPage(
                                      context, displayCalories),
                                ),
                              );
                            },
                          ),
                          AnimatedBuilder(
                            animation: _pageController,
                            builder: (context, child) {
                              double value = 1.0;
                              if (_pageController.position.haveDimensions) {
                                value = (_pageController.page! - 3).abs();
                                value = (1 - (value.clamp(0.0, 1.0)))
                                    .clamp(0.7, 1.0);
                              }
                              return Transform.scale(
                                scale: value,
                                child: Opacity(
                                  opacity: value,
                                  child: _buildMacrosPage(context),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: _buildBottomNavigationBar(),
          ),
        );
      },
    );
  }

  Widget _buildNavigationHeader(BuildContext context) {
    final titles = [
      'Weight Tracking',
      'Step Counter',
      'Calorie Monitor',
      'Macros Analysis'
    ];
    final icons = [
      Icons.monitor_weight,
      Icons.directions_walk,
      Icons.local_fire_department,
      Icons.pie_chart
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          _buildBackButton(context),
          const SizedBox(width: 16),
          Expanded(
            child: TweenAnimationBuilder<double>(
              duration: const Duration(milliseconds: 300),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(20 * (1 - value), 0),
                    child: Row(
                      key: ValueKey(_selectedIndex),
                      children: [
                        Icon(
                          icons[_selectedIndex],
                          color: Theme.of(context).primaryColor,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          titles[_selectedIndex],
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            foreground: Paint()
                              ..shader = LinearGradient(
                                colors: [
                                  Theme.of(context).primaryColor,
                                  Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.7),
                                ],
                              ).createShader(
                                  const Rect.fromLTWH(0, 0, 200, 70)),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).primaryColor,
            ),
            onPressed: () => _showOptionsBottomSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightPage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWeightStats(context),
          const SizedBox(height: 24),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildWeightChartView(),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showWeightLoggingBottomSheet(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              minimumSize: Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add, size: 20),
                const SizedBox(width: 8),
                Text('Log Weight'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsPage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStepsSummaryCard(),
          const SizedBox(height: 24),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildStepsChartView(),
            ),
          ),
          const SizedBox(height: 24),
          _buildStepsWeeklySummary(),
        ],
      ),
    );
  }

  Widget _buildStepsSummaryCard() {
    final progressPercent = (stepsCompleted / stepsGoal).clamp(0.0, 1.0);
    final remainingSteps = stepsGoal - stepsCompleted;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
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
                    '$stepsCompleted',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    'steps today',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).primaryColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(progressPercent * 100).round()}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    '$remainingSteps to go',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).primaryColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progressPercent,
            backgroundColor: Colors.grey[300],
            valueColor:
                AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsWeeklySummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weekly Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ...weeklyStepsData.map((data) {
            final date = DateTime.parse(data['date']);
            final steps = data['steps'] as int;
            final progress = (steps / stepsGoal).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(
                      DateFormat('EEE, MMM d').format(date),
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$steps steps',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildCaloriesPage(BuildContext context, int displayCalories) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCaloriesSummaryCard(displayCalories),
          const SizedBox(height: 24),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildCaloriesChartView(displayCalories),
            ),
          ),
          const SizedBox(height: 24),
          _buildCaloriesBreakdown(displayCalories),
        ],
      ),
    );
  }

  Widget _buildCaloriesSummaryCard(int displayCalories) {
    final progressPercent = (displayCalories / calorieGoal).clamp(0.0, 1.0);
    final remainingCalories = calorieGoal - displayCalories;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
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
                    '$displayCalories',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    'calories consumed',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).primaryColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${(progressPercent * 100).round()}%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  Text(
                    '$remainingCalories left',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).primaryColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progressPercent,
            backgroundColor: Colors.grey[300],
            valueColor:
                AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildCaloriesBreakdown(int displayCalories) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calorie Breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildCalorieBreakdownItem(
                label: 'BMR',
                value: bmr,
                color: Colors.blue,
              ),
              _buildCalorieBreakdownItem(
                label: 'TDEE',
                value: tdee,
                color: Colors.green,
              ),
              _buildCalorieBreakdownItem(
                label: 'Goal',
                value: calorieGoal,
                color: Theme.of(context).primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalorieBreakdownItem({
    required String label,
    required int value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.local_fire_department,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar() {
    final isIOS = Platform.isIOS;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: isIOS ? _buildIOSStyleNavBar() : _buildMaterialNavBar(),
      ),
    );
  }

  Widget _buildIOSStyleNavBar() {
    final icons = [
      Icons.monitor_weight,
      Icons.directions_walk,
      Icons.local_fire_department,
      Icons.pie_chart
    ];
    final labels = ['Weight', 'Steps', 'Calories', 'Macros'];

    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(4, (index) {
          final isSelected = _selectedIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedIndex = index);
              _pageController.animateToPage(
                index,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
              HapticFeedback.selectionClick();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor.withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icons[index],
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Theme.of(context).primaryColor.withOpacity(0.5),
                    size: 24,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[index],
                    style: TextStyle(
                      color: isSelected
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).primaryColor.withOpacity(0.5),
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildMaterialNavBar() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: (index) {
        setState(() => _selectedIndex = index);
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
        HapticFeedback.selectionClick();
      },
      items: [
        BottomNavigationBarItem(
          icon: Icon(Icons.monitor_weight),
          label: 'Weight',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.directions_walk),
          label: 'Steps',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.local_fire_department),
          label: 'Calories',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.pie_chart),
          label: 'Macros',
        ),
      ],
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Theme.of(context).primaryColor.withOpacity(0.5),
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      elevation: 0,
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Hero(
      tag: 'back_button',
      child: Material(
        color: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              size: 20,
              color: Theme.of(context).primaryColor,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.of(context).pop();
            },
          ),
        ),
      ),
    );
  }

  Widget _buildWeightStats(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getWeightStats(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasData) {
          final stats = snapshot.data!;
          final weightChange = stats['change'] as double;
          final percentChange = stats['percentChange'] as double;
          final trend = stats['trend'] as String;
          final startWeight = stats['startWeight'] as double;
          final currentWeight = stats['currentWeight'] as double;

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).primaryColor.withOpacity(0.1),
                  Theme.of(context).primaryColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWeightStatCard(
                      context: context,
                      label: 'Start',
                      value: '${startWeight.toStringAsFixed(1)} $_weightUnit',
                      icon: Icons.play_circle_outline,
                      color: Colors.blue,
                      isFirst: true,
                    ),
                    _buildWeightStatCard(
                      context: context,
                      label: 'Current',
                      value: '${currentWeight.toStringAsFixed(1)} $_weightUnit',
                      icon: Icons.radio_button_checked,
                      color: Colors.green,
                      isFirst: false,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildWeightStatCard(
                      context: context,
                      label: 'Change',
                      value:
                          '${weightChange >= 0 ? '+' : ''}${weightChange.toStringAsFixed(1)} $_weightUnit',
                      icon: Icons.trending_up,
                      color: weightChange >= 0 ? Colors.orange : Colors.blue,
                      isFirst: true,
                    ),
                    _buildWeightStatCard(
                      context: context,
                      label: 'Progress',
                      value:
                          '${percentChange >= 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}%',
                      icon: Icons.percent,
                      color: percentChange >= 0 ? Colors.orange : Colors.blue,
                      isFirst: false,
                    ),
                  ],
                ),
                if (trend.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.insights,
                          size: 16,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          trend,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildWeightStatCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isFirst,
  }) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 800),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, animationValue, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - animationValue)),
          child: Opacity(
            opacity: animationValue,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 20, color: color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      color: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.color
                          ?.withOpacity(0.7),
                      fontSize: 12,
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

  Future<Map<String, dynamic>> _getWeightStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? weightHistoryString = prefs.getString('weight_history');

      if (weightHistoryString != null && weightHistoryString.isNotEmpty) {
        final List<dynamic> weightHistory = jsonDecode(weightHistoryString);
        if (weightHistory.length >= 2) {
          weightHistory.sort((a, b) =>
              DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

          double startWeight = weightHistory.first['weight'];
          double currentWeight = weightHistory.last['weight'];

          if (_weightUnit == 'lbs') {
            startWeight *= 2.20462;
            currentWeight *= 2.20462;
          }

          final change = currentWeight - startWeight;
          final percentChange = (change / startWeight) * 100;

          // Calculate trend
          String trend = '';
          if (weightHistory.length >= 7) {
            final last7Weights = weightHistory
                .skip(weightHistory.length - 7)
                .map((e) => e['weight'] as double)
                .toList();
            bool isIncreasing = true;
            bool isDecreasing = true;

            for (int i = 1; i < last7Weights.length; i++) {
              if (last7Weights[i] <= last7Weights[i - 1]) isIncreasing = false;
              if (last7Weights[i] >= last7Weights[i - 1]) isDecreasing = false;
            }

            if (isIncreasing) {
              trend = 'Trending upward over the last week';
            } else if (isDecreasing) {
              trend = 'Trending downward over the last week';
            } else {
              trend = 'Weight fluctuating over the last week';
            }
          }

          return {
            'startWeight': startWeight,
            'currentWeight': currentWeight,
            'change': change,
            'percentChange': percentChange,
            'trend': trend,
          };
        }
      }

      // Return default values if not enough data
      return {
        'startWeight': 0.0,
        'currentWeight': 0.0,
        'change': 0.0,
        'percentChange': 0.0,
        'trend': '',
      };
    } catch (e) {
      debugPrint('Error calculating weight stats: $e');
      return {
        'startWeight': 0.0,
        'currentWeight': 0.0,
        'change': 0.0,
        'percentChange': 0.0,
        'trend': '',
      };
    }
  }

  Widget _buildWeightChartView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getFormattedWeightData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildChartLoadingState('weight');
        }
        if (snapshot.hasError) {
          return _buildChartErrorState('weight data');
        }
        if (snapshot.hasData) {
          return FutureBuilder<Widget>(
            future: NativeChartService.createWeightChart(snapshot.data!),
            builder: (context, widgetSnapshot) {
              if (widgetSnapshot.connectionState == ConnectionState.waiting) {
                return _buildChartLoadingState('weight');
              }
              if (widgetSnapshot.hasError) {
                return _buildChartErrorState('chart rendering');
              }
              if (widgetSnapshot.hasData) {
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: widgetSnapshot.data!,
                );
              }
              return _buildChartLoadingState('weight');
            },
          );
        }
        return _buildChartLoadingState('weight');
      },
    );
  }

  Widget _buildStepsChartView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getFormattedStepsData(),
      builder: (context, stepsDataSnapshot) {
        if (stepsDataSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (stepsDataSnapshot.hasError) {
          return Center(child: Text('Error loading steps data'));
        }

        if (stepsDataSnapshot.hasData) {
          return FutureBuilder<Widget>(
            future:
                NativeChartService.createStepsChart(stepsDataSnapshot.data!),
            builder: (context, widgetSnapshot) {
              if (widgetSnapshot.hasData) {
                return widgetSnapshot.data!;
              }
              return Center(child: CircularProgressIndicator());
            },
          );
        }

        return Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildCaloriesChartView(int displayCalories) {
    // Format calories data for the chart using the current displayCalories value
    List<Map<String, dynamic>> formattedData =
        _getFormattedCaloriesData(displayCalories);

    return FutureBuilder<Widget>(
      future: NativeChartService.createCaloriesChart(formattedData),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return snapshot.data!;
        }
        return Center(child: CircularProgressIndicator());
      },
    );
  }

  List<Map<String, dynamic>> _getFormattedCaloriesData(int displayCalories) {
    final now = DateTime.now();
    List<Map<String, dynamic>> formattedData = [];

    // Add today's calories from the passed parameter
    formattedData.add({
      'calories': displayCalories.toDouble(),
      'goal': calorieGoal.toDouble(),
      'date': now.toIso8601String(),
    });

    // Add previous 6 days data
    for (int i = 6; i >= 1; i--) {
      final date = now.subtract(Duration(days: i));
      final entries = Provider.of<FoodEntryProvider>(context, listen: false)
          .getAllEntriesForDate(date);

      double totalCalories = 0;
      for (var entry in entries) {
        double quantityInGrams = entry.quantity;
        switch (entry.unit) {
          case "oz":
            quantityInGrams *= 28.35;
            break;
          case "kg":
            quantityInGrams *= 1000;
            break;
          case "lbs":
            quantityInGrams *= 453.59;
            break;
        }
        final multiplier = quantityInGrams / 100;
        totalCalories += entry.food.calories * multiplier;
      }

      formattedData.add({
        'calories': totalCalories,
        'goal': calorieGoal.toDouble(),
        'date': date.toIso8601String(),
      });
    }

    // Sort the data by date
    formattedData.sort((a, b) =>
        DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

    debugPrint('[GoalsPage] Formatted calories data: $formattedData');
    return formattedData;
  }

  Future<List<Map<String, dynamic>>> _getFormattedWeightData() async {
    // Format weight data for native charts
    final prefs = await SharedPreferences.getInstance();
    final String? weightHistoryString = prefs.getString('weight_history');
    List<Map<String, dynamic>> formattedData = [];

    if (weightHistoryString != null && weightHistoryString.isNotEmpty) {
      final List<dynamic> weightHistory = jsonDecode(weightHistoryString);
      weightHistory.sort((a, b) =>
          DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

      // Ensure the data structure matches what iOS expects
      formattedData = weightHistory.map((entry) {
        // Make sure we have the expected fields
        return {
          'weight': entry['weight'] is int
              ? entry['weight'].toDouble()
              : entry['weight'],
          'date': entry['date'],
        };
      }).toList();

      debugPrint('[GoalsPage] Formatted weight data: $formattedData');
    }

    // Return empty list if no data
    if (formattedData.isEmpty) {
      final now = DateTime.now();
      // Add some default data points for last 7 days
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        formattedData.add({
          'weight': 0.0,
          'date': DateFormat('yyyy-MM-dd').format(date),
        });
      }
    }

    return formattedData;
  }

  Future<List<Map<String, dynamic>>> _getFormattedStepsData() async {
    // Don't call _loadStepsData during build - this was causing setState during build
    // Instead, just use the existing data or provide empty data

    // Format steps data for native charts with ISO8601 date strings
    List<Map<String, dynamic>> formattedData = weeklyStepsData.map((data) {
      // Ensure date is in the correct ISO8601 format
      String dateStr = data['date'];
      if (!dateStr.contains('T')) {
        // Convert YYYY-MM-DD to ISO8601 format
        dateStr = DateTime.parse(dateStr).toIso8601String();
      }

      return {
        'steps': data['steps'] is int ? data['steps'] : 0,
        'goal': stepsGoal, // Use current goal
        'date': dateStr,
      };
    }).toList();

    debugPrint('[GoalsPage] Formatted steps data: $formattedData');

    // Ensure we have at least 7 data points if data is empty
    if (formattedData.isEmpty) {
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        formattedData.add({
          'steps': 0,
          'goal': stepsGoal,
          'date': date.toIso8601String(),
        });
      }
    }

    return formattedData;
  }

  Widget _buildChartLoadingState(String chartType) {
    Color color = _getChartColor(chartType);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading data...',
            style: TextStyle(
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withOpacity(0.7),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartErrorState(String errorType) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading $errorType',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Pull down to refresh',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.color
                    ?.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _isLoadingGraphData = true;
                });
                _loadWeightData();
              },
              icon: Icon(Icons.refresh, size: 18),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getChartColor(String chartType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (chartType) {
      case 'weight':
        return isDark ? Color(0xFF4FC3F7) : Color(0xFF0288D1);
      case 'steps':
        return isDark ? Color(0xFF4CD964) : Color(0xFF36C35D);
      case 'calories':
        return isDark ? Colors.redAccent : Colors.red;
      case 'macros':
        return isDark ? Colors.purpleAccent : Colors.purple;
      default:
        return Colors.blue;
    }
  }

  void _showWeightLoggingBottomSheet(BuildContext context) {
    final Color weightColor = Theme.of(context).brightness == Brightness.dark
        ? Color(0xFF64B5F6)
        : Color(0xFF1976D2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.grey[850]
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        String sheetWeightUnit = _weightUnit;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildLocalUnitToggle(String unit) {
              final isSelected = sheetWeightUnit == unit;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (!isSelected) {
                    setSheetState(() {
                      sheetWeightUnit = unit;
                    });
                  }
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? weightColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    unit,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[600],
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 20,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Icon(Icons.monitor_weight_rounded,
                          color: weightColor, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        'Log Weight',
                        style: TextStyle(
                          color: weightColor,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: weightColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today,
                                size: 14, color: weightColor),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _selectDate(context),
                              child: Text(
                                DateFormat('MMM d, yyyy')
                                    .format(_selectedWeightDate),
                                style: TextStyle(
                                  color: weightColor,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => FocusScope.of(context).unfocus(),
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            hintText: 'Enter weight',
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: weightColor),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border:
                                Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              buildLocalUnitToggle('kg'),
                              buildLocalUnitToggle('lbs'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        final weightText = _weightController.text.trim();
                        if (weightText.isNotEmpty) {
                          try {
                            final weight = double.parse(weightText);
                            _logWeight(weight);
                            Navigator.pop(context);
                          } catch (e) {
                            _showErrorMessage('Please enter a valid weight');
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: weightColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save Weight',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOptionsBottomSheet(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          _buildOptionTile(
            context: context,
            icon: Icons.refresh,
            title: 'Refresh Data',
            onTap: () {
              Navigator.pop(context);
              _loadStepsData();
              _loadWeightData();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data refreshed'),
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          _buildOptionTile(
            context: context,
            icon: Icons.edit,
            title: 'Edit Goals',
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const EditGoalsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Theme.of(context).primaryColor),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildMacrosPage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMacrosSummaryCard(),
          const SizedBox(height: 24),
          Container(
            height: 300,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _buildMacrosChartView(),
            ),
          ),
          const SizedBox(height: 24),
          _buildMacrosWeekSelector(),
          const SizedBox(height: 24),
          _buildMacrosDetailCard(),
        ],
      ),
    );
  }

  Widget _buildMacrosSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
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
                    'Macro Nutrients',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Balance your diet for optimal nutrition',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).primaryColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              CircleAvatar(
                backgroundColor:
                    Theme.of(context).primaryColor.withOpacity(0.2),
                radius: 24,
                child: Icon(
                  Icons.pie_chart,
                  color: Theme.of(context).primaryColor,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNutrientIndicator(
                label: 'Protein',
                value: proteinConsumed,
                goal: proteinGoal,
                color: Colors.amber,
              ),
              _buildNutrientIndicator(
                label: 'Carbs',
                value: carbsConsumed,
                goal: carbGoal,
                color: Colors.teal,
              ),
              _buildNutrientIndicator(
                label: 'Fat',
                value: fatConsumed,
                goal: fatGoal,
                color: Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientIndicator({
    required String label,
    required int value,
    required int goal,
    required Color color,
  }) {
    final percentage = (value / goal).clamp(0.0, 1.0);
    return Column(
      children: [
        SizedBox(
          height: 64,
          width: 64,
          child: Stack(
            children: [
              Center(
                child: CircularProgressIndicator(
                  value: percentage,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  backgroundColor: color.withOpacity(0.2),
                  strokeWidth: 8,
                ),
              ),
              Center(
                child: Text(
                  '${(percentage * 100).round()}%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '$value/${goal}g',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }

  Widget _buildMacrosWeekSelector() {
    final startDay = DateFormat('MMM d').format(_macrosStartDate);
    final endDay = DateFormat('MMM d').format(_macrosEndDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _macrosStartDate =
                    _macrosStartDate.subtract(const Duration(days: 7));
                _macrosEndDate =
                    _macrosEndDate.subtract(const Duration(days: 7));
              });
            },
          ),
          Text(
            '$startDay - $endDay',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: _macrosEndDate.isBefore(DateTime.now())
                ? () {
                    setState(() {
                      _macrosStartDate =
                          _macrosStartDate.add(const Duration(days: 7));
                      _macrosEndDate =
                          _macrosEndDate.add(const Duration(days: 7));
                    });
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosDetailCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macros Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recommended Balance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildMacrosBar(
                      carbPercent:
                          carbGoal / (carbGoal + proteinGoal + fatGoal),
                      proteinPercent:
                          proteinGoal / (carbGoal + proteinGoal + fatGoal),
                      fatPercent: fatGoal / (carbGoal + proteinGoal + fatGoal),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Current Balance',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildMacrosBar(
                      carbPercent: carbsConsumed /
                          (carbsConsumed + proteinConsumed + fatConsumed)
                              .clamp(1, double.infinity),
                      proteinPercent: proteinConsumed /
                          (carbsConsumed + proteinConsumed + fatConsumed)
                              .clamp(1, double.infinity),
                      fatPercent: fatConsumed /
                          (carbsConsumed + proteinConsumed + fatConsumed)
                              .clamp(1, double.infinity),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosBar({
    required double carbPercent,
    required double proteinPercent,
    required double fatPercent,
  }) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            flex: (carbPercent * 100).round(),
            child: Container(color: Colors.teal),
          ),
          Expanded(
            flex: (proteinPercent * 100).round(),
            child: Container(color: Colors.amber),
          ),
          Expanded(
            flex: (fatPercent * 100).round(),
            child: Container(color: Colors.purple),
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosChartView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getFormattedMacrosData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildChartLoadingState('macros');
        }

        if (snapshot.hasError) {
          return _buildChartErrorState('macros data');
        }

        if (snapshot.hasData) {
          return FutureBuilder<Widget>(
            future: NativeChartService.createMacrosChart(snapshot.data!),
            builder: (context, widgetSnapshot) {
              if (widgetSnapshot.connectionState == ConnectionState.waiting) {
                return _buildChartLoadingState('macros');
              }

              if (widgetSnapshot.hasError) {
                return _buildChartErrorState('chart rendering');
              }

              if (widgetSnapshot.hasData) {
                return AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 500),
                  child: widgetSnapshot.data!,
                );
              }

              return _buildChartLoadingState('macros');
            },
          );
        }

        return _buildChartLoadingState('macros');
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getFormattedMacrosData() async {
    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);
    List<Map<String, dynamic>> formattedData = [];

    // Generate data for each day in the selected week
    for (int i = 0; i <= 6; i++) {
      final day = _macrosStartDate.add(Duration(days: i));
      final entries = foodEntryProvider.getAllEntriesForDate(day);

      double totalProteins = 0;
      double totalCarbs = 0;
      double totalFats = 0;

      for (var entry in entries) {
        double quantityInGrams = entry.quantity;
        switch (entry.unit) {
          case "oz":
            quantityInGrams *= 28.35;
            break;
          case "kg":
            quantityInGrams *= 1000;
            break;
          case "lbs":
            quantityInGrams *= 453.59;
            break;
        }

        final multiplier = quantityInGrams / 100;
        // Access nutrients from the food's nutrients map using the correct keys
        totalProteins += (entry.food.nutrients['Protein'] ?? 0.0) * multiplier;
        totalCarbs +=
            (entry.food.nutrients['Carbohydrate, by difference'] ?? 0.0) *
                multiplier;
        totalFats +=
            (entry.food.nutrients['Total lipid (fat)'] ?? 0.0) * multiplier;
      }

      formattedData.add({
        'date': day.toIso8601String(),
        'proteins': totalProteins,
        'carbs': totalCarbs,
        'fats': totalFats,
        'proteinGoal': proteinGoal.toDouble(),
        'carbGoal': carbGoal.toDouble(),
        'fatGoal': fatGoal.toDouble(),
      });
    }

    debugPrint('[GoalsPage] Formatted macros data: $formattedData');
    return formattedData;
  }
}
