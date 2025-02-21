import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/camera/camera.dart';
import 'package:macrotracker/screens/accountdashboard.dart';
import 'package:macrotracker/screens/askAI.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:permission_handler/permission_handler.dart';
import '../Health/Health.dart';
import 'package:app_settings/app_settings.dart';

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
    setState(() {
      selectedDate = selectedDate.add(Duration(days: days));
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(days: 1));
    final tomorrow = now.add(Duration(days: 1));

    if (date.year == now.year && date.month == now.month && date.day == now.day) {
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
    return Center(
      child: InkWell(
        borderRadius: BorderRadius.circular(20.0),
        onTap: () {
          // Reset to today's date
          setState(() {
            selectedDate = DateTime.now();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                _formatDate(selectedDate),
                style: const TextStyle(color: Colors.black),
              ),
            ],
          ),
        ),
      ),
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
  final int carbIntake = 20;
  final int fatIntake = 10;
  final int proteinIntake = 80;

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
    if (!_hasHealthPermissions) {
      return Container(
        margin: EdgeInsets.all(16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: [
            // BoxShadow(
            //   color: Colors.grey.withOpacity(0.3),
            //   spreadRadius: 1,
            //   blurRadius: 1,
            //   offset: Offset(0, 3),
            // ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Health Data Access Required',
              style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Please grant access to health data to see your calories and steps.',
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            CupertinoButton(
              color: Theme.of(context).primaryColor,
              child: Text('Grant Access'),
              onPressed: _checkAndRequestPermissions,
            ),
          ],
        ),
      );
    }

    // Calculate remaining calories
    final int caloriesRemaining = caloriesGoal - caloriesBurned.toInt();
    double progress = caloriesBurned / caloriesGoal;
    progress = progress.clamp(0.0, 1.0); // Ensure progress is between 0 and 1

    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          // BoxShadow(
          //   color: Colors.grey.withValues(alpha: 95.0),
          //   spreadRadius: 1,
          //   blurRadius: 1,
          //   offset: Offset(0, 3),
          // ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 120,
                        height: 120,
                        child: CircularProgressIndicator(
                          value: progress,
                          strokeWidth: 8,
                          backgroundColor: Color(0xFFB8EAC5),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF34C85A)),
                        ),
                      ),
                    ),
                    Text(
                      '${caloriesRemaining} cal\nremaining',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 50, 0),
                child: Text(
                  '${caloriesBurned.toInt()} cal\nburned',
                  textAlign: TextAlign.start,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroBar(
                  label: 'S',
                  intake: steps,
                  goal: stepsGoal,
                  color: Colors.red),
              _buildMacroBar(
                  label: 'C',
                  intake: carbIntake,
                  goal: carbGoal,
                  color: Colors.blue),
              _buildMacroBar(
                  label: 'F',
                  intake: fatIntake,
                  goal: fatGoal,
                  color: Colors.orange),
              _buildMacroBar(
                  label: 'P',
                  intake: proteinIntake,
                  goal: proteinGoal,
                  color: Colors.red),
            ],
          )
        ],
      ),
    );
  }
}

Widget _buildMacroBar(
    {required String label,
    required int intake,
    required int goal,
    required Color color}) {
  double progress = intake / goal;
  progress = progress.clamp(0, 1); // Ensure progress is between 0 and 1

  return Column(
    children: [
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      SizedBox(
        width: 50,
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
      Text('$intake/$goal'),
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
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                  '0 Kcals',
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
          if (expandedState[mealType]!)
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
      ),
    );
  }
}
