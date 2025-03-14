class FoodItem {
  final String id;
  final String name;
  final String brand;
  final String image;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double servingSize;
  final String servingUnit;

  FoodItem({
    required this.id,
    required this.name,
    required this.brand,
    required this.image,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.servingSize,
    required this.servingUnit,
  });

  factory FoodItem.fromOpenFoodFacts(Map<String, dynamic> data) {
    final nutrients = data['nutriments'] ?? {};
    return FoodItem(
      id: data['code'] ?? '',
      name: data['product_name'] ?? 'Unknown Product',
      brand: data['brands'] ?? '',
      image: data['image_url'] ?? '',
      calories: (nutrients['energy-kcal_100g'] ?? 0.0).toDouble(),
      protein: (nutrients['proteins_100g'] ?? 0.0).toDouble(),
      carbs: (nutrients['carbohydrates_100g'] ?? 0.0).toDouble(),
      fat: (nutrients['fat_100g'] ?? 0.0).toDouble(),
      servingSize: 100.0,
      servingUnit: 'g',
    );
  }
}
