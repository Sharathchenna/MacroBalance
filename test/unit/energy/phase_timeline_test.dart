import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/phase_timeline.dart';
import 'package:macrotracker/services/energy/targets.dart';

void main() {
  final start = DateTime(2026, 9, 7);
  DateTime plus(int days) => DateTime(2026, 9, 7 + days);

  // Phased: 84 kg, lose 5% (to 79.8), max 16 weeks.
  GoalPhase phasedLose({int seq = 1, DateTime? on, double kg = 84}) => GoalPhase(
      seq: seq,
      kind: PhaseKind.lose,
      startedOn: on ?? start,
      startTrendKg: kg,
      targetPct: 5,
      maxWeeks: 16);

  PhaseTimeline? build(
    List<GoalPhase> phases, {
    required DateTime now,
    required double trend,
    PlanStyle style = PlanStyle.phased,
    GoalKind goal = GoalKind.lose,
    double goalKg = 70,
    double pace = 0.5,
  }) =>
      buildPhaseTimeline(
        phases: phases,
        style: style,
        goal: goal,
        now: now,
        trendKg: trend,
        goalWeightKg: goalKg,
        pacePct: pace,
      );

  test('steady plans, other goals and no open phase have no timeline', () {
    expect(build([phasedLose()], now: plus(10), trend: 83, style: PlanStyle.steady), isNull);
    expect(build([phasedLose()], now: plus(10), trend: 83, goal: GoalKind.maintain), isNull);
    expect(build(const [], now: plus(10), trend: 83), isNull);
    expect(
        build([phasedLose().close(plus(5), PhaseEndReason.goalReached)],
            now: plus(10), trend: 83),
        isNull);
  });

  test('losing: numbers come from the phase and the trend', () {
    final t = build([phasedLose()], now: plus(21), trend: 82.9)!; // 3 weeks in
    expect(t.kind, PhaseKind.lose);
    expect(t.phaseNumber, 1);
    expect(t.weeksIn, 4); // week 4 of the phase
    expect(t.lostKg, closeTo(1.1, 1e-9));
    expect(t.phaseGoalKg, closeTo(4.2, 1e-9));
    // 3.1 kg left at 0.5%/wk of ~83 kg (≈0.41 kg/wk): about 7-8 weeks.
    expect(t.weeksLeft, inInclusiveRange(7, 8));
    expect(t.endsAtCheckin, isFalse);
    expect(t.endRequested, isFalse);
  });

  test('losing: the length is capped at the longest phase', () {
    final t = build([phasedLose()], now: plus(98), trend: 83.9, pace: 0.05)!;
    // Barely losing: the 16 weeks run out first, 2 weeks from now (week 14).
    expect(t.weeksLeft, 2);
  });

  test('losing: loss lost never goes negative; unknown trend leaves kg out', () {
    final up = build([phasedLose()], now: plus(7), trend: 84.5)!;
    expect(up.lostKg, 0);
    final none = buildPhaseTimeline(
        phases: [phasedLose()],
        style: PlanStyle.phased,
        goal: GoalKind.lose,
        now: plus(7),
        trendKg: null,
        goalWeightKg: 70,
        pacePct: 0.5)!;
    expect(none.lostKg, isNull);
    expect(none.weeksLeft, isNull);
    expect(none.phaseGoalKg, closeTo(4.2, 1e-9));
  });

  test('maintenance break: week of weeks, and when losing resumes', () {
    final phases = [
      phasedLose().close(plus(70), PhaseEndReason.reached),
      GoalPhase(
          seq: 2,
          kind: PhaseKind.maintain,
          startedOn: plus(70),
          startTrendKg: 79.7,
          plannedWeeks: 4),
    ];
    final t = build(phases, now: plus(70 + 9), trend: 80)!; // 1 week + 2 days in
    expect(t.kind, PhaseKind.maintain);
    expect(t.weeksIn, 2);
    expect(t.plannedWeeks, 4);
    expect(t.resumesOn, plus(70 + 28));
    expect(t.weeksLeft, 3);
    expect(t.phaseNumber, 1); // the loss phases before: the next one is 2
    expect(t.nextPhaseNumber, 2);
  });

  test('diet breaks: week of the 8 and the break after', () {
    final p = GoalPhase(
        seq: 1, kind: PhaseKind.lose, startedOn: start, startTrendKg: 84, plannedWeeks: 8);
    final t = build([p], now: plus(16), trend: 83, style: PlanStyle.breaks)!;
    expect(t.weeksIn, 3);
    expect(t.plannedWeeks, 8);
    expect(t.weeksLeft, 6);
    expect(t.phaseGoalKg, isNull);
  });

  test('due to end or asked to end: ends at the next check-in', () {
    final reached = build([phasedLose()], now: plus(60), trend: 79.7)!;
    expect(reached.endsAtCheckin, isTrue);
    final asked = build([
      GoalPhase(
          seq: 1,
          kind: PhaseKind.lose,
          startedOn: start,
          startTrendKg: 84,
          targetPct: 5,
          maxWeeks: 16,
          endRequestedOn: plus(10))
    ], now: plus(11), trend: 83)!;
    expect(asked.endRequested, isTrue);
    expect(asked.endsAtCheckin, isTrue);
  });

  test('segments: done, current, then the upcoming phases to the goal', () {
    final phases = [
      phasedLose().close(plus(70), PhaseEndReason.reached),
      GoalPhase(
          seq: 2,
          kind: PhaseKind.maintain,
          startedOn: plus(70),
          startTrendKg: 79.7,
          plannedWeeks: 4),
    ];
    final t = build(phases, now: plus(70 + 14), trend: 79.9, goalKg: 70)!;
    final kinds = [for (final s in t.segments) s.kind];
    final states = [for (final s in t.segments) s.state];
    expect(kinds.take(3), [PhaseKind.lose, PhaseKind.maintain, PhaseKind.lose]);
    expect(states.take(3),
        [SegmentState.done, SegmentState.current, SegmentState.upcoming]);
    expect(t.segments.first.weeks, closeTo(10, 1e-9));
    // The current break is its planned 4 weeks.
    expect(t.segments[1].weeks, closeTo(4, 1e-9));
    // Kinds alternate and weeks are positive.
    for (var i = 1; i < kinds.length; i++) {
      expect(kinds[i], isNot(kinds[i - 1]));
    }
    expect(t.segments.every((s) => s.weeks > 0), isTrue);
  });

  test('the marker sits inside the current segment', () {
    final t = build([phasedLose()], now: plus(21), trend: 82.9)!;
    final before = t.segments.takeWhile((s) => s.state != SegmentState.current);
    final total = t.segments.fold<double>(0, (a, s) => a + s.weeks);
    expect(t.marker, closeTo((before.fold<double>(0, (a, s) => a + s.weeks) + 3) / total, 1e-9));
    expect(t.marker, inExclusiveRange(0, 1));
  });

  test('skipped and zero-length phases are not drawn', () {
    final phases = [
      phasedLose().close(plus(70), PhaseEndReason.reached),
      GoalPhase(
              seq: 2,
              kind: PhaseKind.maintain,
              startedOn: plus(70),
              startTrendKg: 79.7,
              plannedWeeks: 4)
          .close(plus(70), PhaseEndReason.skipped),
      phasedLose(seq: 3, on: plus(70), kg: 79.7),
    ];
    final t = build(phases, now: plus(80), trend: 79)!;
    expect(t.segments.first.kind, PhaseKind.lose);
    expect(t.segments.first.state, SegmentState.done);
    expect(t.segments[1].state, SegmentState.current);
    expect(t.segments[1].kind, PhaseKind.lose);
    expect(t.phaseNumber, 2);
  });

  test('only a handful of upcoming phases are drawn, with a flag for more', () {
    final p = GoalPhase(
        seq: 1, kind: PhaseKind.lose, startedOn: start, startTrendKg: 120, plannedWeeks: 8);
    final t = build([p], now: plus(7), trend: 119, style: PlanStyle.breaks, goalKg: 70)!;
    expect(t.segments.where((s) => s.state == SegmentState.upcoming).length, 4);
    expect(t.more, isTrue);
  });
}
