import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:uuid/uuid.dart';
import 'package:macrotracker/screens/searchPage.dart';

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
  late ServingSize selectedServing;
  late double quantity;
  String selectedMeal = 'Breakfast';

  @override
  void initState() {
    super.initState();
    selectedServing = widget.food.servingSizes.first;
    quantity = 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final calculatedNutrition =
        _calculateNutrition(selectedServing.nutritionInfo);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          leading: CupertinoNavigationBarBackButton(
            color: Theme.of(context).primaryColor,
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(widget.food.name,
              style: TextStyle(color: Theme.of(context).primaryColor)),
          actions: [
            TextButton(
              onPressed: _addToMeal,
              child: Text('Add',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.secondary)),
            ),
          ],
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meal selector
              DropdownButtonFormField<String>(
                value: selectedMeal,
                items: ['Breakfast', 'Lunch', 'Snacks', 'Dinner']
                    .map((meal) => DropdownMenuItem(
                          value: meal,
                          child: Text(meal,
                              style: TextStyle(
                                  color: Theme.of(context).primaryColor)),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedMeal = value!);
                },
              ),
              const SizedBox(height: 16),

              // Quantity and unit selector
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      keyboardType: TextInputType.number,
                      style: TextStyle(color: Theme.of(context).primaryColor),
                      onChanged: (value) {
                        setState(() {
                          quantity = double.tryParse(value) ?? 1.0;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        labelStyle:
                            TextStyle(color: Theme.of(context).primaryColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<ServingSize>(
                      value: selectedServing,
                      items: widget.food.servingSizes
                          .map((serving) => DropdownMenuItem(
                                value: serving,
                                child: Text(serving.unit,
                                    style: TextStyle(
                                        color: Theme.of(context).primaryColor)),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedServing = value!);
                      },
                    ),
                  ),
                ],
              ),

              // Nutrition info
              const SizedBox(height: 32),
              _buildNutritionInfo('Calories', calculatedNutrition.calories),
              _buildNutritionInfo('Protein', calculatedNutrition.protein),
              _buildNutritionInfo('Carbs', calculatedNutrition.carbohydrates),
              _buildNutritionInfo('Fat', calculatedNutrition.fat),
              _buildNutritionInfo('Fiber', calculatedNutrition.fiber),
            ],
          ),
        ),
      ),
    );
  }

  NutritionInfo _calculateNutrition(NutritionInfo base) {
    return NutritionInfo(
      calories: base.calories * quantity,
      protein: base.protein * quantity,
      carbohydrates: base.carbohydrates * quantity,
      fat: base.fat * quantity,
      fiber: base.fiber * quantity,
    );
  }

  Widget _buildNutritionInfo(String label, double value) {
    String unit = label == 'Calories' ? 'kcal' : 'g';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 16,
            ),
          ),
          Text(
            '${value.toStringAsFixed(1)}$unit',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _addToMeal() {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);

    // Convert AI food item to FoodItem
    final foodItem = widget.food.toFoodItem();

    // Create food entry
    final entry = FoodEntry(
      id: const Uuid().v4(),
      food: foodItem,
      meal: selectedMeal,
      quantity: quantity,
      unit: selectedServing.unit,
      date: dateProvider.selectedDate,
    );

    // Add entry to provider
    foodEntryProvider.addEntry(entry);

    // Pop both pages (results and detail)
    Navigator.pop(context);
    Navigator.pop(context);

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${widget.food.name} to $selectedMeal'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
