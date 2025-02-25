import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:uuid/uuid.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:macrotracker/theme/app_theme.dart';

class MacroCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const MacroCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class AIFoodDetailPage extends StatefulWidget {
  final AIFoodItem food;

  const AIFoodDetailPage({
    super.key,
    required this.food,
  });

  @override
  State<AIFoodDetailPage> createState() => _AIFoodDetailPageState();
}

class _AIFoodDetailPageState extends State<AIFoodDetailPage> {
  int selectedServingIndex = 0;
  double quantity = 1.0;
  String selectedMeal = 'Breakfast';
  final TextEditingController quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    quantityController.text = '1.0';
    quantityController.addListener(_updateQuantity);
  }

  @override
  void dispose() {
    quantityController.dispose();
    super.dispose();
  }

  void _updateQuantity() {
    setState(() {
      quantity = double.tryParse(quantityController.text) ?? 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final calculatedNutrition =
        widget.food.getNutritionForIndex(selectedServingIndex, quantity);
    final customColors = Theme.of(context).extension<CustomColors>();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          leading: CupertinoNavigationBarBackButton(
            color: Theme.of(context).primaryColor,
            onPressed: () => Navigator.of(context).pop(),
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(
            'Food Details',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
              onPressed: _addToMeal,
              child: const Text(
                '+ Add',
                style: TextStyle(color: Colors.blue, fontSize: 18),
              ),
            ),
          ],
          elevation: 0,
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Food Title Section
                Text(
                  widget.food.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                      ),
                ),
                const SizedBox(height: 4),
                // Text(
                //   'AI Detected Food',
                //   style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                //         color: Theme.of(context).primaryColor.withValues(alpha:0.7),
                //       ),
                // ),
                const SizedBox(height: 24),

                // Macros Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: customColors?.macroCardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          '${calculatedNutrition.calories.toStringAsFixed(0)} kcal',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: MacroCard(
                              label: 'Carbs',
                              value:
                                  '${calculatedNutrition.carbohydrates.toStringAsFixed(1)}g',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: MacroCard(
                              label: 'Protein',
                              value:
                                  '${calculatedNutrition.protein.toStringAsFixed(1)}g',
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: MacroCard(
                              label: 'Fat',
                              value:
                                  '${calculatedNutrition.fat.toStringAsFixed(1)}g',
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Input Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: customColors?.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      // Meal Row
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              "Meal",
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              dropdownColor:
                                  Theme.of(context).scaffoldBackgroundColor,
                              value: selectedMeal,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  selectedMeal = val!;
                                });
                              },
                              items: ['Breakfast', 'Lunch', 'Snacks', 'Dinner']
                                  .map((meal) => DropdownMenuItem(
                                        value: meal,
                                        child: Text(meal),
                                      ))
                                  .toList(),
                            ),
                          ),
                        ],
                      ),
                      Divider(
                        color: customColors?.dateNavigatorBackground,
                      ),

                      // Quantity Row
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              "Quantity",
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: quantityController,
                              keyboardType: TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              onChanged: (value) {
                                setState(() {});
                              },
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                suffixText: widget
                                    .food.servingSizes[selectedServingIndex],
                                suffixStyle: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(
                        color: customColors?.dateNavigatorBackground,
                      ),

                      // Serving Size Row
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              "Serving Size",
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              dropdownColor:
                                  Theme.of(context).scaffoldBackgroundColor,
                              value: selectedServingIndex,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
                              onChanged: (val) {
                                setState(() {
                                  selectedServingIndex = val!;
                                });
                              },
                              items: List.generate(
                                widget.food.servingSizes.length,
                                (index) => DropdownMenuItem(
                                  value: index,
                                  child: Text(widget.food.servingSizes[index]),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Nutrition Facts Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: customColors?.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nutrition Facts',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                      ),
                      Text(
                        'Per ${widget.food.servingSizes[selectedServingIndex]}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _buildNutrientRow('Calories',
                          '${calculatedNutrition.calories.toStringAsFixed(0)} kcal'),
                      _buildDivider(context),
                      _buildNutrientRow('Protein',
                          '${calculatedNutrition.protein.toStringAsFixed(1)}g'),
                      _buildDivider(context),
                      _buildNutrientRow('Carbohydrates',
                          '${calculatedNutrition.carbohydrates.toStringAsFixed(1)}g'),
                      _buildDivider(context),
                      _buildNutrientRow('Fat',
                          '${calculatedNutrition.fat.toStringAsFixed(1)}g'),
                      _buildDivider(context),
                      _buildNutrientRow('Fiber',
                          '${calculatedNutrition.fiber.toStringAsFixed(1)}g'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return Divider(
      color: customColors?.dateNavigatorBackground,
      height: 1,
    );
  }

  void _addToMeal() {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);

    // Create food entry
    final entry = FoodEntry(
      id: const Uuid().v4(),
      food: FoodItem(
        fdcId: widget.food.name.hashCode.toString(),
        name: widget.food.name,
        brandName: 'AI Detected',
        calories: widget.food.calories[selectedServingIndex],
        nutrients: {
          'Protein': widget.food.protein[selectedServingIndex],
          'Carbohydrate, by difference':
              widget.food.carbohydrates[selectedServingIndex],
          'Total lipid (fat)': widget.food.fat[selectedServingIndex],
          'Fiber': widget.food.fiber[selectedServingIndex],
        },
        mealType: selectedMeal,
      ),
      meal: selectedMeal,
      quantity: quantity,
      unit: widget.food.servingSizes[selectedServingIndex],
      date: dateProvider.selectedDate,
    );

    // Add entry to provider
    foodEntryProvider.addEntry(entry);

    // Pop only this page to return to results page
    Navigator.pop(context);

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.onPrimary),
            SizedBox(width: 8),
            Text(
              'Added ${widget.food.name} to $selectedMeal',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: EdgeInsets.all(8),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
