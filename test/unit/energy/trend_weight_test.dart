import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/energy/trend_weight.dart';

void main() {
  final start = DateTime(2026, 9, 1);
  DateTime day(int n) => DateTime(start.year, start.month, start.day + n);

  /// Daily readings from [weights], starting at day [from].
  List<WeightReading> daily(List<double> weights, {int from = 0}) => [
        for (var i = 0; i < weights.length; i++)
          WeightReading(day(from + i), weights[i]),
      ];

  group('EMA', () {
    test('empty input gives an empty series', () {
      final s = TrendSeries.compute(const []);
      expect(s.points, isEmpty);
      expect(s.latest, isNull);
      expect(s.trendOn(day(0)), isNull);
      expect(s.weeklyChange(), isNull);
    });

    test('the first reading seeds the trend', () {
      final s = TrendSeries.compute([WeightReading(day(0), 80)]);
      expect(s.points.single.trendKg, 80);
      expect(s.points.single.ignored, isFalse);
    });

    test('a next-day reading moves the trend by kTrendAlpha', () {
      final s = TrendSeries.compute(daily([80, 81]));
      expect(s.points[1].trendKg, closeTo(80 + kTrendAlpha * 1, 1e-9));
    });

    test('a gap uses alpha = 1 - (1 - kTrendAlpha)^days', () {
      final s = TrendSeries.compute(
          [WeightReading(day(0), 80), WeightReading(day(7), 81)]);
      final alpha = 1 - math.pow(1 - kTrendAlpha, 7);
      expect(alpha, closeTo(0.5217, 1e-4));
      expect(s.points[1].trendKg, closeTo(80 + alpha, 1e-9));
    });

    test('a gap at a steady weight leaves the trend where it was', () {
      final gappy = TrendSeries.compute(
          [WeightReading(day(0), 80), WeightReading(day(3), 80)]);
      expect(gappy.latest!.trendKg, closeTo(80, 1e-9));
    });

    test('time of day does not change the day count', () {
      final s = TrendSeries.compute([
        WeightReading(DateTime(2026, 9, 1, 23, 30), 80),
        WeightReading(DateTime(2026, 9, 2, 6, 0), 81),
      ]);
      expect(s.points[1].trendKg, closeTo(80.1, 1e-9));
    });

    test('readings are sorted and one per day is kept (the last given)', () {
      final s = TrendSeries.compute([
        WeightReading(day(1), 81),
        WeightReading(DateTime(2026, 9, 1, 8), 79),
        WeightReading(DateTime(2026, 9, 1, 20), 80),
      ]);
      expect(s.points.map((p) => p.weightKg), [80, 81]);
      expect(s.points.first.day, DateTime(2026, 9, 1));
    });

    test('a steady loss is followed with a lag, never ignored', () {
      // 1% of body weight a week, the fastest allowed pace.
      final weights = [for (var i = 0; i < 60; i++) 90 * (1 - 0.01 * i / 7)];
      final s = TrendSeries.compute(daily(weights));
      expect(s.points.where((p) => p.ignored), isEmpty);
      expect(s.latest!.trendKg, greaterThan(weights.last));
      expect(s.latest!.trendKg - weights.last, lessThan(1.5));
    });
  });

  group('outliers', () {
    test('a reading more than 3% from the trend is ignored', () {
      final s = TrendSeries.compute(daily([80, 80, 83, 80]));
      final spike = s.points[2];
      expect(spike.ignored, isTrue);
      expect(spike.trendKg, 80, reason: 'the trend is carried, not updated');
      expect(spike.offTrendKg, closeTo(3, 1e-9));
      expect(s.points[3].ignored, isFalse);
      expect(s.latest!.trendKg, closeTo(80, 1e-9));
    });

    test('exactly 3% is not an outlier', () {
      final s = TrendSeries.compute(daily([80, 82.4]));
      expect(s.points[1].ignored, isFalse);
    });

    test('low readings are ignored too', () {
      final s = TrendSeries.compute(daily([80, 77]));
      expect(s.points[1].ignored, isTrue);
      expect(s.points[1].offTrendKg, closeTo(-3, 1e-9));
    });

    test('two outliers in a row stay ignored when the next is normal', () {
      final s = TrendSeries.compute(daily([80, 83, 83, 80.2]));
      expect(s.points.map((p) => p.ignored), [false, true, true, false]);
      // Ignored days don't count as updates: alpha spans the 3 days since
      // the last reading the trend used.
      final alpha = 1 - math.pow(1 - kTrendAlpha, 3);
      expect(s.latest!.trendKg, closeTo(80 + alpha * 0.2, 1e-9));
    });

    test('outliers on opposite sides do not make a run', () {
      final s = TrendSeries.compute(daily([80, 83, 77, 83, 77]));
      expect(s.points.skip(1).every((p) => p.ignored), isTrue);
      expect(s.latest!.trendKg, 80);
    });

    test('a broken run starts again from zero', () {
      final s = TrendSeries.compute(daily([80, 83, 83, 80, 83, 83, 80]));
      expect(s.points.where((p) => p.ignored).length, 4);
    });
  });

  group('real level shift', () {
    test('three same-side outliers in a row are accepted and replayed', () {
      final s = TrendSeries.compute(daily([80, 80, 80, 76, 76, 76]));
      expect(s.points.every((p) => !p.ignored), isTrue);
      // Replayed as ordinary daily updates from the first of them.
      var t = 80.0;
      for (var i = 0; i < 3; i++) {
        t += kTrendAlpha * (76 - t);
      }
      expect(s.latest!.trendKg, closeTo(t, 1e-9));
      expect(s.points[3].trendKg, closeTo(80 - 0.4, 1e-9));
    });

    test('the trend then follows the new level without new ignored points',
        () {
      final s = TrendSeries.compute(
          daily([...List.filled(20, 80.0), ...List.filled(40, 75.0)]));
      expect(s.points.where((p) => p.ignored), isEmpty);
      expect(s.latest!.trendKg, closeTo(75, 0.1));
    });

    test('a spike back the other way after a shift is still ignored', () {
      final s = TrendSeries.compute(
          daily([...List.filled(10, 80.0), 76, 76, 76, 76, 82, 76]));
      expect(s.points[14].ignored, isTrue);
      expect(s.points[15].ignored, isFalse);
    });

    test('after a long gap, a real change is accepted on the third reading',
        () {
      final s = TrendSeries.compute([
        ...daily(List.filled(10, 80.0)),
        ...daily([75, 75.2, 74.8], from: 70),
      ]);
      expect(s.points.where((p) => p.ignored), isEmpty);
      // The 60-day gap makes alpha ~1, so the trend lands on the new level.
      expect(s.latest!.trendKg, closeTo(75, 0.1));
    });
  });

  group('trendOn (carried forward for display)', () {
    final s = TrendSeries.compute(
        [WeightReading(day(0), 80), WeightReading(day(5), 81)]);

    test('null before the first reading', () {
      expect(s.trendOn(day(-1)), isNull);
    });

    test('carries the last trend over days with no reading', () {
      expect(s.trendOn(day(0)), 80);
      expect(s.trendOn(day(3)), 80);
      expect(s.trendOn(day(5)), s.points[1].trendKg);
      expect(s.trendOn(day(30)), s.points[1].trendKg);
    });

    test('ignores the time of day', () {
      expect(s.trendOn(DateTime(2026, 9, 6, 7)), s.points[1].trendKg);
    });
  });

  group('weeklyChange', () {
    test('null until the readings span a week', () {
      final s = TrendSeries.compute(daily([80, 79.9, 79.8, 79.7, 79.6, 79.5]));
      expect(s.weeklyChange(), isNull);
    });

    test('trend now minus trend 7 days before the latest reading', () {
      final weights = [for (var i = 0; i < 30; i++) 80 - 0.05 * i];
      final s = TrendSeries.compute(daily(weights));
      final change = s.weeklyChange()!;
      final before = s.points[22].trendKg;
      expect(change.kg, closeTo(s.latest!.trendKg - before, 1e-9));
      expect(change.pct, closeTo(change.kg / before * 100, 1e-9));
      expect(change.kg, lessThan(0));
    });

    test('uses the carried trend when there was no reading 7 days back', () {
      final s = TrendSeries.compute([
        WeightReading(day(0), 80),
        WeightReading(day(2), 79.5),
        WeightReading(day(10), 79),
      ]);
      final change = s.weeklyChange()!;
      expect(change.kg, closeTo(s.latest!.trendKg - s.points[1].trendKg, 1e-9));
    });

    test('a level series has no change', () {
      final s = TrendSeries.compute(daily(List.filled(14, 70.0)));
      expect(s.weeklyChange()!.kg, closeTo(0, 1e-9));
      expect(s.weeklyChange()!.pct, closeTo(0, 1e-9));
    });
  });

  group('pace', () {
    test('goal pace is negative when losing, positive when gaining', () {
      expect(signedGoalPacePct(GoalKind.lose, 0.5), -0.5);
      expect(signedGoalPacePct(GoalKind.gain, 0.25), 0.25);
      expect(signedGoalPacePct(GoalKind.maintain, 0.5), 0);
    });

    test('on pace within kPaceTolerancePct either side', () {
      expect(kPaceTolerancePct, 0.15);
      expect(isOnPace(actualPctPerWeek: -0.5, goalPctPerWeek: -0.5), isTrue);
      expect(isOnPace(actualPctPerWeek: -0.35, goalPctPerWeek: -0.5), isTrue);
      expect(isOnPace(actualPctPerWeek: -0.65, goalPctPerWeek: -0.5), isTrue);
      expect(isOnPace(actualPctPerWeek: -0.34, goalPctPerWeek: -0.5), isFalse);
      expect(isOnPace(actualPctPerWeek: -0.66, goalPctPerWeek: -0.5), isFalse);
      expect(isOnPace(actualPctPerWeek: 0.2, goalPctPerWeek: 0), isFalse);
    });
  });
}
