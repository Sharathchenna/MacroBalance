import 'dart:math';

import 'constants.dart';

enum GoalKind { lose, maintain, gain }

/// Daily macro targets in whole grams.
class MacroSplit {
  const MacroSplit({required this.proteinG, required this.carbsG, required this.fatG});

  final int proteinG;
  final int carbsG;
  final int fatG;

  /// The cals the grams add up to.
  int get cals => (proteinG * kKcalPerGramProtein +
          carbsG * kKcalPerGramCarbs +
          fatG * kKcalPerGramFat)
      .round();

  @override
  String toString() => 'P$proteinG C$carbsG F$fatG ($cals cals)';
}

/// The weight protein and the fat floor are scaled by: lean mass when body fat
/// is known, otherwise body weight capped at the BMI-25 weight for the height
/// (so extra fat mass doesn't inflate protein). Unknown height: body weight.
double referenceWeightKg({
  required double weightKg,
  double? heightCm,
  double? bodyFatPct,
}) {
  if (bodyFatPct != null) return weightKg * (1 - bodyFatPct / 100);
  if (heightCm == null || heightCm <= 0) return weightKg;
  final m = heightCm / 100;
  return min(weightKg, kReferenceBmi * m * m);
}

/// Protein in g per kg of [referenceWeightKg]. The same for both sexes.
double defaultProteinPerKg({required GoalKind goal, required bool bodyFatKnown}) {
  if (goal == GoalKind.lose) return bodyFatKnown ? kProteinLoseLean : kProteinLoseRef;
  return bodyFatKnown ? kProteinOtherLean : kProteinOtherRef;
}

/// Splits [cals] into protein, fat and carbs (spec §6.6).
///
/// Protein comes first, then fat (at [fatRatio] of cals, never under the fat
/// floor), and carbs take the rest. When that leaves carbs negative, fat comes
/// down towards its floor, then protein towards 1.2 g/kg, and only then are
/// carbs set to 0. The grams add up to [cals] within 5 for any target at or
/// above the 1,200 cal floor.
MacroSplit splitMacros({
  required double cals,
  required GoalKind goal,
  required double weightKg,
  double? heightCm,
  double? bodyFatPct,
  double? proteinPerKg,
  double? fatRatio,
}) {
  final ref = referenceWeightKg(
      weightKg: weightKg, heightCm: heightCm, bodyFatPct: bodyFatPct);
  final perKg = proteinPerKg ??
      defaultProteinPerKg(goal: goal, bodyFatKnown: bodyFatPct != null);

  var protein = ref * perKg;
  final fatFloor =
      max(kFatFloorPerKg * ref, kFatFloorRatio * cals / kKcalPerGramFat);
  var fat = max(cals * (fatRatio ?? kDefaultFatRatio) / kKcalPerGramFat, fatFloor);

  double carbCals() =>
      cals - protein * kKcalPerGramProtein - fat * kKcalPerGramFat;

  if (carbCals() >= 0) {
    final p = protein.round();
    final f = fat.round();
    final c = (cals - p * kKcalPerGramProtein - f * kKcalPerGramFat) / kKcalPerGramCarbs;
    return MacroSplit(proteinG: p, carbsG: max(0, c.round()), fatG: f);
  }

  // Too few cals for the protein and fat: give up fat, then protein, only as
  // far as needed.
  fat -= min(fat - fatFloor, -carbCals() / kKcalPerGramFat);
  if (carbCals() < 0) {
    final proteinFloor = kMinProteinPerKg * ref;
    protein -= max(0.0, min(protein - proteinFloor, -carbCals() / kKcalPerGramProtein));
  }
  // Round down so the rounded grams never overshoot the cals.
  final p = protein.floor();
  final f = fat.floor();
  final c = (cals - p * kKcalPerGramProtein - f * kKcalPerGramFat) / kKcalPerGramCarbs;
  return MacroSplit(proteinG: p, carbsG: max(0, c.round()), fatG: f);
}
