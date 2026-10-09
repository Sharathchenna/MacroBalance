import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/targets.dart';

void main() {
  // Monday Oct 12 2026: the plan starts on a check-in day.
  final start = DateTime(2026, 10, 12);
  DateTime week(int n, {int days = 0}) =>
      DateTime(start.year, start.month, start.day + 7 * n + days);

  // 180 cm: BMI 30 is 97.2 kg.
  const height = 180.0;

  GoalPhase lose({
    int seq = 1,
    double startKg = 90,
    double? targetPct = 5,
    int? plannedWeeks,
    int? maxWeeks = kMaxLossPhaseWeeks,
    DateTime? on,
    DateTime? endRequestedOn,
  }) =>
      GoalPhase(
        seq: seq,
        kind: PhaseKind.lose,
        startedOn: on ?? start,
        startTrendKg: startKg,
        targetPct: targetPct,
        plannedWeeks: plannedWeeks,
        maxWeeks: maxWeeks,
        endRequestedOn: endRequestedOn,
      );

  GoalPhase maintain({int seq = 2, int weeks = kMaintenanceWeeks, DateTime? on}) => GoalPhase(
        seq: seq,
        kind: PhaseKind.maintain,
        startedOn: on ?? start,
        startTrendKg: 85.5,
        plannedWeeks: weeks,
      );

  PhaseEndReason? due(GoalPhase p, DateTime on, double trend,
          {double? goalKg = 70, GoalKind goal = GoalKind.lose}) =>
      dueToEnd(p, on: on, trendKg: trend, goalWeightKg: goalKg, goal: goal);

  group('loss per phase (X)', () {
    test('5% below BMI 30, 10% from BMI 30', () {
      expect(phaseLossPct(weightKg: 97.1, heightCm: height), kPhasedLossPct);
      expect(phaseLossPct(weightKg: 97.2, heightCm: height), kPhasedLossPctObese);
    });

    test('unknown height: 5%; a setting overrides both', () {
      expect(phaseLossPct(weightKg: 140), kPhasedLossPct);
      expect(
          phaseLossPct(
              weightKg: 140, heightCm: height, settings: const PhaseSettings(lossPct: 7)),
          7);
    });
  });

  group('default plan style', () {
    test('in phases when the goal is more than 10% of body weight', () {
      expect(defaultPlanStyle(weightKg: 100, goalWeightKg: 89.9), PlanStyle.phased);
      expect(defaultPlanStyle(weightKg: 100, goalWeightKg: 90), PlanStyle.steady);
      expect(defaultPlanStyle(weightKg: 100, goalWeightKg: 95), PlanStyle.steady);
    });

    test('codes round-trip; unknown reads as steady', () {
      for (final s in PlanStyle.values) {
        expect(PlanStyle.fromCode(s.code), s);
      }
      expect(PlanStyle.fromCode(null), PlanStyle.steady);
      expect(PlanStyle.fromCode('zigzag'), PlanStyle.steady);
    });
  });

  group('first phase of a plan', () {
    test('phased: lose X% of the start trend, 16 weeks at most', () {
      final p = firstPhase(
          style: PlanStyle.phased,
          goal: GoalKind.lose,
          seq: 1,
          on: start,
          trendKg: 100,
          heightCm: height);
      expect(p.kind, PhaseKind.lose);
      expect(p.targetPct, 10); // BMI 30.9
      expect(p.maxWeeks, kMaxLossPhaseWeeks);
      expect(p.plannedWeeks, isNull);
      expect(p.targetTrendKg, closeTo(90, 1e-9));
      expect(p.isOpen, isTrue);
    });

    test('breaks: lose for 8 weeks', () {
      final p = firstPhase(
          style: PlanStyle.breaks, goal: GoalKind.lose, seq: 1, on: start, trendKg: 80);
      expect(p.kind, PhaseKind.lose);
      expect(p.plannedWeeks, kBreakEveryWeeks);
      expect(p.targetPct, isNull);
      expect(p.maxWeeks, isNull);
    });

    test('steady, and any goal but lose: one open-ended phase of the goal', () {
      for (final (style, goal, kind) in [
        (PlanStyle.steady, GoalKind.lose, PhaseKind.lose),
        (PlanStyle.phased, GoalKind.gain, PhaseKind.gain),
        (PlanStyle.breaks, GoalKind.maintain, PhaseKind.maintain),
      ]) {
        final p = firstPhase(style: style, goal: goal, seq: 3, on: start, trendKg: 80);
        expect(p.kind, kind);
        expect([p.targetPct, p.plannedWeeks, p.maxWeeks], [null, null, null]);
        expect(p.seq, 3);
      }
    });
  });

  group('due to end (spec 6.7 table)', () {
    test('phased lose: reached when the trend is X% below the start', () {
      final p = lose(); // 90 kg, 5%: 85.5
      expect(due(p, week(6), 85.51), isNull);
      expect(due(p, week(6), 85.5), PhaseEndReason.reached);
    });

    test('phased lose: max duration at 16 weeks', () {
      final p = lose();
      expect(due(p, week(16, days: -1), 88), isNull);
      expect(due(p, week(16), 88), PhaseEndReason.maxDuration);
    });

    test('breaks lose: planned after 8 weeks', () {
      final p = lose(targetPct: null, maxWeeks: null, plannedWeeks: kBreakEveryWeeks);
      expect(due(p, week(7), 80), isNull);
      expect(due(p, week(8), 80), PhaseEndReason.planned);
    });

    test('maintain: planned after its weeks', () {
      final m = maintain();
      expect(due(m, week(3), 85.5), isNull);
      expect(due(m, week(4), 85.5), PhaseEndReason.planned);
      expect(due(maintain(weeks: 6), week(4), 85.5), isNull);
    });

    test('goal reached beats every other reason, in either direction', () {
      expect(due(lose(), week(16), 69.9), PhaseEndReason.goalReached);
      expect(due(maintain(), week(4), 70), PhaseEndReason.goalReached);
      final gain = firstPhase(
          style: PlanStyle.steady, goal: GoalKind.gain, seq: 1, on: start, trendKg: 60);
      expect(due(gain, week(3), 64.9, goalKg: 65, goal: GoalKind.gain), isNull);
      expect(due(gain, week(3), 65, goalKg: 65, goal: GoalKind.gain),
          PhaseEndReason.goalReached);
    });

    test('steady lose never ends but at the goal; no goal weight, never', () {
      final p = firstPhase(
          style: PlanStyle.steady, goal: GoalKind.lose, seq: 1, on: start, trendKg: 90);
      expect(due(p, week(80), 71), isNull);
      expect(due(p, week(80), 70), PhaseEndReason.goalReached);
      expect(due(p, week(80), 50, goalKg: null), isNull);
    });

    test('user ended: at the first check-in on or after the request', () {
      final p = lose(endRequestedOn: week(2, days: 3));
      expect(due(p, week(2), 89), isNull);
      expect(due(p, week(3), 89), PhaseEndReason.userEnded);
      expect(due(lose(endRequestedOn: week(3)), week(3), 89), PhaseEndReason.userEnded);
    });

    test('a closed phase is never due', () {
      final p = lose().close(week(2), PhaseEndReason.userEnded);
      expect(due(p, week(20), 50), isNull);
    });
  });

  group('next phase', () {
    test('phased: lose → maintain for M weeks → lose X% of the new start', () {
      final m = nextPhase(
        after: lose(),
        style: PlanStyle.phased,
        goal: GoalKind.lose,
        on: week(11),
        trendKg: 85.4,
      )!;
      expect(m.kind, PhaseKind.maintain);
      expect(m.seq, 2);
      expect(m.startedOn, week(11));
      expect(m.startTrendKg, 85.4);
      expect(m.plannedWeeks, kMaintenanceWeeks);

      final l = nextPhase(
        after: m,
        style: PlanStyle.phased,
        goal: GoalKind.lose,
        on: week(15),
        trendKg: 86,
        heightCm: height,
      )!;
      expect(l.kind, PhaseKind.lose);
      expect(l.seq, 3);
      expect(l.targetPct, kPhasedLossPct); // BMI 26.5 now
      expect(l.maxWeeks, kMaxLossPhaseWeeks);
      expect(l.startTrendKg, 86);
    });

    test('breaks: lose → maintain 2 weeks → lose 8 weeks', () {
      final m = nextPhase(
          after: lose(targetPct: null, maxWeeks: null, plannedWeeks: 8),
          style: PlanStyle.breaks,
          goal: GoalKind.lose,
          on: week(8),
          trendKg: 85)!;
      expect(m.plannedWeeks, kBreakWeeks);
      final l = nextPhase(
          after: m, style: PlanStyle.breaks, goal: GoalKind.lose, on: week(10), trendKg: 85)!;
      expect(l.plannedWeeks, kBreakEveryWeeks);
      expect(l.targetPct, isNull);
    });

    test('settings change the defaults', () {
      const s = PhaseSettings(maintenanceWeeks: 6, breakEveryWeeks: 10, breakWeeks: 1);
      expect(
          nextPhase(
                  after: lose(),
                  style: PlanStyle.phased,
                  goal: GoalKind.lose,
                  on: week(8),
                  trendKg: 85,
                  settings: s)!
              .plannedWeeks,
          6);
      expect(
          nextPhase(
                  after: lose(),
                  style: PlanStyle.breaks,
                  goal: GoalKind.lose,
                  on: week(8),
                  trendKg: 85,
                  settings: s)!
              .plannedWeeks,
          1);
    });

    test('steady plans and other goals have no next phase', () {
      expect(
          nextPhase(
              after: lose(), style: PlanStyle.steady, goal: GoalKind.lose, on: week(8), trendKg: 85),
          isNull);
      expect(
          nextPhase(
              after: lose(), style: PlanStyle.phased, goal: GoalKind.gain, on: week(8), trendKg: 85),
          isNull);
    });
  });

  group('phase transition at a check-in', () {
    PhaseTransition? transition(List<GoalPhase> phases, DateTime on, double trend,
            {PlanStyle style = PlanStyle.phased, double? goalKg = 70}) =>
        phaseTransition(
          phases: phases,
          style: style,
          goal: GoalKind.lose,
          on: on,
          trendKg: trend,
          goalWeightKg: goalKg,
          heightCm: height,
        );

    test('reached: closes the lose phase and starts maintenance that day', () {
      final t = transition([lose()], week(11), 85.4)!;
      expect(t.ended.seq, 1);
      expect(t.ended.endedOn, week(11));
      expect(t.ended.endReason, PhaseEndReason.reached);
      expect(t.next.kind, PhaseKind.maintain);
      expect(t.next.seq, 2);
      expect(t.next.startedOn, week(11));
      expect(t.toMaintain, isTrue);
    });

    test('planned: maintenance ends into the next lose phase', () {
      final t = transition([
        lose().close(week(11), PhaseEndReason.reached),
        maintain(on: week(11)),
      ], week(15), 86)!;
      expect(t.ended.endReason, PhaseEndReason.planned);
      expect(t.next.kind, PhaseKind.lose);
      expect(t.next.seq, 3);
      expect(t.toMaintain, isFalse);
    });

    test('nothing due, steady plans and goal reached give no transition', () {
      expect(transition([lose()], week(3), 89), isNull);
      expect(transition([lose()], week(16), 88, style: PlanStyle.steady), isNull);
      // Row 1 (ticket 15) handles the goal.
      expect(transition([lose()], week(11), 69), isNull);
      expect(transition(const [], week(11), 85), isNull);
    });

    test('the open phase is the latest one; closed ones are history', () {
      final t = transition([
        lose().close(week(11), PhaseEndReason.reached),
        maintain(on: week(11)),
      ], week(13), 86);
      expect(t, isNull);
    });

    test('round-trips through JSON (stored in the check-in reason)', () {
      final t = transition([lose()], week(16), 88)!;
      final back = PhaseTransition.fromJson(t.toJson())!;
      expect(back.ended, t.ended);
      expect(back.next, t.next);
    });
  });

  group('user actions', () {
    final reachedF = phaseTransition(
      phases: [lose()],
      style: PlanStyle.phased,
      goal: GoalKind.lose,
      on: week(11),
      trendKg: 85.4,
      goalWeightKg: 70,
      heightCm: height,
    )!;
    final afterF = applyTransition([lose()], reachedF).applyTo([lose()]);

    test('applying a transition is idempotent', () {
      expect(afterF.map((p) => p.seq), [1, 2]);
      expect(afterF.first.endReason, PhaseEndReason.reached);
      expect(applyTransition(afterF, reachedF).isEmpty, isTrue);
    });

    test('keep losing: the break is skipped (ended the day it started) and the next lose phase starts',
        () {
      final edit = keepLosing(afterF, style: PlanStyle.phased, heightCm: height);
      final out = edit.applyTo(afterF);
      expect(out.map((p) => p.seq), [1, 2, 3]);
      final skipped = out[1];
      expect(skipped.kind, PhaseKind.maintain);
      expect(skipped.endedOn, skipped.startedOn);
      expect(skipped.endReason, PhaseEndReason.skipped);
      final next = out[2];
      expect(next.kind, PhaseKind.lose);
      expect(next.startedOn, week(11));
      expect(next.startTrendKg, 85.4);
      expect(next.targetPct, kPhasedLossPct);
      expect(next.isOpen, isTrue);
      // The F transition can't be applied over it again.
      expect(applyTransition(out, reachedF).isEmpty, isTrue);
      // Nothing to skip now.
      expect(keepLosing(out, style: PlanStyle.phased).isEmpty, isTrue);
    });

    test('extend break: the maintenance phase reopens 2 weeks longer and the lose phase goes', () {
      final phases = [
        lose().close(week(11), PhaseEndReason.reached),
        maintain(on: week(11)),
      ];
      final g = phaseTransition(
          phases: phases,
          style: PlanStyle.phased,
          goal: GoalKind.lose,
          on: week(15),
          trendKg: 86,
          goalWeightKg: 70)!;
      final afterG = applyTransition(phases, g).applyTo(phases);
      expect(afterG.last.kind, PhaseKind.lose);

      final edit = extendBreak(afterG);
      expect(edit.deletes, {3});
      final out = edit.applyTo(afterG);
      expect(out.map((p) => p.seq), [1, 2]);
      expect(out.last.isOpen, isTrue);
      expect(out.last.endReason, isNull);
      expect(out.last.plannedWeeks, kMaintenanceWeeks + kExtendBreakWeeks);
      // Not due at the old end any more, due 2 weeks later.
      expect(dueToEnd(out.last, on: week(16), trendKg: 86, goalWeightKg: 70, goal: GoalKind.lose),
          isNull);
      expect(dueToEnd(out.last, on: week(17), trendKg: 86, goalWeightKg: 70, goal: GoalKind.lose),
          PhaseEndReason.planned);
      // The G check-in can't put the lose phase back.
      expect(applyTransition(out, g).isEmpty, isTrue);
      // Only right after a maintain → lose switch.
      expect(extendBreak(out).isEmpty, isTrue);
      expect(extendBreak([lose()]).isEmpty, isTrue);
    });

    test('end phase early: requested now, ends at the next check-in as user_ended', () {
      final edit = requestPhaseEnd([lose()], on: week(2, days: 2));
      final out = edit.applyTo([lose()]);
      expect(out.single.endRequestedOn, week(2, days: 2));
      expect(out.single.isOpen, isTrue);
      final t = phaseTransition(
          phases: out,
          style: PlanStyle.phased,
          goal: GoalKind.lose,
          on: week(3),
          trendKg: 89,
          goalWeightKg: 70)!;
      expect(t.ended.endReason, PhaseEndReason.userEnded);
      expect(t.next.kind, PhaseKind.maintain);
      // Ending a maintenance break early starts losing again.
      final m = requestPhaseEnd([maintain()], on: week(1)).applyTo([maintain()]);
      final back = phaseTransition(
          phases: m,
          style: PlanStyle.phased,
          goal: GoalKind.lose,
          on: week(1),
          trendKg: 85,
          goalWeightKg: 70)!;
      expect(back.ended.endReason, PhaseEndReason.userEnded);
      expect(back.next.kind, PhaseKind.lose);
      expect(requestPhaseEnd(const [], on: week(1)).isEmpty, isTrue);
    });

    test('replanned: the open phase closes and a fresh sequence starts from the trend', () {
      final edit = replanPhases(afterF,
          style: PlanStyle.breaks, goal: GoalKind.lose, on: week(12), trendKg: 85);
      final out = edit.applyTo(afterF);
      expect(out.map((p) => p.seq), [1, 2, 3]);
      expect(out[1].endedOn, week(12));
      expect(out[1].endReason, PhaseEndReason.replanned);
      expect(out[2].kind, PhaseKind.lose);
      expect(out[2].plannedWeeks, kBreakEveryWeeks);
      expect(out[2].startTrendKg, 85);
      expect(out[2].startedOn, week(12));
      // A first plan has nothing to close.
      final first = replanPhases(const [],
          style: PlanStyle.steady, goal: GoalKind.maintain, on: start, trendKg: 80);
      expect(first.applyTo(const []).single.seq, 1);
    });

    test('goal reached closes the phase without a next one', () {
      final edit = closeForGoal([lose()], on: week(30));
      final out = edit.applyTo([lose()]);
      expect(out.single.endReason, PhaseEndReason.goalReached);
      expect(out.single.endedOn, week(30));
      expect(currentPhase(out), isNull);
    });
  });

  group('phase switches for the estimator', () {
    test('a start where the kind changes; skipped and zero-length phases don\'t count', () {
      final phases = [
        lose().close(week(11), PhaseEndReason.reached),
        maintain(on: week(11)).close(week(15), PhaseEndReason.planned),
        lose(seq: 3, on: week(15)).close(week(20), PhaseEndReason.reached),
        maintain(seq: 4, on: week(20)).close(week(20), PhaseEndReason.skipped),
        lose(seq: 5, on: week(20)).close(week(22), PhaseEndReason.replanned),
        lose(seq: 6, on: week(22), targetPct: null, maxWeeks: null),
      ];
      expect(phaseSwitchDays(phases), [week(11), week(15)]);
    });

    test('a replan to another kind is a switch; the first phase is not', () {
      final phases = [
        firstPhase(style: PlanStyle.steady, goal: GoalKind.lose, seq: 1, on: start, trendKg: 90)
            .close(week(5), PhaseEndReason.replanned),
        firstPhase(style: PlanStyle.steady, goal: GoalKind.maintain, seq: 2, on: week(5), trendKg: 87),
      ];
      expect(phaseSwitchDays(phases), [week(5)]);
      expect(phaseSwitchDays([phases.first]), isEmpty);
    });
  });

  test('a phase round-trips through its row', () {
    final p = lose(endRequestedOn: week(1)).close(week(3), PhaseEndReason.userEnded);
    final row = p.toJson();
    expect(row['kind'], 'lose');
    expect(row['end_reason'], 'user_ended');
    expect(row['started_on'], '2026-10-12');
    expect(GoalPhase.fromJson(row), p);
    expect(GoalPhase.fromJson({'seq': 1}), isNull);
  });
}
