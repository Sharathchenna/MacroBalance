import 'body_composition.dart';
import 'constants.dart';

double mifflinStJeor({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int age,
}) =>
    10 * weightKg + 6.25 * heightCm - 5 * age + (sex == Sex.male ? 5 : -161);

double katchMcArdle(double leanMassKg) => 370 + 21.6 * leanMassKg;

/// Mifflin–St Jeor, averaged with Katch–McArdle only when the user gave a
/// body fat % from a scan or smart scale. No other formula is ever chosen.
double basalMetabolicRate({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int age,
  double? bodyFatPct,
}) {
  final mifflin =
      mifflinStJeor(sex: sex, weightKg: weightKg, heightCm: heightCm, age: age);
  if (bodyFatPct == null) return mifflin;
  final leanMass = weightKg * (1 - bodyFatPct / 100);
  return (mifflin + katchMcArdle(leanMass)) / 2;
}

/// Activity level 1 (sedentary) to 5 (extra active).
double activityFactor(int activityLevel) =>
    kActivityFactors[(activityLevel - 1).clamp(0, kActivityFactors.length - 1)];

/// The formula estimate of daily expenditure: the starting point until the
/// adaptive estimate takes over.
double formulaTdee({
  required Sex sex,
  required double weightKg,
  required double heightCm,
  required int age,
  required int activityLevel,
  double? bodyFatPct,
}) =>
    basalMetabolicRate(
        sex: sex,
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        bodyFatPct: bodyFatPct) *
    activityFactor(activityLevel);
