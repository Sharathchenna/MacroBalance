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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _loadGoals();
    _loadCurrentValues();
    _loadWeightData();
    _loadWeightUnit();
    _loadStepsData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToInitialSection();
    });
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

  Future<void> _saveGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> results = {
        'calorie_target': calorieGoal,
        'protein': proteinGoal,
        'carbs': carbGoal,
        'fat': fatGoal,
        'recommended_steps': stepsGoal,
        'bmr': bmr,
        'tdee': tdee,
      };
      await prefs.setString('macro_results', jsonEncode(results));
    } catch (e) {
      debugPrint('Error saving nutrition goals: $e');
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

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FoodEntryProvider, DateProvider>(
      builder: (context, foodEntryProvider, dateProvider, _) {
        final entries = foodEntryProvider.getAllEntriesForDate(DateTime.now());

        // Calculate nutrition values without modifying state
        double totalCarbs = 0;
        double totalFat = 0;
        double totalProtein = 0;
        double totalCalories = 0;

        for (var entry in entries) {
          final carbs =
              entry.food.nutrients["Carbohydrate, by difference"] ?? 0;
          final fat = entry.food.nutrients["Total lipid (fat)"] ?? 0;
          final protein = entry.food.nutrients["Protein"] ?? 0;

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
          totalCarbs += carbs * multiplier;
          totalFat += fat * multiplier;
          totalProtein += protein * multiplier;
          totalCalories += entry.food.calories * multiplier;
        }

        // Use local variables instead of modifying state
        final displayCalories = totalCalories.round();
        final displayCarbs = totalCarbs.round();
        final displayFat = totalFat.round();
        final displayProtein = totalProtein.round();

        return Scaffold(
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).scaffoldBackgroundColor,
                  Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
                ],
              ),
            ),
            child: SafeArea(
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(context),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      child: Column(
                        children: [
                          if (Platform.isIOS) ...[
                            _buildChartSection(
                              context: context,
                              title: 'Weight History',
                              chartWidget: _buildWeightChartView(),
                              chartColor: _getChartColor('weight'),
                              chartIcon: Icons.monitor_weight,
                            ),
                            const SizedBox(height: 24),
                            _buildChartSection(
                              context: context,
                              title: 'Steps',
                              chartWidget: _buildStepsChartView(),
                              chartColor: _getChartColor('steps'),
                              chartIcon: Icons.directions_walk,
                            ),
                            const SizedBox(height: 24),
                            _buildChartSection(
                              context: context,
                              title: 'Calories',
                              // Pass the local calories value instead of using state
                              chartWidget:
                                  _buildCaloriesChartView(displayCalories),
                              chartColor: _getChartColor('calories'),
                              chartIcon: Icons.local_fire_department,
                            ),
                          ] else ...[
                            Center(
                              child: Text(
                                'Native charts are only available on iOS devices',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChartSection({
    required BuildContext context,
    required String title,
    required Widget chartWidget,
    required Color chartColor,
    required IconData chartIcon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 2,
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
              Row(
                children: [
                  Icon(chartIcon, color: chartColor, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      color: chartColor,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (title == 'Weight History')
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showWeightLoggingBottomSheet(context);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: chartColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, color: chartColor, size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 300, // Fixed height for the chart
            width: double.infinity,
            child: _isLoadingGraphData
                ? const Center(child: CircularProgressIndicator())
                : ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: chartWidget,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightChartView() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getFormattedWeightData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading weight data'));
        }
        if (snapshot.hasData) {
          return FutureBuilder<Widget>(
            future: NativeChartService.createWeightChart(snapshot.data!),
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

  Color _getChartColor(String chartType) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (chartType) {
      case 'weight':
        return isDark ? Color(0xFF4FC3F7) : Color(0xFF0288D1);
      case 'steps':
        return isDark ? Color(0xFF4CD964) : Color(0xFF36C35D);
      case 'calories':
        return isDark ? Colors.redAccent : Colors.red;
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
                            hintStyle: TextStyle(fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: Colors.grey.withOpacity(0.3)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: weightColor, width: 2),
                            ),
                            filled: true,
                            fillColor:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.grey[800]
                                    : Colors.white,
                            border:
                                Border.all(color: Colors.grey.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              buildLocalUnitToggle('kg'),
                              Container(
                                height: 24,
                                width: 1,
                                color: Colors.grey.withOpacity(0.3),
                              ),
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
                          final weight = double.tryParse(weightText);
                          if (weight != null && weight > 0) {
                            setState(() => _weightUnit = sheetWeightUnit);
                            Navigator.pop(context);
                            _logWeight(weight);
                          } else {
                            _showErrorMessage('Please enter a valid weight');
                          }
                        } else {
                          _showErrorMessage('Please enter your weight');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: weightColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: true,
      pinned: true,
      elevation: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        title: Text(
          'Progress',
          style: TextStyle(
            color: Theme.of(context).extension<CustomColors>()!.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
      ),
      leading: Container(
        child: Center(
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_back_ios,
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      actions: [
        Container(
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.more_vert,
                size: 20,
                color: Theme.of(context).primaryColor,
              ),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                builder: (context) => _buildOptionsBottomSheet(context),
              );
            },
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          color: Theme.of(context).dividerColor.withOpacity(0.08),
          height: 1,
        ),
      ),
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
}
