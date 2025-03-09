import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/screens/Dashboard.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ResultsScreen extends StatefulWidget {
  final Map<String, dynamic> results;

  const ResultsScreen({Key? key, required this.results}) : super(key: key);

  @override
  _ResultsScreenState createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOut,
      ),
    );
    _animationController.forward();

    // Save results to shared preferences
    _saveResultsToPrefs();
  }

  Future<void> _saveResultsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('macro_results', jsonEncode(widget.results));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final bmr = widget.results['bmr'];
    final tdee = widget.results['tdee'];
    final calorieTarget = widget.results['calorie_target'];
    final protein = widget.results['protein'];
    final fat = widget.results['fat'];
    final carbs = widget.results['carbs'];
    final recommendedSteps = widget.results['recommended_steps'];

    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeInAnimation,
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 120,
                pinned: true,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(
                    'Your Personalized Plan',
                    style: TextStyle(
                      color: customColors?.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  centerTitle: true,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Based on your information, we've calculated your optimal nutrition plan. Here's what we recommend:",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: customColors?.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 32),

                      // Display daily calorie target with circular progress indicator
                      Center(
                        child: Container(
                          height: 180,
                          width: 180,
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
                              SizedBox(
                                width: 160,
                                height: 160,
                                child: CircularProgressIndicator(
                                  value: 1.0,
                                  strokeWidth: 12,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$calorieTarget',
                                    style: GoogleFonts.poppins(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: customColors?.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'calories/day',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: customColors?.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Macro distribution cards
                      Text(
                        'Daily Macronutrient Targets',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: customColors?.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildMacroCard(
                              context,
                              'Protein',
                              '$protein g',
                              const Color(0xFFEF5350),
                              Icons.fitness_center,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildMacroCard(
                              context,
                              'Carbs',
                              '$carbs g',
                              const Color(0xFF42A5F5),
                              Icons.grain,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildMacroCard(
                              context,
                              'Fat',
                              '$fat g',
                              const Color(0xFFFFA726),
                              Icons.opacity,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Additional information
                      Text(
                        'Additional Information',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: customColors?.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        context,
                        'Basal Metabolic Rate (BMR)',
                        '$bmr calories/day',
                        'This is how many calories your body needs at complete rest.',
                        Icons.hotel,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        context,
                        'Total Daily Energy Expenditure (TDEE)',
                        '$tdee calories/day',
                        'This is your BMR plus calories burned through daily activity.',
                        Icons.directions_run,
                      ),
                      const SizedBox(height: 16),
                      _buildInfoCard(
                        context,
                        'Recommended Steps',
                        '$recommendedSteps steps/day',
                        'Aim for this step count to support your fitness goal.',
                        Icons.directions_walk,
                      ),

                      const SizedBox(height: 40),

                      // Continue to dashboard button
                      Center(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const Dashboard(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Start Tracking',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroCard(
    BuildContext context,
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 28,
            color: color,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: customColors?.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: customColors?.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context,
    String title,
    String value,
    String description,
    IconData icon,
  ) {
    final customColors = Theme.of(context).extension<CustomColors>();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customColors?.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: customColors?.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: customColors?.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: customColors?.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
