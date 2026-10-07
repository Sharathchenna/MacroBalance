import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/targets.dart';

void main() {
  group('paceDeltaCals', () {
    test('is pace × weight × energy density, per day', () {
      // 0.5% of 80 kg = 0.4 kg a week, × 7000 cals/kg / 7 days
      expect(paceDeltaCals(pacePct: 0.5, weightKg: 80, energyDensity: 7000), closeTo(400, 1e-9));
    });
  });

  group('applySafetyLimits', () {
    SafeTarget limit(double cals, double tdee,
            {Sex sex = Sex.male, double weightKg = 80, double ed = 7000, double? currentCals}) =>
        applySafetyLimits(
          cals: cals,
          tdee: tdee,
          sex: sex,
          weightKg: weightKg,
          energyDensity: ed,
          currentCals: currentCals,
        );

    test('leaves a target inside every limit alone', () {
      final t = limit(2300, 2700);
      expect(t.cals, 2300);
      expect(t.limitsHit, isEmpty);
      expect(t.limitHit, isNull);
    });

    test('female floor: 1,200 cals', () {
      final t = limit(1150, 1500, sex: Sex.female, weightKg: 60);
      expect(t.cals, kFloorFemale);
      expect(t.limitsHit, [SafetyLimit.floor]);
    });

    test('male floor: 1,500 cals', () {
      final t = limit(1450, 1900, weightKg: 60);
      expect(t.cals, kFloorMale);
      expect(t.limitsHit, [SafetyLimit.floor]);
      // The same target is fine for a woman.
      expect(limit(1450, 1900, sex: Sex.female, weightKg: 60).limitsHit, isEmpty);
    });

    test('deficit cap: no more than 25% below expenditure', () {
      // The 1%/week pace would allow 2,800 − 800 = 2,000; the 25% cap is 2,100.
      final t = limit(1800, 2800);
      expect(t.cals, closeTo(2100, 1e-9));
      expect(t.limitsHit, [SafetyLimit.maxDeficit]);
    });

    test('loss-pace cap: no faster than 1% of body weight a week', () {
      // 1% of 60 kg × 6000 / 7 = 514 a day, a tighter cap than 25% (1,000).
      final t = limit(3200, 4000, weightKg: 60, ed: 6000);
      expect(t.cals, closeTo(4000 - 0.01 * 60 * 6000 / 7, 1e-9));
      expect(t.limitsHit, [SafetyLimit.maxLossPace]);
    });

    test('surplus cap: no more than 15% above expenditure', () {
      // The 0.5%/week pace would allow 2,000 + 400; the 15% cap is 2,300.
      final t = limit(2500, 2000);
      expect(t.cals, closeTo(2300, 1e-9));
      expect(t.limitsHit, [SafetyLimit.maxSurplus]);
    });

    test('gain-pace cap: no faster than 0.5% of body weight a week', () {
      // 0.5% of 50 kg × 6000 / 7 = 214 a day, tighter than 15% (600).
      final t = limit(4500, 4000, weightKg: 50, ed: 6000);
      expect(t.cals, closeTo(4000 + 0.005 * 50 * 6000 / 7, 1e-9));
      expect(t.limitsHit, [SafetyLimit.maxGainPace]);
    });

    test('the floor comes after the deficit cap and records both', () {
      final t = limit(800, 1500, sex: Sex.female, weightKg: 60);
      expect(t.cals, kFloorFemale);
      expect(t.limitsHit, [SafetyLimit.maxDeficit, SafetyLimit.floor]);
      expect(t.limitHit, SafetyLimit.floor);
    });

    test('the floor applies to maintenance too', () {
      final t = limit(1100, 1100, sex: Sex.female, weightKg: 45);
      expect(t.cals, kFloorFemale);
      expect(t.limitsHit, [SafetyLimit.floor]);
    });

    test('check-in step: at most 150 cals from the current target', () {
      expect(limit(2000, 2400, currentCals: 2300).cals, 2150);
      expect(limit(2000, 2400, currentCals: 2300).limitsHit, [SafetyLimit.checkinStep]);
      expect(limit(2300, 2400, currentCals: 2000).cals, 2150);
    });

    test('the check-in step is skipped without a current target (onboarding, recalculate)', () {
      expect(limit(2000, 2400).cals, 2000);
    });
  });

  group('targetForPace', () {
    PaceTarget target(GoalKind goal, double pace,
            {double tdee = 2700, Sex sex = Sex.male, double weightKg = 80, double ed = 7000}) =>
        targetForPace(
          goal: goal,
          pacePct: pace,
          tdee: tdee,
          sex: sex,
          weightKg: weightKg,
          energyDensity: ed,
        );

    test('losing takes the pace off expenditure', () {
      final t = target(GoalKind.lose, 0.5);
      expect(t.cals, 2300);
      expect(t.effectivePacePct, closeTo(0.5, 0.001));
      expect(t.clamped, isFalse);
    });

    test('gaining adds it on', () {
      final t = target(GoalKind.gain, 0.25);
      expect(t.cals, 2900);
      expect(t.effectivePacePct, closeTo(0.25, 0.001));
    });

    test('maintaining is expenditure', () {
      expect(target(GoalKind.maintain, 0.5).cals, 2700);
    });

    test('a clamped pace reports the slower pace it really gives', () {
      // 1% of 80 kg = 800 a day, above 25% of 2,700 (675).
      final t = target(GoalKind.lose, 1.0);
      expect(t.cals, 2025);
      expect(t.clamped, isTrue);
      expect(t.limitHit, SafetyLimit.maxDeficit);
      expect(t.effectivePacePct, closeTo(675 * 7 / 7000 / 80 * 100, 0.01));
    });

    test('a target held up by the floor above expenditure means no loss', () {
      final t = target(GoalKind.lose, 0.5, tdee: 1150, sex: Sex.female, weightKg: 50);
      expect(t.cals, kFloorFemale);
      expect(t.effectivePacePct, 0);
      expect(t.limitHit, SafetyLimit.floor);
    });

    test('cals are whole numbers', () {
      final t = target(GoalKind.lose, 0.75, tdee: 2633, weightKg: 77.3, ed: 6543);
      expect(t.cals, t.cals.roundToDouble());
    });

    test('every offered pace stays inside the limits for a typical body', () {
      for (final pace in kLosePaceOptions) {
        expect(target(GoalKind.lose, pace).cals, greaterThanOrEqualTo(2700 * 0.75 - 0.5));
      }
      for (final pace in kGainPaceOptions) {
        expect(target(GoalKind.gain, pace).cals, lessThanOrEqualTo(2700 * 1.15 + 0.5));
      }
    });
  });

  group('weeksToGoal', () {
    test('is the weight to go over the weekly change', () {
      // 8 kg × 7000 cals/kg at 500 cals a day = 16 weeks.
      expect(
          weeksToGoal(weightKg: 80, goalWeightKg: 72, tdee: 2700, cals: 2200, energyDensity: 7000),
          closeTo(16, 1e-9));
      expect(
          weeksToGoal(weightKg: 70, goalWeightKg: 73, tdee: 2700, cals: 2950, energyDensity: 7000),
          closeTo(12, 1e-9));
    });

    test('is null when the target does not move towards the goal', () {
      expect(weeksToGoal(weightKg: 80, goalWeightKg: 72, tdee: 2700, cals: 2700, energyDensity: 7000),
          isNull);
      expect(weeksToGoal(weightKg: 80, goalWeightKg: 72, tdee: 1150, cals: 1200, energyDensity: 7000),
          isNull);
    });
  });

  test('the recommended paces are among the options', () {
    expect(kLosePaceOptions, [0.25, 0.5, 0.75, 1.0]);
    expect(kGainPaceOptions, [0.1, 0.25, 0.5]);
    expect(kLosePaceOptions, contains(kDefaultLosePace));
    expect(kGainPaceOptions, contains(kDefaultGainPace));
    expect(defaultPacePct(GoalKind.lose), 0.5);
    expect(defaultPacePct(GoalKind.gain), 0.25);
    expect(defaultPacePct(GoalKind.maintain), 0);
  });
}
