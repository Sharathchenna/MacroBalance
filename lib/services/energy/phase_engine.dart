import 'dart:math';

import 'constants.dart';
import 'estimate_rows.dart' show dayKey, parseDay;
import 'targets.dart';

/// How a weight-loss plan is arranged (spec §2, plan 4.6). The codes are
/// `user_macros.plan_style`'s.
enum PlanStyle {
  /// One continuous phase at the chosen pace until the goal.
  steady,

  /// Lose X% of the phase's start, maintain M weeks, repeat.
  phased,

  /// Lose for 8 weeks, maintain 2, repeat.
  breaks;

  String get code => name;

  /// Unknown or missing codes read as [steady], the column default.
  static PlanStyle fromCode(Object? code) =>
      values.asNameMap()['$code'] ?? PlanStyle.steady;
}

/// What a phase aims for. The codes are `goal_phases.kind`'s.
enum PhaseKind {
  lose,
  maintain,
  gain;

  GoalKind get goal => switch (this) {
        lose => GoalKind.lose,
        maintain => GoalKind.maintain,
        gain => GoalKind.gain,
      };

  static PhaseKind of(GoalKind goal) => switch (goal) {
        GoalKind.lose => lose,
        GoalKind.maintain => maintain,
        GoalKind.gain => gain,
      };
}

/// Why a phase ended (`goal_phases.end_reason`).
enum PhaseEndReason {
  /// A phased lose phase got to its X%.
  reached('reached'),

  /// A phased lose phase ran [kMaxLossPhaseWeeks].
  maxDuration('max_duration'),

  /// A maintenance or diet-break lose phase ran its planned weeks.
  planned('planned'),

  /// A maintenance phase the user skipped ("Keep losing").
  skipped('skipped'),

  /// "End phase early", at the check-in after the request.
  userEnded('user_ended'),

  /// The trend crossed the goal weight.
  goalReached('goal_reached'),

  /// A recalculation changed the plan style, goal or pace.
  replanned('replanned');

  const PhaseEndReason(this.code);

  final String code;

  static PhaseEndReason? fromCode(Object? code) {
    for (final r in values) {
      if (r.code == code) return r;
    }
    return null;
  }
}

/// The user's phase settings (`user_macros` columns); null keeps the default.
class PhaseSettings {
  const PhaseSettings({
    this.lossPct,
    this.maintenanceWeeks = kMaintenanceWeeks,
    this.breakEveryWeeks = kBreakEveryWeeks,
    this.breakWeeks = kBreakWeeks,
  });

  /// X: % of the start trend a phased lose phase aims to lose. Null: by BMI.
  final double? lossPct;

  /// M: weeks of maintenance between phased lose phases.
  final int maintenanceWeeks;

  /// Weeks of losing before each diet break.
  final int breakEveryWeeks;

  /// Weeks of each diet break.
  final int breakWeeks;
}

/// X for a phase starting at [weightKg]: 10% from BMI 30, otherwise 5%, or
/// the user's setting. Unknown height counts as under BMI 30.
double phaseLossPct({
  required double weightKg,
  double? heightCm,
  PhaseSettings settings = const PhaseSettings(),
}) {
  if (settings.lossPct != null) return settings.lossPct!;
  if (heightCm == null || heightCm <= 0) return kPhasedLossPct;
  final m = heightCm / 100;
  return weightKg / (m * m) >= 30 ? kPhasedLossPctObese : kPhasedLossPct;
}

/// The plan style offered first for a lose goal (plan 10.3): in phases when
/// the goal is more than 10% of body weight away, otherwise steady.
PlanStyle defaultPlanStyle({required double weightKg, required double goalWeightKg}) =>
    weightKg > 0 && (weightKg - goalWeightKg) / weightKg > kPhasedDefaultGoalFrac
        ? PlanStyle.phased
        : PlanStyle.steady;

