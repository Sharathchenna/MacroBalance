import 'dart:math';

import 'body_composition.dart';
import 'constants.dart';
import 'phase_engine.dart';
import 'targets.dart';

/// One simulated week.
class ProjectedWeek {
  const ProjectedWeek({
    required this.phaseSeq,
    required this.startKg,
    required this.endKg,
    required this.tdee,
    required this.cals,
  });

  /// The phase the week belongs to.
  final int phaseSeq;
  final double startKg;
  final double endKg;

  /// Expenditure during the week.
  final double tdee;

  /// The daily target eaten during the week.
  final double cals;
}

/// One phase as the projection expects it to run, from today.
class ProjectedPhase {
  const ProjectedPhase({
    required this.seq,
    required this.kind,
    required this.weeks,
    required this.startKg,
    required this.endKg,
    required this.endReason,
  });

  final int seq;
  final PhaseKind kind;

  /// Projected weeks in the phase (from today for the open one). Whole
  /// weeks, as phases end at check-ins, except the last week to the goal.
  final double weeks;
  final double startKg;
  final double endKg;

  /// Null: still running when the projection stopped (156 weeks).
  final PhaseEndReason? endReason;
}

/// How a lose plan unfolds, for "3 loss phases + 2 breaks · about 34 weeks".
class PlanOutline {
  const PlanOutline({
    required this.lossPhases,
    required this.breaks,
    required this.weeks,
    required this.lossWeeks,
  });

  final int lossPhases;
  final int breaks;

  /// To the goal, breaks included.
  final int weeks;

  /// Weeks spent losing.
  final int lossWeeks;
}

/// Weeks to the goal weight (spec 6.9): the one source for every "about N
/// weeks" in the app.
class Projection {
  const Projection({
    required this.on,
    required this.weeks,
    required this.reached,
    required this.path,
    required this.phases,
  });

  /// The day the projection starts (today).
  final DateTime on;

  /// Fractional weeks to the goal: 0 at or past it, null when there's no
  /// goal or it isn't reached within [kMaxProjectionWeeks].
  final double? weeks;
  final bool reached;
  final List<ProjectedWeek> path;
  final List<ProjectedPhase> phases;

  double? get weeksLow => weeks == null ? null : weeks! * kProjectionLowFactor;
  double? get weeksHigh => weeks == null ? null : weeks! * kProjectionHighFactor;

  DateTime? get date => _dayAfter(weeks);
  DateTime? get earliest => _dayAfter(weeksLow);
  DateTime? get latest => _dayAfter(weeksHigh);

  /// "About N weeks": whole weeks, at least 1 unless already there.
  int? get aboutWeeks => weeks == null ? null : (weeks == 0 ? 0 : max(1, weeks!.round()));

  int get lossPhases => phases.where((p) => p.kind == PhaseKind.lose).length;
  int get breaks => phases.where((p) => p.kind == PhaseKind.maintain).length;

  /// The plan's shape to the goal; null when it doesn't get there.
  PlanOutline? get outline => weeks == null || weeks == 0
      ? null
      : PlanOutline(
          lossPhases: lossPhases,
          breaks: breaks,
          weeks: aboutWeeks!,
          lossWeeks: phases
              .where((p) => p.kind == PhaseKind.lose)
              .fold<double>(0, (a, p) => a + p.weeks)
              .round(),
        );

  DateTime? _dayAfter(double? w) =>
      w == null ? null : DateTime(on.year, on.month, on.day + (w * 7).round());
}

