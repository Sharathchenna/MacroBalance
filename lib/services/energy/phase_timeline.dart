import 'dart:math';

import 'body_composition.dart';
import 'phase_engine.dart';
import 'projection.dart';
import 'targets.dart';

/// Where a timeline segment is relative to today.
enum SegmentState { done, current, upcoming }

/// One stretch of the goals card's phase timeline, [weeks] long.
class TimelineSegment {
  const TimelineSegment(this.kind, this.weeks, this.state);

  final PhaseKind kind;
  final double weeks;
  final SegmentState state;
}

/// What the goals card shows for a phased or diet-break plan (plan 9.6): the
/// segments, a you-are-here [marker], and the numbers for the status line.
class PhaseTimeline {
  const PhaseTimeline({
    required this.segments,
    required this.marker,
    required this.more,
    required this.kind,
    required this.phaseNumber,
    required this.nextPhaseNumber,
    required this.weeksIn,
    required this.plannedWeeks,
    required this.lostKg,
    required this.phaseGoalKg,
    required this.weeksLeft,
    required this.resumesOn,
    required this.endsAtCheckin,
    required this.endRequested,
  });

  /// Finished phases, the open one, then the next few the plan expects.
  final List<TimelineSegment> segments;

  /// 0..1 along the segments' total length.
  final double marker;

  /// The plan goes on past the last segment drawn.
  final bool more;

  final PhaseKind kind;

  /// The open phase's loss-phase number (for a break, the one before it).
  final int phaseNumber;

  /// The loss phase that is, or comes next.
  final int nextPhaseNumber;

  /// "Week N" of the open phase.
  final int weeksIn;

  /// Maintenance and diet-break lose phases: their set length.
  final int? plannedWeeks;

  /// Lost since the phase began, from the trend; null when it's unknown.
  final double? lostKg;

  /// What a phased lose phase aims to lose.
  final double? phaseGoalKg;

  /// About how many weeks until the phase ends, from the projection.
  final int? weeksLeft;

  /// A break's last day, when losing resumes.
  final DateTime? resumesOn;

  /// The phase ends at the next check-in (it's due, or the user asked).
  final bool endsAtCheckin;

  /// The user asked to end it early.
  final bool endRequested;
}

/// How many phases after the open one the timeline draws.
const int kTimelineUpcoming = 4;

/// The phase timeline for a phased or diet-break lose plan, or null for
/// anything else (steady plans, other goals, no open phase).
///
/// The future comes from the projection (spec 6.9), continuing the open
/// phase from [trendKg] (the latest trend weight, null before there is one)
/// with [tdee], [cals] and the chosen pace, as the check-ins would.
PhaseTimeline? buildPhaseTimeline({
  required Iterable<GoalPhase> phases,
  required PlanStyle style,
  required GoalKind goal,
  required DateTime now,
  required double? trendKg,
  required double? goalWeightKg,
  required double pacePct,
  required double tdee,
  required BodyProfile body,
  bool adaptive = true,
  double? cals,
  PhaseSettings settings = const PhaseSettings(),
}) {
  if (style == PlanStyle.steady || goal != GoalKind.lose) return null;
  final open = currentPhase(phases);
  if (open == null) return null;
  final today = DateTime(now.year, now.month, now.day);

  final sorted = phases.toList()..sort((a, b) => a.seq.compareTo(b.seq));
  final segments = <TimelineSegment>[
    for (final p in sorted)
      if (!p.isOpen && p.endReason != PhaseEndReason.skipped && p.endedOn!.isAfter(p.startedOn))
        TimelineSegment(
            p.kind, p.endedOn!.difference(p.startedOn).inDays / 7, SegmentState.done),
  ];

  final elapsed = open.weeksOn(today);
  final dueNow = dueToEnd(open,
      on: today, trendKg: trendKg ?? open.startTrendKg, goalWeightKg: goalWeightKg, goal: goal);

  // The open phase's projected end gives the weeks left; the phases after
  // it are the upcoming segments.
  final projected = dueNow == PhaseEndReason.goalReached
      ? const <ProjectedPhase>[]
      : projectToGoal(
          goal: goal,
          weightKg: trendKg ?? open.startTrendKg,
          goalWeightKg: goalWeightKg,
          tdee: tdee,
          pacePct: max(pacePct, 0.0),
          body: body,
          on: today,
          adaptive: adaptive,
          cals: cals,
          style: style,
          phase: open,
          phaseSettings: settings,
        ).phases;
  final ended = projected.where((p) => p.endReason != null).toList();
  final openEnd = ended.isNotEmpty && ended.first.seq == open.seq ? ended.first : null;
  final weeksLeft = openEnd == null ? null : max(1, openEnd.weeks.round());
  final openLength = openEnd == null ? null : elapsed + openEnd.weeks;
  final after = ended.skip(openEnd == null ? 0 : 1).toList();
  final upcoming = [
    for (final p in after.take(kTimelineUpcoming))
      TimelineSegment(p.kind, p.weeks, SegmentState.upcoming),
  ];
  final more = after.length > kTimelineUpcoming;

  segments.add(TimelineSegment(
      open.kind, max(openLength ?? elapsed, max(elapsed, 0.5)), SegmentState.current));
  segments.addAll(upcoming);

  final done = segments
      .where((s) => s.state == SegmentState.done)
      .fold<double>(0, (a, s) => a + s.weeks);
  final total = segments.fold<double>(0, (a, s) => a + s.weeks);
  final marker = total <= 0 ? 0.0 : ((done + elapsed) / total).clamp(0.0, 1.0);

  final lossBefore = sorted.where((p) => p.kind == PhaseKind.lose && p.seq < open.seq).length;
  final isLose = open.kind == PhaseKind.lose;
  final target = open.targetTrendKg;
  final planned = open.plannedWeeks;
  final weeksIntoIt = elapsed.floor() + 1;
  return PhaseTimeline(
    segments: segments,
    marker: marker,
    more: more,
    kind: open.kind,
    phaseNumber: isLose ? lossBefore + 1 : max(lossBefore, 1),
    nextPhaseNumber: lossBefore + 1 + (isLose ? 1 : 0),
    weeksIn: planned == null ? weeksIntoIt : min(weeksIntoIt, planned),
    plannedWeeks: planned,
    lostKg: trendKg == null ? null : max(0, open.startTrendKg - trendKg),
    phaseGoalKg: target == null ? null : open.startTrendKg - target,
    weeksLeft: trendKg == null && target != null ? null : weeksLeft,
    resumesOn: !isLose && planned != null ? DateTime(open.startedOn.year, open.startedOn.month, open.startedOn.day + 7 * planned) : null,
    endsAtCheckin: dueNow != null && dueNow != PhaseEndReason.goalReached,
    endRequested: open.endRequestedOn != null,
  );
}
