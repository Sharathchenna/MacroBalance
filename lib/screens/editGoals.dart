import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/services/storage_service.dart'; // Import StorageService
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'dart:ui';
import 'package:macrotracker/Health/Health.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  // New fields based on recommendations
  bool tdeeManuallySet = false; // Default to false
  String bmrFormula = 'Unknown'; // Default
  double estimatedWeeklyChange = 0.0; // Default
  String estimatedGoalDate = 'N/A'; // Default

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

        // Load additional goals from the enhanced provider
        stepsGoal = foodEntryProvider.stepsGoal;
        bmr = foodEntryProvider.bmr.toInt();
        tdee = foodEntryProvider.tdee.toInt();
      });

      // Still check StorageService (Hive) for backward compatibility
      final String? resultsString = StorageService().get('macro_results');

      if (resultsString != null && resultsString.isNotEmpty) {
        final Map<String, dynamic> results = jsonDecode(resultsString);
        if (mounted) {
          setState(() {
            // If any values are still default, try to get from macro_results
            if (stepsGoal == 9000) {
              stepsGoal = results['recommended_steps'] ?? stepsGoal;
            }
            // Load BMR/TDEE from macro_results if not loaded from provider
            if (bmr == 1500) {
              bmr = results['bmr'] ?? bmr;
            }
            if (tdee == 2000) {
              tdee = results['tdee'] ?? tdee;
            }
            // Load new fields from macro_results
            tdeeManuallySet = results['tdee_manually_set'] ?? tdeeManuallySet;
            bmrFormula = results['bmr_formula'] ?? bmrFormula;
            estimatedWeeklyChange = results['estimated_weekly_change'] ?? estimatedWeeklyChange;
            // Ensure estimated_goal_date is loaded as a string
            if (results['estimated_goal_date'] != null) {
              estimatedGoalDate = results['estimated_goal_date'].toString();
            } else {
              estimatedGoalDate = 'N/A';
            }

          });
        }
      }

      // Also check nutrition_goals for more structured data
      final String? nutritionGoalsString = StorageService().get('nutrition_goals');
      if (nutritionGoalsString != null && nutritionGoalsString.isNotEmpty) {
        try {
          final Map<String, dynamic> nutritionGoals =
              jsonDecode(nutritionGoalsString);
          if (mounted) {
            setState(() {
              // Load data if available
              if (nutritionGoals['steps_goal'] != null) {
                stepsGoal = nutritionGoals['steps_goal'];
              }
              if (nutritionGoals['bmr'] != null) {
                bmr = nutritionGoals['bmr'] is int
                    ? nutritionGoals['bmr']
                    : (nutritionGoals['bmr'] as num).toInt();
              }
              if (nutritionGoals['tdee'] != null) {
                tdee = nutritionGoals['tdee'] is int
                    ? nutritionGoals['tdee']
                    : (nutritionGoals['tdee'] as num).toInt();
              }

              // If calorie/macro goals weren't properly loaded, set them here
              if (nutritionGoals['calories_goal'] != null) {
                calorieGoal = nutritionGoals['calories_goal'] is int
                    ? nutritionGoals['calories_goal']
                    : (nutritionGoals['calories_goal'] as num).toInt();
              }
              if (nutritionGoals['protein_goal'] != null) {
                proteinGoal = nutritionGoals['protein_goal'] is int
                    ? nutritionGoals['protein_goal']
                    : (nutritionGoals['protein_goal'] as num).toInt();
              }
              if (nutritionGoals['carbs_goal'] != null) {
                carbGoal = nutritionGoals['carbs_goal'] is int
                    ? nutritionGoals['carbs_goal']
                    : (nutritionGoals['carbs_goal'] as num).toInt();
              }
              if (nutritionGoals['fat_goal'] != null) {
                fatGoal = nutritionGoals['fat_goal'] is int
                    ? nutritionGoals['fat_goal']
                    : (nutritionGoals['fat_goal'] as num).toInt();
              }

              // Also try loading new fields from nutrition_goals if not found in macro_results
              if (!tdeeManuallySet) { // Only update if not already set true by macro_results
                tdeeManuallySet = nutritionGoals['tdee_manually_set'] ?? tdeeManuallySet;
              }
              if (bmrFormula == 'Unknown') {
                bmrFormula = nutritionGoals['bmr_formula'] ?? bmrFormula;
              }
              // Note: Weekly change and goal date are less likely here, primarily from calculator results
              if (estimatedWeeklyChange == 0.0) {
                 estimatedWeeklyChange = nutritionGoals['estimated_weekly_change'] ?? estimatedWeeklyChange;
              }
            });
          }
        } catch (e) {
          debugPrint('Error parsing nutrition_goals JSON: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading nutrition goals: $e');
    }
  }

  // Load current daily values from food entry provider or stored progress
  Future<void> _loadCurrentValues() async { // Keep async for HealthService
    try {
      // Fetch steps data from HealthService
      final healthService = HealthService();
      final int todaySteps = await healthService.getSteps();

      if (mounted) {
        setState(() {
          stepsCompleted = todaySteps;
        });
      }

      // Load daily progress from StorageService (synchronous)
      final String? dailyProgress = StorageService().get('daily_progress');

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

  // Keep async because FoodEntryProvider setters might be async (due to Supabase sync)
  Future<void> _saveGoals() async {
    try {
      // Update goals in FoodEntryProvider to ensure proper sync with Supabase
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);

      // Call the new method to update all goals at once
      await foodEntryProvider.updateNutritionGoals(
        calories: calorieGoal.toDouble(),
        protein: proteinGoal.toDouble(),
        carbs: carbGoal.toDouble(),
        fat: fatGoal.toDouble(),
        steps: stepsGoal,
        bmr: bmr.toDouble(),
        tdee: tdee.toDouble(),
      );

      // The updateNutritionGoals method handles saving, notifying, and syncing.
      // We still save to 'macro_results' locally for backward compatibility if needed.
      final Map<String, dynamic> results = {
        'calorie_target': calorieGoal,
        'protein': proteinGoal,
        'carbs': carbGoal,
        'fat': fatGoal,
        'recommended_steps': stepsGoal,
        'bmr': bmr,
        'tdee': tdee,
      };
      StorageService().put('macro_results', jsonEncode(results));

      // The provider will handle syncing with Supabase automatically

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Goals saved successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
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
                        style: TextStyle(
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
                      onPressed: () async { // Make onPressed async
                        final newValue = int.tryParse(controller.text);
                        if (newValue != null && newValue > 0) {
                          onSave(newValue); // Update local state for the dialog (used by the card itself)
                          await _saveGoals(); // Await the async save operation

                          // --- Diagnostic Print ---
                          // Check if the provider instance here reflects the change immediately
                          if (context.mounted) {
                             final provider = Provider.of<FoodEntryProvider>(context, listen: false);
                             // Find which goal was being edited based on the title
                             String goalKey = "unknown";
                             if (title.contains("Calorie")) goalKey = "calories";
                             else if (title.contains("Protein")) goalKey = "protein";
                             else if (title.contains("Carb")) goalKey = "carbs";
                             else if (title.contains("Fat")) goalKey = "fat";
                             else if (title.contains("Steps")) goalKey = "steps";

                             dynamic providerValue;
                             switch(goalKey) {
                               case "calories": providerValue = provider.caloriesGoal; break;
                               case "protein": providerValue = provider.proteinGoal; break;
                               case "carbs": providerValue = provider.carbsGoal; break;
                               case "fat": providerValue = provider.fatGoal; break;
                               case "steps": providerValue = provider.stepsGoal; break;
                             }
                             debugPrint("--- DIALOG SAVE ($title) ---");
                             debugPrint("New value entered: $newValue");
                             debugPrint("Provider $goalKey goal after save: $providerValue");
                             debugPrint("--- END DIALOG SAVE ---");
                          }
                          // --- End Diagnostic Print ---

                          if (context.mounted) { // Check if context is still valid
                             Navigator.pop(context, true); // Pop with result TRUE indicating save
                          }
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
    // Add null/zero checks for progress calculation
    final bool isEditable = data['onEdit'] != null; // Check if editable
    double progress = 0.0;
    if (showProgress && data['value'] != null && data['value'] > 0) {
      progress = (data['currentValue'] / data['value']).clamp(0.0, 1.0);
    }

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
            splashColor: isEditable ? data['color'].withOpacity(0.1) : Colors.transparent, // No splash if not editable
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
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: customColors!.textPrimary),
                      ),
                      const Spacer(),
                      // Only show edit icon if editable
                      if (isEditable)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: data['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.edit_rounded, size: 16, color: data['color']),
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
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: customColors.textPrimary,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: data['color'].withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                // Add null check for percentage calculation
                                progress.isFinite
                                    ? '${(progress * 100).toInt()}%'
                                    : '0%',
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
                              width: MediaQuery.of(context).size.width *
                                  0.8 *
                                  progress.clamp(0.0, 1.0),
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
      // Add BMR (non-editable for now)
      {
        'title': 'Basal Metabolic Rate (BMR)',
        'value': bmr,
        'currentValue': null, // No progress for BMR
        'unit': 'kcal',
        'icon': Icons.bedtime_rounded,
        'color': Colors.lightBlue,
        'onEdit': null, // Not editable directly
      },
      // Add TDEE (non-editable for now)
      {
        'title': 'Total Daily Energy Expenditure (TDEE)',
        'value': tdee,
        'currentValue': null, // No progress for TDEE
        'unit': 'kcal',
        'icon': Icons.directions_run_rounded,
        'color': Colors.green,
        'onEdit': null, // Not editable directly
      },

    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutrition Goals & Details'), // Updated Title
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Column( // Wrap ListView in a Column
          children: [
            // Widget for Macro Percentages
            _buildMacroPercentageCard(),
            const SizedBox(height: 10), // Spacing

            // Existing ListView for Goal Cards
            Expanded( // Make ListView take remaining space
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16), // Add bottom padding
                itemCount: _getGoalsData().length,
                itemBuilder: (context, index) {
                  final goalData = _getGoalsData()[index];
                  // Conditionally add extra info below BMR/TDEE cards
                  if (goalData['title'].contains('BMR')) {
                    return Column(
                      children: [
                        _buildGoalCard(goalData),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: Text('Formula Used: $bmrFormula', style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                        ),
                      ],
                    );
                  } else if (goalData['title'].contains('TDEE')) {
                    return Column(
                      children: [
                        _buildGoalCard(goalData),
                        if (tdeeManuallySet)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                                SizedBox(width: 4),
                                Text('Manually Set', style: TextStyle(color: Colors.orange, fontStyle: FontStyle.italic)),
                              ],
                            ),
                          ),
                      ],
                    );
                  }
                  return _buildGoalCard(goalData);
                },
              ),
            ),

            // Placeholder Section for Weight Change Info & Edit Links
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text('Estimated Weekly Change: ${estimatedWeeklyChange.toStringAsFixed(1)} kg/lbs'), // Placeholder
                  Text('Estimated Goal Date: $estimatedGoalDate'), // Placeholder
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () {}, child: const Text('Adjust Activity Level (Placeholder)')),
                  ElevatedButton(onPressed: () {}, child: const Text('Adjust Weight Goal (Placeholder)')),
                  // Potentially add a toggle/button for TDEE override here later
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this new method somewhere within the _EditGoalsScreenState class

  Widget _buildMacroPercentageCard() {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;

    // Calculate total grams for percentage calculation
    final totalGrams = proteinGoal + carbGoal + fatGoal;
    double proteinPercent = totalGrams > 0 ? (proteinGoal / totalGrams * 100) : 0;
    double carbPercent = totalGrams > 0 ? (carbGoal / totalGrams * 100) : 0;
    double fatPercent = totalGrams > 0 ? (fatGoal / totalGrams * 100) : 0;

    // Ensure percentages sum roughly to 100, handle potential rounding issues if needed
    // For simplicity, we'll just display the calculated values for now.

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Target Macro Ratio (by Grams)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPercentItem('Protein', proteinPercent, Colors.purple),
                _buildPercentItem('Carbs', carbPercent, Colors.blue),
                _buildPercentItem('Fat', fatPercent, Colors.amber),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPercentItem(String label, double percent, Color color) {
    return Column(
      children: [
        Text(
          '${percent.toStringAsFixed(0)}%',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
