import 'dart:math' as math;

import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/energy/trend_weight.dart';

/// The simulation harness for the expenditure estimator (spec §10 phase 1).
///
/// Each seed is a synthetic user whose real expenditure is known every day.
/// They diet from the learning start, log imperfectly and weigh in with
/// noise; the estimator only sees the logs and weigh-ins. Its target is the
/// **logged-basis TDEE**: the logged cals a day at which this user's weight
/// would hold steady, `(1 − underReporting) × true TDEE` (plan §2.4).
class SimConfig {
  const SimConfig({
    this.days = 84,
    this.tdeeMin = 1800,
    this.tdeeMax = 3200,
    this.weightNoiseSdKg = 0.7,
    this.untrackedRate = 0.20,
    this.partialRate = 0.10,
    this.partialLoggedFraction = 0.40,
    this.underReporting = 0.15,
    this.glycogenKg = 1.0,
    this.glycogenTauDays = 2,
    this.intakeDayCv = 0.15,
    this.formulaErrorSd = 300,
    this.adaptationPerKg = 15,
  });

  /// Days simulated from the learning start.
  final int days;

  /// True TDEE at the start, uniform in [tdeeMin, tdeeMax].
  final double tdeeMin;
  final double tdeeMax;

  /// Daily scale noise on top of tissue weight and glycogen.
  final double weightNoiseSdKg;

  /// Share of days with nothing logged.
  final double untrackedRate;

  /// Share of days logged only in part, at [partialLoggedFraction] of what
  /// would have been logged. No day has an explicit status: every day goes
  /// through the cals heuristic.
  final double partialRate;
  final double partialLoggedFraction;

  /// Constant share of eaten cals that never gets logged.
  final double underReporting;

  /// Glycogen and water shift at the diet start: down when losing, up when
  /// gaining, reaching [glycogenKg] with time constant [glycogenTauDays].
  final double glycogenKg;
  final double glycogenTauDays;

  /// Day-to-day variation of what's eaten, as a share of the mean.
  final double intakeDayCv;

  /// The formula TDEE prior's error against the logged-basis TDEE: normal with
  /// this sd, matching what the prior claims ([kPriorSd]).
  final double formulaErrorSd;

  /// Cals a day expenditure falls per kg of tissue lost (Mifflin's 10/kg ×
  /// a typical activity factor), so the truth drifts as the user diets.
  final double adaptationPerKg;
}

/// One synthetic user and what happened to them.
class SimulatedUser {
  SimulatedUser._({
    required this.seed,
    required this.inputs,
    required this.loggedBasisTdee,
    required this.goal,
    required this.pacePct,
  });

  /// A user drawn from [seed]: body, true TDEE, goal and pace, then [config]
  /// days of eating, logging and weighing in.
  factory SimulatedUser.generate(int seed, [SimConfig config = const SimConfig()]) {
    final rng = math.Random(seed);
    double normal() {
      // Box–Muller.
      final u1 = 1 - rng.nextDouble();
      final u2 = rng.nextDouble();
      return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
    }

    double uniform(double a, double b) => a + (b - a) * rng.nextDouble();

    final sex = rng.nextBool() ? Sex.male : Sex.female;
    final heightCm = sex == Sex.male ? 177 + 7 * normal() : 163 + 6 * normal();
    final age = 18 + rng.nextInt(48);
    final startBmi = uniform(20, 38);
    final w0 = startBmi * math.pow(heightCm / 100, 2);
    final body = BodyProfile(sex: sex, heightCm: heightCm, age: age);
    final tdee0 = uniform(config.tdeeMin, config.tdeeMax);

    final roll = rng.nextDouble();
    final goal = roll < 0.6
        ? GoalKind.lose
        : roll < 0.8
            ? GoalKind.maintain
            : GoalKind.gain;
    final pacePct = switch (goal) {
      GoalKind.lose => kLosePaceOptions[rng.nextInt(kLosePaceOptions.length)],
      GoalKind.gain => kGainPaceOptions[rng.nextInt(kGainPaceOptions.length)],
      GoalKind.maintain => 0.0,
    };
    // What they really eat on average: the pace's delta, within the deficit
    // and surplus limits.
    final delta = math.min(
      paceDeltaCals(
          pacePct: pacePct, weightKg: w0, energyDensity: body.energyDensityAt(w0)),
      tdee0 * (goal == GoalKind.lose ? kMaxDeficitFrac : kMaxSurplusFrac),
    );
    final meanEaten = switch (goal) {
      GoalKind.lose => tdee0 - delta,
      GoalKind.gain => tdee0 + delta,
      GoalKind.maintain => tdee0,
    };
    final glycogenSign = switch (goal) {
      GoalKind.lose => -1,
      GoalKind.gain => 1,
      GoalKind.maintain => 0,
    };

    final logged = 1 - config.underReporting;
    final formulaTdee = logged * tdee0 + config.formulaErrorSd * normal();

    final start = DateTime(2026, 1, 5);
    final food = <DateTime, FoodDay>{};
    final weights = <WeightReading>[];
    final truth = <double>[];
    var tissue = w0;
    for (var d = 0; d < config.days; d++) {
      final day = DateTime(start.year, start.month, start.day + d);
      final tdee = tdee0 - config.adaptationPerKg * (w0 - tissue);
      truth.add(logged * tdee);

      final glycogen = glycogenSign *
          config.glycogenKg *
          (1 - math.exp(-d / config.glycogenTauDays));
      weights.add(WeightReading(
          day, tissue + glycogen + config.weightNoiseSdKg * normal()));

      final eaten = math.max(0.0, meanEaten * (1 + config.intakeDayCv * normal()));
      final r = rng.nextDouble();
      if (r < config.untrackedRate) {
        // Nothing logged.
      } else if (r < config.untrackedRate + config.partialRate) {
        food[day] = FoodDay(
            loggedCals: logged * eaten * config.partialLoggedFraction);
      } else {
        food[day] = FoodDay(loggedCals: logged * eaten);
      }
      tissue += (eaten - tdee) / body.energyDensityAt(tissue);
    }

    return SimulatedUser._(
      seed: seed,
      goal: goal,
      pacePct: pacePct,
      loggedBasisTdee: List.unmodifiable(truth),
      inputs: EstimatorInputs(
        learningStartedOn: start,
        formulaTdee: formulaTdee,
        body: body,
        food: food,
        weights: weights,
      ),
    );
  }

