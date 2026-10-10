import 'day_status.dart';
import 'energy_estimator.dart';

/// Days of estimates kept on the device (spec §4: the last 400 days).
const int kEstimateCacheDays = 400;

/// `yyyy-MM-dd`, the `day` column and the cache key.
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// The calendar day in a `yyyy-MM-dd` string, or null.
DateTime? parseDay(Object? s) {
  final t = DateTime.tryParse('$s');
  return t == null ? null : DateTime(t.year, t.month, t.day);
}

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// The estimator's food log: [calsByDay] has the days with food entries
/// (their total cals, which may be 0), [statuses] what the user said about a
/// day. A day in neither is left out.
Map<DateTime, FoodDay> foodDaysFrom({
  required Map<DateTime, double> calsByDay,
  required Map<DateTime, ExplicitDayStatus> statuses,
}) {
  final cals = {for (final e in calsByDay.entries) _dayOf(e.key): e.value};
  final explicit = {for (final e in statuses.entries) _dayOf(e.key): e.value};
  return {
    for (final day in {...cals.keys, ...explicit.keys})
      day: FoodDay(
        loggedCals: cals[day] ?? 0,
        hasEntries: cals.containsKey(day),
        explicit: explicit[day],
      ),
  };
}

/// Where learning starts for an account from before `learning_started_on`
/// existed: its first weigh-in or food day, so the history it already has
/// counts, but no further back than the device keeps estimates. Today when
/// there's no data.
DateTime defaultLearningStart({
  required DateTime today,
  required Iterable<DateTime> dataDays,
}) {
  final t = _dayOf(today);
  final floor = DateTime(t.year, t.month, t.day - (kEstimateCacheDays - 1));
  var start = t;
  for (final d in dataDays) {
    final day = _dayOf(d);
    if (day.isBefore(start)) start = day;
  }
  return start.isBefore(floor) ? floor : start;
}

/// The rows from the last [kEstimateCacheDays] days up to [today].
Map<DateTime, EnergyEstimate> keepRecent(
  Map<DateTime, EnergyEstimate> rows, {
  required DateTime today,
}) {
  final t = _dayOf(today);
  final floor = DateTime(t.year, t.month, t.day - (kEstimateCacheDays - 1));
  return {
    for (final e in rows.entries)
      if (!e.key.isBefore(floor)) e.key: e.value,
  };
}

/// The rows in [fresh] that the cloud doesn't have yet: new days, and days
/// whose stored (rounded) values differ from [cached].
List<EnergyEstimate> rowsToUpload(
  Iterable<EnergyEstimate> fresh,
  Map<DateTime, EnergyEstimate> cached,
) {
  bool same(Map<String, dynamic> a, Map<String, dynamic> b) =>
      a.length == b.length && a.keys.every((k) => a[k] == b[k]);
  return [
    for (final r in fresh)
      if (cached[_dayOf(r.day)] == null ||
          !same(r.toRemoteRow(''), cached[_dayOf(r.day)]!.toRemoteRow('')))
        r,
  ];
}

double? _num(Object? v) =>
    v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

double? _round(double? v, int places) {
  if (v == null) return null;
  final p = [1, 10, 100, 1000, 10000][places];
  return (v * p).roundToDouble() / p;
}

extension EnergyEstimateRows on EnergyEstimate {
  /// The `energy_estimates` row, rounded to its column types.
  Map<String, dynamic> toRemoteRow(String userId) => {
        'user_id': userId,
        'day': dayKey(day),
        'tdee': tdee.round(),
        'tdee_sd': tdeeSd.round(),
        'state': state.code,
        'trend_weight_kg': _round(trendWeightKg, 2),
        'slope_kg_per_day': _round(slopeKgPerDay, 4),
        'avg_intake': avgIntake?.round(),
        'complete_days': completeDays,
        'weigh_ins': weighIns,
        'algo_version': algoVersion,
      };

  /// Everything, at full precision, for the device cache.
  Map<String, dynamic> toCacheJson() => {
        'day': dayKey(day),
        'tdee': tdee,
        'tdee_sd': tdeeSd,
        'state': state.code,
        'trend_weight_kg': trendWeightKg,
        'slope_kg_per_day': slopeKgPerDay,
        'avg_intake': avgIntake,
        'complete_days': completeDays,
        'weigh_ins': weighIns,
        'updated': updated,
        'last_update_day': lastUpdateDay == null ? null : dayKey(lastUpdateDay!),
        'observed_tdee': observedTdee,
        'energy_density': energyDensity,
        'algo_version': algoVersion,
      };
}

/// A row from [EnergyEstimateRows.toCacheJson], or null if it can't be read.
EnergyEstimate? estimateFromCache(Object? json) {
  if (json is! Map) return null;
  final day = parseDay(json['day']);
  final tdee = _num(json['tdee']);
  final sd = _num(json['tdee_sd']);
  final state = EnergyState.fromCode(json['state']);
  if (day == null || tdee == null || sd == null || state == null) return null;
  return EnergyEstimate(
    day: day,
    tdee: tdee,
    tdeeSd: sd,
    state: state,
    trendWeightKg: _num(json['trend_weight_kg']),
    slopeKgPerDay: _num(json['slope_kg_per_day']),
    avgIntake: _num(json['avg_intake']),
    completeDays: _num(json['complete_days'])?.toInt() ?? 0,
    weighIns: _num(json['weigh_ins'])?.toInt() ?? 0,
    updated: json['updated'] == true,
    lastUpdateDay: parseDay(json['last_update_day']),
    observedTdee: _num(json['observed_tdee']),
    energyDensity: _num(json['energy_density']),
    algoVersion: _num(json['algo_version'])?.toInt() ?? 0,
  );
}

/// An `energy_estimates` row. The fields only the device keeps (`updated`,
/// last update day, observation) are unknown.
EnergyEstimate? estimateFromRemote(Map<String, dynamic> row) =>
    estimateFromCache({...row, 'updated': false, 'last_update_day': null});
