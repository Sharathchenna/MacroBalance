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
    this.goal,
    this.switches = const [],
    this.knowsPhaseStarts = true,
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

  /// Every user gets this goal instead of the 60/20/20 draw.
  final GoalKind? goal;

  /// Phase switches (ticket 18), in day order. The estimator gets each day as
  /// a phase start. Empty: one phase throughout.
  final List<SimSwitch> switches;

  /// Whether the estimator is told about [switches]. False is a comparator
  /// only: the diet switches but the estimator doesn't know.
  final bool knowsPhaseStarts;
}

/// The user's diet changes on [day] (0 = the learning start).
class SimSwitch {
  const SimSwitch(this.day, this.to, {this.reboundKg = 0});

  final int day;

  /// The new phase. Maintain eats the true TDEE of the switch day; lose and
  /// gain eat it ∓ the drawn pace's deficit/surplus (so switching back to
  /// lose needs a lose [SimConfig.goal]).
  final GoalKind to;

  /// Water and glycogen gained (negative: lost) after the switch, reached
  /// with time constant [SimConfig.glycogenTauDays]: e.g. +1 kg as a diet
  /// ends, −1 kg as it starts again.
  final double reboundKg;
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
    final goal = config.goal ??
        (roll < 0.6
            ? GoalKind.lose
            : roll < 0.8
                ? GoalKind.maintain
                : GoalKind.gain);
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
    double eatingFor(GoalKind kind, double tdee) => switch (kind) {
          GoalKind.lose => tdee - delta,
          GoalKind.gain => tdee + delta,
          GoalKind.maintain => tdee,
        };
    var meanEaten = eatingFor(goal, tdee0);
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

      var glycogen = glycogenSign *
          config.glycogenKg *
          (1 - math.exp(-d / config.glycogenTauDays));
      for (final s in config.switches) {
        if (d == s.day) meanEaten = eatingFor(s.to, tdee);
        if (d >= s.day) {
          glycogen += s.reboundKg *
              (1 - math.exp(-(d - s.day) / config.glycogenTauDays));
        }
      }
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
        phaseStarts: [
          if (config.knowsPhaseStarts)
            for (final s in config.switches)
              DateTime(start.year, start.month, start.day + s.day),
        ],
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
  ///
  /// [knownReporting] is a comparator, not the spec: it scales the energy
  /// density by `1 − underReporting`, so the observation becomes
  /// `intake − 0.85·slope·ED`, which is unbiased for the logged-basis TDEE.
  /// It measures how much of the error the spec's observation bias explains.
  List<EnergyEstimate> estimate({
    double overlapInflation = kOverlapInflation,
    double? knownReporting,
  }) {
    final s = inputs.learningStartedOn;
    final last =
        DateTime(s.year, s.month, s.day + loggedBasisTdee.length - 1);
    final i = knownReporting == null
        ? inputs
        : EstimatorInputs(
            learningStartedOn: inputs.learningStartedOn,
            formulaTdee: inputs.formulaTdee,
            body: _ScaledBody(inputs.body, 1 - knownReporting),
            food: inputs.food,
            weights: inputs.weights,
            phaseStarts: inputs.phaseStarts,
          );
    return EnergyEstimator(i, overlapInflation: overlapInflation)
        .replay(through: last)
        .estimates;
  }
}

class _ScaledBody extends BodyProfile {
  _ScaledBody(BodyProfile b, this.factor)
      : super(
            sex: b.sex,
            heightCm: b.heightCm,
            age: b.age,
            bodyFatPct: b.bodyFatPct);

  final double factor;

  @override
  double energyDensityAt(double weightKg) =>
      factor * super.energyDensityAt(weightKg);
}

/// The seeds the harness was tuned on. Ablations and the bias checks use
/// [kHeldOutSeeds] instead.
const int kTuningSeeds = 200;

/// A seed range never used for tuning: seeds 10,000 … 10,999.
const int kHeldOutFirstSeed = 10000;
const int kHeldOutSeeds = 1000;

/// What the acceptance bar looks at, over many seeds.
class SimReport {
  SimReport._({
    required this.seeds,
    required this.errors,
    required this.goals,
    required this.calibration,
    required this.maxStep,
  });

  /// Runs seeds `firstSeed … firstSeed + seeds − 1`.
  factory SimReport.run({
    int firstSeed = 0,
    int seeds = kTuningSeeds,
    SimConfig config = const SimConfig(),
    double overlapInflation = kOverlapInflation,
    bool knownReporting = false,
  }) {
    final errors = <List<double>>[];
    final goals = <GoalKind>[];
    var inBand = 0, seedDays = 0;
    var maxStep = 0.0;
    for (var seed = firstSeed; seed < firstSeed + seeds; seed++) {
      final user = SimulatedUser.generate(seed, config);
      final rows = user.estimate(
          overlapInflation: overlapInflation,
          knownReporting: knownReporting ? config.underReporting : null);
      var prev = user.inputs.formulaTdee;
      final e = <double>[];
      for (var d = 0; d < rows.length; d++) {
        final r = rows[d];
        final truth = user.loggedBasisTdee[d];
        if ((r.tdee - truth).abs() <= 1.28 * r.tdeeSd) inBand++;
        seedDays++;
        maxStep = math.max(maxStep, (r.tdee - prev).abs());
        prev = r.tdee;
        e.add(r.tdee - truth);
      }
      errors.add(e);
      goals.add(user.goal);
    }
    return SimReport._(
      seeds: seeds,
      errors: errors,
      goals: goals,
      calibration: inBand / seedDays,
      maxStep: maxStep,
    );
  }

  final int seeds;

  /// `estimate − logged-basis TDEE` per seed, per day (index 0 = day 1).
  final List<List<double>> errors;
  final List<GoalKind> goals;

  /// Share of seed-days with the truth within ±1.28 sd of the estimate.
  final double calibration;

  /// Largest day-to-day change of any seed (day 1 against the formula).
  final double maxStep;

  /// `|error|` on [day] (counting the learning start as day 1), per seed.
  List<double> absErrorsOn(int day) =>
      [for (final e in errors) e[day - 1].abs()];

  /// Share of seeds within [cals] of the truth on [day].
  double within(double cals, {int day = 28}) {
    final a = absErrorsOn(day);
    return a.where((e) => e <= cals).length / a.length;
  }

  /// Mean signed error on [day] for the seeds with [goal].
  double meanError(GoalKind goal, {int day = 28}) {
    var sum = 0.0, n = 0;
    for (var i = 0; i < errors.length; i++) {
      if (goals[i] != goal) continue;
      sum += errors[i][day - 1];
      n++;
    }
    return n == 0 ? 0 : sum / n;
  }

  /// [p] quantile of `|error|` on [day].
  double quantile(double p, {int day = 28}) {
    final a = absErrorsOn(day)..sort();
    return a[((a.length - 1) * p).round()];
  }

  @override
  String toString() =>
      'seeds $seeds · day 28 within 150: '
      '${(within(150) * 100).toStringAsFixed(1)}%, within 250: '
      '${(within(250) * 100).toStringAsFixed(1)}% '
      '(median ${quantile(0.5).round()}, p90 ${quantile(0.9).round()}) · '
      'calibration ${(calibration * 100).toStringAsFixed(1)}% · '
      'max step ${maxStep.toStringAsFixed(1)}';
}
