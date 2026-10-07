import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';

import 'personas.dart';

/// Reviewed snapshot of onboarding targets for the reference personas
/// (ticket 02). A change here is a change to what new users are told to eat:
/// review the new numbers before updating them.
const _snapshot = {
  'small lean woman, maintaining': [1180, 1623, 1623, 80, 225, 45],
  'small obese woman, losing': [1533, 1839, 1339, 120, 132, 37],
  'tall lean man, gaining': [1803, 3109, 3409, 115, 524, 95],
  'large obese man, losing': [2561, 3522, 2772, 171, 349, 77],
  'woman with a scanned body fat, losing': [1404, 2176, 1876, 124, 228, 52],
  'lean man with a scanned body fat, maintaining': [1828, 2833, 2833, 141, 390, 79],
};

void main() {
  test('every persona has a snapshot', () {
    expect(personas.map((p) => p.name).toSet(), _snapshot.keys.toSet());
  });

  for (final p in personas) {
    group(p.name, () {
      final r = p.onboardingResults();
      int n(String key) => r[key] as int;

      test('matches the reviewed targets', () {
        expect(
          [n('bmr'), n('tdee'), n('target_calories'), n('protein_g'), n('carb_g'), n('fat_g')],
          _snapshot[p.name],
        );
      });

      test('targets are sane', () {
        final cals = n('target_calories');
        expect(n('protein_g') * 4 + n('carb_g') * 4 + n('fat_g') * 9, closeTo(cals, 5));
        expect(cals, inInclusiveRange(1200, 4000));
        // Protein between 1.2 and 2.6 g per kg of body weight at most, and never
        // more than 2.6 g/kg of the BMI-25 weight for the height.
        final bmi25Weight = 25 * (p.heightCm / 100) * (p.heightCm / 100);
        expect(n('protein_g'), lessThanOrEqualTo(2.6 * bmi25Weight + 1));
        expect(n('protein_g') / p.weightKg, inInclusiveRange(1.0, 2.6));
        // Fat at least 20% of cals.
        expect(n('fat_g') * 9, greaterThanOrEqualTo(0.2 * cals - 9));
        expect(n('carb_g'), greaterThan(0));
        // Losing and gaining move weight at a believable pace.
        final weekly = (r['weekly_weight_change'] as num).toDouble();
        if (p.goal == MacroCalculatorService.GOAL_MAINTAIN) {
          expect(weekly, 0);
        } else {
          expect(weekly.abs() / p.weightKg * 100, inInclusiveRange(0.1, 1.0));
        }
      });
    });
  }
}