/// One stretch of lose, maintain or gain with its own target rule: a
/// `goal_phases` row. Phases are numbered by [seq]; at most one is open.
class GoalPhase {
  const GoalPhase({
    required this.seq,
    required this.kind,
    required this.startedOn,
    required this.startTrendKg,
    this.targetPct,
    this.plannedWeeks,
    this.maxWeeks,
    this.endedOn,
    this.endReason,
    this.endRequestedOn,
  });

  final int seq;
  final PhaseKind kind;
  final DateTime startedOn;

  /// Trend weight on [startedOn]; phase progress is measured from it.
  final double startTrendKg;

  /// Phased lose phases: the % of [startTrendKg] to lose.
  final double? targetPct;

  /// Maintenance and diet-break lose phases: how long they run.
  final int? plannedWeeks;

  /// Phased lose phases: the longest they run.
  final int? maxWeeks;

  final DateTime? endedOn;
  final PhaseEndReason? endReason;

  /// "End phase early" was asked on this day; the next check-in ends it.
  final DateTime? endRequestedOn;

  bool get isOpen => endedOn == null;

  /// The trend that ends a phased lose phase.
  double? get targetTrendKg =>
      targetPct == null ? null : startTrendKg * (1 - targetPct! / 100);

  /// Weeks from the start to [day], fractional.
  double weeksOn(DateTime day) => _daysBetween(startedOn, day) / 7;

  GoalPhase close(DateTime on, PhaseEndReason reason) =>
      _copy(endedOn: _dayOf(on), endReason: reason);

  GoalPhase _copy({
    int? plannedWeeks,
    DateTime? endedOn,
    PhaseEndReason? endReason,
    DateTime? endRequestedOn,
    bool reopen = false,
  }) =>
      GoalPhase(
        seq: seq,
        kind: kind,
        startedOn: startedOn,
        startTrendKg: startTrendKg,
        targetPct: targetPct,
        plannedWeeks: plannedWeeks ?? this.plannedWeeks,
        maxWeeks: maxWeeks,
        endedOn: reopen ? null : endedOn ?? this.endedOn,
        endReason: reopen ? null : endReason ?? this.endReason,
        endRequestedOn: reopen ? null : endRequestedOn ?? this.endRequestedOn,
      );

  /// The `goal_phases` columns (without `id`/`user_id`), also the cache form.
  Map<String, Object?> toJson() => {
        'seq': seq,
        'kind': kind.name,
        'started_on': dayKey(startedOn),
        'start_trend_kg': double.parse(startTrendKg.toStringAsFixed(2)),
        'target_pct': targetPct,
        'planned_weeks': plannedWeeks,
        'max_weeks': maxWeeks,
        'ended_on': endedOn == null ? null : dayKey(endedOn!),
        'end_reason': endReason?.code,
        'end_requested_on': endRequestedOn == null ? null : dayKey(endRequestedOn!),
      };

  /// From a cache entry or a `goal_phases` row; null when unreadable.
  static GoalPhase? fromJson(Object? json) {
    if (json is! Map) return null;
    final seq = (json['seq'] as num?)?.toInt();
    final kind = PhaseKind.values.asNameMap()[json['kind']];
    final started = parseDay(json['started_on']);
    final trend = _num(json['start_trend_kg']);
    if (seq == null || kind == null || started == null || trend == null) return null;
    return GoalPhase(
      seq: seq,
      kind: kind,
      startedOn: started,
      startTrendKg: trend,
      targetPct: _num(json['target_pct']),
      plannedWeeks: _num(json['planned_weeks'])?.toInt(),
      maxWeeks: _num(json['max_weeks'])?.toInt(),
      endedOn: parseDay(json['ended_on']),
      endReason: PhaseEndReason.fromCode(json['end_reason']),
      endRequestedOn: parseDay(json['end_requested_on']),
    );
  }

