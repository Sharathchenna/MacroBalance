import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(0xFFF5F4F0),
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [DateNavigatorbar(), CalorieTracker()],
          ),
        ));
  }
}

class DateNavigatorbar extends StatelessWidget {
  const DateNavigatorbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavigationButton(icon: Icons.chevron_left),
          _buildTodayButton(),
          _buildNavigationButton(icon: Icons.chevron_right),
        ],
      ),
    );
  }
}

Widget _buildNavigationButton({required IconData icon}) {
  return InkWell(
    onTap: () {
      // Add your navigation logic here (e.g., go to previous/next day)
      print('Navigation button tapped!');
    },
    child: Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Color(0xFFF0E9DF), // Background color of the buttons
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: Colors.black,
      ),
    ),
  );
}

Widget _buildTodayButton() {
  return InkWell(
    onTap: () {
      // Add your logic to go back to the current day
      print('Today button tapped!');
    },
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Color(0xFFF0E9DF), // Background color of the button
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            color: Colors.black,
            size: 16,
          ),
          SizedBox(width: 8.0),
          Text('Today', style: TextStyle(color: Colors.black)),
        ],
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
                    SizedBox(
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
                    Text(
                      '$caloriesRemaining cal\nremaining',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$caloriesConsumed cal\nconsumed',
                textAlign: TextAlign.start,
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
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
