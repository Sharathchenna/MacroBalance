import 'constants.dart';
import 'day_status.dart';
import 'energy_estimator.dart';

/// Share of the strip's days that are partial or untracked before the
/// data-quality tip asks the user to finish their days (spec 7.1 R4).
const double kFinishDayTipFraction = 0.30;

/// The headline ± (spec 7.1 R1: `round(√var, 10)`).
int roundToTen(double v) => (v / 10).round() * 10;

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

/// What the Energy tab shows from the stored estimates (spec 7.1 R1, R3).
///
/// Only rows since the learning start count: "Reset learning" keeps the old
/// rows for the chart, but the headline starts again from the formula.
class EnergySummary {
  const EnergySummary({
    required this.state,
    required this.tdee,
    required this.sd,
    required this.completeDays,
    required this.weighIns,
    this.latest,
    this.weekChange,
    this.lastUpdated,
    this.breakdown,
  });

  factory EnergySummary.from({
    required List<EnergyEstimate> estimates,
    required DateTime? learningStartedOn,
    required double formulaTdee,
  }) {
    final start = learningStartedOn == null ? null : _dayOf(learningStartedOn);
    final rows = [
      for (final r in estimates)
        if (start == null || !r.day.isBefore(start)) r,
    ]..sort((a, b) => a.day.compareTo(b.day));
    if (rows.isEmpty) {
      return EnergySummary(
        state: EnergyState.learning,
        tdee: formulaTdee,
        sd: kPriorSd,
        completeDays: 0,
        weighIns: 0,
      );
    }

    final latest = rows.last;
    EnergyEstimate? lastUpdatedRow;
    for (final r in rows.reversed) {
      if (r.updated) {
        lastUpdatedRow = r;
        break;
      }
    }

    int? weekChange;
    if (latest.state != EnergyState.learning) {
      final weekAgo = _addDays(latest.day, -7);
      for (final r in rows) {
        if (r.day == weekAgo) {
          final delta = (latest.tdee - r.tdee).round();
          if (delta.abs() >= 10) weekChange = delta;
          break;
        }
      }
    }

    Breakdown? breakdown;
    if (latest.state != EnergyState.learning) {
      for (final r in rows.reversed) {
        breakdown = Breakdown.of(r);
        if (breakdown != null) break;
      }
    }

    return EnergySummary(
      state: latest.state,
      tdee: latest.tdee,
      sd: latest.tdeeSd,
      completeDays: latest.completeDays,
      weighIns: latest.weighIns,
      latest: latest,
      weekChange: weekChange,
      lastUpdated: latest.lastUpdateDay ?? lastUpdatedRow?.day,
      breakdown: breakdown,
    );
  }

  final EnergyState state;
  final double tdee;
  final double sd;

  /// Complete days and weigh-ins in the latest window: the learning progress
  /// toward [kMinCompleteDays] and [kMinWeighIns].
  final int completeDays;
  final int weighIns;

  /// The latest row since the learning start; null before the first.
  final EnergyEstimate? latest;

  /// Change since 7 days earlier, rounded; null when under 10 cals, while
  /// learning, or with no row then.
  final int? weekChange;

  /// The last day an observation moved the estimate, for "Last updated".
  final DateTime? lastUpdated;

  /// The "How we got this" numbers; null while learning.
  final Breakdown? breakdown;
}

/// The plain-language maths behind an estimate (spec 7.1 R3), from one row's
/// window stats. The rounded numbers add up: [avgIntake] + [weightTerm] =
/// [result].
class Breakdown {
  const Breakdown({
    required this.day,
    required this.avgIntake,
    required this.completeDays,
    required this.trendKgPerWeek,
    required this.weightTerm,
  });

  /// Null unless the row's observation was used (the gate passed).
  static Breakdown? of(EnergyEstimate row) {
    final intake = row.avgIntake, slope = row.slopeKgPerDay, ed = row.energyDensity;
    if (!row.updated || intake == null || slope == null || ed == null) {
      return null;
    }
    return Breakdown(
      day: row.day,
      avgIntake: intake.round(),
      completeDays: row.completeDays,
      trendKgPerWeek: slope * 7,
      weightTerm: (-slope * ed).round(),
    );
  }

  /// The window's last day.
  final DateTime day;

  /// Mean cals of the window's complete and fasting days.
  final int avgIntake;
  final int completeDays;

  /// The weigh-ins' slope, per week.
  final double trendKgPerWeek;

  /// What the weight change is worth in cals/day: `−slope·ED`. Positive
  /// when losing (more was burned than eaten).
  final int weightTerm;

  /// This window's expenditure: `avgIntake − slope·ED`.
  int get result => avgIntake + weightTerm;
}

/// One dot of the data-quality strip.
class QualityDay {
  const QualityDay(
    this.day,
    this.status, {
    required this.weighedIn,
    this.beforeLearning = false,
  });

  final DateTime day;

  /// Null before the learning start.
  final DayStatus? status;
  final bool weighedIn;

  /// Before the learning start: not used, drawn faint.
  final bool beforeLearning;
}

/// The last [days] days through [through] (normally yesterday), each
/// classified as the estimator does: against the estimate entering the day
/// ([tdeeByDay] of the day before), else [formulaTdee] (spec 7.1 R4).
List<QualityDay> qualityStrip({
  required DateTime through,
  required DateTime? learningStartedOn,
  required Map<DateTime, FoodDay> food,
  required Iterable<DateTime> weighInDays,
  required Map<DateTime, double> tdeeByDay,
  required double formulaTdee,
  int days = kWindowDays,
}) {
  final last = _dayOf(through);
  final start = learningStartedOn == null ? null : _dayOf(learningStartedOn);
  final foodByDay = {for (final e in food.entries) _dayOf(e.key): e.value};
  final tdee = {for (final e in tdeeByDay.entries) _dayOf(e.key): e.value};
  final weighed = {for (final d in weighInDays) _dayOf(d)};
  return [
    for (var i = days - 1; i >= 0; i--)
      () {
        final d = _addDays(last, -i);
        if (start != null && d.isBefore(start)) {
          return QualityDay(d, null, weighedIn: false, beforeLearning: true);
        }
        final f = foodByDay[d];
        final c = classifyDay(
          day: d,
          today: _addDays(d, 1),
          explicit: f?.explicit,
          hasEntries: f?.hasEntries ?? false,
          loggedCals: f?.loggedCals ?? 0,
          tdeeEstimate: tdee[_addDays(d, -1)] ?? formulaTdee,
        );
        return QualityDay(d, c?.status, weighedIn: weighed.contains(d));
      }(),
  ];
}

/// The data-quality strip's one tip.
enum QualityTip { weighIn, finishDay }

/// Spec 7.1 R4, over the days since the learning start: fewer than
/// [kMinWeighIns] weigh-ins → weigh in; else partial + untracked over
/// [kFinishDayTipFraction] → finish day; else none.
QualityTip? qualityTip(List<QualityDay> strip) {
  final counted = [for (final d in strip) if (!d.beforeLearning) d];
  if (counted.where((d) => d.weighedIn).length < kMinWeighIns) {
    return QualityTip.weighIn;
  }
  final gaps = counted
      .where((d) =>
          d.status == DayStatus.partial || d.status == DayStatus.untracked)
      .length;
  if (gaps > kFinishDayTipFraction * counted.length) return QualityTip.finishDay;
  return null;
}