  static double? _num(Object? v) =>
      v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);

  @override
  bool operator ==(Object other) =>
      other is GoalPhase &&
      other.seq == seq &&
      other.kind == kind &&
      other.startedOn == startedOn &&
      other.startTrendKg == startTrendKg &&
      other.targetPct == targetPct &&
      other.plannedWeeks == plannedWeeks &&
      other.maxWeeks == maxWeeks &&
      other.endedOn == endedOn &&
      other.endReason == endReason &&
      other.endRequestedOn == endRequestedOn;

  @override
  int get hashCode => Object.hash(seq, kind, startedOn, startTrendKg, targetPct,
      plannedWeeks, maxWeeks, endedOn, endReason, endRequestedOn);

  @override
  String toString() => 'Phase $seq ${kind.name} from ${dayKey(startedOn)}'
      '${endedOn == null ? '' : ' to ${dayKey(endedOn!)} (${endReason?.code})'}';
}

/// The open phase, or null when there is none (no plan yet, or it ended at
/// the goal).
GoalPhase? currentPhase(Iterable<GoalPhase> phases) {
  GoalPhase? out;
  for (final p in phases) {
    if (p.isOpen && (out == null || p.seq > out.seq)) out = p;
  }
  return out;
}

/// The first phase of a fresh sequence (spec 6.7). Only lose goals have
/// phased or diet-break plans; anything else is one open-ended phase of the
/// goal.
GoalPhase firstPhase({
  required PlanStyle style,
  required GoalKind goal,
  required int seq,
  required DateTime on,
  required double trendKg,
  double? heightCm,
  PhaseSettings settings = const PhaseSettings(),
}) {
  final day = _dayOf(on);
  if (goal != GoalKind.lose || style == PlanStyle.steady) {
    return GoalPhase(seq: seq, kind: PhaseKind.of(goal), startedOn: day, startTrendKg: trendKg);
  }
  return style == PlanStyle.phased
      ? GoalPhase(
          seq: seq,
          kind: PhaseKind.lose,
          startedOn: day,
          startTrendKg: trendKg,
          targetPct: phaseLossPct(weightKg: trendKg, heightCm: heightCm, settings: settings),
          maxWeeks: kMaxLossPhaseWeeks,
        )
      : GoalPhase(
          seq: seq,
          kind: PhaseKind.lose,
          startedOn: day,
          startTrendKg: trendKg,
          plannedWeeks: settings.breakEveryWeeks,
        );
}

/// The phase after [after] in a phased or diet-break lose plan, starting
/// [on] at [trendKg]: maintenance after losing, losing after maintenance.
/// Null for steady plans and other goals.
GoalPhase? nextPhase({
  required GoalPhase after,
  required PlanStyle style,
  required GoalKind goal,
  required DateTime on,
  required double trendKg,
  double? heightCm,
  PhaseSettings settings = const PhaseSettings(),
}) {
  if (goal != GoalKind.lose || style == PlanStyle.steady) return null;
  return switch (after.kind) {
    PhaseKind.lose => GoalPhase(
        seq: after.seq + 1,
        kind: PhaseKind.maintain,
        startedOn: _dayOf(on),
        startTrendKg: trendKg,
        plannedWeeks:
            style == PlanStyle.phased ? settings.maintenanceWeeks : settings.breakWeeks,
      ),
    PhaseKind.maintain => firstPhase(
        style: style,
        goal: GoalKind.lose,
        seq: after.seq + 1,
        on: on,
        trendKg: trendKg,
        heightCm: heightCm,
        settings: settings,
      ),
    PhaseKind.gain => null,
  };
}

