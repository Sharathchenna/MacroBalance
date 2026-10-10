import 'constants.dart';
import 'energy_estimator.dart';
import 'energy_summary.dart';
import 'trend_weight.dart';

/// What recalculating goals starts from (spec 7.6, plan 10.4): the trend
/// weight and, once it's confident, the learned expenditure.

/// The weight recalculate prefills.
class WeightPrefill {
  const WeightPrefill({required this.kg, required this.recent});

  /// The trend weight at the latest weigh-in.
  final double kg;

  /// The latest weigh-in is within [kRecentWeighInDays], so the trend is
  /// offered as a one-tap "Use 81.4 kg (your trend)".
  final bool recent;
}

/// The trend at the latest of [readings], or null without any.
WeightPrefill? weightPrefill(Iterable<WeightReading> readings,
    {required DateTime today}) {
  final latest = TrendSeries.compute(readings).latest;
  if (latest == null) return null;
  final day = DateTime(today.year, today.month, today.day);
  // Rounded, so a daylight-saving hour doesn't drop a day.
  final daysAgo = (day.difference(latest.day).inHours / 24).round();
  return WeightPrefill(
    kg: latest.trendKg,
    recent: daysAgo >= 0 && daysAgo < kRecentWeighInDays,
  );
}

/// The expenditure recalculate plans from instead of the formula: the
/// Energy tab's estimate, once it's confident. Null means use the formula,
/// with the activity level.
double? learnedTdee(EnergySummary summary) =>
    summary.state == EnergyState.confident ? summary.tdee : null;
