import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/bmr.dart';
import 'package:macrotracker/services/energy/body_composition.dart';

void main() {
  group('mifflinStJeor', () {
    test('man: 10w + 6.25h − 5a + 5', () {
      // 800 + 1125 − 150 + 5
      expect(mifflinStJeor(sex: Sex.male, weightKg: 80, heightCm: 180, age: 30),
          closeTo(1780, 1e-9));
    });

    test('woman: 10w + 6.25h − 5a − 161', () {
      // 600 + 1031.25 − 175 − 161
      expect(mifflinStJeor(sex: Sex.female, weightKg: 60, heightCm: 165, age: 35),
          closeTo(1295.25, 1e-9));
    });
  });

  group('katchMcArdle', () {
    test('is 370 + 21.6 × lean mass', () {
      expect(katchMcArdle(60), closeTo(1666, 1e-9));
    });
  });

  group('basalMetabolicRate', () {
    test('is Mifflin alone when body fat is unknown', () {
      expect(basalMetabolicRate(sex: Sex.male, weightKg: 80, heightCm: 180, age: 30),
          closeTo(1780, 1e-9));
    });

    test('averages Mifflin and Katch–McArdle when body fat is known', () {
      // LBM = 80 × 0.85 = 68 → Katch = 370 + 21.6·68 = 1838.8; mean with 1780
      expect(
        basalMetabolicRate(
            sex: Sex.male, weightKg: 80, heightCm: 180, age: 30, bodyFatPct: 15),
        closeTo((1780 + 1838.8) / 2, 1e-9),
      );
    });
  });

  group('formulaTdee', () {
    test('multiplies BMR by the activity factor', () {
      const factors = [1.2, 1.375, 1.55, 1.725, 1.9];
      for (var level = 1; level <= 5; level++) {
        expect(
          formulaTdee(
              sex: Sex.male, weightKg: 80, heightCm: 180, age: 30, activityLevel: level),
          closeTo(1780 * factors[level - 1], 1e-9),
          reason: 'level $level',
        );
      }
    });

    test('an out-of-range activity level is clamped', () {
      expect(activityFactor(0), 1.2);
      expect(activityFactor(9), 1.9);
    });
  });
}
