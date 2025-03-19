import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';

class EditGoalsScreen extends StatefulWidget {
  const EditGoalsScreen({super.key});

  @override
  State<EditGoalsScreen> createState() => _EditGoalsScreenState();
}

class _EditGoalsScreenState extends State<EditGoalsScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadGoals();
    _loadCurrentValues();
  }

  Future<void> _loadGoals() async {
    try {
      // Load goals from FoodEntryProvider first
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);
      setState(() {
        calorieGoal = foodEntryProvider.caloriesGoal.toInt();
        proteinGoal = foodEntryProvider.proteinGoal.toInt();
        carbGoal = foodEntryProvider.carbsGoal.toInt();
        fatGoal = foodEntryProvider.fatGoal.toInt();
      });

      // Keep existing SharedPreferences logic for backward compatibility
      final prefs = await SharedPreferences.getInstance();
      final String? resultsString = prefs.getString('macro_results');

      if (resultsString != null && resultsString.isNotEmpty) {
        final Map<String, dynamic> results = jsonDecode(resultsString);
        if (mounted) {
          setState(() {
            // Only load step goals, BMR and TDEE from SharedPreferences
            // as these aren't in the FoodEntryProvider
            stepsGoal = results['recommended_steps'] ?? stepsGoal;
            bmr = results['bmr'] ?? bmr;
            tdee = results['tdee'] ?? tdee;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading nutrition goals: $e');
    }
  }

  // Load current daily values from food entry provider or stored progress
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

    // Update with actual values from FoodEntryProvider if available
    try {
      // Update values with latest data from provider
      if (mounted) {
        final foodEntryProvider =
            Provider.of<FoodEntryProvider>(context, listen: false);
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

          final multiplier = quantityInGrams / 100;
          totalCarbs += carbs * multiplier;
          totalFat += fat * multiplier;
          totalProtein += protein * multiplier;
          totalCalories += entry.food.calories * multiplier;
        }

        setState(() {
          caloriesConsumed = totalCalories.round();
          carbsConsumed = totalCarbs.round();
          fatConsumed = totalFat.round();
          proteinConsumed = totalProtein.round();
        });
      }
    } catch (e) {
      debugPrint('Error updating values from FoodEntryProvider: $e');
    }
  }

  Future<void> _saveGoals() async {
    try {
      // Update goals in FoodEntryProvider to ensure proper sync with Supabase
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);
      foodEntryProvider.caloriesGoal = calorieGoal.toDouble();
      foodEntryProvider.proteinGoal = proteinGoal.toDouble();
      foodEntryProvider.carbsGoal = carbGoal.toDouble();
      foodEntryProvider.fatGoal = fatGoal.toDouble();

      // Also update SharedPreferences for backward compatibility
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

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goals saved successfully'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving nutrition goals: $e');
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save goals: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.red,
          ),
        );
      }
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

  Widget _buildGoalCard(Map<String, dynamic> data) {
    // Check if this is a progress card or simple goal card
    final bool showProgress = data['currentValue'] != null;
    final progress = showProgress ? data['currentValue'] / data['value'] : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: data['onEdit'],
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
                    Icon(
                      Icons.edit,
                      size: 20,
                      color: data['color'],
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (showProgress)
                  Column(
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
                else
                  Text(
                    '${data['value']} ${data['unit']}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
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

  List<Map<String, dynamic>> _getGoalsData() {
    return [
      {
        'title': 'Daily Calorie Goal',
        'value': calorieGoal,
        'currentValue': caloriesConsumed,
        'unit': 'kcal',
        'icon': Icons.local_fire_department,
        'color': Colors.orange,
        'onEdit': () => _showEditDialog(
              'Daily Calorie Goal',
              calorieGoal,
              'kcal',
              (value) => setState(() => calorieGoal = value),
            ),
      },
      {
        'title': 'Protein Goal',
        'value': proteinGoal,
        'currentValue': proteinConsumed,
        'unit': 'g',
        'icon': Icons.fitness_center,
        'color': Colors.red,
        'onEdit': () => _showEditDialog(
              'Protein Goal',
              proteinGoal,
              'g',
              (value) => setState(() => proteinGoal = value),
            ),
      },
      {
        'title': 'Carbohydrate Goal',
        'value': carbGoal,
        'currentValue': carbsConsumed,
        'unit': 'g',
        'icon': Icons.grain,
        'color': Colors.blue,
        'onEdit': () => _showEditDialog(
              'Carbohydrate Goal',
              carbGoal,
              'g',
              (value) => setState(() => carbGoal = value),
            ),
      },
      {
        'title': 'Fat Goal',
        'value': fatGoal,
        'currentValue': fatConsumed,
        'unit': 'g',
        'icon': Icons.opacity,
        'color': Colors.yellow,
        'onEdit': () => _showEditDialog(
              'Fat Goal',
              fatGoal,
              'g',
              (value) => setState(() => fatGoal = value),
            ),
      },
      {
        'title': 'Daily Steps Goal',
        'value': stepsGoal,
        'currentValue': stepsCompleted,
        'unit': 'steps',
        'icon': Icons.directions_walk,
        'color': Colors.green,
        'onEdit': () => _showEditDialog(
              'Daily Steps Goal',
              stepsGoal,
              'steps',
              (value) => setState(() => stepsGoal = value),
            ),
      },
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Macro Goals'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView.builder(
        itemCount: _getGoalsData().length,
        itemBuilder: (context, index) {
          return _buildGoalCard(_getGoalsData()[index]);
        },
      ),
    );
  }
}
