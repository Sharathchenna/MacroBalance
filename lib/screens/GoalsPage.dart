// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/screens/editGoals.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'dart:math' as math;
import 'package:macrotracker/Health/Health.dart';

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

  // Add keys for each section we want to scroll to
  final GlobalKey _stepsChartKey = GlobalKey();

  // Graph selection state
  String _selectedGraphType = 'Weight'; // Default to calories
  bool _isLoadingGraphData = false;

  // Goal values
  int calorieGoal = 2000;
  int proteinGoal = 150;
  int carbGoal = 75;
  int fatGoal = 80;
  int stepsGoal = 9000;
  int bmr = 1500;
  int tdee = 2000;

  // Current values (for progress demonstration)
  int caloriesConsumed = 0;
  int proteinConsumed = 0;
  int carbsConsumed = 0;
  int fatConsumed = 0;
  int stepsCompleted = 0;

  // Weekly progress data (for the chart)
  final List<FlSpot> weeklyCaloriesData = [];
  final List<FlSpot> weeklyProteinData = [];
  final List<FlSpot> weightData = [];
  final List<String> weekDays = [];
  final List<String> weightDates = [];

  // Weight logging
  final TextEditingController _weightController = TextEditingController();
  String _weightUnit = 'kg'; // Default unit
  bool _isLoggingWeight = false;
  DateTime _selectedWeightDate =
      DateTime.now(); // Track selected date for weight logging

  // Steps data for the chart
  final List<FlSpot> stepsData = [];
  final List<double> stepsBarData = [];
  final List<String> stepsDays = [];
  List<Map<String, dynamic>> weeklyStepsData = [];
  bool _isHealthConnected = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _loadGoals();
    _loadCurrentValues();
    _generateWeeklyData();
    _loadWeightData();
    _loadWeightUnit();
    _loadStepsData();

    // Add post-frame callback to scroll to the requested section
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToInitialSection();
    });
  }

  // Add method to scroll to section
  void _scrollToInitialSection() {
    if (widget.initialSection == 'steps' &&
        _stepsChartKey.currentContext != null) {
      // Get the position of the steps section
      final RenderBox box =
          _stepsChartKey.currentContext!.findRenderObject() as RenderBox;
      final position = box.localToGlobal(Offset.zero);

      // Scroll to that position with some padding
      _scrollController.animateTo(
        position.dy - 100, // Subtract header height and some padding
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

  // Load current daily values (would normally come from food entry provider)
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
      }
      // Instead of generating dummy data, initialize with 0 if no progress exists
      else {
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

  // Load weight data
  Future<void> _loadWeightData() async {
    setState(() {
      _isLoadingGraphData = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? weightHistoryString = prefs.getString('weight_history');

      weightData.clear();
      weightDates.clear();

      if (weightHistoryString != null && weightHistoryString.isNotEmpty) {
        final List<dynamic> weightHistory = jsonDecode(weightHistoryString);

        // Sort by date
        weightHistory.sort((a, b) =>
            DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

        // Get the last 30 entries or all if less than 30
        final historyToShow = weightHistory.length > 30
            ? weightHistory.sublist(weightHistory.length - 30)
            : weightHistory;

        for (int i = 0; i < historyToShow.length; i++) {
          final entry = historyToShow[i];
          double weight = double.parse(entry['weight'].toString());
          // Always display in kg in the graph
          weightData.add(FlSpot(i.toDouble(), weight));

          final date = DateTime.parse(entry['date']);
          weightDates.add(DateFormat('MMM d').format(date));
        }
      } else {
        // Add some sample data if no weight history exists
        final now = DateTime.now();
        double defaultWeight = 70.0; // Always in kg

        for (int i = 6; i >= 0; i--) {
          final day = now.subtract(Duration(days: i));
          weightData.add(FlSpot(6 - i.toDouble(), defaultWeight));
          weightDates.add(DateFormat('MMM d').format(day));
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

  // Load preferred weight unit
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

  // Log weight for selected date
  Future<void> _logWeight(double weight) async {
    setState(() {
      _isLoggingWeight = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? weightHistoryString = prefs.getString('weight_history');
      final customColors = Theme.of(context).extension<CustomColors>();

      List<Map<String, dynamic>> weightHistory = [];
      if (weightHistoryString != null && weightHistoryString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(weightHistoryString);
        weightHistory = decoded.cast<Map<String, dynamic>>();
      }

      // Convert weight to kg for storage if needed
      double weightInKg = weight;
      if (_weightUnit == 'lbs') {
        weightInKg = weight / 2.20462; // Convert lbs to kg for storage
      }

      // Format the selected date
      final formattedDate =
          DateFormat('yyyy-MM-dd').format(_selectedWeightDate);

      // Check if there's already an entry for the selected date
      final existingIndex =
          weightHistory.indexWhere((entry) => entry['date'] == formattedDate);

      if (existingIndex >= 0) {
        // Update existing entry
        weightHistory[existingIndex]['weight'] = weightInKg;
      } else {
        // Add new entry
        weightHistory.add({
          'date': formattedDate,
          'weight': weightInKg,
        });
      }

      await prefs.setString('weight_history', jsonEncode(weightHistory));

      // Show success message
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

      // Reset date selection to today after successful logging
      setState(() {
        _selectedWeightDate = DateTime.now();
      });

      // Reload weight data to update the chart
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
          _isLoggingWeight = false;
          _weightController.clear(); // Clear the input field
        });
      }
    }
  }

  // Date picker for weight logging
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

  void _showEditDialog(
      String title, int currentValue, String unit, Function(int) onSave) {
    final TextEditingController controller =
        TextEditingController(text: currentValue.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit $title'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            suffixText: unit,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newValue = int.tryParse(controller.text);
              if (newValue != null && newValue > 0) {
                onSave(newValue);
                _saveGoals();
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // Generate weekly data for the chart
  void _generateWeeklyData() {
    setState(() {
      _isLoadingGraphData = true;
    });

    final now = DateTime.now();
    weeklyCaloriesData.clear();
    weeklyProteinData.clear();
    weekDays.clear();

    try {
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);

      for (int i = 6; i >= 0; i--) {
        final day = now.subtract(Duration(days: i));
        final entries = foodEntryProvider.getAllEntriesForDate(day);

        double totalCalories = 0;
        double totalProtein = 0;

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
          totalProtein += (entry.food.nutrients["Protein"] ?? 0) * multiplier;
        }

        weeklyCaloriesData.add(FlSpot(6 - i.toDouble(), totalCalories));
        weeklyProteinData.add(FlSpot(6 - i.toDouble(), totalProtein));
        weekDays.add(DateFormat('E').format(day));
      }
    } catch (e) {
      debugPrint('Error generating weekly data: $e');
      // Add some default data if there was an error
      if (weeklyCaloriesData.isEmpty) {
        for (int i = 6; i >= 0; i--) {
          final day = now.subtract(Duration(days: i));
          weeklyCaloriesData.add(FlSpot(6 - i.toDouble(), 0));
          weeklyProteinData.add(FlSpot(6 - i.toDouble(), 0));
          weekDays.add(DateFormat('E').format(day));
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGraphData = false;
        });
      }
    }
  }

  // Load steps data from Apple Health
  Future<void> _loadStepsData() async {
    setState(() {
      _isLoadingGraphData = true;
    });

    try {
      final healthService = HealthService();

      // Directly load the steps data without checking connection first
      weeklyStepsData = await healthService.getStepsForLastWeek();

      stepsData.clear();
      stepsBarData.clear();
      stepsDays.clear();

      if (weeklyStepsData.isNotEmpty) {
        // Convert the data for the graph
        for (int i = 0; i < weeklyStepsData.length; i++) {
          final dayData = weeklyStepsData[i];
          stepsData.add(FlSpot(i.toDouble(), dayData['steps'].toDouble()));
          stepsBarData.add(dayData['steps'].toDouble());
          stepsDays.add(dayData['day']);
        }

        // Update stepsCompleted with today's steps (last item in the list)
        setState(() {
          stepsCompleted = weeklyStepsData.last['steps'];
        });
      } else {
        // If no data was returned, use zeros
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
    stepsData.clear();
    stepsBarData.clear();
    stepsDays.clear();

    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final dayName = DateFormat('E').format(day);
      stepsData.add(FlSpot(6 - i.toDouble(), 0));
      stepsBarData.add(0);
      stepsDays.add(dayName);
    }
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
        // Calculate total macros from all food entries
        final entries = foodEntryProvider.getAllEntriesForDate(DateTime.now());

        double totalCarbs = 0;
        double totalFat = 0;
        double totalProtein = 0;
        double totalCalories = 0;

        for (var entry in entries) {
          final carbs =
              entry.food.nutrients["Carbohydrate, by difference"] ?? 0;
          final fat = entry.food.nutrients["Total lipid (fat)"] ?? 0;
          final protein = entry.food.nutrients["Protein"] ?? 0;

          // Convert quantity to grams
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

          // Since nutrients are per 100g, divide by 100 to get per gram
          final multiplier = quantityInGrams / 100;
          totalCarbs += carbs * multiplier;
          totalFat += fat * multiplier;
          totalProtein += protein * multiplier;
          totalCalories += entry.food.calories * multiplier;
        }

        // Update the state variables with actual values
        caloriesConsumed = totalCalories.round();
        carbsConsumed = totalCarbs.round();
        fatConsumed = totalFat.round();
        proteinConsumed = totalProtein.round();

        return GestureDetector(
          // Dismiss keyboard when tapping anywhere outside of text fields
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
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

                    // All progress charts in a column
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                        child: Column(
                          children: [
                            // Weight Chart Section
                            _buildChartSection(
                              context: context,
                              title: 'Weight History',
                              chartWidget: _buildWeightChart(context),
                              additionalWidget:
                                  _buildWeightLoggingSection(context),
                              chartColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Color(0xFF64B5F6)
                                  : Color(0xFF1976D2),
                              chartIcon: Icons.monitor_weight,
                            ),

                            const SizedBox(height: 24), // Gap between charts

                            // Steps Chart Section
                            _buildChartSection(
                              context: context,
                              title: 'Steps - Last 7 Days',
                              chartWidget: _buildStepsChart(context),
                              chartColor: Colors.green,
                              chartIcon: Icons.directions_walk,
                            ),

                            const SizedBox(height: 24), // Gap between charts

                            // Calories Chart Section
                            _buildChartSection(
                              context: context,
                              title: 'Calories - Last 7 Days',
                              chartWidget: _buildCaloriesChart(context),
                              chartColor: Colors.red,
                              chartIcon: Icons.local_fire_department,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Empty space at bottom
                    const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
                  ],
                ),
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
    Widget? additionalWidget,
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
                  Icon(
                    chartIcon,
                    color: chartColor,
                    size: 18,
                  ),
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
              // Only show the add button for weight history chart
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
                    child: Icon(
                      Icons.add,
                      color: chartColor,
                      size: 18,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            height: 280, // Consistent height for all charts
            child: _isLoadingGraphData
                ? Center(child: CircularProgressIndicator())
                : chartWidget,
          ),
          // Add additional widget if provided (but skip for weight since we moved it to modal)
          if (additionalWidget != null && title != 'Weight History')
            additionalWidget,
        ],
      ),
    );
  }

  // Add a new method to show the bottom sheet for weight logging
  void _showWeightLoggingBottomSheet(BuildContext context) {
    final Color weightColor = Theme.of(context).brightness == Brightness.dark
        ? Color(0xFF64B5F6) // Light blue for dark mode
        : Color(0xFF1976D2); // Darker blue for light mode

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
        // Create a state variable to track the selected unit within this bottom sheet
        String sheetWeightUnit = _weightUnit;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget buildLocalUnitToggle(String unit) {
              final isSelected = sheetWeightUnit == unit;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  if (!isSelected) {
                    // Update the local sheet state
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

  Widget _buildWeightLoggingSection(BuildContext context) {
    // Get the color to match chart
    final Color weightColor = Theme.of(context).brightness == Brightness.dark
        ? Color(0xFF64B5F6) // Light blue for dark mode
        : Color(0xFF1976D2); // Darker blue for light mode

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey[850]?.withOpacity(0.5)
            : Colors.grey[100]?.withOpacity(0.6),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_weight_rounded,
                color: weightColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Log Weight',
                style: TextStyle(
                  color: weightColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: weightColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: weightColor),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _selectDate(context);
                      },
                      child: Text(
                        DateFormat('MMM d, yyyy').format(_selectedWeightDate),
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
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => FocusScope.of(context).unfocus(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter weight',
                    hintStyle: TextStyle(fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: Colors.grey.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: weightColor, width: 2),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).brightness == Brightness.dark
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
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[800]
                        : Colors.white,
                    border: Border.all(color: Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildUnitToggleButton('kg'),
                      Container(
                        height: 24,
                        width: 1,
                        color: Colors.grey.withOpacity(0.3),
                      ),
                      _buildUnitToggleButton('lbs'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoggingWeight
                  ? null
                  : () {
                      HapticFeedback.selectionClick();
                      FocusScope.of(context).unfocus();
                      final weightText = _weightController.text.trim();
                      if (weightText.isNotEmpty) {
                        final weight = double.tryParse(weightText);
                        if (weight != null && weight > 0) {
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
              child: _isLoggingWeight
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUnitToggleButton(String unit) {
    final isSelected = _weightUnit == unit;

    // Get the color to match chart
    final Color weightColor = Theme.of(context).brightness == Brightness.dark
        ? Color(0xFF64B5F6) // Light blue for dark mode
        : Color(0xFF1976D2); // Darker blue for light mode

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        if (!isSelected) {
          setState(() {
            _weightUnit = unit;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? weightColor : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          unit,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
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

  Widget _buildCaloriesChart(BuildContext context) {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: calorieGoal / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.15),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < weekDays.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      weekDays[value.toInt()],
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.grey[400]
                            : Colors.grey[600],
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const SizedBox();
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: calorieGoal / 2,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey[400]
                        : Colors.grey[600],
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 40,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: calorieGoal.toDouble() * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: weeklyCaloriesData,
            isCurved: true,
            color: Colors.red,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.red,
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.red.withOpacity(0.3),
                  Colors.red.withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsChart(BuildContext context) {
    // Calculate the maximum value from the data or goal
    double maxValue = math.max(
        stepsBarData.isEmpty ? 0 : stepsBarData.reduce(math.max),
        stepsGoal.toDouble());
    // Set upper bound to 20% above the larger value
    double upperBound = maxValue * 1.2;

    // Add key to this widget for scrolling
    return Container(
      key: _stepsChartKey,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: upperBound,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${stepsBarData[groupIndex].toInt()} steps',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value >= 0 && value < stepsDays.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        stepsDays[value.toInt()],
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const SizedBox();
                },
                reservedSize: 30,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: upperBound / 4,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                      fontSize: 10,
                    ),
                  );
                },
                reservedSize: 40,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: upperBound / 4,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withOpacity(0.15),
                strokeWidth: 1,
              );
            },
          ),
          barGroups: stepsBarData.asMap().entries.map((entry) {
            final index = entry.key;
            final value = entry.value;

            // Calculate color based on reaching the goal
            final percentOfGoal = value / stepsGoal;
            Color barColor;
            if (percentOfGoal >= 1) {
              barColor = Colors.green;
            } else if (percentOfGoal >= 0.7) {
              barColor = Colors.amber;
            } else if (percentOfGoal >= 0.4) {
              barColor = Colors.orange;
            } else {
              barColor = Colors.redAccent;
            }

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: math.min(value, upperBound),
                  color: barColor,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: upperBound,
                    color: Colors.grey.withOpacity(0.1),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      barColor,
                      barColor.withOpacity(0.7),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ],
            );
          }).toList(),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: stepsGoal.toDouble(),
                color: Colors.green.withOpacity(0.8),
                strokeWidth: 2,
                dashArray: [8, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 8, bottom: 4),
                  style: const TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  labelResolver: (line) => 'Goal: $stepsGoal',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeightChart(BuildContext context) {
    // Find min and max weight for proper scaling
    double minWeight = 50.0; // Default min in kg
    double maxWeight = 100.0; // Default max in kg

    // Get chart color based on theme
    final Color chartColor = Theme.of(context).brightness == Brightness.dark
        ? Color(0xFF64B5F6) // Light blue for dark mode
        : Color(0xFF1976D2); // Darker blue for light mode

    if (weightData.isNotEmpty) {
      minWeight =
          weightData.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) -
              2.0;
      maxWeight =
          weightData.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) +
              2.0;
    }

    return Column(
      children: [
        // Container(
        //   height: 16,
        //   alignment: Alignment.centerRight,
        //   child: Row(
        //     mainAxisSize: MainAxisSize.min,
        //     children: [
        //       Icon(
        //         Icons.info_outline,
        //         size: 12,
        //         color: Colors.grey[600],
        //       ),
        //       Text(
        //         'Tap on data points for details',
        //         style: TextStyle(
        //           fontSize: 10,
        //           color: Colors.grey[600],
        //           fontStyle: FontStyle.italic,
        //         ),
        //       ),
        //     ],
        //   ),
        // ),
        const SizedBox(height: 4),
        Expanded(
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: (maxWeight - minWeight) / 5,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: Colors.grey.withOpacity(0.15),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 0, // Increased to give more room for labels
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index >= 0 && index < weightDates.length) {
                        // Only show labels at fixed intervals or for first/last point
                        bool showLabel = (weightDates.length <= 10) ||
                            (index % math.max(1, (weightDates.length ~/ 5)) ==
                                0) ||
                            (index == 0) ||
                            (index == weightDates.length - 1);

                        if (showLabel) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              weightDates[index],
                              style: TextStyle(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        }
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: (maxWeight - minWeight) / 4,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(1),
                        style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400]
                              : Colors.grey[600],
                          fontSize: 10,
                        ),
                      );
                    },
                    reservedSize: 30,
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  tooltipRoundedRadius: 8,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((spot) {
                      final index = spot.x.toInt();
                      String date =
                          index < weightDates.length ? weightDates[index] : '';
                      return LineTooltipItem(
                        '${spot.y.toStringAsFixed(1)} kg\n$date',
                        TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      );
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
                touchSpotThreshold: 100,
              ),
              minX: 0,
              maxX: weightData.isEmpty ? 6 : (weightData.length - 1).toDouble(),
              minY: minWeight,
              maxY: maxWeight,
              clipData:
                  FlClipData.all(), // Prevent drawing outside the chart area
              lineBarsData: [
                LineChartBarData(
                  spots: weightData,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: chartColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 5,
                        color: chartColor,
                        strokeWidth: 2,
                        strokeColor: Colors.white,
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        chartColor.withOpacity(0.3),
                        chartColor.withOpacity(0.05),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.grey[300]
                : Colors.grey[700],
          ),
        ),
      ],
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
        // margin: const EdgeInsets.only(left: 16),
        child: Center(
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                // color: Theme.of(context).primaryColor.withOpacity(0.1),
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
              // Show options menu
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
              _generateWeeklyData();
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

  Widget _buildGoalCard(Map<String, dynamic> data) {
    final progress = data['currentValue'] != null
        ? data['currentValue'] / data['value']
        : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: data['editable'] == true ? data['onEdit'] : null,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  data['color'].withOpacity(0.15),
                  data['color'].withOpacity(0.05),
                ],
              ),
              border: Border.all(
                color: data['color'].withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: data['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            data['icon'],
                            color: data['color'],
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          data['title'],
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (data['editable'] == true)
                      Icon(
                        Icons.edit,
                        size: 20,
                        color: data['color'],
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                data['currentValue'] != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${data['currentValue']} / ${data['value']} ${data['unit']}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: _getProgressColor(progress),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              backgroundColor: Colors.grey.withOpacity(0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  _getProgressColor(progress)),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            data['secondaryValue'] != null
                                ? '${data['value']} / ${data['secondaryValue']} ${data['unit']}'
                                : '${data['value']} ${data['unit']}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getProgressColor(double progress) {
    if (progress >= 0.9) return Colors.green;
    if (progress >= 0.7) return Colors.lime;
    if (progress >= 0.5) return Colors.orange;
    return Colors.red;
  }

  Map<String, dynamic> getGoalData(int index) {
    switch (index) {
      case 0:
        return {
          'title': 'Daily Calorie Goal',
          'value': calorieGoal,
          'currentValue': caloriesConsumed,
          'unit': 'kcal',
          'icon': Icons.local_fire_department,
          'color': Colors.orange,
          'editable': true,
          'onEdit': () => _showEditDialog(
                'Daily Calorie Goal',
                calorieGoal,
                'kcal',
                (value) => setState(() => calorieGoal = value),
              ),
        };
      case 1:
        return {
          'title': 'Protein Goal',
          'value': proteinGoal,
          'currentValue': proteinConsumed,
          'unit': 'g',
          'icon': Icons.fitness_center,
          'color': Colors.red,
          'editable': true,
          'onEdit': () => _showEditDialog(
                'Protein Goal',
                proteinGoal,
                'g',
                (value) => setState(() => proteinGoal = value),
              ),
        };
      case 2:
        return {
          'title': 'Carbohydrate Goal',
          'value': carbGoal,
          'currentValue': carbsConsumed,
          'unit': 'g',
          'icon': Icons.grain,
          'color': Colors.blue,
          'editable': true,
          'onEdit': () => _showEditDialog(
                'Carbohydrate Goal',
                carbGoal,
                'g',
                (value) => setState(() => carbGoal = value),
              ),
        };
      case 3:
        return {
          'title': 'Fat Goal',
          'value': fatGoal,
          'currentValue': fatConsumed,
          'unit': 'g',
          'icon': Icons.opacity,
          'color': Colors.yellow,
          'editable': true,
          'onEdit': () => _showEditDialog(
                'Fat Goal',
                fatGoal,
                'g',
                (value) => setState(() => fatGoal = value),
              ),
        };
      case 4:
        return {
          'title': 'Daily Steps Goal',
          'value': stepsGoal,
          'currentValue': stepsCompleted,
          'unit': 'steps',
          'icon': Icons.directions_walk,
          'color': Colors.green,
          'editable': true,
          'onEdit': () => _showEditDialog(
                'Daily Steps Goal',
                stepsGoal,
                'steps',
                (value) => setState(() => stepsGoal = value),
              ),
        };
      default:
        return {
          'title': '',
          'value': 0,
          'unit': '',
          'icon': Icons.help,
          'color': Colors.grey,
          'editable': false,
        };
    }
  }
}
