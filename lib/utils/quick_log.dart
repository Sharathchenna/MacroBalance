import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/foodEntry.dart';
import '../providers/dateProvider.dart';
import '../providers/foodEntryProvider.dart';
import '../services/posthog_service.dart';
import 'meal_time.dart';
import 'number_format.dart';

/// "1½ × 1 cup", "150 g" or "1 bowl" for a logged entry.
String describeEntryAmount(FoodEntry entry) {
  if (entry.food.brandName == 'AI Detected' && entry.food.servings.isEmpty) {
    final serving = (entry.servingDescription ?? 'serving')
        .replaceAll(RegExp(r'^\d+(\.\d+)?\s*x\s*'), '')
        .trim();
    return entry.quantity == 1 ? serving : '${formatServings(entry.quantity)} × $serving';
  }
  final unit = entry.unit.toLowerCase();
  if (entry.servingDescription != null && unit != 'g' && unit != 'oz') {
    for (final serving in entry.food.servings) {
      if (serving.description == entry.servingDescription && serving.metricAmount > 0) {
        final count = entry.quantity / serving.metricAmount;
        return count == 1 ? serving.description : '${formatServings(count)} × ${serving.description}';
      }
    }
  }
  return '${formatNumber(entry.quantity)} ${entry.unit}';
}

/// Logs [template]'s food again with the same amount, to [meal] on the
/// dashboard's selected day, and offers Undo.
Future<FoodEntry> quickLogAgain(BuildContext context, FoodEntry template,
    {String? meal}) async {
  final provider = Provider.of<FoodEntryProvider>(context, listen: false);
  final date = Provider.of<DateProvider>(context, listen: false).selectedDate;
  final messenger = ScaffoldMessenger.of(context);
  final targetMeal = meal ?? MealTime.suggested();
  final entry = FoodEntry(
    id: const Uuid().v4(),
    food: template.food,
    meal: targetMeal,
    quantity: template.quantity,
    unit: template.unit,
    date: date,
    servingDescription: template.servingDescription,
  );
  await provider.addEntry(entry);
  MealTime.remember(targetMeal);
  PostHogService.trackEvent('food_quick_logged', properties: {'meal_type': targetMeal});
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('Added ${entry.food.name} to $targetMeal'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () => provider.removeEntry(entry.id),
      ),
    ));
  return entry;
}