  final int seed;
  final EstimatorInputs inputs;
  final GoalKind goal;
  final double pacePct;

  /// The truth the estimator is scored against, one per simulated day.
  final List<double> loggedBasisTdee;

  /// The estimator's rows for every simulated day.
  List<EnergyEstimate> estimate({double overlapInflation = kOverlapInflation}) {
    final s = inputs.learningStartedOn;
    final last =
        DateTime(s.year, s.month, s.day + loggedBasisTdee.length - 1);
    return EnergyEstimator(inputs, overlapInflation: overlapInflation)
        .replay(through: last)
        .estimates;
  }
}

/// What the acceptance bar looks at, over many seeds.
class SimReport {
  SimReport._({
    required this.seeds,
    required this.day28Errors,
    required this.calibration,
    required this.maxStep,
  });

  /// Runs seeds `0 … seeds − 1`.
  factory SimReport.run({
    int seeds = 200,
    SimConfig config = const SimConfig(),
    double overlapInflation = kOverlapInflation,
  }) {
    final errors = <double>[];
    var inBand = 0, seedDays = 0;
    var maxStep = 0.0;
    for (var seed = 0; seed < seeds; seed++) {
      final user = SimulatedUser.generate(seed, config);
      final rows = user.estimate(overlapInflation: overlapInflation);
      var prev = user.inputs.formulaTdee;
      for (var d = 0; d < rows.length; d++) {
        final r = rows[d];
        final truth = user.loggedBasisTdee[d];
        if ((r.tdee - truth).abs() <= 1.28 * r.tdeeSd) inBand++;
        seedDays++;
        maxStep = math.max(maxStep, (r.tdee - prev).abs());
        prev = r.tdee;
      }
      errors.add((rows[day28Index].tdee - user.loggedBasisTdee[day28Index]).abs());
    }
    return SimReport._(
      seeds: seeds,
      day28Errors: errors,
      calibration: inBand / seedDays,
      maxStep: maxStep,
    );
  }

  /// Day 28 counting the learning start as day 1.
  static const int day28Index = 27;

  final int seeds;

  /// `|estimate − logged-basis TDEE|` on day 28, one per seed.
  final List<double> day28Errors;

  /// Share of seed-days with the truth within ±1.28 sd of the estimate.
  final double calibration;

  /// Largest day-to-day change of any seed (day 1 against the formula).
  final double maxStep;

  /// Share of seeds within [cals] of the truth on day 28.
  double within(double cals) =>
      day28Errors.where((e) => e <= cals).length / day28Errors.length;

  @override
  String toString() {
    final sorted = [...day28Errors]..sort();
    double q(double p) => sorted[((sorted.length - 1) * p).round()];
    return 'seeds $seeds · day 28 within 150: '
        '${(within(150) * 100).toStringAsFixed(1)}% '
        '(median ${q(0.5).round()}, p90 ${q(0.9).round()}) · '
        'calibration ${(calibration * 100).toStringAsFixed(1)}% · '
        'max step ${maxStep.toStringAsFixed(1)}';
  }
}

/// The share of users an ideal estimator gets within [cals] on day 28 when
/// only the scale noise is in the way: no glycogen, no under-reporting, every
/// day logged in full at a constant intake, expenditure that doesn't drift.
/// It fits all 28 raw weigh-ins by OLS with the true energy density and
/// combines that with the formula prior, each weighted by its true variance.
///
/// This bounds what any estimator can reach in the spec's scenario.
double noiseOnlyOracleWithin(double cals, {int seeds = 2000}) {
  const clean = SimConfig(
    days: 28,
    glycogenKg: 0,
    underReporting: 0,
    untrackedRate: 0,
    partialRate: 0,
    intakeDayCv: 0,
    adaptationPerKg: 0,
  );
  const n = 28;
  final xs = [for (var i = 0; i < n; i++) i];
  final priorVar = clean.formulaErrorSd * clean.formulaErrorSd;
  var hits = 0;
  for (var seed = 0; seed < seeds; seed++) {
    final u = SimulatedUser.generate(seed, clean);
    final weights = [for (final w in u.inputs.weights) w.weightKg];
    final slope = olsFit(xs, weights)!.slope;
    final intake = u.inputs.food.values.first.loggedCals;
    final ed = u.inputs.body.energyDensityAt(weights.first);
    final obs = intake - slope * ed;
    // Var of an OLS slope over n daily points: σ² / Sxx, Sxx = n(n²−1)/12.
    final obsVar = clean.weightNoiseSdKg *
        clean.weightNoiseSdKg /
        (n * (n * n - 1) / 12) *
        ed *
        ed;
    final best = (obs / obsVar + u.inputs.formulaTdee / priorVar) /
        (1 / obsVar + 1 / priorVar);
    if ((best - u.loggedBasisTdee.last).abs() <= cals) hits++;
  }
  return hits / seeds;
}
