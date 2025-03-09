// ignore_for_file: file_names, avoid_print

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/camera/camera.dart';
import 'package:macrotracker/screens/GoalsPage.dart';
import 'package:macrotracker/screens/accountdashboard.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../Health/Health.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import '../providers/dateProvider.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  Widget build(BuildContext context) {
    // Calculate dynamic sizes based on screen dimensions.
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Content
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                DateNavigatorbar(),
                CalorieTracker(),
                Expanded(child: MealSection())
              ],
            ),
            // Updated Navigation Bar - frosted and translucent
            Positioned(
              bottom: screenHeight * 0.015,
              left: screenWidth * 0.1,
              right: screenWidth * 0.1,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14.0),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14.0),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                        sigmaX: 15.0, sigmaY: 15.0), // Increased blur
                    child: Container(
                      height: 42,
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14.0),
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.white.withOpacity(
                                0.6) // Light theme translucent white
                            : Colors.black.withOpacity(
                                0.4), // Dark theme translucent black
                        border: Border.all(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.white.withOpacity(0.1),
                          width: 0.5,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItemCompact(
                            context: context,
                            icon: CupertinoIcons.add,
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoSheetRoute(
                                    builder: (context) => FoodSearchPage()),
                              );
                            },
                          ),
                          _buildNavItemCompact(
                            context: context,
                            icon: CupertinoIcons.camera,
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (context) => CameraScreen()),
                              );
                            },
                          ),
                          _buildNavItemCompact(
                            context: context,
                            icon: CupertinoIcons.graph_circle,
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoSheetRoute(
                                    builder: (context) => GoalsScreen()),
                              );
                            },
                          ),
                          _buildNavItemCompact(
                            context: context,
                            icon: CupertinoIcons.person,
                            onTap: () {
                              Navigator.push(
                                context,
                                CupertinoSheetRoute(
                                    builder: (context) => Accountdashboard()),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Smaller compact navigation item with updated styling for frosted glass effect
Widget _buildNavItemCompact({
  required BuildContext context,
  required IconData icon,
  required VoidCallback onTap,
  bool isActive = false,
}) {
  return Expanded(
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFFFFC107).withOpacity(0.2)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: const Color(0xFFFFC107),
          size: 20,
        ),
      ),
    ),
  );
}

// Keep original _buildNavItem for reference, but we're not using it anymore
// Helper method to build navigation items
Widget _buildNavItem({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool isActive = false,
}) {
  return Expanded(
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isActive
                  ? const Color(0xFFFFC107).withOpacity(0.15)
                  : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFFFFC107),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).extension<CustomColors>()?.textPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

// First, update the DateNavigatorbar class to be stateful
class DateNavigatorbar extends StatefulWidget {
  const DateNavigatorbar({super.key});

  @override
  State<DateNavigatorbar> createState() => _DateNavigatorbarState();
}

class _DateNavigatorbarState extends State<DateNavigatorbar> {
  DateTime selectedDate = DateTime.now();