/// Why [phase] is due to end on [on] at trend [trendKg] (spec 6.7 table), or
/// null when it isn't. The goal comes first, then the user's request, then
/// the phase's own rule.
PhaseEndReason? dueToEnd(
  GoalPhase phase, {
  required DateTime on,
  required double trendKg,
  required double? goalWeightKg,
  required GoalKind goal,
}) {
  if (!phase.isOpen) return null;
  final g = goalWeightKg;
  if (g != null && g > 0) {
    if (goal == GoalKind.lose && trendKg <= g) return PhaseEndReason.goalReached;
    if (goal == GoalKind.gain && trendKg >= g) return PhaseEndReason.goalReached;
  }
  final day = _dayOf(on);
  if (phase.endRequestedOn != null && !day.isBefore(phase.endRequestedOn!)) {
    return PhaseEndReason.userEnded;
  }
  final weeks = phase.weeksOn(day);
  final target = phase.targetTrendKg;
  if (phase.kind == PhaseKind.lose && target != null && trendKg <= target) {
    return PhaseEndReason.reached;
  }
  if (phase.kind == PhaseKind.lose && phase.maxWeeks != null && weeks >= phase.maxWeeks!) {
    return PhaseEndReason.maxDuration;
  }
  if (phase.plannedWeeks != null && weeks >= phase.plannedWeeks!) {
    return PhaseEndReason.planned;
  }
  return null;
}

/// A phase ending into the next one at a check-in (spec 6.8 rows 2–3).
class PhaseTransition {
  const PhaseTransition({required this.ended, required this.next});

  /// The open phase, closed on the check-in day.
  final GoalPhase ended;

  /// Starts on the check-in day.
  final GoalPhase next;

  /// Variant F (to maintenance) rather than G (back to losing).
  bool get toMaintain => next.kind == PhaseKind.maintain;

  Map<String, Object?> toJson() => {'ended': ended.toJson(), 'next': next.toJson()};

  static PhaseTransition? fromJson(Object? json) {
    if (json is! Map) return null;
    final ended = GoalPhase.fromJson(json['ended']);
    final next = GoalPhase.fromJson(json['next']);
    if (ended == null || next == null) return null;
    return PhaseTransition(ended: ended, next: next);
  }
}

/// The phase change a check-in [on] makes, or null when the open phase
/// isn't due to end into another one. Reaching the goal is left to
/// decision row 1.
PhaseTransition? phaseTransition({
  required Iterable<GoalPhase> phases,
  required PlanStyle style,
  required GoalKind goal,
  required DateTime on,
  required double trendKg,
  required double? goalWeightKg,
  double? heightCm,
  PhaseSettings settings = const PhaseSettings(),
}) {
  final open = currentPhase(phases);
  if (open == null) return null;
  final reason =
      dueToEnd(open, on: on, trendKg: trendKg, goalWeightKg: goalWeightKg, goal: goal);
  if (reason == null || reason == PhaseEndReason.goalReached) return null;
  final next = nextPhase(
    after: open,
    style: style,
    goal: goal,
    on: on,
    trendKg: trendKg,
    heightCm: heightCm,
    settings: settings,
  );
  if (next == null) return null;
  return PhaseTransition(ended: open.close(on, reason), next: next);
}

// --- Changes to the phases ---

/// Phases to write and phases to remove, by [GoalPhase.seq].
class PhaseEdit {
  const PhaseEdit({this.upserts = const [], this.deletes = const {}});

  static const none = PhaseEdit();

  final List<GoalPhase> upserts;
  final Set<int> deletes;

  bool get isEmpty => upserts.isEmpty && deletes.isEmpty;

  /// [phases] with the edit made, by seq.
  List<GoalPhase> applyTo(Iterable<GoalPhase> phases) {
    final bySeq = {for (final p in phases) p.seq: p};
    for (final s in deletes) {
      bySeq.remove(s);
    }
    for (final p in upserts) {
      bySeq[p.seq] = p;
    }
    return bySeq.values.toList()..sort((a, b) => a.seq.compareTo(b.seq));
  }
}

