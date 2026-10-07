import 'dart:math' as math;

/// Pounds in a kilogram. Weight is stored in kg; everything shown in lbs goes
/// through this.
const double lbsPerKg = 2.20462262;

/// Rough energy in a kilogram of body weight, in cals.
const double calsPerKg = 7700;

/// One weigh-in, in kg.
class WeightEntry {
  const WeightEntry(this.date, this.kg);

  final DateTime date;
  final double kg;

  DateTime get day => DateTime(date.year, date.month, date.day);
}

/// Reads the stored `weight_history` rows (`{date, weight}`), oldest first,
/// keeping the last weigh-in of each day and skipping unreadable rows.
List<WeightEntry> parseWeightHistory(Iterable<dynamic> rows) {
  final byDay = <DateTime, WeightEntry>{};
  for (final row in rows) {
    if (row is! Map) continue;
    final date = DateTime.tryParse('${row['date']}');
    final kg = row['weight'];
    if (date == null || kg is! num || kg <= 0) continue;
    final entry = WeightEntry(date, kg.toDouble());
    final existing = byDay[entry.day];
    if (existing == null || !entry.date.isBefore(existing.date)) {
      byDay[entry.day] = entry;
    }
  }
  return byDay.values.toList()..sort((a, b) => a.date.compareTo(b.date));
}

int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;

/// Smoothed weight at each weigh-in: every day the trend moves 10% of the way
/// to the scale, so water and salt swings settle out. Gaps count as the days
/// they span, so a weekly weigh-in moves the trend about half way.
List<double> weightTrend(List<WeightEntry> entries) {
  final trend = <double>[];
  for (var i = 0; i < entries.length; i++) {
    if (i == 0) {
      trend.add(entries[i].kg);
      continue;
    }
    final days = math.max(1, _daysBetween(entries[i - 1].date, entries[i].date));
    final alpha = 1 - math.pow(0.9, days).toDouble();
    trend.add(trend[i - 1] + alpha * (entries[i].kg - trend[i - 1]));
  }
  return trend;
}

/// Change in kg per week across [entries], from a least-squares fit, or null
/// when they span less than [minDays].
double? weeklyRateKg(List<WeightEntry> entries, {int minDays = 7}) {
  if (entries.length < 2) return null;
  final origin = entries.first.date;
  final xs = [for (final e in entries) _daysBetween(origin, e.date).toDouble()];
  if (xs.last < minDays) return null;
  final ys = [for (final e in entries) e.kg];
  final n = xs.length;
  final mx = xs.reduce((a, b) => a + b) / n;
  final my = ys.reduce((a, b) => a + b) / n;
  var sxy = 0.0, sxx = 0.0;
  for (var i = 0; i < n; i++) {
    sxy += (xs[i] - mx) * (ys[i] - my);
    sxx += (xs[i] - mx) * (xs[i] - mx);
  }
  if (sxx == 0) return null;
  return sxy / sxx * 7;
}

/// When the goal is reached at [weeklyKg], or null when the weight isn't
/// heading toward it or it's more than two years out.
DateTime? projectedGoalDate({
  required double currentKg,
  required double goalKg,
  required double? weeklyKg,
  required DateTime from,
}) {
  if (weeklyKg == null || goalKg <= 0) return null;
  final remaining = goalKg - currentKg;
  if (remaining.abs() < 0.05) return null;
  if (weeklyKg.abs() < 0.05 || remaining.sign != weeklyKg.sign) return null;
  final days = (remaining / weeklyKg * 7).round();
  if (days > 730) return null;
  final today = DateTime(from.year, from.month, from.day);
  return DateTime(today.year, today.month, today.day + days);
}

/// Evenly spaced, round axis values covering [min]..[max] (in whatever unit
/// they're given), about [count] of them: steps of 1, 2, 2.5 or 5 times a
/// power of ten.
List<double> niceTicks(double min, double max, {int count = 4}) {
  if (max < min) return niceTicks(max, min, count: count);
  if (max == min) {
    max += 1;
    min -= 1;
  }
  final raw = (max - min) / math.max(1, count - 1);
  final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final step = [1.0, 2.0, 2.5, 5.0, 10.0]
          .map((m) => m * mag)
          .firstWhere((s) => s >= raw - 1e-9);
  final start = (min / step).floor() * step;
  final end = (max / step).ceil() * step;
  return [
    for (var v = start; v <= end + step / 2; v += step)
      double.parse(v.toStringAsFixed(6)),
  ];
}

/// Weigh-ins to measure the recent rate from: the last [days] days, plus the
/// last weigh-in before them so someone weighing in every few weeks still
/// gets a rate.
List<WeightEntry> recentForRate(List<WeightEntry> entries, DateTime today,
    {int days = 28}) {
  final from = DateTime(today.year, today.month, today.day - days);
  final i = entries.indexWhere((e) => !e.day.isBefore(from));
  if (i == -1) return const [];
  return entries.sublist(i > 0 ? i - 1 : 0);
}
