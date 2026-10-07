import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/day_status.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/trend_weight.dart';

void main() {
  final start = DateTime(2026, 9, 1);
  DateTime day(int n) => DateTime(start.year, start.month, start.day + n);

  const body = BodyProfile(sex: Sex.male, heightCm: 180, age: 30);

  /// Logs [cals] on each of [days].
  Map<DateTime, FoodDay> eat(Iterable<int> days, double cals) =>
      {for (final d in days) day(d): FoodDay(loggedCals: cals)};

  /// Daily weigh-ins on [days], [w0] on day 0 then [perDay] kg a day.
  List<WeightReading> weigh(Iterable<int> days,
          {double w0 = 80, double perDay = -0.1}) =>
      [for (final d in days) WeightReading(day(d), w0 + perDay * d)];

  EstimatorInputs inputs({
    Map<DateTime, FoodDay> food = const {},
    List<WeightReading> weights = const [],
    double formulaTdee = 2500,
    List<DateTime> phaseStarts = const [],
  }) =>
      EstimatorInputs(
        learningStartedOn: day(0),
        formulaTdee: formulaTdee,
        body: body,
        food: food,
        weights: weights,
        phaseStarts: phaseStarts,
      );

  List<EnergyEstimate> run(EstimatorInputs i, int throughDay) =>
      EnergyEstimator(i).replay(through: day(throughDay)).estimates;

  int? firstUpdate(List<EnergyEstimate> rows) {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].updated) return i;
    }
    return null;
  }

  final everyDay = List.generate(60, (i) => i);

  group('initialise and predict', () {
    test('starts at the formula TDEE with the prior variance, learning', () {
      final s = EstimatorState.initial(2400);
      expect(s.tdee, 2400);
      expect(s.variance, kPriorSd * kPriorSd);
      expect(s.lastUpdateDay, isNull);
    });

    test('with no data, each day only adds process variance', () {
      final rows = run(inputs(), 9);
      expect(rows, hasLength(10));
      expect(rows.first.day, day(0));
      expect(rows.last.day, day(9));
      for (var i = 0; i < rows.length; i++) {
        expect(rows[i].tdee, 2500);
        expect(rows[i].updated, isFalse);
        expect(rows[i].tdeeSd,
            closeTo(math.sqrt(kPriorSd * kPriorSd + (i + 1) * 225), 1e-9));
        expect(rows[i].algoVersion, algoVersion);
      }
    });

    test('replays nothing before the learning start', () {
      final rows = EnergyEstimator(inputs()).replay(through: day(-1)).estimates;
      expect(rows, isEmpty);
    });
  });

  group('window and gate', () {
    test('first update needs the settle days, 7 complete days and 4 weigh-ins '
        'spanning 7 days', () {
      // Window starts on day kSwitchSettleDays (4); 7 complete days end day 10.
      final rows =
          run(inputs(food: eat(everyDay, 2000), weights: weigh(everyDay)), 20);
      expect(firstUpdate(rows), kSwitchSettleDays + kMinCompleteDays - 1);
      expect(rows[9].completeDays, 6);
      expect(rows[10].completeDays, 7);
    });

    // Settle-day weigh-ins still feed the trend (and so the energy density),
    // so only the food differs here.
    test('days in the settle period never reach the observation', () {
      final clean =
          run(inputs(food: eat(everyDay, 2000), weights: weigh(everyDay)), 15);
      final noisySettle = run(
          inputs(
            food: {...eat(everyDay, 2000), ...eat([0, 1, 2, 3], 9000)},
            weights: weigh(everyDay),
          ),
          15);
      for (var i = 10; i <= 15; i++) {
        expect(noisySettle[i].tdee, closeTo(clean[i].tdee, 1e-9));
      }
    });

    test('the window covers at most kWindowDays days', () {
      final rows = run(
          inputs(food: eat(everyDay, 2000), weights: weigh(everyDay)), 40);
      expect(rows[40].completeDays, kWindowDays);
      expect(rows[40].weighIns, kWindowDays);
    });

    test('a phase start restarts the settle period', () {
      final rows = run(
          inputs(
            food: eat(everyDay, 2000),
            weights: weigh(everyDay),
            phaseStarts: [day(30)],
          ),
          45);
      // Window restarts on day 34: 7 complete days again by day 40.
      expect(rows[39].updated, isFalse);
      expect(rows[39].completeDays, 6);
      expect(rows[40].updated, isTrue);
      expect(rows[29].completeDays, 21);
      expect(rows[30].completeDays, 0); // window starts on day 34
    });

    test('a phase start before the learning start is ignored', () {
      final a = run(
          inputs(food: eat(everyDay, 2000), weights: weigh(everyDay)), 15);
      final b = run(
          inputs(
            food: eat(everyDay, 2000),
            weights: weigh(everyDay),
            phaseStarts: [day(-10)],
          ),
          15);
      expect(firstUpdate(b), firstUpdate(a));
    });

    test('6 complete days fail the gate', () {
      final rows = run(
          inputs(
              food: eat([4, 5, 6, 7, 8, 9], 2000), weights: weigh(everyDay)),
          20);
      expect(firstUpdate(rows), isNull);
    });

    test('3 weigh-ins fail the gate', () {
      final rows = run(
          inputs(food: eat(everyDay, 2000), weights: weigh([4, 8, 12])), 20);
      expect(firstUpdate(rows), isNull);
    });

    test('4 weigh-ins spanning under 7 days fail the gate', () {
      final rows = run(
          inputs(food: eat(everyDay, 2000), weights: weigh([4, 5, 6, 9])), 20);
      expect(firstUpdate(rows), isNull);
    });

    test('4 weigh-ins spanning 7 days pass the gate', () {
      final rows = run(
          inputs(food: eat(everyDay, 2000), weights: weigh([4, 5, 6, 10])), 10);
      expect(rows[10].updated, isTrue);
      expect(rows[10].weighIns, 4);
    });

    test('ignored weigh-ins do not count', () {
      // Day 10 is 10% over the trend: ignored, leaving 3 weigh-ins.
      final rows = run(
          inputs(
            food: eat(everyDay, 2000),
            weights: [
              ...weigh([4, 6, 8]),
              WeightReading(day(10), 88),
            ],
          ),
          10);
      expect(rows[10].weighIns, 3);
      expect(rows[10].updated, isFalse);
    });
  });

  group('observation', () {
    test('intake mean minus OLS slope times energy density', () {
      final rows = run(
          inputs(food: eat(everyDay, 2000), weights: weigh(everyDay)), 10);
      final r = rows[10];
      expect(r.avgIntake, closeTo(2000, 1e-9));
      expect(r.slopeKgPerDay, closeTo(-0.1, 1e-9));
      final trend = TrendSeries.compute(weigh(List.generate(11, (i) => i)))
          .trendOn(day(10))!;
      expect(r.trendWeightKg, closeTo(trend, 1e-9));
      final ed = body.energyDensityAt(trend);
      expect(r.energyDensity, closeTo(ed, 1e-9));
      expect(r.observedTdee, closeTo(2000 + 0.1 * ed, 1e-6));
    });

    test('uses raw readings for the slope, not the trend', () {
      // A trend lags a linear fall; the OLS on raw readings recovers it.
      final rows = run(
          inputs(
              food: eat(everyDay, 2000),
              weights: weigh(everyDay, perDay: -0.2)),
          10);
      expect(rows[10].slopeKgPerDay, closeTo(-0.2, 1e-9));
    });

    test('fasting counts as 0 cals; partial and untracked days are left out',
        () {
      final food = {
        ...eat(everyDay, 2000),
        day(5): const FoodDay(loggedCals: 1800, explicit: ExplicitDayStatus.fasting),
        day(6): const FoodDay(loggedCals: 2600, explicit: ExplicitDayStatus.partial),
        day(7): const FoodDay(loggedCals: 900), // inferred partial (< 0.5 × 2500)
      }..remove(day(8)); // untracked
      final rows = run(inputs(food: food, weights: weigh(everyDay)), 13);
      // Days 4..13: 10 days, minus 6, 7, 8 → 7 counted, one of them 0.
      expect(rows[13].completeDays, 7);
      expect(rows[13].avgIntake, closeTo(2000 * 6 / 7, 1e-9));
      expect(rows[12].updated, isFalse);
      expect(rows[13].updated, isTrue);
    });

    test('a day with entries but no cals is untracked only if it has none',
        () {
      // hasEntries with 0 cals is an inferred partial, not untracked: both
      // are left out, so the count is what matters.
      final food = {
        ...eat(everyDay, 2000),
        day(5): const FoodDay(loggedCals: 0, hasEntries: true),
      };
      final rows = run(inputs(food: food, weights: weigh(everyDay)), 11);
      expect(rows[11].completeDays, 7);
    });

    test('the partial threshold uses the estimate as of that day', () {
      // Formula 4000: 1900 logged is under half of it, so partial while the
      // estimate is still 4000.
      final rows = run(
          inputs(
              food: eat(everyDay, 1900),
              weights: weigh(everyDay, perDay: 0),
              formulaTdee: 4000),
          12);
      expect(rows[12].completeDays, 0);
    });

    test('observation variance follows the spec formula', () {
      final o = observe(
        avgIntake: 2100,
        intakeSd: 300,
        countedDays: 9,
        slopeKgPerDay: -0.05,
        slopeSe: 0.02,
        energyDensity: 7000,
      );
      expect(o.tdee, closeTo(2100 + 0.05 * 7000, 1e-9));
      expect(
          o.variance,
          closeTo(
              kOverlapInflation *
                  (math.pow(0.02 * 7000, 2) +
                      300 * 300 / 9 +
                      kIntakeBiasSd * kIntakeBiasSd),
              1e-6));
    });
  });

  group('OLS', () {
    test('slope and standard error of a known fit', () {
      // y = 2 − 0.5x with residuals +0.1, −0.1, −0.1, +0.1.
      final fit = olsFit(const [0, 1, 2, 3], const [2.1, 1.4, 0.9, 0.6])!;
      expect(fit.slope, closeTo(-0.5, 1e-9));
      // SSR = 0.04, s² = 0.02, Sxx = 5 → SE = √0.004.
      expect(fit.slopeSe, closeTo(math.sqrt(0.004), 1e-9));
    });

    test('a perfect line has zero standard error', () {
      final fit = olsFit(const [0, 2, 5], const [80, 79, 77.5])!;
      expect(fit.slope, closeTo(-0.5, 1e-12));
      expect(fit.slopeSe, closeTo(0, 1e-9));
    });

    test('needs 3 points and some spread in x', () {
      expect(olsFit(const [0, 1], const [1, 2]), isNull);
      expect(olsFit(const [3, 3, 3], const [1, 2, 3]), isNull);
    });
  });

  group('update', () {
    test('Kalman gain moves the estimate towards the observation', () {
      final s = kalmanUpdate(
        tdee: 2500,
        variance: 10000,
        observation: const Observation(tdee: 2540, variance: 30000),
      );
      expect(s.gain, closeTo(0.25, 1e-12));
      expect(s.tdee, closeTo(2510, 1e-9));
      expect(s.variance, closeTo(7500, 1e-9));
    });

    test('a step is clamped to kMaxDailyTdeeStep either way', () {
      final up = kalmanUpdate(
        tdee: 2500,
        variance: 90000,
        observation: const Observation(tdee: 3500, variance: 10000),
      );
      expect(up.tdee, 2500 + kMaxDailyTdeeStep);
      expect(up.variance, closeTo(0.1 * 90000, 1e-6));
      final down = kalmanUpdate(
        tdee: 2500,
        variance: 90000,
        observation: const Observation(tdee: 1500, variance: 10000),
      );
      expect(down.tdee, 2500 - kMaxDailyTdeeStep);
    });

    test('no day in a replay moves more than kMaxDailyTdeeStep', () {
      // Formula far too high: the estimate walks down 50 a day at most.
      final rows = run(
          inputs(
              food: eat(everyDay, 2000),
              weights: weigh(everyDay, perDay: 0),
              formulaTdee: 3400),
          50);
      var prev = 3400.0;
      for (final r in rows) {
        expect((r.tdee - prev).abs(), lessThanOrEqualTo(kMaxDailyTdeeStep + 1e-9));
        prev = r.tdee;
      }
      expect(rows[10].tdee, 3400 - kMaxDailyTdeeStep);
      expect(rows.last.tdee, lessThan(2300));
    });
  });

  group('state', () {
    test('learning until the first update, then estimated', () {
      final rows = run(
          inputs(food: eat(everyDay, 2000), weights: weigh(everyDay)), 11);
      expect(rows[9].state, EnergyState.learning);
      expect(rows[10].state, isNot(EnergyState.learning));
    });

    test('confident once the sd is at most kConfidentSd', () {
      expect(stateFor(paused: false, everUpdated: true, variance: 200 * 200),
          EnergyState.confident);
      expect(
          stateFor(paused: false, everUpdated: true, variance: 200 * 200 + 1),
          EnergyState.estimated);
      expect(stateFor(paused: false, everUpdated: false, variance: 100),
          EnergyState.learning);
      expect(stateFor(paused: true, everUpdated: true, variance: 100),
          EnergyState.paused);
    });

    test('confident from the first day the sd is at most kConfidentSd', () {
      final rows = run(
          inputs(food: eat(everyDay, 2000), weights: weigh(everyDay)), 59);
      final states = rows.map((r) => r.state).toSet();
      expect(states, contains(EnergyState.learning));
      expect(states, contains(EnergyState.confident));
      final firstConfident =
          rows.indexWhere((r) => r.state == EnergyState.confident);
      expect(rows[firstConfident].tdeeSd, lessThanOrEqualTo(kConfidentSd));
      expect(rows[firstConfident - 1].tdeeSd, greaterThan(kConfidentSd));
    });

    test('paused after kPausedAfterDays with no complete days', () {
      final rows = run(
          inputs(
              food: eat(List.generate(30, (i) => i), 2000),
              weights: weigh(everyDay)),
          45);
      expect(rows[35].state, isNot(EnergyState.paused)); // day 29 in view
      expect(rows[36].state, EnergyState.paused);
      expect(rows[36].lastUpdateDay, isNotNull);
    });

    test('paused after kPausedAfterDays with no weigh-ins', () {
      final rows = run(
          inputs(
              food: eat(everyDay, 2000),
              weights: weigh(List.generate(30, (i) => i))),
          45);
      expect(rows[35].state, isNot(EnergyState.paused));
      expect(rows[36].state, EnergyState.paused);
    });

    test('an ignored weigh-in still counts as weighing in for paused', () {
      final rows = run(
          inputs(
            food: eat(everyDay, 2000),
            weights: [
              ...weigh(List.generate(30, (i) => i)),
              WeightReading(day(33), 90),
            ],
          ),
          37);
      expect(rows[36].state, isNot(EnergyState.paused));
    });

    test('a new user with no data is learning, not paused', () {
      final rows = run(inputs(), 20);
      expect(rows.take(kPausedAfterDays - 1).map((r) => r.state),
          everyElement(EnergyState.learning));
    });

    test('a user who logs nothing for their first week is paused', () {
      final rows = run(inputs(), 20);
      expect(rows[kPausedAfterDays - 1].state, EnergyState.paused);
    });
  });

  group('replay', () {
    test('resuming from a stored day gives the same rows as a full replay',
        () {
      final rng = math.Random(7);
      final food = {
        for (final d in everyDay)
          if (rng.nextDouble() > 0.2)
            day(d): FoodDay(loggedCals: 1900 + rng.nextDouble() * 400),
      };
      final weights = [
        for (final d in everyDay)
          WeightReading(day(d), 85 - 0.07 * d + rng.nextDouble() - 0.5),
      ];
      final i = inputs(food: food, weights: weights, formulaTdee: 2700);
      final full = EnergyEstimator(i).replay(through: day(50));

      final first = EnergyEstimator(i).replay(through: day(30));
      final resumed = EnergyEstimator(i).replay(
        through: day(50),
        from: first.state,
        tdeeByDay: {for (final r in first.estimates) r.day: r.tdee},
      );
      expect(resumed.estimates.first.day, day(31));
      for (var k = 0; k < resumed.estimates.length; k++) {
        final a = full.estimates[31 + k];
        final b = resumed.estimates[k];
        expect(b.day, a.day);
        expect(b.tdee, closeTo(a.tdee, 1e-9));
        expect(b.tdeeSd, closeTo(a.tdeeSd, 1e-9));
        expect(b.state, a.state);
      }
      expect(resumed.state.tdee, closeTo(full.state.tdee, 1e-9));
    });

    test('a future reading or log does not change a past day', () {
      final base = inputs(food: eat(everyDay, 2000), weights: weigh(everyDay));
      final later = inputs(
        food: {...eat(everyDay, 2000), day(25): const FoodDay(loggedCals: 5000)},
        weights: [...weigh(everyDay), WeightReading(day(25), 70)],
      );
      final a = run(base, 24);
      final b = run(later, 24);
      for (var k = 0; k < a.length; k++) {
        expect(b[k].tdee, a[k].tdee);
      }
    });

    test('rows carry the window stats even when the gate fails', () {
      final rows = run(
          inputs(food: eat(everyDay, 2000), weights: weigh(everyDay)), 8);
      expect(rows[8].completeDays, 5);
      expect(rows[8].weighIns, 5);
      expect(rows[8].updated, isFalse);
    });
  });
}