/// Makes a check-in's [transition], unless it has been made or overtaken
/// already: the phase it ends must still be open exactly as it was (an
/// extended break isn't), and the phase it starts mustn't exist yet.
PhaseEdit applyTransition(Iterable<GoalPhase> phases, PhaseTransition transition) {
  final bySeq = {for (final p in phases) p.seq: p};
  final ending = bySeq[transition.ended.seq];
  final asItWas = transition.ended._copy(reopen: true);
  final unchanged = ending != null &&
      ending.isOpen &&
      ending._copy(reopen: true) == asItWas;
  if (!unchanged || bySeq.containsKey(transition.next.seq)) return PhaseEdit.none;
  return PhaseEdit(upserts: [transition.ended, transition.next]);
}

/// "Keep losing" on variant F (spec 6.7): the maintenance phase that just
/// started is skipped (ended the day it started) and the next lose phase
/// starts that day, from the same trend.
PhaseEdit keepLosing(
  Iterable<GoalPhase> phases, {
  required PlanStyle style,
  double? heightCm,
  PhaseSettings settings = const PhaseSettings(),
}) {
  final open = currentPhase(phases);
  if (open == null || open.kind != PhaseKind.maintain) return PhaseEdit.none;
  final next = nextPhase(
    after: open,
    style: style,
    goal: GoalKind.lose,
    on: open.startedOn,
    trendKg: open.startTrendKg,
    heightCm: heightCm,
    settings: settings,
  );
  if (next == null) return PhaseEdit.none;
  return PhaseEdit(upserts: [open.close(open.startedOn, PhaseEndReason.skipped), next]);
}

/// "Extend break" on variant G: the maintenance phase that just ended is
/// reopened [weeks] longer, and the lose phase it ended into is removed.
PhaseEdit extendBreak(Iterable<GoalPhase> phases, {int weeks = kExtendBreakWeeks}) {
  final open = currentPhase(phases);
  if (open == null || open.kind != PhaseKind.lose) return PhaseEdit.none;
  GoalPhase? before;
  for (final p in phases) {
    if (p.seq == open.seq - 1) before = p;
  }
  if (before == null ||
      before.kind != PhaseKind.maintain ||
      before.endedOn != open.startedOn ||
      before.endReason == PhaseEndReason.skipped) {
    return PhaseEdit.none;
  }
  return PhaseEdit(
    upserts: [before._copy(reopen: true, plannedWeeks: (before.plannedWeeks ?? 0) + weeks)],
    deletes: {open.seq},
  );
}

/// "End phase early": the open phase ends at the next check-in on or after
/// [on], with reason `user_ended`.
PhaseEdit requestPhaseEnd(Iterable<GoalPhase> phases, {required DateTime on}) {
  final open = currentPhase(phases);
  if (open == null) return PhaseEdit.none;
  return PhaseEdit(upserts: [open._copy(endRequestedOn: _dayOf(on))]);
}

/// A recalculation that changed the plan style, goal or pace: the open phase
/// closes as `replanned` and a fresh sequence starts [on] from [trendKg].
PhaseEdit replanPhases(
  Iterable<GoalPhase> phases, {
  required PlanStyle style,
  required GoalKind goal,
  required DateTime on,
  required double trendKg,
  double? heightCm,
  PhaseSettings settings = const PhaseSettings(),
}) {
  final open = currentPhase(phases);
  final seq = phases.fold<int>(0, (m, p) => max(m, p.seq)) + 1;
  return PhaseEdit(upserts: [
    if (open != null) open.close(on, PhaseEndReason.replanned),
    firstPhase(
      style: style,
      goal: goal,
      seq: seq,
      on: on,
      trendKg: trendKg,
      heightCm: heightCm,
      settings: settings,
    ),
  ]);
}

/// The goal was reached: the open phase closes and nothing follows until a
/// new plan (ticket 15).
PhaseEdit closeForGoal(Iterable<GoalPhase> phases, {required DateTime on}) {
  final open = currentPhase(phases);
  return open == null
      ? PhaseEdit.none
      : PhaseEdit(upserts: [open.close(on, PhaseEndReason.goalReached)]);
}

