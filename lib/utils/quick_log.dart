import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/foodEntry.dart';
import '../providers/dateProvider.dart';
import '../providers/foodEntryProvider.dart';
import '../services/posthog_service.dart';
import 'meal_time.dart';
import 'number_format.dart';
import '../widgets/app_toast.dart';

/// "1½ × 1 cup", "150 g" or "1 bowl" for a logged entry.
String describeEntryAmount(FoodEntry entry) {
  if (entry.food.brandName == 'AI Detected' && entry.food.servings.isEmpty) {
    final serving = (entry.servingDescription ?? 'serving')
        .replaceAll(RegExp(r'^\d+(\.\d+)?\s*x\s*'), '')
        .trim();
    return entry.quantity == 1 ? serving : '${formatServings(entry.quantity)} × $serving';
  }
  final unit = entry.unit.toLowerCase();
  final byWeight = unit == 'g' || unit == 'oz';
  if (entry.servingDescription != null) {
    for (final serving in entry.food.servings) {
      if (serving.description != entry.servingDescription || serving.metricAmount <= 0) continue;
      final count = entry.quantity / serving.metricAmount;
      // A weight reads as servings only when it's a tidy number of a
      // serving with a name ("1 slice (35g)", not "100 g").
      final named = !RegExp(r'^\s*[\d.,]+\s*(g|oz)\s*$', caseSensitive: false)
          .hasMatch(serving.description);
      final tidy = (count * 4 - (count * 4).round()).abs() < 0.001;
      if (byWeight && !(serving.metricUnit.toLowerCase() == unit && named && tidy)) break;
      return count == 1 ? serving.description : '${formatServings(count)} × ${serving.description}';
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
  final targetMeal = meal ?? MealTime.suggested();
  final entry = template.copyWith(id: const Uuid().v4(), meal: targetMeal, date: date);
  await provider.addEntry(entry);
  MealTime.remember(targetMeal);
  PostHogService.trackEvent('food_quick_logged', properties: {'meal_type': targetMeal});
  AppToast.show(
    'Added ${entry.food.name} to $targetMeal',
    context: context.mounted ? context : null,
    actionLabel: 'Undo',
    onAction: () => provider.removeEntry(entry.id),
  );
  return entry;
}
