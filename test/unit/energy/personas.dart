import 'package:macrotracker/services/macro_calculator_service.dart';

/// Six reference users for checking onboarding targets end to end: small and
/// large, male and female, lean and obese, with and without a scanned body fat.
class Persona {
  const Persona({
    required this.name,
    required this.gender,
    required this.weightKg,
    required this.heightCm,
    required this.age,
    required this.activityLevel,
    required this.goal,
    this.deficit = 0,
    this.goalWeightKg,
    this.bodyFatPct,
  });

  final String name;
  final String gender;
  final double weightKg;
  final double heightCm;
  final int age;
  final int activityLevel;
  final String goal;
  final int deficit;
  final double? goalWeightKg;
  final double? bodyFatPct;

  /// The targets onboarding would produce with every other setting left alone.
  Map<String, dynamic> onboardingResults() => MacroCalculatorService().calculateAll(
        gender: gender,
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        activityLevel: activityLevel,
        goal: goal,
        deficit: deficit,
        goalWeightKg: goalWeightKg,
        bodyFatPercentage: bodyFatPct,
      );
}

const personas = [
  Persona(
    name: 'small lean woman, maintaining',
    gender: MacroCalculatorService.FEMALE,
    weightKg: 50,
    heightCm: 157,
    age: 28,
    activityLevel: MacroCalculatorService.LIGHTLY_ACTIVE,
    goal: MacroCalculatorService.GOAL_MAINTAIN,
  ),
  Persona(
    name: 'small obese woman, losing',
    gender: MacroCalculatorService.FEMALE,
    weightKg: 95,
    heightCm: 155,
    age: 45,
    activityLevel: MacroCalculatorService.SEDENTARY,
    goal: MacroCalculatorService.GOAL_LOSE,
    deficit: 500,
    goalWeightKg: 80,
  ),
  Persona(
    name: 'tall lean man, gaining',
    gender: MacroCalculatorService.MALE,
    weightKg: 72,
    heightCm: 190,
    age: 22,
    activityLevel: MacroCalculatorService.VERY_ACTIVE,
    goal: MacroCalculatorService.GOAL_GAIN,
    deficit: 300,
    goalWeightKg: 80,
  ),
  Persona(
    name: 'large obese man, losing',
    gender: MacroCalculatorService.MALE,
    weightKg: 160,
    heightCm: 185,
    age: 40,
    activityLevel: MacroCalculatorService.LIGHTLY_ACTIVE,
    goal: MacroCalculatorService.GOAL_LOSE,
    deficit: 750,
    goalWeightKg: 120,
  ),
  Persona(
    name: 'woman with a scanned body fat, losing',
    gender: MacroCalculatorService.FEMALE,
    weightKg: 68,
    heightCm: 168,
    age: 32,
    activityLevel: MacroCalculatorService.MODERATELY_ACTIVE,
    goal: MacroCalculatorService.GOAL_LOSE,
    deficit: 300,
    goalWeightKg: 62,
    bodyFatPct: 30,
  ),
  Persona(
    name: 'lean man with a scanned body fat, maintaining',
    gender: MacroCalculatorService.MALE,
    weightKg: 82,
    heightCm: 178,
    age: 35,
    activityLevel: MacroCalculatorService.MODERATELY_ACTIVE,
    goal: MacroCalculatorService.GOAL_MAINTAIN,
    bodyFatPct: 14,
  ),
];
