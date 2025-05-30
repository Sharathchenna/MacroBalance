class NutritionGoals {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final int steps;
  final double bmr;
  final double tdee;
  final double goalWeightKg;
  final double currentWeightKg;
  final String goalType;
  final int deficitSurplus;

  const NutritionGoals({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.steps = 10000,
    this.bmr = 1500.0,
    this.tdee = 2000.0,
    this.goalWeightKg = 0.0,
    this.currentWeightKg = 0.0,
    this.goalType = 'maintain',
    this.deficitSurplus = 500,
  });

  factory NutritionGoals.defaultGoals() {
    return const NutritionGoals(
      calories: 2000.0,
      protein: 150.0,
      carbs: 225.0,
      fat: 65.0,
    );
  }

  factory NutritionGoals.fromJson(Map<String, dynamic> json) {
    final macroTargets = json['macro_targets'] ?? {};
    return NutritionGoals(
      calories: (macroTargets['calories'] as num?)?.toDouble() ?? 2000.0,
      protein: (macroTargets['protein'] as num?)?.toDouble() ?? 150.0,
      carbs: (macroTargets['carbs'] as num?)?.toDouble() ?? 225.0,
      fat: (macroTargets['fat'] as num?)?.toDouble() ?? 65.0,
      steps: json['steps_goal'] ?? 10000,
      bmr: (json['bmr'] as num?)?.toDouble() ?? 1500.0,
      tdee: (json['tdee'] as num?)?.toDouble() ?? 2000.0,
      goalWeightKg: (json['goal_weight_kg'] as num?)?.toDouble() ?? 0.0,
      currentWeightKg: (json['current_weight_kg'] as num?)?.toDouble() ?? 0.0,
      goalType: json['goal_type'] ?? 'maintain',
      deficitSurplus: json['deficit_surplus'] ?? 500,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'macro_targets': {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      },
      'steps_goal': steps,
      'bmr': bmr,
      'tdee': tdee,
      'goal_weight_kg': goalWeightKg,
      'current_weight_kg': currentWeightKg,
      'goal_type': goalType,
      'deficit_surplus': deficitSurplus,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  NutritionGoals copyWith({
    double? calories,
    double? protein,
    double? carbs,
    double? fat,
    int? steps,
    double? bmr,
    double? tdee,
    double? goalWeightKg,
    double? currentWeightKg,
    String? goalType,
    int? deficitSurplus,
  }) {
    return NutritionGoals(
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      steps: steps ?? this.steps,
      bmr: bmr ?? this.bmr,
      tdee: tdee ?? this.tdee,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      goalType: goalType ?? this.goalType,
      deficitSurplus: deficitSurplus ?? this.deficitSurplus,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NutritionGoals &&
        other.calories == calories &&
        other.protein == protein &&
        other.carbs == carbs &&
        other.fat == fat &&
        other.steps == steps &&
        other.bmr == bmr &&
        other.tdee == tdee &&
        other.goalWeightKg == goalWeightKg &&
        other.currentWeightKg == currentWeightKg &&
        other.goalType == goalType &&
        other.deficitSurplus == deficitSurplus;
  }

  @override
  int get hashCode {
    return Object.hash(
      calories,
      protein,
      carbs,
      fat,
      steps,
      bmr,
      tdee,
      goalWeightKg,
      currentWeightKg,
      goalType,
      deficitSurplus,
    );
  }

  @override
  String toString() {
    return 'NutritionGoals(calories: $calories, protein: $protein, carbs: $carbs, fat: $fat, steps: $steps, goalType: $goalType)';
  }
}
