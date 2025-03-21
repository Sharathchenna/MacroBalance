import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'dart:ui';
import 'package:macrotracker/Health/Health.dart';

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
      // Fetch steps data from HealthService
      final healthService = HealthService();      
      final int todaySteps = await healthService.getSteps();
      
      if (mounted) {
        setState(() {
          stepsCompleted = todaySteps;
        });
      }

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
            // stepsCompleted = progress['steps'] ?? 0;
          });
        }
      } else {
        setState(() {
          caloriesConsumed = 0;
          proteinConsumed = 0;
          carbsConsumed = 0;
          fatConsumed = 0;
          // stepsCompleted = 0;
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
    final customColors = Theme.of(context).extension<CustomColors>();
    // Find the color associated with this title
    Color dialogColor = Colors.deepOrange; // Default color
    for (var data in _getGoalsData()) {
      if (data['title'].contains(title.split(' ')[0])) {
        dialogColor = data['color'];
        break;
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Fix for overflow - Wrap with Flexible for title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: dialogColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getIconForTitle(title),
                        color: dialogColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Flexible(
                      child: Text(
                        'Edit $title',
                        style:  TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: customColors!.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                Container(
                  decoration: BoxDecoration(
                    color: customColors.cardBackground,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      suffixText: unit,
                      suffixStyle: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: dialogColor,
                      ),
                      hintText: 'Enter value',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: dialogColor.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(
                          color: dialogColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Cancel button
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: customColors.textSecondary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Save button
                    ElevatedButton(
                      onPressed: () {
                        final newValue = int.tryParse(controller.text);
                        if (newValue != null && newValue > 0) {
                          onSave(newValue);
                          _saveGoals();
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: dialogColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
  
  // Helper method to get appropriate icon for the dialog
  IconData _getIconForTitle(String title) {
    if (title.contains('Calorie')) return Icons.local_fire_department_rounded;
    if (title.contains('Protein')) return Icons.fitness_center_rounded;
    if (title.contains('Carbohydrate')) return Icons.grain_rounded;
    if (title.contains('Fat')) return Icons.opacity_rounded;
    if (title.contains('Steps')) return Icons.directions_walk_rounded;
    return Icons.edit_rounded;
  }

  Widget _buildGoalCard(Map<String, dynamic> data) {
    final bool showProgress = data['currentValue'] != null;
    final progress = showProgress ? data['currentValue'] / data['value'] : 0.0;
    final customColors = Theme.of(context).extension<CustomColors>();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 160,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: data['onEdit'],
            splashColor: data['color'].withOpacity(0.1),
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Colored icon in a circular container
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: data['color'].withOpacity(0.2),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: data['color'].withOpacity(0.1),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: Icon(
                          data['icon'],
                          color: data['color'],
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        data['title'],
                        style:  TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: customColors!.textPrimary
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: data['color'].withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: data['color'],
                        ),
                      ),
                    ],
                  ),
                  
                  const Spacer(),
                  if (showProgress) 
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${data['currentValue']} / ${data['value']} ${data['unit']}',
                              style:  TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color:  customColors.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: data['color'].withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${(progress * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: data['color'],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        // Enhanced progress bar with icon color
                        Stack(
                          children: [
                            // Background
                            Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            // Foreground with icon color
                            Container(
                              height: 12,
                              width: MediaQuery.of(context).size.width * 0.8 * progress.clamp(0.0, 1.0),
                              decoration: BoxDecoration(
                                color: data['color'],
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: data['color'].withOpacity(0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  else
                    Text(
                      '${data['value']} ${data['unit']}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getGoalsData() {
    return [
      {
        'title': 'Daily Calorie Goal',
        'value': calorieGoal,
        'currentValue': caloriesConsumed,
        'unit': 'kcal',
        'icon': Icons.local_fire_department_rounded,
        'color': Colors.deepOrange,
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
        'icon': Icons.fitness_center_rounded,
        'color': Colors.purple,
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
        'icon': Icons.grain_rounded,
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
        'icon': Icons.opacity_rounded,
        'color': Colors.amber,
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
        'icon': Icons.directions_walk_rounded,
        'color': Colors.teal,
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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: _getGoalsData().length,
            itemBuilder: (context, index) {
              return _buildGoalCard(_getGoalsData()[index]);
            },
          ),
        ),
      ),
    );
  }
}
