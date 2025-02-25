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
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Meal selector
              Text(
                'Meal',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedMeal,
                style: TextStyle(color: Theme.of(context).primaryColor),
                items: ['Breakfast', 'Lunch', 'Snacks', 'Dinner']
                    .map((meal) => DropdownMenuItem(
                          value: meal,
                          child: Text(meal),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedMeal = value!);
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 24),

              // Quantity and serving size selectors
              Row(
                children: [
                  // Quantity input
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quantity',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: quantityController,
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                          ),
                          keyboardType:
                              TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Serving size dropdown
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Serving Size',
                          style: TextStyle(
                            fontSize: 16,
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<int>(
                          value: selectedServingIndex,
                          items: List.generate(
                            widget.food.servingSizes.length,
                            (index) => DropdownMenuItem(
                              value: index,
                              child: Text(widget.food.servingSizes[index],
                                  style: TextStyle(
                                      color: Theme.of(context).primaryColor)),
                            ),
                          ),
                          onChanged: (value) {
                            setState(() => selectedServingIndex = value!);
                          },
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Nutrition info
              const SizedBox(height: 32),
              Text(
                'Nutrition Information',
                style: TextStyle(
                  fontSize: 18,
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildNutritionInfo(
                  'Calories', calculatedNutrition.calories, 'kcal'),
              Divider(),
              _buildNutritionInfo('Protein', calculatedNutrition.protein, 'g'),
              Divider(),
              _buildNutritionInfo(
                  'Carbohydrates', calculatedNutrition.carbohydrates, 'g'),
              Divider(),
              _buildNutritionInfo('Fat', calculatedNutrition.fat, 'g'),
              Divider(),
              _buildNutritionInfo('Fiber', calculatedNutrition.fiber, 'g'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionInfo(String label, double value, String unit) {
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
            '${value.toStringAsFixed(1)} $unit',
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
        content: Text(
          'Added ${widget.food.name} to $selectedMeal',
          style: TextStyle(color: Theme.of(context).primaryColor),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
