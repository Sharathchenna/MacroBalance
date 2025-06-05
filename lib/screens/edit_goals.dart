import 'package:flutter/material.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/services/storage_service.dart'; // Import StorageService
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/food_entry_provider.dart';
import 'package:macrotracker/models/nutrition_goals.dart'; // Import NutritionGoals
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
    // Setup listener for provider changes
    Future.microtask(() {
      if (mounted) {
        Provider.of<FoodEntryProvider>(context, listen: false)
            .addListener(_refreshGoalsFromProvider);
      }
    });
  }

  @override
  void dispose() {
    // Remove listener
    try {
      Provider.of<FoodEntryProvider>(context, listen: false)
          .removeListener(_refreshGoalsFromProvider);
    } catch (e) {
      // Handle any dispose errors quietly
    }
    super.dispose();
  }

  void _refreshGoalsFromProvider() {
    if (!mounted) return;

    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);

    // Only update if the values are different to avoid unnecessary setState calls
    final newCalorieGoal = foodEntryProvider.caloriesGoal.round();
    final newProteinGoal = foodEntryProvider.proteinGoal.round();
    final newCarbGoal = foodEntryProvider.carbsGoal.round();
    final newFatGoal = foodEntryProvider.fatGoal.round();
    final newStepsGoal = foodEntryProvider.stepsGoal;
    final newBmr = foodEntryProvider.bmr.round();

    if (calorieGoal != newCalorieGoal ||
        proteinGoal != newProteinGoal ||
        carbGoal != newCarbGoal ||
        fatGoal != newFatGoal ||
        stepsGoal != newStepsGoal ||
        bmr != newBmr) {
      setState(() {
        calorieGoal = newCalorieGoal;
        proteinGoal = newProteinGoal;
        carbGoal = newCarbGoal;
        fatGoal = newFatGoal;
        stepsGoal = newStepsGoal;
        bmr = newBmr;
      });

      debugPrint(
          'Goals refreshed from provider: calories=$calorieGoal, protein=$proteinGoal');
    }
  }

  Future<void> _loadGoals() async {
    try {
      // First, load from the provider
      if (mounted) {
        final foodEntryProvider =
            Provider.of<FoodEntryProvider>(context, listen: false);

        // Wait for provider to initialize if needed
        await foodEntryProvider.initialize();

        setState(() {
          calorieGoal = foodEntryProvider.caloriesGoal.round();
          proteinGoal = foodEntryProvider.proteinGoal.round();
          carbGoal = foodEntryProvider.carbsGoal.round();
          fatGoal = foodEntryProvider.fatGoal.round();
          stepsGoal = foodEntryProvider.stepsGoal;
          bmr = foodEntryProvider.bmr.round();
        });

        debugPrint(
            'Loaded goals from provider: calories=$calorieGoal, protein=$proteinGoal, carbs=$carbGoal, fat=$fatGoal');
        return; // Exit early since we got values from provider
      }
    } catch (e) {
      debugPrint('Error loading goals from provider: $e');
      // Continue to try loading from storage
    }

    // Load from storage as fallback
    final String? resultsString = StorageService().get('macro_results');
    if (resultsString != null && resultsString.isNotEmpty) {
      final Map<String, dynamic> results = jsonDecode(resultsString);
      if (mounted) {
        setState(() {
          stepsGoal = results['recommended_steps'] ?? stepsGoal;
        });
      }
    }

    // Also check nutrition_goals for more structured data
    final String? nutritionGoalsString =
        StorageService().get('nutrition_goals');
    if (nutritionGoalsString != null && nutritionGoalsString.isNotEmpty) {
      final Map<String, dynamic> goals = jsonDecode(nutritionGoalsString);
      if (mounted) {
        setState(() {
          calorieGoal =
              goals['macro_targets']?['calories']?.round() ?? calorieGoal;
          proteinGoal =
              goals['macro_targets']?['protein']?.round() ?? proteinGoal;
          carbGoal = goals['macro_targets']?['carbs']?.round() ?? carbGoal;
          fatGoal = goals['macro_targets']?['fat']?.round() ?? fatGoal;
          stepsGoal = goals['steps_goal'] ?? stepsGoal;
          bmr = goals['bmr']?.round() ?? bmr;
        });
      }
    }
  }

  // Load current daily values from food entry provider or stored progress
  Future<void> _loadCurrentValues() async {
    // Keep async for HealthService
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
              entry.food.nutrients['Carbohydrate, by difference'] ?? 0;
          final fat = entry.food.nutrients['Total lipid (fat)'] ?? 0;
          final protein = entry.food.nutrients['Protein'] ?? 0;

          // Convert quantity to grams
          double quantityInGrams = entry.quantity;
          switch (entry.unit) {
            case 'oz':
              quantityInGrams *= 28.35;
              break;
            case 'kg':
              quantityInGrams *= 1000;
              break;
            case 'lbs':
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
  Future<void> _saveGoals(Map<String, int> newMacros) async {
    try {
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);

      // First update local state
      setState(() {
        calorieGoal = newMacros['calories']!;
        proteinGoal = newMacros['protein']!;
        carbGoal = newMacros['carbs']!;
        fatGoal = newMacros['fat']!;
      });

      // Create nutrition goals object
      final nutritionGoals = foodEntryProvider.nutritionGoals.copyWith(
        calories: newMacros['calories']!.toDouble(),
        protein: newMacros['protein']!.toDouble(),
        carbs: newMacros['carbs']!.toDouble(),
        fat: newMacros['fat']!.toDouble(),
        steps: stepsGoal,
        bmr: bmr.toDouble(),
      );

      // Update provider - this will handle both local storage and Supabase sync
      await foodEntryProvider.updateNutritionGoals(nutritionGoals);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goals updated successfully')),
        );
      }
    } catch (e) {
      debugPrint('Error saving goals: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating goals')),
        );
      }
    }
  }

  void _showEditDialog(
      String title, int currentValue, String unit, Function(int) onSave) {
    final TextEditingController controller =
        TextEditingController(text: currentValue.toString());
    final customColors = Theme.of(context).extension<CustomColors>();
    Color dialogColor = Colors.deepOrange;
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
                color: Colors.black.withAlpha((0.2 * 255).round()),
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: dialogColor.withAlpha((0.2 * 255).round()),
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
                        color: Colors.black.withAlpha((0.05 * 255).round()),
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
                          color: dialogColor.withAlpha((0.3 * 255).round()),
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
                    ElevatedButton(
                      onPressed: () async {
                        final newValue = int.tryParse(controller.text);
                        if (newValue != null && newValue > 0) {
                          // Determine which macro is being changed
                          String macroType = '';
                          if (title.contains('Protein')) {
                            macroType = 'protein';
                          } else if (title.contains('Carbohydrate'))
                            macroType = 'carbs';
                          else if (title.contains('Fat'))
                            macroType = 'fat';
                          else if (title.contains('Calorie'))
                            macroType = 'calories';
                          else if (title.contains('Steps')) {
                            setState(() {
                              stepsGoal = newValue;
                            });
                            await _saveGoals({
                              'calories': calorieGoal,
                              'protein': proteinGoal,
                              'carbs': carbGoal,
                              'fat': fatGoal,
                            });
                            if (context.mounted) {
                              Navigator.pop(context, true);
                            }
                            return;
                          }

                          // Calculate new macro values
                          final newMacros = await calculateInterconnectedMacros(
                              macroType, newValue);

                          // Save all updated values
                          await _saveGoals(newMacros);

                          if (context.mounted) {
                            Navigator.pop(context, true);
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please enter a valid positive number')),
                          );
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
            color: Colors.black.withAlpha((0.08 * 255).round()),
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
            splashColor: isEditable
                ? data['color'].withAlpha((0.1 * 255).round())
                : Colors.transparent, // No splash if not editable
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
                          color: data['color'].withAlpha((0.2 * 255).round()),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color:
                                  data['color'].withAlpha((0.1 * 255).round()),
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
                            color: data['color'].withAlpha((0.1 * 255).round()),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.edit_rounded,
                              size: 16, color: data['color']),
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
                                color: data['color']
                                    .withAlpha((0.2 * 255).round()),
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
                                color:
                                    Colors.grey.withAlpha((0.15 * 255).round()),
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
                                    color: data['color']
                                        .withAlpha((0.3 * 255).round()),
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
        'color': Colors.green,
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
      // {
      //   'title': 'Basal Metabolic Rate (BMR)',
      //   'value': bmr,
      //   'currentValue': null, // No progress for BMR
      //   'unit': 'kcal',
      //   'icon': Icons.bedtime_rounded,
      //   'color': Colors.lightBlue,
      //   'onEdit': null, // Not editable directly
      // },
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
        child: Column(
          // Wrap ListView in a Column
          children: [
            // Widget for Macro Percentages
            // _buildMacroPercentageCard(),
            // const SizedBox(height: 10), // Spacing

            // Existing ListView for Goal Cards
            Expanded(
              // Make ListView take remaining space
              child: ListView.builder(
                padding:
                    const EdgeInsets.only(bottom: 16), // Add bottom padding
                itemCount: _getGoalsData().length,
                itemBuilder: (context, index) {
                  final goalData = _getGoalsData()[index];
                  return _buildGoalCard(goalData);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Constants for macro calculations
  static const double PROTEIN_CAL = 4.0;
  static const double CARBS_CAL = 4.0;
  static const double FAT_CAL = 9.0;
  static const double PROTEIN_RATIO = 0.30;
  static const double CARBS_RATIO = 0.40;
  static const double FAT_RATIO = 0.30;

  Future<Map<String, int>> calculateInterconnectedMacros(
      String changedMacro, int newValue) async {
    Map<String, int> newMacros = {
      'calories': calorieGoal,
      'protein': proteinGoal,
      'carbs': carbGoal,
      'fat': fatGoal
    };

    switch (changedMacro) {
      case 'protein':
        newMacros['protein'] = newValue;
        newMacros['calories'] =
            (newValue * PROTEIN_CAL + carbGoal * CARBS_CAL + fatGoal * FAT_CAL)
                .round();
        break;
      case 'carbs':
        newMacros['carbs'] = newValue;
        newMacros['calories'] = (proteinGoal * PROTEIN_CAL +
                newValue * CARBS_CAL +
                fatGoal * FAT_CAL)
            .round();
        break;
      case 'fat':
        newMacros['fat'] = newValue;
        newMacros['calories'] = (proteinGoal * PROTEIN_CAL +
                carbGoal * CARBS_CAL +
                newValue * FAT_CAL)
            .round();
        break;
      case 'calories':
        newMacros['calories'] = newValue;
        // Distribute calories according to macro ratios
        newMacros['protein'] =
            ((newValue * PROTEIN_RATIO) / PROTEIN_CAL).round();
        newMacros['carbs'] = ((newValue * CARBS_RATIO) / CARBS_CAL).round();
        newMacros['fat'] = ((newValue * FAT_RATIO) / FAT_CAL).round();
        break;
    }
    return newMacros;
  }
}
