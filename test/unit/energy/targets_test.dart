import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/targets.dart';

void main() {
  group('referenceWeightKg', () {
    test('is body weight when it is under BMI 25 for the height', () {
      expect(referenceWeightKg(weightKg: 70, heightCm: 180), 70);
    });

    test('is capped at the BMI-25 weight for heavier people', () {
      expect(referenceWeightKg(weightKg: 120, heightCm: 180), closeTo(81, 1e-9));
    });

    test('is lean mass when body fat is known', () {
      expect(referenceWeightKg(weightKg: 100, heightCm: 180, bodyFatPct: 30),
          closeTo(70, 1e-9));
    });

    test('falls back to body weight when height is unknown', () {
      expect(referenceWeightKg(weightKg: 95), 95);
    });
  });

  group('defaultProteinPerKg', () {
    test('follows the goal table, with no split by sex', () {
      expect(defaultProteinPerKg(goal: GoalKind.lose, bodyFatKnown: true), 2.6);
      expect(defaultProteinPerKg(goal: GoalKind.lose, bodyFatKnown: false), 2.0);
      expect(defaultProteinPerKg(goal: GoalKind.maintain, bodyFatKnown: true), 2.0);
      expect(defaultProteinPerKg(goal: GoalKind.maintain, bodyFatKnown: false), 1.6);
      expect(defaultProteinPerKg(goal: GoalKind.gain, bodyFatKnown: true), 2.0);
      expect(defaultProteinPerKg(goal: GoalKind.gain, bodyFatKnown: false), 1.6);
    });
  });

  group('splitMacros', () {
    test('protein is reference weight × the table value', () {
      final m = splitMacros(cals: 2500, goal: GoalKind.maintain, weightKg: 80, heightCm: 180);
      expect(m.proteinG, 128); // 80 × 1.6
      final heavy = splitMacros(cals: 2200, goal: GoalKind.lose, weightKg: 120, heightCm: 180);
      expect(heavy.proteinG, 162); // 81 × 2.0
    });

    test('a protein override replaces the table value', () {
      final m = splitMacros(
          cals: 2500, goal: GoalKind.maintain, weightKg: 80, heightCm: 180, proteinPerKg: 2.2);
      expect(m.proteinG, 176);
    });

    test('fat is 25% of cals by default', () {
      final m = splitMacros(cals: 2700, goal: GoalKind.maintain, weightKg: 70, heightCm: 175);
      expect(m.fatG, 75); // 2700 × 0.25 / 9
    });

    test('fat never drops below half a gram per kg of reference weight', () {
      // ref 100 kg → floor 50 g, above 25% of 1500 cals (41.7 g)
      final m = splitMacros(cals: 1500, goal: GoalKind.maintain, weightKg: 120, heightCm: 200);
      expect(m.fatG, 50);
    });

    test('fat never drops below 20% of cals', () {
      final m = splitMacros(
          cals: 3000, goal: GoalKind.maintain, weightKg: 60, heightCm: 170, fatRatio: 0.15);
      expect(m.fatG, 67); // 3000 × 0.20 / 9
    });

    test('carbs take the rest', () {
      final m = splitMacros(cals: 2500, goal: GoalKind.maintain, weightKg: 80, heightCm: 180);
      // fat 69 g, protein 128 g → (2500 − 512 − 621) / 4
      expect(m.fatG, 69);
      expect(m.carbsG, 342);
    });

    group('when carbs would go negative', () {
      // 100 kg at 15% → 85 kg lean mass, protein 2.6 g/kg = 221 g, fat floor 42.5 g
      MacroSplit split(double cals, {double fatRatio = 0.25}) => splitMacros(
          cals: cals,
          goal: GoalKind.lose,
          weightKg: 100,
          heightCm: 185,
          bodyFatPct: 15,
          fatRatio: fatRatio);

      test('fat comes down first, protein is kept', () {
        final m = split(1400, fatRatio: 0.40); // fat 62 g would leave carbs < 0
        expect(m.proteinG, 221);
        expect(m.carbsG, lessThanOrEqualTo(3)); // about 0, after rounding
        expect(m.fatG, lessThan(62));
        expect(m.fatG, greaterThanOrEqualTo(42));
        expect(m.cals, closeTo(1400, 5));
      });

      test('then protein, once fat is at its floor', () {
        final m = split(1100);
        expect(m.fatG, closeTo(42.5, 1));
        expect(m.proteinG, lessThan(221));
        expect(m.proteinG, greaterThanOrEqualTo(102)); // 1.2 × 85
        expect(m.carbsG, lessThanOrEqualTo(3)); // about 0, after rounding
        expect(m.cals, closeTo(1100, 5));
      });

      test('protein stops at 1.2 g/kg and carbs are 0', () {
        final m = split(700);
        expect(m.proteinG, 102);
        expect(m.fatG, closeTo(42.5, 1));
        expect(m.carbsG, 0);
      });
    });

    test('property: over 1,000 generated users the macros add up to the cals within 5', () {
      final random = Random(42);
      double between(double lo, double hi) => lo + random.nextDouble() * (hi - lo);
      for (var i = 0; i < 1000; i++) {
        final heightCm = between(145, 210);
        final weightKg = between(40, 200);
        // Known body fat only at plausible values: lean mass no higher than the
        // BMI-25 weight for the height.
        final minBf = max(5.0, 100 * (1 - 25 * pow(heightCm / 100, 2) / weightKg));
        final double? bodyFatPct =
            random.nextBool() && minBf < 50 ? between(minBf, 50) : null;
        final cals = between(1200, 5000).roundToDouble();
        final goal = GoalKind.values[random.nextInt(3)];
        final double? proteinPerKg = random.nextInt(4) == 0 ? between(1.2, 2.4) : null;
        final fatRatio = between(0.20, 0.40);

        final m = splitMacros(
          cals: cals,
          goal: goal,
          weightKg: weightKg,
          heightCm: heightCm,
          bodyFatPct: bodyFatPct,
          proteinPerKg: proteinPerKg,
          fatRatio: fatRatio,
        );
        final input = 'cals $cals, $goal, ${weightKg.toStringAsFixed(1)} kg, '
            '${heightCm.toStringAsFixed(1)} cm, bf $bodyFatPct, p/kg $proteinPerKg, '
            'fat ${fatRatio.toStringAsFixed(2)} → $m';
        expect(m.proteinG, greaterThan(0), reason: input);
        expect(m.fatG, greaterThan(0), reason: input);
        expect(m.carbsG, greaterThanOrEqualTo(0), reason: input);
        expect((m.cals - cals).abs(), lessThanOrEqualTo(5), reason: input);
      }
    });
  });
}
