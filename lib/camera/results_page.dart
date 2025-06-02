import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:macrotracker/providers/date_provider.dart';
import 'package:macrotracker/providers/food_entry_provider.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/camera/ai_food_detail_page.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

class ResultsPage extends StatelessWidget {
  final List<AIFoodItem> foods;

  const ResultsPage({
    super.key,
    required this.foods,
  });

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return Scaffold(
      appBar: AppBar(
        leading: CupertinoNavigationBarBackButton(
          color: customColors!.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Detected Foods',
          style: TextStyle(
            color: customColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        // actions: [
        //   TextButton.icon(
        //     onPressed: () {
        //       // Navigate to dashboard (replacing the entire stack)
        //       Navigator.of(context).pushNamedAndRemoveUntil(
        //         '/dashboard', // Your dashboard route
        //         (route) => false, // This will clear the entire navigation stack
        //       );
        //     },
        //     icon:
        //         Icon(Icons.dashboard_outlined, color: customColors.textPrimary),
        //     label: Text(
        //       'Dashboard',
        //       style: TextStyle(color: customColors.textPrimary),
        //     ),
        //   ),
        // ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: foods.isEmpty
            ? Center(
                child: Text(
                  'No foods detected',
                  style: TextStyle(color: customColors.textPrimary),
                ),
              )
            : ListView.builder(
                key: ValueKey<int>(foods.length),
                itemCount: foods.length,
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                itemBuilder: (context, index) {
                  final food = foods[index];
                  return _buildFoodCard(context, food, index);
                },
              ),
      ),
    );
  }

  Widget _buildFoodCard(BuildContext context, AIFoodItem food, int index) {
    final customColors = Theme.of(context).extension<CustomColors>();
    // Default to first serving size
    final defaultServing = food.servingSizes[0];
    final calories = food.calories[0];
    final protein = food.protein[0];
    final carbs = food.carbohydrates[0];
    final fat = food.fat[0];

    return Hero(
      tag: 'food-${food.name}-$index',
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 400 + (index * 100)),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () => _openFoodDetail(context, food),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Food info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              food.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: customColors!.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Serving: $defaultServing',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Add button
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              CupertinoIcons.add_circled,
                              color: customColors.textPrimary,
                            ),
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              _quickAddFood(context, food);
                            },
                            tooltip: 'Add to meal',
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            CupertinoIcons.chevron_right,
                          )
                        ],
                      )
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Nutrition chips row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildNutritionChip(
                            context,
                            Icons.local_fire_department_outlined,
                            '${calories.toStringAsFixed(0)} kcal'),
                        const SizedBox(width: 8),
                        _buildNutritionChip(
                            context,
                            Icons.fitness_center_outlined,
                            '${protein.toStringAsFixed(1)}g protein'),
                        const SizedBox(width: 8),
                        _buildNutritionChip(
                            context,
                            Icons.bubble_chart_outlined,
                            '${carbs.toStringAsFixed(1)}g carbs'),
                        const SizedBox(width: 8),
                        _buildNutritionChip(context, Icons.opacity_outlined,
                            '${fat.toStringAsFixed(1)}g fat'),
                      ],
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

  Widget _buildNutritionChip(
      BuildContext context, IconData icon, String label) {
    // Define specific colors for each nutrient type
    Color chipColor;
    if (label.contains('kcal')) {
      chipColor = Colors.green.shade500;
    } else if (label.contains('protein')) {
      chipColor = Colors.red.shade500;
    } else if (label.contains('carbs')) {
      chipColor = Colors.blue.shade500;
    } else if (label.contains('fat')) {
      chipColor = Colors.orange.shade500;
    } else {
      chipColor = Theme.of(context).primaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor
            .withAlpha((0.1 * 255).round()), // Use withAlpha for clarity
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: chipColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _openFoodDetail(BuildContext context, AIFoodItem food) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AIFoodDetailPage(food: food),
      ),
    );
  }

  void _quickAddFood(BuildContext context, AIFoodItem food) {
    final customColors = Theme.of(context).extension<CustomColors>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to Meal',
              style: TextStyle(
                color: customColors!.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              food.name,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            ...[
              'Breakfast',
              'Lunch',
              'Snacks',
              'Dinner',
            ].map((meal) => _buildMealOption(context, food, meal)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMealOption(BuildContext context, AIFoodItem food, String meal) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _addFoodToMeal(context, food, meal);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey
                  .withAlpha((0.2 * 255).round()), // Use withAlpha for clarity
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              meal,
              style: TextStyle(
                color: customColors!.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: customColors.textPrimary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _addFoodToMeal(BuildContext context, AIFoodItem food, String meal) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);

    // The nutrition values from AI are already for the serving size, but the app expects values per 100g
    // So we need to adjust the values to be per 100g
    // Default quantity is 1.0 for quick add
    final double quantity = 1.0;

    // The nutrition values from AI are already for the serving size.
    // We store the selected serving's nutrients directly and the quantity as the multiplier.
    final calories = food.calories[0];
    final protein = food.protein[0];
    final carbs = food.carbohydrates[0];
    final fat = food.fat[0];
    final fiber = food.fiber[0];

    // Create food entry using the first serving size
    final entry = FoodEntry(
      id: const Uuid().v4(),
      food: FoodEntry.createFood(
        fdcId: food.name.hashCode.toString(),
        name: food.name,
        brandName: 'AI Detected',
        calories: calories, // Use adjusted value
        nutrients: {
          'Protein': protein, // Use adjusted value
          'Carbohydrate, by difference': carbs, // Use adjusted value
          'Total lipid (fat)': fat, // Use adjusted value
          'Fiber': fiber, // Use adjusted value
        },
        mealType: meal,
      ),
      meal: meal,
      quantity: quantity,
      unit: food.servingSizes[0],
      date: dateProvider.selectedDate,
    );

    foodEntryProvider.addEntry(entry);
    Navigator.pop(context); // Close bottom sheet

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.onPrimary),
            const SizedBox(width: 8),
            Text(
              'Added to $meal',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFFC107),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
        duration: const Duration(seconds: 2),
      ),
    );

    // Navigate directly to Dashboard instead of staying on results page
    // Navigator.pop(context); // Close results page
  }
}
