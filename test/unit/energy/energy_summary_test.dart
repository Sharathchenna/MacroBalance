import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/day_status.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/energy_summary.dart';

DateTime day(int n) => DateTime(2026, 9, 7 + n);

EnergyEstimate row(
  int n, {
  double tdee = 2400,
  double sd = 150,
  EnergyState state = EnergyState.confident,
  bool updated = true,
  double? avgIntake = 2140,
  double? slope = -0.3 / 7,
  double? ed = 7230,
  int completeDays = 12,
  int weighIns = 15,
  DateTime? lastUpdateDay,
}) =>
    EnergyEstimate(
      day: day(n),
      tdee: tdee,
      tdeeSd: sd,
      state: state,
      completeDays: completeDays,
      weighIns: weighIns,
      updated: updated,
      avgIntake: avgIntake,
      slopeKgPerDay: slope,
      energyDensity: updated ? ed : null,
      observedTdee: updated && avgIntake != null && slope != null && ed != null
          ? avgIntake - slope * ed
          : null,
      lastUpdateDay: lastUpdateDay ?? (updated ? day(n) : null),
    );

void main() {
  group('roundToTen', () {
    test('rounds the ± to the nearest 10', () {
      expect(roundToTen(88), 90);
      expect(roundToTen(84.9), 80);
      expect(roundToTen(85), 90);
      expect(roundToTen(300), 300);
    });
  });

  group('EnergySummary', () {
    test('no rows: learning on the formula estimate', () {
      final s = EnergySummary.from(
          estimates: const [], learningStartedOn: day(0), formulaTdee: 2300);
      expect(s.state, EnergyState.learning);
      expect(s.tdee, 2300);
      expect(s.completeDays, 0);
      expect(s.weighIns, 0);
      expect(s.weekChange, isNull);
      expect(s.breakdown, isNull);
      expect(s.latest, isNull);
    });

    test('learning shows the window progress and no breakdown', () {
      final s = EnergySummary.from(
        estimates: [
          for (var n = 0; n < 6; n++)
            row(n,
                tdee: 2300,
                sd: 300,
                state: EnergyState.learning,
                updated: false,
                completeDays: n,
                weighIns: n ~/ 2),
        ],
        learningStartedOn: day(0),
        formulaTdee: 2300,
      );
      expect(s.state, EnergyState.learning);
      expect(s.completeDays, 5);
      expect(s.weighIns, 2);
      expect(s.breakdown, isNull);
      expect(s.weekChange, isNull);
    });

    test('week change vs 7 days earlier, hidden under 10', () {
      List<EnergyEstimate> rows(double then) => [
            for (var n = 0; n < 14; n++) row(n, tdee: n == 6 ? then : 2450),
          ];
      final up = EnergySummary.from(
          estimates: rows(2410), learningStartedOn: day(0), formulaTdee: 2300);
      expect(up.weekChange, 40);
      final down = EnergySummary.from(
          estimates: rows(2480), learningStartedOn: day(0), formulaTdee: 2300);
      expect(down.weekChange, -30);
      final flat = EnergySummary.from(
          estimates: rows(2441), learningStartedOn: day(0), formulaTdee: 2300);
      expect(flat.weekChange, isNull);
    });

    test('no week change without a row 7 days earlier', () {
      final s = EnergySummary.from(
          estimates: [row(5, tdee: 2300), row(6, tdee: 2400)],
          learningStartedOn: day(5),
          formulaTdee: 2300);
      expect(s.weekChange, isNull);
    });

    test('rows before the learning start are ignored (after a reset)', () {
      final s = EnergySummary.from(
        estimates: [for (var n = 0; n < 20; n++) row(n, tdee: 2600)],
        learningStartedOn: day(21),
        formulaTdee: 2300,
      );
      expect(s.state, EnergyState.learning);
      expect(s.tdee, 2300);
      expect(s.latest, isNull);
      expect(s.weekChange, isNull);
    });

    test('a week change never reaches back past a reset', () {
      final s = EnergySummary.from(
        estimates: [
          for (var n = 0; n < 10; n++) row(n, tdee: 2600),
          for (var n = 10; n < 20; n++) row(n, tdee: 2300),
        ],
        learningStartedOn: day(10),
        formulaTdee: 2300,
      );
      // day(19) − 7 = day(12): inside the new period, both 2,300.
      expect(s.weekChange, isNull);
      final early = EnergySummary.from(
        estimates: [
          for (var n = 0; n < 10; n++) row(n, tdee: 2600),
          for (var n = 10; n < 15; n++) row(n, tdee: 2300),
        ],
        learningStartedOn: day(10),
        formulaTdee: 2300,
      );
      expect(early.weekChange, isNull);
    });

    test('paused: last updated is the last day an observation was used', () {
      final s = EnergySummary.from(
        estimates: [
          for (var n = 0; n < 20; n++) row(n),
          for (var n = 20; n < 28; n++)
            row(n,
                state: n >= 26 ? EnergyState.paused : EnergyState.confident,
                updated: false,
                lastUpdateDay: day(19)),
        ],
        learningStartedOn: day(0),
        formulaTdee: 2300,
      );
      expect(s.state, EnergyState.paused);
      expect(s.lastUpdated, day(19));
    });

    test('paused falls back to the last updated row when lastUpdateDay is '
        'missing (a row pulled from the cloud)', () {
      final pulled = EnergyEstimate(
        day: day(25),
        tdee: 2400,
        tdeeSd: 150,
        state: EnergyState.paused,
        completeDays: 0,
        weighIns: 0,
        updated: false,
      );
      final s = EnergySummary.from(
        estimates: [for (var n = 0; n < 20; n++) row(n), pulled],
        learningStartedOn: day(0),
        formulaTdee: 2300,
      );
      expect(s.lastUpdated, day(19));
    });

    test('paused before any update has no last-updated day', () {
      final s = EnergySummary.from(
        estimates: [
          for (var n = 0; n < 9; n++)
            row(n,
                tdee: 2300,
                state: n >= 7 ? EnergyState.paused : EnergyState.learning,
                updated: false),
        ],
        learningStartedOn: day(0),
        formulaTdee: 2300,
      );
      expect(s.state, EnergyState.paused);
      expect(s.lastUpdated, isNull);
      expect(s.breakdown, isNull);
    });

    test('breakdown comes from the latest updated row', () {
      final s = EnergySummary.from(
        estimates: [
          for (var n = 0; n < 20; n++) row(n, avgIntake: 2000 + n.toDouble()),
          row(20, updated: false, avgIntake: 1500),
        ],
        learningStartedOn: day(0),
        formulaTdee: 2300,
      );
      expect(s.breakdown!.day, day(19));
      expect(s.breakdown!.avgIntake, 2019);
    });
  });

  group('Breakdown', () {
    test('adds up: intake + weight term = result', () {
      final b = Breakdown.of(row(0, avgIntake: 2140.4, slope: -0.3 / 7, ed: 7230))!;
      expect(b.avgIntake, 2140);
      expect(b.completeDays, 12);
      expect(b.trendKgPerWeek, closeTo(-0.3, 1e-9));
      // −slope·ED = 0.3/7 × 7230 = 309.9
      expect(b.weightTerm, 310);
      expect(b.result, 2450);
      expect(b.result, b.avgIntake + b.weightTerm);
    });

    test('gaining weight subtracts', () {
      final b = Breakdown.of(row(0, avgIntake: 2600, slope: 0.2 / 7, ed: 7000))!;
      expect(b.weightTerm, -200);
      expect(b.result, 2400);
    });

    test('null when the row has no observation', () {
      expect(Breakdown.of(row(0, updated: false)), isNull);
    });
  });

  group('qualityStrip', () {
    final through = day(20);

    test('21 days ending on the given day, classified like the estimator', () {
      final strip = qualityStrip(
        through: through,
        learningStartedOn: day(0),
        food: {
          day(0): const FoodDay(loggedCals: 2200),
          day(1): const FoodDay(loggedCals: 800), // under half of 2,300
          day(2): const FoodDay(
              loggedCals: 0, hasEntries: false, explicit: ExplicitDayStatus.fasting),
          day(3): const FoodDay(loggedCals: 900, explicit: ExplicitDayStatus.complete),
          day(4): const FoodDay(loggedCals: 2500, explicit: ExplicitDayStatus.partial),
          day(6): const FoodDay(loggedCals: 1100),
        },
        weighInDays: [day(0), day(4), DateTime(2026, 9, 11, 7, 30)],
        tdeeByDay: {day(5): 2000},
        formulaTdee: 2300,
      );
      expect(strip, hasLength(21));
      expect(strip.first.day, day(0));
      expect(strip.last.day, through);
      expect([for (final d in strip.take(7)) d.status], [
        DayStatus.complete,
        DayStatus.partial,
        DayStatus.fasting,
        DayStatus.complete,
        DayStatus.partial,
        DayStatus.untracked,
        // 1,100 ≥ half of the estimate entering the day (2,000).
        DayStatus.complete,
      ]);
      expect([for (final d in strip.take(5)) d.weighedIn],
          [true, false, false, false, true]);
    });

    test('days before the learning start are left out', () {
      final strip = qualityStrip(
        through: through,
        learningStartedOn: day(15),
        food: {day(3): const FoodDay(loggedCals: 2200)},
        weighInDays: [day(3)],
        tdeeByDay: const {},
        formulaTdee: 2300,
      );
      expect(strip[3].beforeLearning, isTrue);
      expect(strip[3].status, isNull);
      expect(strip[3].weighedIn, isFalse);
      expect(strip[15].beforeLearning, isFalse);
      expect(strip[15].status, DayStatus.untracked);
    });
  });

  group('qualityTip', () {
    List<QualityDay> strip({
      int weighIns = 10,
      int partial = 0,
      int untracked = 0,
      int beforeLearning = 0,
    }) {
      var p = partial, u = untracked, b = beforeLearning, w = weighIns;
      return [
        for (var n = 0; n < 21; n++)
          if (b-- > 0)
            QualityDay(day(n), null, weighedIn: false, beforeLearning: true)
          else
            QualityDay(
              day(n),
              p-- > 0
                  ? DayStatus.partial
                  : u-- > 0
                      ? DayStatus.untracked
                      : DayStatus.complete,
              weighedIn: w-- > 0,
            ),
      ];
    }

    test('fewer than 4 weigh-ins: weigh in', () {
      expect(qualityTip(strip(weighIns: 3)), QualityTip.weighIn);
      expect(qualityTip(strip(weighIns: 3, partial: 10)), QualityTip.weighIn);
    });

    test('over 30% partial or untracked: finish day', () {
      // 7 of 21 = 33%.
      expect(qualityTip(strip(partial: 4, untracked: 3)), QualityTip.finishDay);
      // 6 of 21 = 29%.
      expect(qualityTip(strip(partial: 3, untracked: 3)), isNull);
    });

    test('otherwise nothing', () {
      expect(qualityTip(strip()), isNull);
    });

    test('only days since the learning start count', () {
      // 3 untracked of 7 learning days = 43%.
      expect(qualityTip(strip(beforeLearning: 14, untracked: 3, weighIns: 4)),
          QualityTip.finishDay);
      // A reset today: no weigh-ins yet.
      expect(qualityTip(strip(beforeLearning: 21)), QualityTip.weighIn);
    });
  });
}
