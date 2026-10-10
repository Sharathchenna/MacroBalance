import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/body_composition.dart';

void main() {
  group('bmi', () {
    test('is weight over height squared', () {
      expect(bmi(weightKg: 80, heightCm: 200), closeTo(20, 1e-9));
    });
  });

  group('deurenbergBodyFatPct', () {
    test('matches the formula for a man and a woman', () {
      // 1.20·25 + 0.23·40 − 10.8 − 5.4 = 23.0
      expect(deurenbergBodyFatPct(bmi: 25, age: 40, sex: Sex.male), closeTo(23.0, 1e-9));
      // 1.20·25 + 0.23·40 − 5.4 = 33.8
      expect(deurenbergBodyFatPct(bmi: 25, age: 40, sex: Sex.female), closeTo(33.8, 1e-9));
    });

    test('is clamped to 5–60%', () {
      expect(deurenbergBodyFatPct(bmi: 14, age: 18, sex: Sex.male), 5);
      expect(deurenbergBodyFatPct(bmi: 60, age: 90, sex: Sex.female), 60);
    });
  });

  group('fatMassKg', () {
    test('uses a known body fat % as given', () {
      expect(
        fatMassKg(weightKg: 80, heightCm: 180, age: 30, sex: Sex.male, bodyFatPct: 15),
        closeTo(12, 1e-9),
      );
    });

    test('estimates body fat with Deurenberg when it is unknown', () {
      // BMI 80/1.8² = 24.69; bf = 1.2·24.69 + 0.23·30 − 10.8 − 5.4 = 20.33%
      final fm = fatMassKg(weightKg: 80, heightCm: 180, age: 30, sex: Sex.male);
      final expectedPct = 1.2 * (80 / (1.8 * 1.8)) + 0.23 * 30 - 10.8 - 5.4;
      expect(fm, closeTo(80 * expectedPct / 100, 1e-9));
    });
  });

  group('energyDensity', () {
    test('is about 6,300 cals/kg at 15 kg of fat mass', () {
      expect(energyDensity(15), closeTo(6318, 5));
    });

    test('is about 7,900 cals/kg at 40 kg of fat mass', () {
      expect(energyDensity(40), closeTo(7866, 5));
    });

    test('rises with fat mass and stays between the lean and fat values', () {
      var previous = energyDensity(0);
      expect(previous, closeTo(1816, 1e-9));
      for (var fm = 5.0; fm <= 150; fm += 5) {
        final ed = energyDensity(fm);
        expect(ed, greaterThan(previous));
        expect(ed, lessThan(9440));
        previous = ed;
      }
    });
  });
}
