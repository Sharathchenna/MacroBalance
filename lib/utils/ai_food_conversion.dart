import '../models/ai_food_item.dart';
import '../screens/searchPage.dart' show FoodItem, Serving;

/// The weight in a serving label such as "1 cup (240g)", "100 g" or
/// "3.5 oz", in grams; null when the label gives none.
double? gramsInServing(String description) {
  final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*(g|gm|grams?|oz|ounces?)\b',
          caseSensitive: false)
      .firstMatch(description);
  if (match == null) return null;
  final amount = double.tryParse(match.group(1)!.replaceAll(',', '.'));
  if (amount == null || amount <= 0) return null;
  return match.group(2)!.toLowerCase().startsWith('o') ? amount * 28.35 : amount;
}

extension AIFoodAsFoodItem on AIFoodItem {
  /// The AI's foods as an ordinary food, so they open in the same detail page
  /// as searched foods. Each suggested serving becomes a serving; one whose
  /// label gives a weight is measured in grams, which lets the amount also be
  /// entered by weight.
  FoodItem toFoodItem() {
    final servings = <Serving>[
      for (var i = 0; i < servingSizes.length; i++)
        _serving(servingSizes[i], i),
    ];
    final first = servings.isNotEmpty ? servings.first : null;
    return FoodItem(
      // Same id the AI screens always used, so saved AI foods still match.
      fdcId: name.hashCode.toString(),
      name: name,
      calories: first?.calories ?? 0,
      nutrients: first?.nutrients ?? const {},
      brandName: 'AI Detected',
      mealType: '',
      servingSize: gramsInServing(servingSizes.isEmpty ? '' : servingSizes.first) ?? 100,
      servings: servings,
    );
  }

  Serving _serving(String description, int i) {
    final grams = gramsInServing(description);
    double at(List<double> values) => i < values.length ? values[i] : 0;
    return Serving(
      description: description,
      metricAmount: grams ?? 1,
      metricUnit: grams != null ? 'g' : 'serving',
      calories: at(calories),
      nutrients: {
        'Protein': at(protein),
        'Carbohydrate, by difference': at(carbohydrates),
        'Total lipid (fat)': at(fat),
        'Fiber': at(fiber),
      },
    );
  }
}
