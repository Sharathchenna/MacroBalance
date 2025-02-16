import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/camera/camera.dart';
import 'package:macrotracker/screens/searchPage.dart';

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
                    BoxShadow(
                      color: Colors.grey.withAlpha(77),
                      spreadRadius: 2,
                      blurRadius: 7,
                      offset: Offset(0, 3),
                    ),
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
                            MaterialPageRoute(
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
                            MaterialPageRoute(
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
                          // Handle the "bar chart" action
                        },
                        color: const Color(0xFFFFC107),
                      ),
                    ),
                    Expanded(
                      child: IconButton(
                        icon: const Icon(CupertinoIcons.person),
                        onPressed: () {
                          // Handle the "person" action
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

class DateNavigatorbar extends StatelessWidget {
  const DateNavigatorbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Row(
        // Use spaceEvenly or spaceBetween if you prefer different spacing.
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Expanded(child: _buildNavigationButton(icon: Icons.chevron_left)),
          Expanded(child: _buildTodayButton()),
          Expanded(child: _buildNavigationButton(icon: Icons.chevron_right)),
        ],
      ),
    );
  }
}

Widget _buildNavigationButton({required IconData icon}) {
  return Material(
    color: Color(0xFFF0E9DF), // Background color of the button
    shape: CircleBorder(),
    child: InkWell(
      customBorder: CircleBorder(),
      onTap: () {
        // Add your navigation logic here (e.g., go to previous/next day)
        print('Navigation button tapped!');
      },
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Icon(
          icon,
          color: Colors.black,
        ),
      ),
    ),
  );
}

Widget _buildTodayButton() {
  return Center(
    child: InkWell(
      borderRadius: BorderRadius.circular(20.0),
      // TODO: Today Animation Not Working;
      onTap: () {
        print('Today button tapped!');
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Color(0xFFF0E9DF),
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.calendar_today,
              color: Colors.black,
              size: 16,
            ),
            SizedBox(width: 8.0),
            Text('Today', style: TextStyle(color: Colors.black)),
          ],
        ),
      ),
    ),
  );
}

class CalorieTracker extends StatelessWidget {
  const CalorieTracker({super.key});

  // mock data

  final int caloriesRemaining = 500;
  final int caloriesConsumed = 1500;
  final int carbIntake = 50;
  final int carbGoal = 75;
  final int fatIntake = 60;
  final int fatGoal = 80;
  final int proteinIntake = 100;
  final int proteinGoal = 150;
  final int steps = 4000;
  final int stepsGoal = 9000;

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    double totalCalories = (caloriesConsumed + caloriesRemaining).toDouble();
    double progress = 0.75;
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 95.0),
            spreadRadius: 1,
            blurRadius: 1,
            offset: Offset(0, 3),
          ),
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
                      '$caloriesRemaining cal\nremaining',
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
                  '$caloriesConsumed cal\nconsumed',
                  textAlign: TextAlign.start,
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
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