/// "Switch to maintenance" on the goal-reached check-in (spec 6.8 row 1): the
/// open phase closes as `goal_reached` and a steady, open-ended maintain
/// phase starts [on] from [trendKg]. Nothing to do when the plan is already
/// maintaining (the choice was made, here or on another device).
PhaseEdit switchToMaintenance(
  Iterable<GoalPhase> phases, {
  required DateTime on,
  required double trendKg,
}) {
  final open = currentPhase(phases);
  if (open != null && open.kind == PhaseKind.maintain && open.plannedWeeks == null) {
    return PhaseEdit.none;
  }
  final seq = phases.fold<int>(0, (m, p) => max(m, p.seq)) + 1;
  return PhaseEdit(upserts: [
    if (open != null) open.close(on, PhaseEndReason.goalReached),
    firstPhase(
        style: PlanStyle.steady, goal: GoalKind.maintain, seq: seq, on: on, trendKg: trendKg),
  ]);
}

/// The days the diet really switched (lose ↔ maintain ↔ gain), for the
/// estimator's settle period: starts of phases whose kind differs from the
/// phase before. Phases that never ran (skipped, or ended the day they
/// started) don't count, and the first phase is covered by the learning
/// start.
List<DateTime> phaseSwitchDays(Iterable<GoalPhase> phases) {
  final sorted = phases.toList()..sort((a, b) => a.seq.compareTo(b.seq));
  final out = <DateTime>[];
  PhaseKind? previous;
  for (final p in sorted) {
    if (p.endedOn != null && !p.endedOn!.isAfter(p.startedOn)) continue;
    if (previous != null && p.kind != previous) out.add(p.startedOn);
    previous = p.kind;
  }
  return out;
}

// --- Plan outline ---

/// How a lose plan unfolds: loss phases, breaks and total weeks.
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

/// Walks a lose plan week by week through the phase engine, losing [pacePct]
/// of the current weight each lose week, to count its phases and weeks
/// (plan 10.3's "3 loss phases + 2 breaks · about 34 weeks"). Stops at the
/// goal or [kMaxProjectionWeeks]. Null when there's nothing to lose or no
/// pace. (A constant-pace walk; the projection replaces the weight model.)
PlanOutline? outlinePlan({
  required PlanStyle style,
  required double weightKg,
  required double goalWeightKg,
  required double pacePct,
  double? heightCm,
  PhaseSettings settings = const PhaseSettings(),
}) {
  if (pacePct <= 0 || goalWeightKg >= weightKg) return null;
  final day0 = DateTime(2000, 1, 3);
  var weight = weightKg;
  var phase = firstPhase(
      style: style,
      goal: GoalKind.lose,
      seq: 1,
      on: day0,
      trendKg: weight,
      heightCm: heightCm,
      settings: settings);
  var lossPhases = 1, breaks = 0, lossWeeks = 0, week = 0;
  while (week < kMaxProjectionWeeks) {
    week++;
    if (phase.kind == PhaseKind.lose) {
      weight *= 1 - pacePct / 100;
      lossWeeks++;
    }
    final on = DateTime(day0.year, day0.month, day0.day + 7 * week);
    final reason = dueToEnd(phase,
        on: on, trendKg: weight, goalWeightKg: goalWeightKg, goal: GoalKind.lose);
    if (reason == PhaseEndReason.goalReached) break;
    if (reason == null) continue;
    final next = nextPhase(
        after: phase,
        style: style,
        goal: GoalKind.lose,
        on: on,
        trendKg: weight,
        heightCm: heightCm,
        settings: settings);
    if (next == null) break;
    if (next.kind == PhaseKind.lose) {
      lossPhases++;
    } else {
      breaks++;
    }
    phase = next;
  }
  return PlanOutline(lossPhases: lossPhases, breaks: breaks, weeks: week, lossWeeks: lossWeeks);
}

DateTime _dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

int _daysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
