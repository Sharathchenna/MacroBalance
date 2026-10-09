import 'bmr.dart' show activityFactor;
import 'constants.dart';

enum Sex { male, female }

/// What energy density and the projection's falling expenditure depend on.
/// Unknown height, age or activity use the onboarding defaults (170 cm, 30,
/// moderately active).
class BodyProfile {
  const BodyProfile({
    required this.sex,
    this.heightCm,
    this.age,
    this.activityLevel,
    this.bodyFatPct,
  });

  final Sex sex;
  final double? heightCm;
  final int? age;

  /// 1–5.
  final int? activityLevel;

  /// From a scan or smart scale; null estimates it with Deurenberg.
  final double? bodyFatPct;

  /// Cals per kg of weight change at [weightKg] (spec 6.1).
  double energyDensityAt(double weightKg) => energyDensity(fatMassKg(
        weightKg: weightKg,
        heightCm: heightCm ?? 170,
        age: age ?? 30,
        sex: sex,
        bodyFatPct: bodyFatPct,
      ));

  /// The activity multiplier on the BMR (spec 6.5).
  double get bmrMultiplier => activityFactor(activityLevel ?? 3);
}

double bmi({required double weightKg, required double heightCm}) {
  final m = heightCm / 100;
  return weightKg / (m * m);
}

/// Deurenberg (1991) body fat % from BMI, age and sex, clamped to 5–60%.
double deurenbergBodyFatPct({
  required double bmi,
  required int age,
  required Sex sex,
}) {
  final pct = 1.20 * bmi + 0.23 * age - 10.8 * (sex == Sex.male ? 1 : 0) - 5.4;
  return pct.clamp(kMinBodyFatPct, kMaxBodyFatPct).toDouble();
}

/// Fat mass from a body fat % measured by a scan or smart scale, or estimated
/// with Deurenberg when there isn't one.
double fatMassKg({
  required double weightKg,
  required double heightCm,
  required int age,
  required Sex sex,
  double? bodyFatPct,
}) {
  final pct = bodyFatPct ??
      deurenbergBodyFatPct(
          bmi: bmi(weightKg: weightKg, heightCm: heightCm), age: age, sex: sex);
  return weightKg * pct / 100;
}

/// Cals per kg of body weight lost or gained (Hall 2008 with Forbes' rule):
/// the leaner the body, the more of a change is lean tissue, so each kg is
/// worth fewer cals. The same value applies to gain and loss.
double energyDensity(double fatMassKg) {
  final leanShare = kForbesC / (kForbesC + fatMassKg);
  return leanShare * kLeanEnergyKcalPerKg + (1 - leanShare) * kFatEnergyKcalPerKg;
}
