class ServingInfo {
  final String description;
  final double amount;
  final String unit;
  final double metricAmount;
  final String metricUnit;
  final double calories;
  final double carbohydrate;
  final double protein;
  final double fat;
  final double saturatedFat;
  final double? polyunsaturatedFat;
  final double? monounsaturatedFat;
  final double? transFat;
  final double? cholesterol;
  final double? sodium;
  final double? potassium;
  final double? fiber;
  final double? sugar;
  final double? vitaminA;
  final double? vitaminC;
  final double? calcium;
  final double? iron;

  ServingInfo({
    required this.description,
    required this.amount,
    required this.unit,
    required this.metricAmount,
    required this.metricUnit,
    required this.calories,
    required this.carbohydrate,
    required this.protein,
    required this.fat,
    required this.saturatedFat,
    this.polyunsaturatedFat,
    this.monounsaturatedFat,
    this.transFat,
    this.cholesterol,
    this.sodium,
    this.potassium,
    this.fiber,
    this.sugar,
    this.vitaminA,
    this.vitaminC,
    this.calcium,
    this.iron,
  });

  factory ServingInfo.fromJson(Map<String, dynamic> json) {
    return ServingInfo(
      description: json['serving_description'] ?? '',
      amount: double.tryParse(json['number_of_units'].toString()) ?? 0.0,
      unit: json['measurement_description'] ?? 'g',
      metricAmount:
          double.tryParse(json['metric_serving_amount'].toString()) ?? 0.0,
      metricUnit: json['metric_serving_unit'] ?? 'g',
      calories: double.tryParse(json['calories'].toString()) ?? 0.0,
      carbohydrate: double.tryParse(json['carbohydrate'].toString()) ?? 0.0,
      protein: double.tryParse(json['protein'].toString()) ?? 0.0,
      fat: double.tryParse(json['fat'].toString()) ?? 0.0,
      saturatedFat: double.tryParse(json['saturated_fat'].toString()) ?? 0.0,
      polyunsaturatedFat:
          double.tryParse(json['polyunsaturated_fat']?.toString() ?? ''),
      monounsaturatedFat:
          double.tryParse(json['monounsaturated_fat']?.toString() ?? ''),
      transFat: double.tryParse(json['trans_fat']?.toString() ?? ''),
      cholesterol: double.tryParse(json['cholesterol']?.toString() ?? ''),
      sodium: double.tryParse(json['sodium']?.toString() ?? ''),
      potassium: double.tryParse(json['potassium']?.toString() ?? ''),
      fiber: double.tryParse(json['fiber']?.toString() ?? ''),
      sugar: double.tryParse(json['sugar']?.toString() ?? ''),
      vitaminA: double.tryParse(json['vitamin_a']?.toString() ?? ''),
      vitaminC: double.tryParse(json['vitamin_c']?.toString() ?? ''),
      calcium: double.tryParse(json['calcium']?.toString() ?? ''),
      iron: double.tryParse(json['iron']?.toString() ?? ''),
    );
  }
}

class FoodItem {
  final String id;
  final String name;
  final String brandName;
  final String foodType;
  final List<ServingInfo> servings;
  final Map<String, double> nutrients;

  FoodItem({
    required this.id,
    required this.name,
    required this.brandName,
    required this.foodType,
    required this.servings,
    required this.nutrients,
  });

  factory FoodItem.fromFatSecretJson(Map<String, dynamic> json) {
    List<ServingInfo> servings = [];
    if (json['servings'] != null && json['servings']['serving'] != null) {
      var servingData = json['servings']['serving'];
      if (servingData is List) {
        servings = servingData
            .map((s) => ServingInfo.fromJson(Map<String, dynamic>.from(s)))
            .toList();
      } else if (servingData is Map) {
        servings = [
          ServingInfo.fromJson(Map<String, dynamic>.from(servingData))
        ];
      }
    }

    // Extract first serving for default nutrients
    var firstServing = servings.isNotEmpty ? servings[0] : null;
    Map<String, double> nutrients = {};

    if (firstServing != null) {
      nutrients = {
        'Calories': firstServing.calories,
        'Carbohydrates': firstServing.carbohydrate,
        'Protein': firstServing.protein,
        'Fat': firstServing.fat,
        'Saturated Fat': firstServing.saturatedFat,
      };

      // Add optional nutrients if they exist
      if (firstServing.polyunsaturatedFat != null) {
        nutrients['Polyunsaturated Fat'] = firstServing.polyunsaturatedFat!;
      }
      if (firstServing.monounsaturatedFat != null) {
        nutrients['Monounsaturated Fat'] = firstServing.monounsaturatedFat!;
      }
      if (firstServing.transFat != null) {
        nutrients['Trans Fat'] = firstServing.transFat!;
      }
      if (firstServing.cholesterol != null) {
        nutrients['Cholesterol'] = firstServing.cholesterol!;
      }
      if (firstServing.sodium != null) {
        nutrients['Sodium'] = firstServing.sodium!;
      }
      if (firstServing.potassium != null) {
        nutrients['Potassium'] = firstServing.potassium!;
      }
      if (firstServing.fiber != null) nutrients['Fiber'] = firstServing.fiber!;
      if (firstServing.sugar != null) nutrients['Sugar'] = firstServing.sugar!;
    }

    return FoodItem(
      id: json['food_id']?.toString() ?? '',
      name: json['food_name']?.toString() ?? '',
      brandName: json['brand_name']?.toString() ?? '',
      foodType: json['food_type']?.toString() ?? '',
      servings: servings,
      nutrients: nutrients,
    );
  }

  double get calories => servings.isNotEmpty ? servings[0].calories : 0.0;
  double get protein => servings.isNotEmpty ? servings[0].protein : 0.0;
  double get carbs => servings.isNotEmpty ? servings[0].carbohydrate : 0.0;
  double get fat => servings.isNotEmpty ? servings[0].fat : 0.0;
}