/// Simulates the plan week by week from [weightKg] (the trend) to
/// [goalWeightKg] (spec 6.9):
/// - energy density from the fat mass at each week's weight;
/// - `ΔW = 7·(cals − tdee)/ED`;
/// - expenditure moves with the weight by Mifflin's 10 cals/kg × activity;
/// - adaptive: the target is worked out again each week (spec 6.6, the
///   chosen pace of the current weight, through the safety limits); fixed
///   targets keep a phase's target until the next phase (the open phase
///   keeps [cals] when given);
/// - phased and diet-break plans run the phase engine at each weekly
///   check-in, from [phase] (the open one) or a fresh plan.
///
/// Stops at the goal or [kMaxProjectionWeeks].
Projection projectToGoal({
  required GoalKind goal,
  required double weightKg,
  required double? goalWeightKg,
  required double tdee,
  required double pacePct,
  required BodyProfile body,
  required DateTime on,
  bool adaptive = true,
  double? cals,
  PlanStyle style = PlanStyle.steady,
  GoalPhase? phase,
  PhaseSettings phaseSettings = const PhaseSettings(),
}) {
  final day0 = DateTime(on.year, on.month, on.day);
  final g = goalWeightKg;
  if (goal == GoalKind.maintain || g == null || g <= 0 || weightKg <= 0) {
    return Projection(on: day0, weeks: null, reached: false, path: const [], phases: const []);
  }
  bool atGoal(double kg) => goal == GoalKind.lose ? kg <= g : kg >= g;
  if (atGoal(weightKg)) {
    return Projection(on: day0, weeks: 0, reached: true, path: const [], phases: const []);
  }

  double targetFor(PhaseKind kind, double kg, double tdee) => targetForPace(
        goal: kind.goal,
        pacePct: pacePct,
        tdee: tdee,
        sex: body.sex,
        weightKg: kg,
        energyDensity: body.energyDensityAt(kg),
      ).cals;

  var current = phase ??
      firstPhase(
          style: style,
          goal: goal,
          seq: 1,
          on: day0,
          trendKg: weightKg,
          heightCm: body.heightCm,
          settings: phaseSettings);
  var w = weightKg;
  var expenditure = tdee;
  var target = cals ?? targetFor(current.kind, w, expenditure);
  var phaseWeeks = 0.0;
  var phaseStartKg = w;
  final af = body.bmrMultiplier;
  final path = <ProjectedWeek>[];
  final phases = <ProjectedPhase>[];
  double? weeks;

  void endPhase(PhaseEndReason? reason, double endKg) => phases.add(ProjectedPhase(
      seq: current.seq,
      kind: current.kind,
      weeks: phaseWeeks,
      startKg: phaseStartKg,
      endKg: endKg,
      endReason: reason));

  for (var k = 1; k <= kMaxProjectionWeeks; k++) {
    if (adaptive) target = targetFor(current.kind, w, expenditure);
    final dW = 7 * (target - expenditure) / body.energyDensityAt(w);
    final next = w + dW;
    path.add(ProjectedWeek(
        phaseSeq: current.seq, startKg: w, endKg: next, tdee: expenditure, cals: target));
    expenditure += kMifflinKcalPerKg * dW * af;

    if (atGoal(next)) {
      // Part of this week: where the line crosses the goal.
      final part = dW == 0 ? 1.0 : ((g - w) / dW).clamp(0.0, 1.0);
      weeks = k - 1 + part;
      phaseWeeks += part;
      endPhase(PhaseEndReason.goalReached, g);
      break;
    }
    w = next;
    phaseWeeks += 1;

    final checkin = DateTime(day0.year, day0.month, day0.day + 7 * k);
    final reason =
        dueToEnd(current, on: checkin, trendKg: w, goalWeightKg: g, goal: goal);
    if (reason == null) continue;
    final following = nextPhase(
        after: current,
        style: style,
        goal: goal,
        on: checkin,
        trendKg: w,
        heightCm: body.heightCm,
        settings: phaseSettings);
    if (following == null) continue;
    endPhase(reason, w);
    current = following;
    phaseWeeks = 0;
    phaseStartKg = w;
    target = targetFor(current.kind, w, expenditure);
  }
  if (weeks == null) endPhase(null, w);

  return Projection(
      on: day0, weeks: weeks, reached: weeks != null, path: path, phases: phases);
}