  void _navigateDate(int days) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final newDate = dateProvider.selectedDate.add(Duration(days: days));
    dateProvider.setDate(newDate);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    final tomorrow = now.add(Duration(days: 1));

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'Tomorrow';
    }
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year.toString().substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(
            child: _buildNavigationButton(
              icon: Icons.chevron_left,
              onTap: () => _navigateDate(-1),
            ),
          ),
          Expanded(
            child: _buildDateButton(),
          ),
          Expanded(
            child: _buildNavigationButton(
              icon: Icons.chevron_right,
              onTap: () => _navigateDate(1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color:
          Theme.of(context).extension<CustomColors>()?.dateNavigatorBackground,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7.0), // Reduced from 8
          child: Icon(
            icon,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            size: 18, // Add specific size
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton() {
    return Consumer<DateProvider>(
      builder: (context, dateProvider, child) {
        return Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(18.0), // Slightly reduced
            onTap: () {
              dateProvider.setDate(DateTime.now());
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14.0, vertical: 7.0), // Reduced
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .extension<CustomColors>()
                    ?.dateNavigatorBackground,
                borderRadius: BorderRadius.circular(18.0), // Slightly reduced
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.calendar_today,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : Colors.white,
                    size: 14, // Reduced from 16
                  ),
                  const SizedBox(width: 6.0), // Reduced from 8
                  Text(
                    _formatDate(dateProvider.selectedDate),
                    style: GoogleFonts.poppins(
                      fontSize: 13, // Add specific size
                      fontWeight: FontWeight.w500, // Make it medium weight
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black
                          : Colors.white,
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
}

class CalorieTracker extends StatefulWidget {
  const CalorieTracker({super.key});

  @override
  State<CalorieTracker> createState() => _CalorieTrackerState();
}

class _CalorieTrackerState extends State<CalorieTracker> {
  final HealthService _healthService = HealthService();
  int steps = 0;
  double caloriesBurned = 0;
  bool _hasHealthPermissions = false;

  // Nutrition goals loaded from SharedPreferences
  int caloriesGoal = 2000;
  int carbGoal = 75;
  int fatGoal = 80;
  int proteinGoal = 150;
  int stepsGoal = 9000;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
    _loadNutritionGoals();
  }

  Future<void> _loadNutritionGoals() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? resultsString = prefs.getString('macro_results');
      if (resultsString != null && resultsString.isNotEmpty) {
        final Map<String, dynamic> results = jsonDecode(resultsString);
        if (mounted) {
          // Check if the widget is still mounted before calling setState
          setState(() {
            caloriesGoal = results['calorie_target'] ?? 2000;
            proteinGoal = results['protein'] ?? 150;
            carbGoal = results['carbs'] ?? 75;
            fatGoal = results['fat'] ?? 80;
            stepsGoal = results['recommended_steps'] ?? 9000;
          });
        }
      }
    } catch (e) {
      print('Error loading nutrition goals: $e');
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      final granted = await _healthService.requestPermissions();
      if (!mounted) return; // Check if widget is still mounted
      setState(() {
        _hasHealthPermissions = granted;
      });

      if (_hasHealthPermissions) {
        await _fetchHealthData();
      } else if (mounted) {
        // Check if widget is still mounted before showing dialog
        _showPermissionDialog();
      }
    } catch (e) {
      print('Error checking permissions: $e');
    }
  }

  void _showPermissionDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text('Health Data Access Required'),
        content: Text(
            'This app needs access to your health data to track calories and steps.'),
        actions: [
          CupertinoDialogAction(
            child: Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: Text('Open Settings'),
            onPressed: () {
              Navigator.pop(context);
              // Open app settings
              openAppSettings();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _fetchHealthData() async {
    final fetchedSteps = await _healthService.getSteps();
    final fetchedCalories = await _healthService.getCalories();
    if (mounted) {
      // Check if widget is still mounted before calling setState
      setState(() {
        steps = fetchedSteps;
        caloriesBurned = fetchedCalories;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<FoodEntryProvider, DateProvider>(
      builder: (context, foodEntryProvider, dateProvider, child) {
        // Calculate total macros from all food entries
        final entries =
            foodEntryProvider.getAllEntriesForDate(dateProvider.selectedDate);

        double totalCarbs = 0;
        double totalFat = 0;
        double totalProtein = 0;

        for (var entry in entries) {
          final carbs =
              entry.food.nutrients["Carbohydrate, by difference"] ?? 0;
          final fat = entry.food.nutrients["Total lipid (fat)"] ?? 0;
          final protein = entry.food.nutrients["Protein"] ?? 0;

          final multiplier = entry.quantity;
          totalCarbs += carbs * multiplier;
          totalFat += fat * multiplier;
          totalProtein += protein * multiplier;
        }

        // Calculate calories from food entries
        final caloriesFromFood = foodEntryProvider
            .getTotalCaloriesForDate(dateProvider.selectedDate);

        // Calculate remaining calories
        final int caloriesRemaining =
            caloriesGoal - caloriesBurned.toInt() - caloriesFromFood.toInt();
        double progress = (caloriesBurned + caloriesFromFood) / caloriesGoal;
        progress = progress.clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16), // Reduced from 20
          decoration: BoxDecoration(
            color: Theme.of(context).extension<CustomColors>()?.cardBackground,
            borderRadius: BorderRadius.circular(20.0), // Slightly reduced
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey.withOpacity(0.08) // More subtle shadow
                    : Colors.black.withOpacity(0.1),
                blurRadius: 16,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align to start
            children: [
              // Add a header
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  "Today's Nutrition",
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .extension<CustomColors>()
                        ?.textPrimary,
                  ),
                ),
              ),

              // Rest of your existing code...
              Column(
                children: [
                  // Calories Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Calorie Circle
                      Container(
                        height: 130,
                        width: 130,
                        decoration: BoxDecoration(
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.white
                                  : Colors.grey.shade900.withOpacity(0.3),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.grey.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              spreadRadius: 1,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Progress circle
                            SizedBox(
                              width: 110,
                              height: 110,
                              child: CircularProgressIndicator(
                                value: progress,
                                strokeWidth: 10,
                                backgroundColor: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.grey.shade200
                                    : Colors.grey.shade800,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  progress > 1.0
                                      ? Colors.red
                                      : const Color(0xFF34C85A),
                                ),
                              ),
                            ),
                            // Calorie text
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  caloriesRemaining.toString(),
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context)
                                        .extension<CustomColors>()
                                        ?.textPrimary,
                                  ),
                                ),
                                Text(
                                  'cal left',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Calories Info - Vertical layout with colored cards
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              _buildCalorieInfoCard(
                                context,
                                'Goal',
                                caloriesGoal,
                                const Color(0xFF34C85A),
                                Icons.flag,
                              ),
                              const SizedBox(height: 8),
                              _buildCalorieInfoCard(
                                context,
                                'Food',
                                caloriesFromFood.toInt(),
                                const Color(0xFFFFA726),
                                Icons.restaurant,
                              ),
                              const SizedBox(height: 8),
                              _buildCalorieInfoCard(
                                context,
                                'Burned',
                                caloriesBurned.toInt(),
                                const Color(0xFF42A5F5),
                                Icons.local_fire_department,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Macro section header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4.0, vertical: 4.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.pie_chart_outline,
                          size: 14,
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Macronutrients & Activity",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Macro circles - Enhanced with circular progress
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMacroProgressEnhanced(
                          context,
                          'Carbs',
                          totalCarbs.round(),
                          carbGoal,
                          const Color(0xFF42A5F5),
                          'g',
                        ),
                        _buildMacroProgressEnhanced(
                          context,
                          'Protein',
                          totalProtein.round(),
                          proteinGoal,
                          const Color(0xFFEF5350),
                          'g',
                        ),
                        _buildMacroProgressEnhanced(
                          context,
                          'Fat',
                          totalFat.round(),
                          fatGoal,
                          const Color(0xFFFFA726),
                          'g',
                        ),
                        _buildMacroProgressEnhanced(
                          context,
                          'Steps',
                          steps,
                          stepsGoal,
                          const Color(0xFF66BB6A),
                          '',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _buildCalorieInfo(
    BuildContext context, String label, int value, Color color) {
  return Row(
    children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).extension<CustomColors>()?.textPrimary,
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildMacroProgress(
    BuildContext context, String label, int value, int goal, Color color) {
  double progress = (value / goal).clamp(0.0, 1.0);

  return Column(
    children: [
      Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      const SizedBox(height: 8),
      SizedBox(
        height: 40,
        width: 6,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: progress,
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '$value',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).extension<CustomColors>()?.textPrimary,
        ),
      ),
    ],
  );
}

Widget _buildCalorieInfoEnhanced(
    BuildContext context, String label, int value, Color color) {
  return Row(
    children: [
      Container(
        width: 8, // Reduced size
        height: 8, // Reduced size
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2), // More subtle shadow
              spreadRadius: 1,
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12, // Reduced from 14
              fontWeight: FontWeight.w500,
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$value',
            style: GoogleFonts.poppins(
              fontSize: 16, // Reduced from 18
              fontWeight: FontWeight.w600,
              color: Theme.of(context).extension<CustomColors>()?.textPrimary,
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildMacroProgressEnhanced(BuildContext context, String label,
    int value, int goal, Color color, String unit) {
  double progress = (value / goal).clamp(0.0, 1.0);
  double percentage = (progress * 100).roundToDouble();

  return Container(
    width: 70,
    child: Column(
      children: [
        Container(
          height: 70,
          width: 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              Container(
                height: 64,
                width: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey.shade100
                      : Colors.grey.shade800.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
              ),
              // Progress circle
              SizedBox(
                height: 64,
                width: 64,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 6,
                  backgroundColor:
                      Theme.of(context).brightness == Brightness.light
                          ? color.withOpacity(0.15)
                          : color.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
              // Macro icon
              Icon(
                _getMacroIcon(label),
                color: color,
                size: 20,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).extension<CustomColors>()?.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: '$value',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color:
                      Theme.of(context).extension<CustomColors>()?.textPrimary,
                ),
              ),
              if (unit.isNotEmpty)
                TextSpan(
                  text: unit,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w400,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
            ],
          ),
        ),
        Text(
          '${percentage.toInt()}%',
          style: GoogleFonts.poppins(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: color,
          ),
        ),
      ],
    ),
  );
}

// Add this helper method to get appropriate icons for macros
IconData _getMacroIcon(String label) {
  switch (label) {
    case 'Carbs':
      return Icons.grain;
    case 'Protein':
      return Icons.fitness_center;
    case 'Fat':
      return Icons.opacity;
    case 'Steps':
      return Icons.directions_walk;
    default:
      return Icons.circle;
  }
}

// Add this class after your existing code
class MealSection extends StatefulWidget {
  const MealSection({super.key});

  @override
  State<MealSection> createState() => _MealSectionState();
}

class _MealSectionState extends State<MealSection> {
  Map<String, bool> expandedState = {
    'Breakfast': false,
    'Lunch': false,
    'Snacks': false,
    'Dinner': false,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            _buildMealCard('Breakfast'),
            _buildMealCard('Lunch'),
            _buildMealCard('Snacks'),
            _buildMealCard('Dinner'),
            SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildMealCard(String mealType) {
    return Consumer2<FoodEntryProvider, DateProvider>(
      builder: (context, foodEntryProvider, dateProvider, child) {
        final entries = foodEntryProvider.getEntriesForMeal(
            mealType, dateProvider.selectedDate);
        double totalCalories = entries.fold(0, (sum, entry) {
          final energy = entry.food.calories;
          return sum + (energy * entry.quantity);
        });

        // Meal type icon mapping
        IconData getMealIcon() {
          switch (mealType) {
            case 'Breakfast':
              return Icons.breakfast_dining;
            case 'Lunch':
              return Icons.lunch_dining;
            case 'Dinner':
              return Icons.dinner_dining;
            case 'Snacks':
              return Icons.cookie;
            default:
              return Icons.restaurant;
          }
        }

        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).extension<CustomColors>()?.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey.withOpacity(0.1)
                    : Colors.black12,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                // Header section
                InkWell(
                  onTap: () {
                    setState(() {
                      expandedState[mealType] = !expandedState[mealType]!;
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14), // Reduced padding
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6), // Reduced from 8
                          decoration: BoxDecoration(
                            color: _getMealColor(mealType).withOpacity(0.1),
                            borderRadius:
                                BorderRadius.circular(10), // More compact
                          ),
                          child: Icon(
                            getMealIcon(),
                            color: _getMealColor(mealType),
                            size: 20, // Reduced from 24
                          ),
                        ),
                        const SizedBox(width: 12), // Reduced from 16
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mealType,
                                style: GoogleFonts.poppins(
                                  fontSize: 16, // Reduced from 18
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .extension<CustomColors>()
                                      ?.textPrimary,
                                ),
                              ),
                              Text(
                                '${entries.length} item${entries.length != 1 ? 's' : ''}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11, // Reduced from 13
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${totalCalories.toStringAsFixed(0)} kcal',
                              style: GoogleFonts.poppins(
                                fontSize: 14, // Reduced from 16
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .extension<CustomColors>()
                                    ?.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            AnimatedRotation(
                              turns: expandedState[mealType]! ? 0.5 : 0,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                Icons.expand_more,
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.grey.shade700
                                    : Colors.grey.shade400,
                                size: 18, // Reduced size
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Food entries list
                AnimatedCrossFade(
                  firstChild: const SizedBox(height: 0),
                  secondChild: Column(
                    children: [
                      const Divider(height: 1, thickness: 1),
                      ...entries.map((entry) =>
                          _buildFoodItem(context, entry, foodEntryProvider)),
                      Padding(
                        padding: const EdgeInsets.all(14.0), // Reduced from 16
                        child: InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              CupertinoSheetRoute(
                                  builder: (context) => FoodSearchPage()),
                            );
                          },
                          borderRadius:
                              BorderRadius.circular(10), // More compact
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 14), // Reduced from 12,16
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.grey.shade100
                                  : Colors.grey.shade800,
                              borderRadius:
                                  BorderRadius.circular(10), // More compact
                              border: Border.all(
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.grey.shade300
                                    : Colors.grey.shade700,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.add_circle_outline,
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.blue.shade700
                                      : Colors.blue.shade300,
                                  size: 16, // Reduced from 20
                                ),
                                const SizedBox(width: 6), // Reduced from 8
                                Text(
                                  'Add Food to $mealType',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12, // Reduced from 14
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.blue.shade700
                                        : Colors.blue.shade300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  crossFadeState: expandedState[mealType]!
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 300),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Add this helper method for meal color
Color _getMealColor(String mealType) {
  switch (mealType) {
    case 'Breakfast':
      return Colors.orange;
    case 'Lunch':
      return Colors.green;
    case 'Dinner':
      return Colors.indigo;
    case 'Snacks':
      return Colors.purple;
    default:
      return Colors.blue;
  }
}

// Add this helper method for food items
Widget _buildFoodItem(
    BuildContext context, dynamic entry, FoodEntryProvider provider) {
  return Dismissible(
    key: Key(entry.id),
    background: Container(
      color: Colors.red,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    ),
    direction: DismissDirection.endToStart,
    onDismissed: (direction) {
      provider.removeEntry(entry.id);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10), // Reduced padding
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36, // Reduced from 40
            height: 36, // Reduced from 40
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.grey.shade100
                  : Colors.grey.shade800,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.restaurant,
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.grey.shade600
                  : Colors.grey.shade400,
              size: 18, // Reduced size
            ),
          ),
          const SizedBox(width: 12), // Reduced from 16
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.food.name,
                  style: GoogleFonts.poppins(
                    fontSize: 14, // Reduced from 16
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context)
                        .extension<CustomColors>()
                        ?.textPrimary,
                  ),
                ),
                Text(
                  '${entry.quantity}${entry.unit}',
                  style: GoogleFonts.poppins(
                    fontSize: 11, // Reduced from 13
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${(entry.food.calories * entry.quantity).toStringAsFixed(0)} kcal',
            style: GoogleFonts.poppins(
              fontSize: 13, // Reduced from 15
              fontWeight: FontWeight.w600,
              color: Theme.of(context).extension<CustomColors>()?.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline,
              size: 20, // Reduced size
            ),
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.red.shade400
                : Colors.red.shade300,
            onPressed: () {
              provider.removeEntry(entry.id);
            },
            padding: const EdgeInsets.all(8), // Smaller padding for icon button
            constraints: const BoxConstraints(), // Remove constraints
          ),
        ],
      ),
    ),
  );
}

// Add this method after _buildCalorieInfoEnhanced

Widget _buildCalorieInfoCard(
    BuildContext context, String label, int value, Color color, IconData icon) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Theme.of(context).brightness == Brightness.light
          ? color.withOpacity(0.08)
          : color.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: color.withOpacity(0.3),
        width: 1,
      ),
    ),
    child: Row(
      children: [
        Icon(
          icon,
          color: color,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey.shade700
                      : Colors.grey.shade300,
                ),
              ),
              Text(
                '$value',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color:
                      Theme.of(context).extension<CustomColors>()?.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
