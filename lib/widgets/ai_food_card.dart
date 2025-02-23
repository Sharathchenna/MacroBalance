import 'package:flutter/material.dart';
import 'package:macrotracker/models/ai_food_item.dart';

class AIFoodCard extends StatelessWidget {
  final AIFoodItem food;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  const AIFoodCard({
    super.key,
    required this.food,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    // Get the default 100g serving for preview
    final defaultServing = food.servingSizes.firstWhere(
      (serving) => serving.unit == '100g',
      orElse: () => food.servingSizes.first,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      food.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: Theme.of(context).primaryColor,
                    onPressed: onAdd,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Nutritional preview
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildNutrientPreview(
                      'Cal', defaultServing.nutritionInfo.calories.round()),
                  _buildNutrientPreview(
                      'P', defaultServing.nutritionInfo.protein.round()),
                  _buildNutrientPreview(
                      'C', defaultServing.nutritionInfo.carbohydrates.round()),
                  _buildNutrientPreview(
                      'F', defaultServing.nutritionInfo.fat.round()),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Serving sizes: ${food.servingSizes.map((s) => s.unit).join(", ")}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNutrientPreview(String label, int value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
