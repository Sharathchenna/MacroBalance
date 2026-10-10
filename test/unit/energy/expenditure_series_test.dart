import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/expenditure_series.dart';

DateTime day(int n) => DateTime(2026, 9, 7 + n);

EnergyEstimate row(
  int n, {
  double tdee = 2400,
  double sd = 150,
  EnergyState state = EnergyState.confident,
}) =>
    EnergyEstimate(
      day: day(n),
      tdee: tdee,
      tdeeSd: sd,
      state: state,
      completeDays: 12,
      weighIns: 15,
      updated: state != EnergyState.learning,
    );

/// A learning run from [from] to [to]: learning for the first [learning]
/// days at [start], then climbing 20 cals a day.
List<EnergyEstimate> run(int from, int to,
        {double start = 2000, int learning = 10}) =>
    [
      for (var n = from; n <= to; n++)
        n - from < learning
            ? row(n, tdee: start, sd: 300, state: EnergyState.learning)
            : row(n, tdee: start + 20 * (n - from - learning + 1)),
    ];

List<int> lengths(ExpenditureSeries s) =>
    [for (final seg in s.segments) seg.rows.length];

void main() {
  group('segments', () {
    test('consecutive days form one segment', () {
      final s = ExpenditureSeries.from(run(0, 29), learningStartedOn: day(0));
      expect(lengths(s), [30]);
      expect(s.segments.single.preReset, isFalse);
      expect(s.segments.single.startsRun, isTrue);
      expect(s.resets, isEmpty);
      expect(s.first, day(0));
      expect(s.last, day(29));
    });

    test('rows are sorted by day', () {
      final rows = run(0, 9).reversed.toList();
      final s = ExpenditureSeries.from(rows, learningStartedOn: day(0));
      expect(s.rows.map((r) => r.day), [for (var n = 0; n <= 9; n++) day(n)]);
    });

    test('a missing day breaks the line without a reset marker', () {
      final rows = run(0, 29)..removeWhere((r) => r.day == day(15));
      final s = ExpenditureSeries.from(rows, learningStartedOn: day(0));
      expect(lengths(s), [15, 14]);
      expect(s.segments[1].startsRun, isFalse);
      expect(s.resets, isEmpty);
    });

    test('the learning start is a reset: earlier rows are pre-reset', () {
      final rows = [...run(0, 19, start: 2000), ...run(20, 29, start: 2300)];
      final s = ExpenditureSeries.from(rows, learningStartedOn: day(20));
      expect(lengths(s), [20, 10]);
      expect(s.segments[0].preReset, isTrue);
      expect(s.segments[1].preReset, isFalse);
      expect(s.segments[1].startsRun, isTrue);
      expect(s.resets, [day(20)]);
    });

    test('a reset while still learning splits at the learning start', () {
      // Both runs are learning at the same value: nothing in the rows shows
      // the reset, only the stored learning start.
      final rows = [
        ...run(0, 5, learning: 10),
        ...run(6, 9, learning: 10),
      ];
      final s = ExpenditureSeries.from(rows, learningStartedOn: day(6));
      expect(lengths(s), [6, 4]);
      expect(s.resets, [day(6)]);
    });

    test('an earlier reset is found from learning following a learned row', () {
      final rows = [
        ...run(0, 19, start: 2000),
        ...run(20, 39, start: 2000), // back to learning at the same value
        ...run(40, 49, start: 2500),
      ];
      final s = ExpenditureSeries.from(rows, learningStartedOn: day(40));
      expect(lengths(s), [20, 20, 10]);
      expect([for (final seg in s.segments) seg.preReset], [true, true, false]);
      expect(s.resets, [day(20), day(40)]);
    });

    test('an earlier reset is found from a jump bigger than a day can move', () {
      // A day moves at most kMaxDailyTdeeStep; 2,200 → 2,600 must be a restart
      // (here from a learned row straight to another learned row).
      final rows = [
        for (var n = 0; n < 10; n++) row(n, tdee: 2200),
        for (var n = 10; n < 20; n++) row(n, tdee: 2600),
      ];
      final s = ExpenditureSeries.from(rows, learningStartedOn: day(0));
      expect(lengths(s), [10, 10]);
      expect(s.resets, [day(10)]);
      // Only the stored learning start decides what counts as pre-reset.
      expect(s.segments.every((seg) => !seg.preReset), isTrue);
    });

    test('a 50 cal move is an ordinary day, not a reset', () {
      final rows = [row(0, tdee: 2400), row(1, tdee: 2450), row(2, tdee: 2400)];
      final s = ExpenditureSeries.from(rows, learningStartedOn: day(0));
      expect(lengths(s), [3]);
    });

    test('a paused stretch stays on the line', () {
      final rows = [
        for (var n = 0; n < 10; n++) row(n),
        for (var n = 10; n < 20; n++) row(n, state: EnergyState.paused),
        for (var n = 20; n < 25; n++) row(n),
      ];
      final s = ExpenditureSeries.from(rows, learningStartedOn: day(0));
      expect(lengths(s), [25]);
    });

    test('a reset today: every row is pre-reset and the marker is after them',
        () {
      final s = ExpenditureSeries.from(run(0, 29), learningStartedOn: day(30));
      expect(s.segments.single.preReset, isTrue);
      expect(s.resets, [day(30)]);
      expect(s.last, day(30));
    });

    test('no learning start: nothing is pre-reset', () {
      final s = ExpenditureSeries.from(run(0, 9), learningStartedOn: null);
      expect(s.segments.single.preReset, isFalse);
      expect(s.resets, isEmpty);
    });

    test('no rows', () {
      final s = ExpenditureSeries.from(const [], learningStartedOn: day(0));
      expect(s.segments, isEmpty);
      expect(s.isEmpty, isTrue);
      expect(s.first, isNull);
      expect(s.change, isNull);
    });
  });

  group('since', () {
    final rows = [...run(0, 59, start: 2000), ...run(60, 89, start: 2400)];
    final all = ExpenditureSeries.from(rows, learningStartedOn: day(60));

    test('keeps rows on or after the start', () {
      final s = all.since(day(70));
      expect(lengths(s), [20]);
      expect(s.first, day(70));
      expect(s.segments.single.startsRun, isFalse);
      expect(s.resets, isEmpty);
    });

    test('keeps a reset inside the range', () {
      final s = all.since(day(45));
      expect(lengths(s), [15, 30]);
      expect(s.segments[0].preReset, isTrue);
      expect(s.resets, [day(60)]);
    });

    test('a reset on the first day of the range is not marked', () {
      expect(all.since(day(60)).resets, isEmpty);
    });

    test('null keeps everything', () {
      expect(lengths(all.since(null)), [60, 30]);
    });
  });

  group('change', () {
    test('over the current run, from its start', () {
      final s = ExpenditureSeries.from(run(0, 29, start: 2000, learning: 10),
          learningStartedOn: day(0));
      final c = s.change!;
      expect(c.delta, 400); // 20 learned days × 20
      expect(c.from, day(0));
      expect(c.fromRunStart, isTrue);
    });

    test('over the range when the run started before it', () {
      final s = ExpenditureSeries.from(run(0, 29), learningStartedOn: day(0))
          .since(day(20));
      final c = s.change!;
      expect(c.delta, 180);
      expect(c.from, day(20));
      expect(c.fromRunStart, isFalse);
    });

    test('never across a reset', () {
      final rows = [...run(0, 19, start: 2000), ...run(20, 39, start: 2400)];
      final c = ExpenditureSeries.from(rows, learningStartedOn: day(20)).change!;
      expect(c.from, day(20));
      expect(c.delta, 200);
    });

    test('spans a missing day within the run', () {
      final rows = run(0, 29)..removeWhere((r) => r.day == day(25));
      final c = ExpenditureSeries.from(rows, learningStartedOn: day(0)).change!;
      expect(c.from, day(0));
      expect(c.delta, 400);
    });

    test('null with one row in the run, or only pre-reset rows', () {
      expect(
          ExpenditureSeries.from([row(0)], learningStartedOn: day(0)).change,
          isNull);
      expect(
          ExpenditureSeries.from(run(0, 9), learningStartedOn: day(10)).change,
          isNull);
    });
  });

  group('scale', () {
    test('covers the band', () {
      final s = ExpenditureSeries.from(
          [row(0, tdee: 2400, sd: 100), row(1, tdee: 2600, sd: 100)],
          learningStartedOn: day(0));
      final scale = s.scale(formula: null);
      expect(scale.lo, lessThanOrEqualTo(2300));
      expect(scale.hi, greaterThanOrEqualTo(2700));
      expect(scale.showsFormula, isFalse);
    });

    test('a flat line still spans at least kMinScaleSpan', () {
      final s = ExpenditureSeries.from(
          [for (var n = 0; n < 5; n++) row(n, tdee: 2400, sd: 20)],
          learningStartedOn: day(0));
      final scale = s.scale(formula: null);
      expect(scale.hi - scale.lo, greaterThanOrEqualTo(kMinScaleSpan));
      expect((scale.hi + scale.lo) / 2, closeTo(2400, 1e-9));
    });

    test('includes a nearby formula', () {
      final s = ExpenditureSeries.from(
          [row(0, tdee: 2400, sd: 50), row(1, tdee: 2500, sd: 50)],
          learningStartedOn: day(0));
      final scale = s.scale(formula: 2000);
      expect(scale.showsFormula, isTrue);
      expect(scale.lo, lessThanOrEqualTo(2000));
    });

    test('leaves out a formula far off the data', () {
      final s = ExpenditureSeries.from(
          [row(0, tdee: 2400, sd: 50), row(1, tdee: 2500, sd: 50)],
          learningStartedOn: day(0));
      final scale = s.scale(formula: 900);
      expect(scale.showsFormula, isFalse);
      expect(scale.lo, greaterThan(900));
    });

    test('no rows: centred on the formula', () {
      final s = ExpenditureSeries.from(const [], learningStartedOn: day(0));
      final scale = s.scale(formula: 2000);
      expect(scale.showsFormula, isTrue);
      expect(scale.lo, lessThan(2000));
      expect(scale.hi, greaterThan(2000));
    });
  });

  test('a year of rows splits in well under a frame', () {
    final rows = run(0, 399, learning: 10);
    final watch = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      ExpenditureSeries.from(rows, learningStartedOn: day(0))
          .since(day(100))
          .scale(formula: 2000);
    }
    expect(watch.elapsedMilliseconds / 20, lessThan(8));
  });
}
