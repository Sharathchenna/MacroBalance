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
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      food.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Available in: ${food.servingSizes.map((s) => s.unit).join(", ")}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: Theme.of(context).primaryColor,
                onPressed: onAdd,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
