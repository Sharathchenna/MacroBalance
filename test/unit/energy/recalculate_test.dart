import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/energy_summary.dart';
import 'package:macrotracker/services/energy/recalculate.dart';
import 'package:macrotracker/services/energy/trend_weight.dart';

void main() {
  final today = DateTime(2026, 10, 8, 9, 30);
  DateTime ago(int n) => DateTime(2026, 10, 8 - n);

  group('weightPrefill', () {
    test('is null without weigh-ins', () {
      expect(weightPrefill(const [], today: today), isNull);
    });

    test('is the trend at the latest weigh-in, not the scale reading', () {
      final readings = [
        for (var i = 20; i >= 0; i--) WeightReading(ago(i), i.isEven ? 80.0 : 81.0),
      ];
      final prefill = weightPrefill(readings, today: today)!;
      final trend = TrendSeries.compute(readings).latest!.trendKg;
      expect(prefill.kg, trend);
      expect(prefill.kg, isNot(80.0));
    });

    test('ignores an outlier the trend ignores', () {
      final prefill = weightPrefill([
        WeightReading(ago(3), 80),
        WeightReading(ago(2), 80),
        WeightReading(ago(1), 80),
        WeightReading(ago(0), 90),
      ], today: today)!;
      expect(prefill.kg, 80);
    });

    test('a single weigh-in is its own trend', () {
      expect(weightPrefill([WeightReading(ago(10), 72.4)], today: today)!.kg, 72.4);
    });

    test('is recent when the last weigh-in was today or in the 2 days before', () {
      for (final n in [0, 1, 2]) {
        expect(weightPrefill([WeightReading(ago(n), 80)], today: today)!.recent, isTrue,
            reason: '$n days ago');
      }
      for (final n in [3, 10]) {
        expect(weightPrefill([WeightReading(ago(n), 80)], today: today)!.recent, isFalse,
            reason: '$n days ago');
      }
    });

    test('readings in any order use the latest day', () {
      final prefill = weightPrefill([
        WeightReading(ago(0), 84),
        WeightReading(ago(30), 85),
      ], today: today)!;
      expect(prefill.recent, isTrue);
      expect(prefill.kg, lessThan(85));
    });

    test('recent holds across a daylight-saving change', () {
      // Oct 25 2026 is the EU switch: Oct 27 00:00 is 2 days less an hour on.
      expect(
          weightPrefill([WeightReading(DateTime(2026, 10, 25), 80)],
                  today: DateTime(2026, 10, 27, 0, 30))!
              .recent,
          isTrue);
    });
  });

  group('learnedTdee', () {
    EnergySummary summary(EnergyState state, double tdee) => EnergySummary(
        state: state, tdee: tdee, sd: 90, completeDays: 18, weighIns: 20);

    test('is the estimate when it is confident', () {
      expect(learnedTdee(summary(EnergyState.confident, 2451.6)), 2451.6);
    });

    test('is null while learning, estimated or paused', () {
      for (final state in [EnergyState.learning, EnergyState.estimated, EnergyState.paused]) {
        expect(learnedTdee(summary(state, 2400)), isNull, reason: state.code);
      }
    });

    test('only counts estimates since the learning start', () {
      final s = EnergySummary.from(
        estimates: [
          EnergyEstimate(
              day: ago(5), tdee: 2600, tdeeSd: 80, state: EnergyState.confident,
              completeDays: 20, weighIns: 20, updated: true),
        ],
        learningStartedOn: ago(2), // reset since
        formulaTdee: 2200,
      );
      expect(learnedTdee(s), isNull);
    });
  });
}
