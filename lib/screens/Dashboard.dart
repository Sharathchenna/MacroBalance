import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/camera/camera.dart';
import 'package:macrotracker/screens/accountdashboard.dart';
import 'package:macrotracker/screens/askAI.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../Health/Health.dart';
import 'package:app_settings/app_settings.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import '../providers/dateProvider.dart';

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
      backgroundColor: Color(0xFFF5F4F0),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                DateNavigatorbar(),
                CalorieTracker(),
                Expanded(child: MealSection())
              ],
            ),
            // Use dynamic sizing for positioning
            Positioned(
              bottom:
                  screenHeight * 0.02, // 2% of screen height from the bottom
              left: screenWidth * 0.2, // 20% of screen width from the left
              right: screenWidth * 0.2, // 20% of screen width from the right
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal:
                        screenWidth * 0.06), // 6% of screen width as padding
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30.0),
                  boxShadow: [
                    // BoxShadow(
                    //   color: Colors.grey.withAlpha(77),
                    //   spreadRadius: 2,
                    //   blurRadius: 7,
                    //   offset: Offset(0, 3),
                    // ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: IconButton(
                        icon: const Icon(CupertinoIcons.add),
                        onPressed: () {
                          // Handle the "add" action
                          Navigator.push(
                            context,
                            CupertinoSheetRoute(
                                builder: (context) => FoodSearchPage()),
                          );
                        },
                        color: const Color(0xFFFFC107),
                      ),
                    ),
                    Expanded(
                      child: IconButton(
                        icon: const Icon(CupertinoIcons.camera),
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                                builder: (context) => CameraScreen()),
                          );
                        },
                        color: const Color(0xFFFFC107),
                      ),
                    ),
                    Expanded(
                      child: IconButton(
                        icon: ImageIcon(AssetImage("assets/icons/AI Icon.png")),
                        onPressed: () {
                          // Handle the "AI" action
                          Navigator.push(
                            context,
                            CupertinoSheetRoute(builder: (context) => Askai()),
                          );
                        },
                        color: const Color(0xFFFFC107),
                      ),
                    ),
                    Expanded(
                      child: IconButton(
                        icon: const Icon(CupertinoIcons.person),
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoSheetRoute(
                                builder: (context) => Accountdashboard()),
                          );
                        },
                        color: const Color(0xFFFFC107),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
      color: const Color(0xFFF0E9DF),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Icon(
            icon,
            color: Colors.black,
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
            borderRadius: BorderRadius.circular(20.0),
            onTap: () {
              dateProvider.setDate(DateTime.now());
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E9DF),
                borderRadius: BorderRadius.circular(20.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    CupertinoIcons.calendar_today,
                    color: Colors.black,
                    size: 16,
                  ),
                  const SizedBox(width: 8.0),
                  Text(
                    _formatDate(dateProvider.selectedDate),
                    style: const TextStyle(color: Colors.black),
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

  // Keep your goals as is
  final int caloriesGoal = 2000; // Adjust this based on user's goal
  final int carbGoal = 75;
  final int fatGoal = 80;
  final int proteinGoal = 150;
  final int stepsGoal = 9000;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    try {
      final granted = await _healthService.requestPermissions();
      setState(() {
        _hasHealthPermissions = granted;
      });

      if (_hasHealthPermissions) {
        await _fetchHealthData();
      } else {
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

    setState(() {
      steps = fetchedSteps;
      caloriesBurned = fetchedCalories;
    });
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
          // Get macros values from nutrients map
          final carbs =
              entry.food.nutrients["Carbohydrate, by difference"] ?? 0;
          final fat = entry.food.nutrients["Total lipid (fat)"] ?? 0;
          final protein = entry.food.nutrients["Protein"] ?? 0;

          // Calculate based on quantity
          final multiplier = entry.quantity / 100;
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
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade200,
                blurRadius: 15,
                spreadRadius: 5,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Calorie Circle
                  SizedBox(
                    height: 130,
                    width: 130,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 130,
                          height: 130,
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: 10,
                            backgroundColor: const Color(0xFFEDF3FF),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF34C85A),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              caloriesRemaining.toString(),
                              style: GoogleFonts.roboto(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            Text(
                              'cal left',
                              style: GoogleFonts.roboto(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Calories Info
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCalorieInfo(
                          'Goal',
                          caloriesGoal,
                          const Color(0xFF34C85A),
                        ),
                        const SizedBox(height: 12),
                        _buildCalorieInfo(
                          'Food',
                          caloriesFromFood.toInt(),
                          Colors.orange,
                        ),
                        const SizedBox(height: 12),
                        _buildCalorieInfo(
                          'Burned',
                          caloriesBurned.toInt(),
                          Colors.blue,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Macro Bars
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildMacroProgress(
                    'Carbs',
                    totalCarbs.round(),
                    carbGoal,
                    Colors.blue,
                  ),
                  _buildMacroProgress(
                    'Protein',
                    totalProtein.round(),
                    proteinGoal,
                    Colors.red,
                  ),
                  _buildMacroProgress(
                    'Fat',
                    totalFat.round(),
                    fatGoal,
                    Colors.orange,
                  ),
                  _buildMacroProgress(
                    'Steps',
                    steps,
                    stepsGoal,
                    Colors.green,
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

Widget _buildCalorieInfo(String label, int value, Color color) {
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    ],
  );
}

Widget _buildMacroProgress(String label, int value, int goal, Color color) {
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
                color: color.withValues(alpha:0.2),
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
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
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
          return sum + (energy * entry.quantity / 100);
        });

        return Card(
          color: Colors.white,
          margin: const EdgeInsets.only(bottom: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Column(
            children: [
              ListTile(
                title: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          mealType,
                          style: GoogleFonts.roboto(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Icon(
                          expandedState[mealType]!
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                        ),
                      ],
                    ),
                    Text(
                      '${totalCalories.toStringAsFixed(0)} Kcals',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                onTap: () {
                  setState(() {
                    expandedState[mealType] = !expandedState[mealType]!;
                  });
                },
              ),
              if (expandedState[mealType]!) ...[
                ...entries.map((entry) => ListTile(
                      title: Text(entry.food.name),
                      subtitle: Text(
                        '${entry.quantity}${entry.unit} - ${(entry.food.calories * entry.quantity / 100).toStringAsFixed(0)} kcal',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () {
                          foodEntryProvider.removeEntry(entry.id);
                        },
                      ),
                    )),
                Padding(
                  padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          CupertinoSheetRoute(
                              builder: (context) => FoodSearchPage()),
                        );
                      },
                      icon: const Icon(Icons.add, color: Colors.blue),
                      label: Text(
                        'Add Food',
                        style: GoogleFonts.roboto(
                          color: Colors.blue,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
