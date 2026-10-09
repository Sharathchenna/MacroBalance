import 'constants.dart';
import 'energy_estimator.dart';

/// The smallest span the expenditure chart's scale covers, in cals, so a
/// steady month doesn't look dramatic.
const double kMinScaleSpan = 400;

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// A stretch of consecutive days drawn as one unbroken line.
class ExpenditureSegment {
  const ExpenditureSegment({
    required this.rows,
    required this.run,
    required this.preReset,
    required this.startsRun,
  });

  /// One row per day, oldest first, no days missing.
  final List<EnergyEstimate> rows;

  /// Which learning run the rows belong to, counting from 0. A missing day
  /// breaks the line but not the run; a reset starts a new run.
  final int run;

  /// Before the current learning start: history "Reset learning" kept for
  /// the chart that no longer counts.
  final bool preReset;

  /// Whether the first row is the first day of its run (not a day after a
  /// gap, or the first day in a range).
  final bool startsRun;

  DateTime get first => rows.first.day;
  DateTime get last => rows.last.day;
}

/// How far the current run moved over a range, for the chart header.
class ExpenditureChange {
  const ExpenditureChange({
    required this.delta,
    required this.from,
    required this.fromRunStart,
  });

  /// Last minus first, rounded to whole cals.
  final int delta;

  /// The day the change is measured from.
  final DateTime from;

  /// Whether [from] is where the run started rather than where the range
  /// starts.
  final bool fromRunStart;
}

/// The values the chart's y axis has to cover, before padding and ticks.
class ExpenditureScale {
  const ExpenditureScale(this.lo, this.hi, {required this.showsFormula});

  final double lo;
  final double hi;

  /// Whether the formula line shares the scale. Left out when it's so far
  /// off that it would flatten the line.
  final bool showsFormula;
}

/// The stored estimates as the expenditure chart draws them (spec 7.1 R2):
/// unbroken segments, with breaks at missing days and at resets.
///
/// Only the latest reset is stored (`learning_started_on`). Earlier ones are
/// read off the rows, which is safe because the estimator never does either
/// on its own: once a run has updated it never goes back to learning, and a
/// day never moves more than [kMaxDailyTdeeStep].
class ExpenditureSeries {
  const ExpenditureSeries._(this.segments, this.resets, this._end);

  factory ExpenditureSeries.from(
    List<EnergyEstimate> estimates, {
    required DateTime? learningStartedOn,
  }) {
    final start = learningStartedOn == null ? null : _dayOf(learningStartedOn);
    final rows = [...estimates]..sort((a, b) => a.day.compareTo(b.day));
    final segments = <ExpenditureSegment>[];
    final resets = <DateTime>[];
    var current = <EnergyEstimate>[];
    var run = 0;
    var startsRun = true;

    void close() {
      if (current.isEmpty) return;
      segments.add(ExpenditureSegment(
        rows: current,
        run: run,
        preReset: start != null && current.first.day.isBefore(start),
        startsRun: startsRun,
      ));
      current = [];
    }

    for (final r in rows) {
      if (current.isNotEmpty) {
        final prev = current.last;
        final reset = r.day == start ||
            (r.state == EnergyState.learning &&
                prev.state != EnergyState.learning) ||
            (r.tdee - prev.tdee).abs() > kMaxDailyTdeeStep + 0.5;
        if (reset) {
          close();
          resets.add(r.day);
          run++;
          startsRun = true;
        } else if (r.day != _addDays(prev.day, 1)) {
          close();
          startsRun = false;
        }
      }
      current.add(r);
    }
    close();

    // Reset with no rows since (today): mark it after the history.
    DateTime? end;
    if (start != null && rows.isNotEmpty && start.isAfter(rows.last.day)) {
      resets.add(start);
      end = start;
    }
    return ExpenditureSeries._(segments, resets, end);
  }

  /// Unbroken stretches, oldest first.
  final List<ExpenditureSegment> segments;

  /// Days a new learning run started after earlier rows: drawn as markers.
  final List<DateTime> resets;

  final DateTime? _end;

  bool get isEmpty => segments.isEmpty;

  /// Every row, oldest first.
  List<EnergyEstimate> get rows => [for (final s in segments) ...s.rows];

  DateTime? get first => isEmpty ? null : segments.first.first;

  /// The last day to show: the last row, or a later reset.
  DateTime? get last => _end ?? (isEmpty ? null : segments.last.last);

  /// The rows on or after [start] (all of them for null).
  ExpenditureSeries since(DateTime? start) {
    if (start == null) return this;
    final from = _dayOf(start);
    final kept = <ExpenditureSegment>[];
    for (final s in segments) {
      if (s.last.isBefore(from)) continue;
      if (!s.first.isBefore(from)) {
        kept.add(s);
        continue;
      }
      kept.add(ExpenditureSegment(
        rows: [
          for (final r in s.rows)
            if (!r.day.isBefore(from)) r
        ],
        run: s.run,
        preReset: s.preReset,
        startsRun: false,
      ));
    }
    return ExpenditureSeries._(
      kept,
      [
        for (final d in resets)
          if (d.isAfter(from)) d
      ],
      _end,
    );
  }

  /// How far the latest run moved: from its first row here to its last.
  /// Null with fewer than two rows of it, or when every row is pre-reset.
  ExpenditureChange? get change {
    if (isEmpty || segments.last.preReset) return null;
    final run = segments.last.run;
    final ofRun = [
      for (final s in segments)
        if (s.run == run) s
    ];
    final first = ofRun.first.rows.first;
    final last = ofRun.last.rows.last;
    if (first.day == last.day) return null;
    return ExpenditureChange(
      delta: (last.tdee - first.tdee).round(),
      from: first.day,
      fromRunStart: ofRun.first.startsRun,
    );
  }

  /// What the y axis covers: every row's ±1 sd band (just the line when
  /// [band] is false), at least [kMinScaleSpan] wide, plus [formula] when
  /// it's within about twice the data's spread.
  ExpenditureScale scale({required double? formula, bool band = true}) {
    if (isEmpty) {
      final mid = formula ?? 2000;
      return ExpenditureScale(
        mid - kMinScaleSpan / 2,
        mid + kMinScaleSpan / 2,
        showsFormula: formula != null,
      );
    }
    var lo = double.infinity, hi = double.negativeInfinity;
    for (final s in segments) {
      for (final r in s.rows) {
        final sd = band ? r.tdeeSd : 0.0;
        if (r.tdee - sd < lo) lo = r.tdee - sd;
        if (r.tdee + sd > hi) hi = r.tdee + sd;
      }
    }
    final reach = 2 * (hi - lo < kMinScaleSpan ? kMinScaleSpan : hi - lo);
    final showsFormula =
        formula != null && formula >= lo - reach && formula <= hi + reach;
    if (showsFormula) {
      if (formula < lo) lo = formula;
      if (formula > hi) hi = formula;
    }
    if (hi - lo < kMinScaleSpan) {
      final mid = (hi + lo) / 2;
      lo = mid - kMinScaleSpan / 2;
      hi = mid + kMinScaleSpan / 2;
    }
    return ExpenditureScale(lo, hi, showsFormula: showsFormula);
  }
}
