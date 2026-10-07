import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/day_status.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/estimate_rows.dart';

void main() {
  EnergyEstimate row(
    DateTime day, {
    double tdee = 2412.4,
    double sd = 180.26,
    EnergyState state = EnergyState.estimated,
    bool updated = true,
  }) =>
      EnergyEstimate(
        day: day,
        tdee: tdee,
        tdeeSd: sd,
        state: state,
        completeDays: 9,
        weighIns: 12,
        updated: updated,
        trendWeightKg: 79.4567,
        slopeKgPerDay: -0.071234,
        avgIntake: 1987.6,
        lastUpdateDay: updated ? day : DateTime(2026, 9, 1),
        observedTdee: updated ? 2501.2 : null,
        energyDensity: updated ? 7012.5 : null,
      );

  group('dayKey / parseDay', () {
    test('round-trips a calendar day', () {
      expect(dayKey(DateTime(2026, 3, 5, 23, 59)), '2026-03-05');
      expect(parseDay('2026-03-05'), DateTime(2026, 3, 5));
      expect(parseDay('nonsense'), isNull);
    });
  });

  group('foodDaysFrom', () {
    test('a day with entries keeps its cals; a status alone is a FoodDay too', () {
      final food = foodDaysFrom(
        calsByDay: {DateTime(2026, 9, 2, 13): 1850, DateTime(2026, 9, 3): 0},
        statuses: {
          DateTime(2026, 9, 3): ExplicitDayStatus.complete,
          DateTime(2026, 9, 4): ExplicitDayStatus.fasting,
        },
      );
      expect(food.keys, unorderedEquals([
        DateTime(2026, 9, 2),
        DateTime(2026, 9, 3),
        DateTime(2026, 9, 4),
      ]));
      expect(food[DateTime(2026, 9, 2)]!.loggedCals, 1850);
      expect(food[DateTime(2026, 9, 2)]!.hasEntries, isTrue);
      expect(food[DateTime(2026, 9, 2)]!.explicit, isNull);
      // Entries that add up to 0 cals still count as entries.
      expect(food[DateTime(2026, 9, 3)]!.hasEntries, isTrue);
      expect(food[DateTime(2026, 9, 3)]!.explicit, ExplicitDayStatus.complete);
      expect(food[DateTime(2026, 9, 4)]!.hasEntries, isFalse);
      expect(food[DateTime(2026, 9, 4)]!.explicit, ExplicitDayStatus.fasting);
    });
  });

  group('cache json', () {
    test('round-trips every field at full precision', () {
      final r = row(DateTime(2026, 9, 20));
      final back = estimateFromCache(r.toCacheJson())!;
      expect(back.day, r.day);
      expect(back.tdee, r.tdee);
      expect(back.tdeeSd, r.tdeeSd);
      expect(back.state, r.state);
      expect(back.trendWeightKg, r.trendWeightKg);
      expect(back.slopeKgPerDay, r.slopeKgPerDay);
      expect(back.avgIntake, r.avgIntake);
      expect(back.completeDays, r.completeDays);
      expect(back.weighIns, r.weighIns);
      expect(back.updated, isTrue);
      expect(back.lastUpdateDay, r.lastUpdateDay);
      expect(back.observedTdee, r.observedTdee);
      expect(back.energyDensity, r.energyDensity);
      expect(back.algoVersion, algoVersion);
    });

    test('nulls survive and junk is rejected', () {
      final r = EnergyEstimate(
        day: DateTime(2026, 9, 1),
        tdee: 2500,
        tdeeSd: 300,
        state: EnergyState.learning,
        completeDays: 0,
        weighIns: 0,
        updated: false,
      );
      final back = estimateFromCache(r.toCacheJson())!;
      expect(back.trendWeightKg, isNull);
      expect(back.lastUpdateDay, isNull);
      expect(back.avgIntake, isNull);
      expect(estimateFromCache({'day': 'x'}), isNull);
      expect(estimateFromCache('not a map'), isNull);
    });
  });

  group('remote row', () {
    test('rounds to the column types', () {
      final r = row(DateTime(2026, 9, 20)).toRemoteRow('u1');
      expect(r, {
        'user_id': 'u1',
        'day': '2026-09-20',
        'tdee': 2412,
        'tdee_sd': 180,
        'state': 'estimated',
        'trend_weight_kg': 79.46,
        'slope_kg_per_day': -0.0712,
        'avg_intake': 1988,
        'complete_days': 9,
        'weigh_ins': 12,
        'algo_version': algoVersion,
      });
    });

    test('reads a cloud row back (without the local-only fields)', () {
      final back = estimateFromRemote({
        'day': '2026-09-20',
        'tdee': 2412,
        'tdee_sd': '180',
        'state': 'confident',
        'trend_weight_kg': '79.46',
        'slope_kg_per_day': null,
        'avg_intake': 1988,
        'complete_days': 9,
        'weigh_ins': 12,
        'algo_version': 1,
      })!;
      expect(back.day, DateTime(2026, 9, 20));
      expect(back.tdee, 2412);
      expect(back.tdeeSd, 180);
      expect(back.state, EnergyState.confident);
      expect(back.trendWeightKg, 79.46);
      expect(back.slopeKgPerDay, isNull);
      expect(back.updated, isFalse);
      expect(back.lastUpdateDay, isNull);
    });
  });

  group('rowsToUpload', () {
    final d = DateTime(2026, 9, 20);

    test('new days and days whose stored values changed', () {
      final cached = {
        d: row(d),
        d.add(const Duration(days: 1)): row(d.add(const Duration(days: 1))),
      };
      final fresh = [
        row(d, tdee: 2412.3), // rounds the same: nothing to send
        row(DateTime(2026, 9, 21), tdee: 2450), // changed
        row(DateTime(2026, 9, 22)), // new
      ];
      expect(rowsToUpload(fresh, cached).map((r) => r.day),
          [DateTime(2026, 9, 21), DateTime(2026, 9, 22)]);
    });

    test('a re-run of the same rows sends nothing', () {
      final rows = [row(d), row(DateTime(2026, 9, 21))];
      expect(rowsToUpload(rows, {for (final r in rows) r.day: r}), isEmpty);
    });
  });

  group('defaultLearningStart', () {
    final today = DateTime(2026, 10, 7, 9);

    test('the first logged day, so history counts', () {
      expect(
          defaultLearningStart(
              today: today,
              dataDays: [DateTime(2026, 9, 12), DateTime(2026, 9, 7, 8)]),
          DateTime(2026, 9, 7));
    });

    test('today with no data', () {
      expect(defaultLearningStart(today: today, dataDays: const []),
          DateTime(2026, 10, 7));
    });

    test('never further back than the cache keeps', () {
      expect(
          defaultLearningStart(today: today, dataDays: [DateTime(2024, 1, 1)]),
          DateTime(2026, 10, 7 - (kEstimateCacheDays - 1)));
    });

    test('ignores future days', () {
      expect(
          defaultLearningStart(today: today, dataDays: [DateTime(2026, 12, 1)]),
          DateTime(2026, 10, 7));
    });
  });

  group('keepRecent', () {
    test('keeps the last kEstimateCacheDays days up to today', () {
      final today = DateTime(2026, 10, 7);
      final old = DateTime(2026, 10, 7 - kEstimateCacheDays);
      final edge = DateTime(2026, 10, 7 - (kEstimateCacheDays - 1));
      final kept = keepRecent({old: row(old), edge: row(edge)}, today: today);
      expect(kept.keys, [edge]);
    });
  });
}
