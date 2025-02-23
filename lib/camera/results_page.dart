import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/widgets/ai_food_card.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/camera/ai_food_detail_page.dart';
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
    return Scaffold(
      appBar: AppBar(
        leading: CupertinoNavigationBarBackButton(
          color: Theme.of(context).primaryColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Detected Foods',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView.builder(
        itemCount: foods.length,
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemBuilder: (context, index) {
          final food = foods[index];
          return AIFoodCard(
            food: food,
            onTap: () => _openFoodDetail(context, food),
            onAdd: () => _quickAddFood(context, food),
          );
        },
      ),
    );
  }

  void _openFoodDetail(BuildContext context, AIFoodItem food) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AIFoodDetailPage(food: food),
      ),
    );
  }

  void _quickAddFood(BuildContext context, AIFoodItem food) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add to Meal',
          style: TextStyle(color: Theme.of(context).primaryColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            'Breakfast',
            'Lunch',
            'Snacks',
            'Dinner',
          ]
              .map((meal) => ListTile(
                    title: Text(
                      meal,
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                    onTap: () {
                      final dateProvider =
                          Provider.of<DateProvider>(context, listen: false);
                      final foodEntryProvider = Provider.of<FoodEntryProvider>(
                          context,
                          listen: false);

                      // Convert and add with default serving
                      final foodItem = food.toFoodItem();
                      final entry = FoodEntry(
                        id: const Uuid().v4(),
                        food: foodItem,
                        meal: meal,
                        quantity: 1.0,
                        unit: food.servingSizes.first.unit,
                        date: dateProvider.selectedDate,
                      );

                      foodEntryProvider.addEntry(entry);
                      Navigator.pop(context); // Close dialog
                      Navigator.pop(context); // Close results page

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added ${food.name} to $meal'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }
}
