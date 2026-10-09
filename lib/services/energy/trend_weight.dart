import 'dart:math' as math;

import 'constants.dart';
import 'targets.dart';

/// One weigh-in: the day it was taken and the scale weight.
class WeightReading {
  const WeightReading(this.day, this.weightKg);

  final DateTime day;
  final double weightKg;
}

/// A weigh-in with the trend as of that day (spec 6.2).
class TrendPoint {
  const TrendPoint({
    required this.day,
    required this.weightKg,
    required this.trendKg,
    required this.ignored,
  });

  /// Local midnight of the weigh-in day.
  final DateTime day;
  final double weightKg;

  /// The trend after this reading. For an ignored reading it's the trend
  /// carried from before, which the reading didn't move.
  final double trendKg;

  /// True when the reading was an outlier and left out of the trend.
  final bool ignored;

  /// Scale weight minus trend: how far off the trend the reading was.
  double get offTrendKg => weightKg - trendKg;
}

/// Trend weight change over the last 7 days.
class WeeklyChange {
  const WeeklyChange({required this.kg, required this.pct});

  /// Negative when the trend went down.
  final double kg;

  /// [kg] as a % of the trend a week earlier.
  final double pct;
}

/// Smoothed body weight: a time-aware EMA that leaves out outliers.
///
/// - `trend₀` is the first reading. Each later reading moves the trend by
///   `α = 1 − (1 − kTrendAlpha)^Δdays`, where Δdays counts from the last
///   reading the trend used.
/// - A reading more than [kOutlierPct] of the trend away is ignored.
/// - [kOutlierRunToAccept] ignored readings in a row on the same side are a
///   real shift: they're accepted and replayed from the first of them. Until a
///   reading comes back within [kOutlierPct] of the trend, the lagging trend
///   isn't the reference on that side: a reading is accepted when it's within
///   [kOutlierPct] of the new level (the mean of the last
///   [kOutlierRunToAccept] accepted readings), so the trend can catch up.
///   One further off is a fresh outlier and is ignored.
/// - For [kSwitchExpectedDays] from each phase switch the band is
///   [kSwitchOutlierPct]: the water and glycogen shift is expected, so it
///   moves the trend instead of being ignored.
class TrendSeries {
  TrendSeries._(this.points);

  /// [readings] in any order. Only the last reading given for a day is used.
  /// [switches] are the phase switch days (`phaseSwitchDays`).
  factory TrendSeries.compute(Iterable<WeightReading> readings,
      {Iterable<DateTime> switches = const []}) {
    final switchDays = switches.toList();
    final byDay = <DateTime, double>{};
    for (final r in readings) {
      byDay[_dayOf(r.day)] = r.weightKg;
    }
    final days = byDay.keys.toList()..sort();

    final points = <TrendPoint>[];
    double trend = 0;
    DateTime? lastUsed;
    final run = <int>[]; // indexes of the pending same-side outliers
    var runSide = 0;
    var shiftSide = 0; // side of an accepted shift still being followed
    final level = <double>[]; // last accepted readings while following it

    void use(int i) {
      final day = days[i];
      final w = byDay[day]!;
      if (lastUsed == null) {
        trend = w;
      } else {
        final alpha =
            1 - math.pow(1 - kTrendAlpha, _daysBetween(lastUsed!, day));
        trend += alpha * (w - trend);
      }
      lastUsed = day;
      final point =
          TrendPoint(day: day, weightKg: w, trendKg: trend, ignored: false);
      if (i < points.length) {
        points[i] = point;
      } else {
        points.add(point);
      }
    }

    for (var i = 0; i < days.length; i++) {
      final w = byDay[days[i]]!;
      if (i == 0) {
        use(i);
        continue;
      }
      final off = w - trend;
      final side = off.sign.toInt();
      final band = settlingAfterSwitch(days[i], switchDays) == null
          ? kOutlierPct
          : kSwitchOutlierPct;
      final isOutlier = off.abs() > band * trend + 1e-9;

      if (!isOutlier) {
        run.clear();
        shiftSide = 0;
        use(i);
        continue;
      }
      if (side == shiftSide) {
        final ref = level.reduce((a, b) => a + b) / level.length;
        if ((w - ref).abs() <= kOutlierPct * ref + 1e-9) {
          run.clear();
          use(i);
          level
            ..add(w)
            ..removeAt(0);
          continue;
        }
      }

      if (run.isNotEmpty && runSide != side) run.clear();
      run.add(i);
      runSide = side;
      points.add(
          TrendPoint(day: days[i], weightKg: w, trendKg: trend, ignored: true));

      if (run.length >= kOutlierRunToAccept) {
        // Ignored readings never moved the trend, so the state is still the
        // one from before the run: replay the run as ordinary readings.
        for (final j in run) {
          use(j);
        }
        level
          ..clear()
          ..addAll(run.map((j) => byDay[days[j]]!));
        run.clear();
        shiftSide = side;
      }
    }
    return TrendSeries._(List.unmodifiable(points));
  }

  /// One point per weigh-in day, oldest first.
  final List<TrendPoint> points;

  TrendPoint? get latest => points.isEmpty ? null : points.last;

  /// The trend on [day], carried forward from the last weigh-in on or before
  /// it. Null before the first weigh-in.
  double? trendOn(DateTime day) {
    final d = _dayOf(day);
    double? trend;
    for (final p in points) {
      if (p.day.isAfter(d)) break;
      trend = p.trendKg;
    }
    return trend;
  }

  /// The trend change over the 7 days up to the latest weigh-in. Null until
  /// the weigh-ins span a week.
  WeeklyChange? weeklyChange() {
    final last = latest;
    if (last == null) return null;
    final weekAgo = trendOn(
        DateTime(last.day.year, last.day.month, last.day.day - 7));
    if (weekAgo == null || weekAgo <= 0) return null;
    final kg = last.trendKg - weekAgo;
    return WeeklyChange(kg: kg, pct: kg / weekAgo * 100);
  }
}

/// The latest of [switches] that [day] is within [kSwitchExpectedDays] of
/// (the switch day is the first), or null: the days the Weight tab labels
/// "Expected: water & glycogen".
DateTime? settlingAfterSwitch(DateTime day, Iterable<DateTime> switches) {
  final d = _dayOf(day);
  DateTime? found;
  for (final s in switches) {
    final sw = _dayOf(s);
    final k = _daysBetween(sw, d);
    if (k >= 0 && k < kSwitchExpectedDays && (found == null || sw.isAfter(found))) {
      found = sw;
    }
  }
  return found;
}

/// The goal pace with a sign: negative when losing, 0 when maintaining.
double signedGoalPacePct(GoalKind goal, double pacePctPerWeek) =>
    switch (goal) {
      GoalKind.lose => -pacePctPerWeek,
      GoalKind.gain => pacePctPerWeek,
      GoalKind.maintain => 0,
    };

/// Whether the actual weekly change (% of body weight, signed) is within
/// [kPaceTolerancePct] of the signed goal pace.
bool isOnPace({
  required double actualPctPerWeek,
  required double goalPctPerWeek,
}) =>
    (actualPctPerWeek - goalPctPerWeek).abs() <= kPaceTolerancePct + 1e-9;

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Whole calendar days from [a] to [b], safe across DST changes.
int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;
