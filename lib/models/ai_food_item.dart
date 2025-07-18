class AIFoodItem {
  final String name;
  final List<String> servingSizes;
  final List<double> calories;
  final List<double> protein;
  final List<double> carbohydrates;
  final List<double> fat;
  final List<double> fiber;

  AIFoodItem({
    required this.name,
    required this.servingSizes,
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
  });

  factory AIFoodItem.fromJson(Map<String, dynamic> json) {
    return AIFoodItem(
      name: json['food'] as String,
      servingSizes: List<String>.from(json['serving_size']),
      calories:
          List<double>.from(json['calories'].map((x) => (x as num).toDouble())),
      protein:
          List<double>.from(json['protein'].map((x) => (x as num).toDouble())),
      carbohydrates: List<double>.from(
          json['carbohydrates'].map((x) => (x as num).toDouble())),
      fat: List<double>.from(json['fat'].map((x) => (x as num).toDouble())),
      fiber: List<double>.from(json['fiber'].map((x) => (x as num).toDouble())),
    );
  }

  // Get nutrition values for a specific serving size index
  NutritionInfo getNutritionForIndex(int index, double quantity) {
    if (index < 0 || index >= servingSizes.length) {
      return NutritionInfo.zero();
    }

    return NutritionInfo(
      calories: calories[index] * quantity,
      protein: protein[index] * quantity,
      carbohydrates: carbohydrates[index] * quantity,
      fat: fat[index] * quantity,
      fiber: fiber[index] * quantity,
    );
  }
}

class NutritionInfo {
  final double calories;
  final double protein;
  final double carbohydrates;
  final double fat;
  final double fiber;

  NutritionInfo({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
  });

  factory NutritionInfo.zero() {
    return NutritionInfo(
      calories: 0,
      protein: 0,
      carbohydrates: 0,
      fat: 0,
      fiber: 0,
    );
  }

  // Calculate health score from 0 to 100
  int calculateHealthScore() {
    if (calories <= 0) return 0;
    
    double score = 50.0; // Base score
    
    // Protein score (higher protein = better, up to +25 points)
    double proteinRatio = protein / calories * 100; // protein per 100 calories
    if (proteinRatio >= 10) {
      score += 25;
    } else if (proteinRatio >= 7) {
      score += 20;
    } else if (proteinRatio >= 5) {
      score += 15;
    } else if (proteinRatio >= 3) {
      score += 10;
    } else if (proteinRatio >= 1) {
      score += 5;
    }
    
    // Fiber score (higher fiber = better, up to +20 points)
    double fiberRatio = fiber / calories * 100; // fiber per 100 calories
    if (fiberRatio >= 5) {
      score += 20;
    } else if (fiberRatio >= 3) {
      score += 15;
    } else if (fiberRatio >= 2) {
      score += 10;
    } else if (fiberRatio >= 1) {
      score += 5;
    }
    
    // Calorie density penalty (high calorie density = penalty, up to -15 points)
    // Assuming standard serving sizes, penalize very high calorie foods
    if (calories > 600) {
      score -= 15;
    } else if (calories > 400) {
      score -= 10;
    } else if (calories > 300) {
      score -= 5;
    }
    
    // Fat ratio consideration (moderate fat is good, too much is bad)
    double fatRatio = (fat * 9) / calories; // fat calories / total calories
    if (fatRatio > 0.5) { // More than 50% fat
      score -= 10;
    } else if (fatRatio > 0.35) { // More than 35% fat
      score -= 5;
    } else if (fatRatio >= 0.20 && fatRatio <= 0.35) { // 20-35% fat (optimal)
      score += 5;
    }
    
    // Ensure score is within bounds
    return score.clamp(0, 100).round();
  }

  // Get health score color
  String getHealthScoreColor() {
    int score = calculateHealthScore();
    if (score >= 80) return '#4CAF50'; // Green
    if (score >= 60) return '#8BC34A'; // Light Green
    if (score >= 40) return '#FFC107'; // Yellow/Amber
    if (score >= 20) return '#FF9800'; // Orange
    return '#F44336'; // Red
  }

  // Get health score label
  String getHealthScoreLabel() {
    int score = calculateHealthScore();
    if (score >= 80) return 'Excellent';
    if (score >= 60) return 'Good';
    if (score >= 40) return 'Fair';
    if (score >= 20) return 'Poor';
    return 'Very Poor';
  }
}
