import 'dart:math' as math;

import 'body_composition.dart';
import 'constants.dart';
import 'constants.dart' as k show algoVersion;
import 'day_status.dart';
import 'trend_weight.dart';

/// How far the expenditure estimate has got (`energy_estimates.state`).
enum EnergyState {
  learning('learning'),
  estimated('estimated'),
  confident('confident'),
  paused('paused');

  const EnergyState(this.code);

  final String code;

  static EnergyState? fromCode(Object? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

/// One day's food log, as the estimator needs it. A day missing from
/// [EstimatorInputs.food] has no entries and no explicit status.
class FoodDay {
  const FoodDay({required this.loggedCals, bool? hasEntries, this.explicit})
      : hasEntries = hasEntries ?? loggedCals > 0;

  final double loggedCals;
  final bool hasEntries;

  /// What the user said about the day, if anything.
  final ExplicitDayStatus? explicit;
}

/// What the energy density of a weight change depends on.
class BodyProfile {
  const BodyProfile({
    required this.sex,
    required this.heightCm,
    required this.age,
    this.bodyFatPct,
  });

  final Sex sex;
  final double heightCm;
  final int age;

  /// From a scan or smart scale; null estimates it with Deurenberg.
  final double? bodyFatPct;

  /// Cals per kg of weight change at [weightKg] (spec 6.1).
  double energyDensityAt(double weightKg) => energyDensity(fatMassKg(
        weightKg: weightKg,
        heightCm: heightCm,
        age: age,
        sex: sex,
        bodyFatPct: bodyFatPct,
      ));
}

/// Everything the estimator reads. Days are calendar days (time ignored).
class EstimatorInputs {
  const EstimatorInputs({
    required this.learningStartedOn,
    required this.formulaTdee,
    required this.body,
    this.food = const {},
    this.weights = const [],
    this.phaseStarts = const [],
  });

  /// Set at onboarding and on "Reset learning". Nothing before it is used.
  final DateTime learningStartedOn;

  /// The prior (spec 6.5).
  final double formulaTdee;
  final BodyProfile body;

  /// Keyed by day.
  final Map<DateTime, FoodDay> food;

  /// Raw weigh-ins, any order. The trend and outliers come from these.
  final List<WeightReading> weights;

  /// Start days of the goal phases. Each restarts the settle period.
  final List<DateTime> phaseStarts;
}

/// The filter state after a day (spec 6.4).
class EstimatorState {
  const EstimatorState({
    required this.tdee,
    required this.variance,
    this.lastUpdateDay,
    this.day,
  });

  /// At the learning start: the formula TDEE with the prior variance.
  factory EstimatorState.initial(double formulaTdee) =>
      EstimatorState(tdee: formulaTdee, variance: kPriorSd * kPriorSd);

  final double tdee;
  final double variance;

  /// The last day an observation was used. Null while learning.
  final DateTime? lastUpdateDay;

  /// The last day replayed. Null before the first.
  final DateTime? day;

  double get sd => math.sqrt(variance);
}

/// One day's estimate: an `energy_estimates` row plus what the "How we got
/// this" card needs.
class EnergyEstimate {
  const EnergyEstimate({
    required this.day,
    required this.tdee,
    required this.tdeeSd,
    required this.state,
    required this.completeDays,
    required this.weighIns,
    required this.updated,
    this.trendWeightKg,
    this.slopeKgPerDay,
    this.avgIntake,
    this.lastUpdateDay,
    this.observedTdee,
    this.energyDensity,
    this.algoVersion = k.algoVersion,
  });

  final DateTime day;
  final double tdee;
  final double tdeeSd;
  final EnergyState state;

  /// Trend weight on [day].
  final double? trendWeightKg;

  /// OLS slope of the window's weigh-ins, kg/day.
  final double? slopeKgPerDay;

  /// Mean cals of the window's complete and fasting days, up to the day
  /// before [day] (that day's food isn't in its weigh-in yet).
  final double? avgIntake;

  /// Complete and fasting days in the window, up to the day before [day].
  final int completeDays;

  /// Weigh-ins in the window the trend didn't ignore.
  final int weighIns;

  /// Whether this day's observation moved the estimate (the gate passed).
  final bool updated;
  final DateTime? lastUpdateDay;

  /// `avgIntake − slope·ED`, when [updated].
  final double? observedTdee;

  /// Cals per kg used for the slope term, when [updated].
  final double? energyDensity;
  final int algoVersion;
}

/// The rows a replay produced and the state after the last of them.
class EstimatorRun {
  const EstimatorRun(this.estimates, this.state);

  final List<EnergyEstimate> estimates;
  final EstimatorState state;
}

/// An observed TDEE and its variance.
class Observation {
  const Observation({required this.tdee, required this.variance});

  final double tdee;
  final double variance;
}

/// Spec 6.4 step 4: `obs = intake − slope·ED`, with
/// `σ²obs = kOverlapInflation · [(slopeSE·ED)² + intakeSD²/n + kIntakeBiasSd²]`.
/// The inflation stands in for consecutive windows sharing most of their days.
Observation observe({
  required double avgIntake,
  required double intakeSd,
  required int countedDays,
  required double slopeKgPerDay,
  required double slopeSe,
  required double energyDensity,
  double overlapInflation = kOverlapInflation,
}) {
  final slopeTerm = slopeSe * energyDensity;
  return Observation(
    tdee: avgIntake - slopeKgPerDay * energyDensity,
    variance: overlapInflation *
        (slopeTerm * slopeTerm +
            intakeSd * intakeSd / countedDays +
            kIntakeBiasSd * kIntakeBiasSd),
  );
}

class KalmanStep {
  const KalmanStep({
    required this.tdee,
    required this.variance,
    required this.gain,
  });

  final double tdee;
  final double variance;
  final double gain;
}

/// Spec 6.4 step 5: `K = var/(var+σ²obs)`, the step `K·(obs − tdee)` clamped
/// to ±[kMaxDailyTdeeStep], `var = (1−K)·var`.
KalmanStep kalmanUpdate({
  required double tdee,
  required double variance,
  required Observation observation,
}) {
  final k = variance / (variance + observation.variance);
  final step = (k * (observation.tdee - tdee))
      .clamp(-kMaxDailyTdeeStep, kMaxDailyTdeeStep)
      .toDouble();
  return KalmanStep(tdee: tdee + step, variance: (1 - k) * variance, gain: k);
}

/// Spec 6.4 step 6, first match wins.
EnergyState stateFor({
  required bool paused,
  required bool everUpdated,
  required double variance,
}) {
  if (paused) return EnergyState.paused;
  if (!everUpdated) return EnergyState.learning;
  if (variance <= kConfidentSd * kConfidentSd) return EnergyState.confident;
  return EnergyState.estimated;
}

class OlsFit {
  const OlsFit({required this.slope, required this.slopeSe});

  final double slope;

  /// Standard error of [slope]: `√(SSR/(n−2) / Sxx)`.
  final double slopeSe;
}

/// Least-squares line through ([xs], [ys]). Null with fewer than 3 points or
/// when every x is the same.
OlsFit? olsFit(List<num> xs, List<num> ys) {
  final n = xs.length;
  if (n < 3 || ys.length != n) return null;
  final mx = xs.fold<double>(0, (a, x) => a + x) / n;
  final my = ys.fold<double>(0, (a, y) => a + y) / n;
  var sxx = 0.0, sxy = 0.0;
  for (var i = 0; i < n; i++) {
    sxx += (xs[i] - mx) * (xs[i] - mx);
    sxy += (xs[i] - mx) * (ys[i] - my);
  }
  if (sxx <= 0) return null;
  final slope = sxy / sxx;
  final intercept = my - slope * mx;
  var ssr = 0.0;
  for (var i = 0; i < n; i++) {
    final r = ys[i] - (intercept + slope * xs[i]);
    ssr += r * r;
  }
  return OlsFit(slope: slope, slopeSe: math.sqrt(ssr / (n - 2) / sxx));
}

/// The daily expenditure estimator (spec 6.4): a scalar Kalman-style filter
/// whose observation is a trailing window's mean intake minus the energy its
/// weight change accounts for.
///
/// Everything is causal: a day's row only uses data up to that day, and each
/// day is classified (complete / partial / …) against the estimate entering
/// it. So rows already stored never change when later data arrives, and a
/// replay resumed from a stored day matches a full replay.
class EnergyEstimator {
  /// [overlapInflation] is only overridden by the simulation harness when
  /// tuning [kOverlapInflation].
  EnergyEstimator(this.inputs, {this.overlapInflation = kOverlapInflation})
      : _learn = _dayOf(inputs.learningStartedOn),
        _readings = ([
          for (final w in inputs.weights) WeightReading(_dayOf(w.day), w.weightKg)
        ]..sort((a, b) => a.day.compareTo(b.day))),
        _food = {
          for (final e in inputs.food.entries) _dayOf(e.key): e.value,
        },
        _phaseStarts = (inputs.phaseStarts.map(_dayOf).toList()..sort());

  final EstimatorInputs inputs;
  final double overlapInflation;
  final DateTime _learn;
  final List<WeightReading> _readings;
  final Map<DateTime, FoodDay> _food;
  final List<DateTime> _phaseStarts;

  /// Replays each day from the day after [from] (or from the learning start)
  /// through [through], normally yesterday.
  ///
  /// When resuming, [tdeeByDay] gives the stored estimate at the end of each
  /// earlier day, so those days are classified as they were the first time.
  /// A day missing from it falls back to [from]'s estimate.
  EstimatorRun replay({
    required DateTime through,
    EstimatorState? from,
    Map<DateTime, double> tdeeByDay = const {},
  }) {
    var state = from ?? EstimatorState.initial(inputs.formulaTdee);
    final last = _dayOf(through);
    var d = from?.day == null ? _learn : _addDays(from!.day!, 1);
    if (d.isBefore(_learn)) d = _learn;

    final fallbackTdee = state.tdee;
    final tdeeEnd = {for (final e in tdeeByDay.entries) _dayOf(e.key): e.value};
    final classified = <DateTime, DayClassification?>{};

    DayClassification? classify(DateTime day) =>
        classified.putIfAbsent(day, () {
          final before = _addDays(day, -1);
          final threshold = tdeeEnd[before] ??
              (before.isBefore(_learn) ? inputs.formulaTdee : fallbackTdee);
          final food = _food[day];
          return classifyDay(
            day: day,
            today: _addDays(day, 1),
            explicit: food?.explicit,
            hasEntries: food?.hasEntries ?? false,
            loggedCals: food?.loggedCals ?? 0,
            tdeeEstimate: threshold,
          );
        });

    final rows = <EnergyEstimate>[];
    while (!d.isAfter(last)) {
      // 1. Predict.
      var tdee = state.tdee;
      var variance = state.variance + kProcessSdPerDay * kProcessSdPerDay;
      var lastUpdateDay = state.lastUpdateDay;

      // 2. Window.
      final windowStart =
          _later(_addDays(d, 1 - kWindowDays), _addDays(_lastSwitch(d), kSwitchSettleDays));

      // A weigh-in is taken in the morning, before that day's food, so the
      // weights on [windowStart, d] reflect the intake on [windowStart, d − 1]:
      // day d's intake only counts from day d + 1.
      final intakes = <double>[];
      for (var x = windowStart; x.isBefore(d); x = _addDays(x, 1)) {
        final c = classify(x);
        if (c != null && c.countsInIntake) {
          intakes.add(c.intakeCals(_food[x]?.loggedCals ?? 0));
        }
      }

      final upToD = _readings.where((r) => !r.day.isAfter(d));
      final trend = TrendSeries.compute(upToD);
      final used = trend.points
          .where((p) => !p.ignored && !p.day.isBefore(windowStart))
          .toList();
      final span =
          used.length < 2 ? 0 : _daysBetween(used.first.day, used.last.day);

      final avgIntake = intakes.isEmpty
          ? null
          : intakes.reduce((a, b) => a + b) / intakes.length;
      final fit = olsFit(
        [for (final p in used) _daysBetween(windowStart, p.day)],
        [for (final p in used) p.weightKg],
      );
      final trendKg = trend.trendOn(d);

      // 3. Gate (span counted inclusively: 7 calendar days).
      final gate = intakes.length >= kMinCompleteDays &&
          used.length >= kMinWeighIns &&
          span >= 6 &&
          fit != null &&
          trendKg != null;

      Observation? obs;
      double? ed;
      if (gate) {
        // 4. Observation.
        ed = inputs.body.energyDensityAt(trendKg);
        obs = observe(
          avgIntake: avgIntake!,
          intakeSd: _sampleSd(intakes, avgIntake),
          countedDays: intakes.length,
          slopeKgPerDay: fit.slope,
          slopeSe: fit.slopeSe,
          energyDensity: ed,
          overlapInflation: overlapInflation,
        );
        // 5. Update.
        final k = kalmanUpdate(tdee: tdee, variance: variance, observation: obs);
        tdee = k.tdee;
        variance = k.variance;
        lastUpdateDay = d;
      }

      // 6. State.
      final state6 = stateFor(
        paused: _paused(d, classify),
        everUpdated: lastUpdateDay != null,
        variance: variance,
      );

      // 7. Row.
      rows.add(EnergyEstimate(
        day: d,
        tdee: tdee,
        tdeeSd: math.sqrt(variance),
        state: state6,
        trendWeightKg: trendKg,
        slopeKgPerDay: fit?.slope,
        avgIntake: avgIntake,
        completeDays: intakes.length,
        weighIns: used.length,
        updated: gate,
        lastUpdateDay: lastUpdateDay,
        observedTdee: obs?.tdee,
        energyDensity: ed,
      ));
      state = EstimatorState(
          tdee: tdee, variance: variance, lastUpdateDay: lastUpdateDay, day: d);
      tdeeEnd[d] = tdee;
      d = _addDays(d, 1);
    }
    return EstimatorRun(List.unmodifiable(rows), state);
  }

  /// The latest of the learning start and the last phase start on or before
  /// [d].
  DateTime _lastSwitch(DateTime d) {
    var latest = _learn;
    for (final p in _phaseStarts) {
      if (p.isAfter(d)) break;
      latest = _later(latest, p);
    }
    return latest;
  }

  /// No complete days, or no weigh-ins at all (ignored ones included), in the
  /// last [kPausedAfterDays] days. Only once that many days of learning have
  /// passed: days before the learning start don't count against the user.
  bool _paused(DateTime d, DayClassification? Function(DateTime) classify) {
    final from = _addDays(d, 1 - kPausedAfterDays);
    if (from.isBefore(_learn)) return false;
    var ate = false;
    for (var x = from; !x.isAfter(d); x = _addDays(x, 1)) {
      if (classify(x)?.countsInIntake ?? false) {
        ate = true;
        break;
      }
    }
    final weighed =
        _readings.any((r) => !r.day.isBefore(from) && !r.day.isAfter(d));
    return !ate || !weighed;
  }
}

double _sampleSd(List<double> xs, double mean) {
  if (xs.length < 2) return 0;
  var ss = 0.0;
  for (final x in xs) {
    ss += (x - mean) * (x - mean);
  }
  return math.sqrt(ss / (xs.length - 1));
}

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime _addDays(DateTime d, int n) => DateTime(d.year, d.month, d.day + n);

DateTime _later(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

/// Whole calendar days from [a] to [b], safe across DST changes.
int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day)
        .difference(DateTime.utc(a.year, a.month, a.day))
        .inDays;
