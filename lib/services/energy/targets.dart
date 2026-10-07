import 'dart:math';

import 'body_composition.dart';
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

// --- Calories for a goal (spec §6.6) ---

/// The pace offered first: 0.5%/week to lose, 0.25%/week to gain.
double defaultPacePct(GoalKind goal) => switch (goal) {
      GoalKind.lose => kDefaultLosePace,
      GoalKind.gain => kDefaultGainPace,
      GoalKind.maintain => 0,
    };

/// Daily cals that move [pacePct] % of [weightKg] a week.
double paceDeltaCals({
  required double pacePct,
  required double weightKg,
  required double energyDensity,
}) =>
    pacePct / 100 * weightKg * energyDensity / 7;

/// The weekly change, in % of body weight, that eating [cals] against [tdee]
/// gives: negative when losing.
double impliedPacePct({
  required double cals,
  required double tdee,
  required double weightKg,
  required double energyDensity,
}) =>
    (cals - tdee) * 7 / energyDensity / weightKg * 100;

/// A safety limit that changed a target.
enum SafetyLimit { maxDeficit, maxLossPace, maxSurplus, maxGainPace, floor, checkinStep }

class SafeTarget {
  const SafeTarget(this.cals, this.limitsHit);

  final double cals;

  /// Every limit that changed the target, in the order applied.
  final List<SafetyLimit> limitsHit;

  /// The limit that set the final target.
  SafetyLimit? get limitHit => limitsHit.isEmpty ? null : limitsHit.last;
}

/// Keeps a calorie target safe (spec §6.6), in order:
/// 1. Below [tdee]: a deficit of at most 25% and a loss of at most 1% of body
///    weight a week. Above it: a surplus of at most 15% and a gain of at most
///    0.5% a week.
/// 2. At least the floor for [sex].
/// 3. Only for ordinary check-ins, which pass [currentCals]: at most 150 cals
///    from the current target.
SafeTarget applySafetyLimits({
  required double cals,
  required double tdee,
  required Sex sex,
  required double weightKg,
  required double energyDensity,
  double? currentCals,
}) {
  final hit = <SafetyLimit>[];
  void raiseTo(double bound, SafetyLimit limit) {
    if (cals < bound) {
      cals = bound;
      hit.add(limit);
    }
  }

  void lowerTo(double bound, SafetyLimit limit) {
    if (cals > bound) {
      cals = bound;
      hit.add(limit);
    }
  }

  double maxDelta(double pct) =>
      paceDeltaCals(pacePct: pct, weightKg: weightKg, energyDensity: energyDensity);

  if (cals < tdee) {
    raiseTo(tdee * (1 - kMaxDeficitFrac), SafetyLimit.maxDeficit);
    raiseTo(tdee - maxDelta(kMaxLossPct), SafetyLimit.maxLossPace);
  } else if (cals > tdee) {
    lowerTo(tdee * (1 + kMaxSurplusFrac), SafetyLimit.maxSurplus);
    lowerTo(tdee + maxDelta(kMaxGainPct), SafetyLimit.maxGainPace);
  }

  raiseTo(sex == Sex.female ? kFloorFemale : kFloorMale, SafetyLimit.floor);

  if (currentCals != null) {
    raiseTo(currentCals - kMaxCheckinStep, SafetyLimit.checkinStep);
    lowerTo(currentCals + kMaxCheckinStep, SafetyLimit.checkinStep);
  }
  return SafeTarget(cals, hit);
}

/// The daily target for a goal at a chosen pace, after the safety limits.
class PaceTarget {
  const PaceTarget({
    required this.pacePct,
    required this.cals,
    required this.effectivePacePct,
    required this.limitsHit,
  });

  /// The pace the user chose, % of body weight a week.
  final double pacePct;

  /// Whole cals a day.
  final double cals;

  /// The pace [cals] really gives, towards the goal (never negative). Lower
  /// than [pacePct] when a limit applied.
  final double effectivePacePct;

  final List<SafetyLimit> limitsHit;

  SafetyLimit? get limitHit => limitsHit.isEmpty ? null : limitsHit.last;
  bool get clamped => limitsHit.isNotEmpty;
}

/// Onboarding and recalculation: `tdee ∓ pace`, then the safety limits
/// (without the check-in step).
PaceTarget targetForPace({
  required GoalKind goal,
  required double pacePct,
  required double tdee,
  required Sex sex,
  required double weightKg,
  required double energyDensity,
}) {
  final delta =
      paceDeltaCals(pacePct: pacePct, weightKg: weightKg, energyDensity: energyDensity);
  final raw = switch (goal) {
    GoalKind.lose => tdee - delta,
    GoalKind.gain => tdee + delta,
    GoalKind.maintain => tdee,
  };
  final safe = applySafetyLimits(
    cals: raw,
    tdee: tdee,
    sex: sex,
    weightKg: weightKg,
    energyDensity: energyDensity,
  );
  final cals = safe.cals.roundToDouble();
  final implied = impliedPacePct(
      cals: cals, tdee: tdee, weightKg: weightKg, energyDensity: energyDensity);
  final effective = switch (goal) {
    GoalKind.lose => max(0.0, -implied),
    GoalKind.gain => max(0.0, implied),
    GoalKind.maintain => 0.0,
  };
  return PaceTarget(
    pacePct: goal == GoalKind.maintain ? 0 : pacePct,
    cals: cals,
    // Rounding the cals shouldn't read as a slower pace.
    effectivePacePct: safe.limitsHit.isEmpty ? pacePct : effective,
    limitsHit: safe.limitsHit,
  );
}

/// About how many weeks eating [cals] takes to get from [weightKg] to
/// [goalWeightKg], at today's energy balance. Null when the target doesn't
/// move towards the goal. (A simple estimate until the projection, which also
/// lets expenditure fall with weight, replaces it.)
double? weeksToGoal({
  required double weightKg,
  required double goalWeightKg,
  required double tdee,
  required double cals,
  required double energyDensity,
}) {
  final toGo = goalWeightKg - weightKg;
  final dailyBalance = cals - tdee;
  if (toGo == 0 || dailyBalance == 0 || toGo.sign != dailyBalance.sign) return null;
  return toGo * energyDensity / (dailyBalance * 7);
}
