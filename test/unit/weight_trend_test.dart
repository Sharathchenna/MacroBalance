import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/utils/nutrition_stats.dart';
import 'package:macrotracker/utils/weight_trend.dart';
import 'package:macrotracker/widgets/weight_chart.dart' show WeightChart, dateTicks;

void main() {
  final today = DateTime(2026, 10, 6);
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n, 8);

  group('parseWeightHistory', () {
    test('sorts, keeps the last weigh-in of a day and skips bad rows', () {
      final entries = parseWeightHistory([
        {'date': daysAgo(1).toIso8601String(), 'weight': 80},
        {'date': daysAgo(3).toIso8601String(), 'weight': 81.5},
        {'date': daysAgo(1).add(const Duration(hours: 2)).toIso8601String(), 'weight': 79.8},
        {'date': 'nope', 'weight': 70},
        {'date': daysAgo(2).toIso8601String(), 'weight': -1},
        'junk',
      ]);
      expect(entries.map((e) => e.kg), [81.5, 79.8]);
    });
  });

  group('weightTrend', () {
    test('starts at the first weigh-in and moves 10% a day', () {
      final trend = weightTrend([
        WeightEntry(daysAgo(2), 80),
        WeightEntry(daysAgo(1), 70),
      ]);
      expect(trend[0], 80);
      expect(trend[1], closeTo(79, 1e-9));
    });

    test('a week-long gap moves it about half way', () {
      final trend = weightTrend([
        WeightEntry(daysAgo(7), 80),
        WeightEntry(daysAgo(0), 78),
      ]);
      expect(trend[1], closeTo(80 - 2 * (1 - 0.4782969), 1e-6));
    });
  });

  group('weeklyRateKg', () {
    test('fits the slope per week', () {
      final entries = [
        for (var d = 28; d >= 0; d -= 2) WeightEntry(daysAgo(d), 80 - (28 - d) / 14),
      ];
      expect(weeklyRateKg(entries), closeTo(-0.5, 1e-9));
    });

    test('needs a week of weigh-ins', () {
      expect(weeklyRateKg([WeightEntry(daysAgo(3), 80), WeightEntry(daysAgo(0), 79)]),
          isNull);
      expect(weeklyRateKg([WeightEntry(daysAgo(0), 80)]), isNull);
    });
  });

  group('projectedGoalDate', () {
    test('projects when heading toward the goal', () {
      expect(
        projectedGoalDate(currentKg: 80, goalKg: 78, weeklyKg: -0.5, from: today),
        DateTime(2026, 11, 3),
      );
    });

    test('nothing when heading away, flat, or years out', () {
      expect(projectedGoalDate(currentKg: 80, goalKg: 75, weeklyKg: 0.3, from: today), isNull);
      expect(projectedGoalDate(currentKg: 80, goalKg: 75, weeklyKg: 0.01, from: today), isNull);
      expect(projectedGoalDate(currentKg: 80, goalKg: 60, weeklyKg: -0.1, from: today), isNull);
    });
  });

  group('niceTicks', () {
    test('round kg steps', () {
      expect(niceTicks(78.3, 82.1), [78, 80, 82, 84]);
    });

    test('round lbs steps from the same weights', () {
      final ticks = niceTicks(78.3 * lbsPerKg, 82.1 * lbsPerKg);
      expect(ticks, [170, 175, 180, 185]);
    });

    test('calorie axis from zero', () {
      expect(niceTicks(0, 2300), [0, 1000, 2000, 3000]);
    });
  });

  group('dateTicks', () {
    test('a week labels every day', () {
      expect(dateTicks(DateTime(2026, 9, 30), today).length, 7);
    });

    test('a month labels weekly, ending today', () {
      final ticks = dateTicks(DateTime(2026, 9, 6), today);
      expect(ticks.last.$1, today);
      expect(ticks.length, 5);
    });

    test('six months labels month starts', () {
      final ticks = dateTicks(DateTime(2026, 4, 6), today);
      expect(ticks.first.$1, DateTime(2026, 5, 1));
      expect(ticks.last.$1, DateTime(2026, 10, 1));
    });
  });

  group('NutritionSummary', () {
    const day = DayIntake(cals: 2000, protein: 150, carbs: 200, fat: 70);
    const low = DayIntake(cals: 1500, protein: 100, carbs: 150, fat: 50);

    test('averages logged, finished days only', () {
      final s = NutritionSummary.lastDays(7, {
        dayOf(daysAgo(6)): day,
        dayOf(daysAgo(3)): low,
        dayOf(today): const DayIntake(cals: 300, protein: 10, carbs: 40, fat: 5),
      }, today: today);
      expect(s.days.length, 7);
      expect(s.completeDays, 6);
      expect(s.loggedDays, 2);
      expect(s.avgCals, 1750);
      expect(s.daysOnTarget(2000), 1);
      expect(s.daysProteinHit(140), 1);
    });

    test('nothing logged gives no averages', () {
      final s = NutritionSummary.lastDays(7, {}, today: today);
      expect(s.avgCals, isNull);
      expect(s.loggedDays, 0);
    });
  });

  group('MaintenanceEstimate', () {
    Map<DateTime, DayIntake> eating(double cals, {int days = 28}) => {
          for (var i = 1; i <= days; i++)
            dayOf(daysAgo(i)): DayIntake(cals: cals, protein: 0, carbs: 0, fat: 0),
        };

    test('eating 2000 and losing 0.5 kg a week means 2550 maintenance', () {
      final weights = [
        for (var d = 28; d >= 0; d -= 7) WeightEntry(daysAgo(d), 80 - (28 - d) / 14),
      ];
      final m = MaintenanceEstimate.compute(
          intake: eating(2000), weights: weights, today: today);
      expect(m.cals, 2550);
      expect(m.weeklyKgAt(2000), closeTo(-0.5, 0.01));
    });

    test('waits for enough logs and weigh-ins', () {
      final weights = [WeightEntry(daysAgo(20), 80), WeightEntry(daysAgo(0), 79)];
      final fewLogs = MaintenanceEstimate.compute(
          intake: eating(2000, days: 10), weights: weights, today: today);
      expect(fewLogs.ready, isFalse);
      expect(fewLogs.loggedDays, 10);

      final closeWeighIns = MaintenanceEstimate.compute(
          intake: eating(2000),
          weights: [WeightEntry(daysAgo(5), 80), WeightEntry(daysAgo(0), 79)],
          today: today);
      expect(closeWeighIns.ready, isFalse);
      expect(closeWeighIns.weighInSpanDays, 5);
    });

    test('ignores implausible results', () {
      // Eating 800 while gaining a kilo a week: the logs are incomplete.
      final weights = [
        for (var d = 28; d >= 0; d -= 7) WeightEntry(daysAgo(d), 70 + (28 - d) / 7),
      ];
      final m = MaintenanceEstimate.compute(
          intake: eating(800), weights: weights, today: today);
      expect(m.ready, isFalse);
    });
  });

  group('recentForRate', () {
    test('keeps the last weigh-in before the window as an anchor', () {
      final entries = [
        WeightEntry(daysAgo(60), 72),
        WeightEntry(daysAgo(30), 71),
        WeightEntry(daysAgo(3), 69.1),
        WeightEntry(daysAgo(0), 69.5),
      ];
      final recent = recentForRate(entries, today);
      expect(recent.map((e) => e.kg), [71, 69.1, 69.5]);
      expect(weeklyRateKg(recent), isNotNull);
    });

    test('nothing recent, nothing to measure', () {
      expect(recentForRate([WeightEntry(daysAgo(60), 72)], today), isEmpty);
    });
  });

  group('WeightChart rules', () {
    test('the line follows the trend only for frequent weigh-ins', () {
      final daily = [for (var d = 20; d >= 0; d--) WeightEntry(daysAgo(d), 70)];
      final weekly = [for (var d = 70; d >= 0; d -= 7) WeightEntry(daysAgo(d), 70)];
      expect(WeightChart.showsTrend(daily), isTrue);
      expect(WeightChart.showsTrend(weekly), isFalse);
      expect(WeightChart.showsTrend(daily.sublist(0, 5)), isFalse);
    });

    test('the goal is drawn only when it is near the data', () {
      final entries = [WeightEntry(daysAgo(7), 62), WeightEntry(daysAgo(0), 60)];
      expect(WeightChart.showsGoal(entries, [62, 61], 66), isTrue);
      expect(WeightChart.showsGoal(entries, [62, 61], 55), isFalse);
      expect(WeightChart.showsGoal(entries, [62, 61], null), isFalse);
      expect(WeightChart.showsGoal(const [], const [], 60), isFalse);
    });
  });
}
