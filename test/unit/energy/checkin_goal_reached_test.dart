import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/bmr.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/targets.dart';

/// Decision row 1 (spec 6.8): the trend weight has crossed the goal weight.
/// Variant D, for lose and gain, adaptive or not, above every other row.
void main() {
  final start = DateTime(2026, 7, 20);
  DateTime week(int n) => DateTime(start.year, start.month, start.day + 7 * n);

  EnergyEstimate row({
    double tdee = 2400,
    EnergyState state = EnergyState.confident,
    double? trendKg = 74.8,
  }) =>
      EnergyEstimate(
        day: week(11).subtract(const Duration(days: 1)),
        tdee: tdee,
        tdeeSd: 90,
        state: state,
        completeDays: 18,
        weighIns: 20,
        updated: true,
        trendWeightKg: trendKg,
        avgIntake: 1900,
      );

  CheckinSettings settings({
    bool adaptive = true,
    GoalKind goal = GoalKind.lose,
    double? goalKg = 75,
  }) =>
      CheckinSettings(
        adaptive: adaptive,
        goal: goal,
        pacePct: goal == GoalKind.maintain ? 0 : 0.5,
        sex: Sex.male,
        heightCm: 180,
        age: 35,
        activityLevel: 3,
        goalWeightKg: goalKg,
      );

  const current = CheckinTargets(cals: 1900, protein: 160, carbs: 180, fat: 60);

  CheckinDecision? decide({
    CheckinSettings? s,
    EnergyEstimate? latest,
    bool noRow = false,
    CheckinPlan? plan,
    double? fallbackWeightKg,
  }) =>
      decideCheckin(
        settings: s ?? settings(),
        current: current,
        tdeePrev: 2350,
        latest: noRow ? null : latest ?? row(),
        fallbackWeightKg: fallbackWeightKg,
        plan: plan,
      );

  double formulaAt(double kg) => formulaTdee(
      sex: Sex.male, weightKg: kg, heightCm: 180, age: 35, activityLevel: 3);

  for (final adaptive in [true, false]) {
    final who = adaptive ? 'adaptive' : 'fixed targets';

    group('lose ($who)', () {
      test('trend below the goal weight: D', () {
        final d = decide(s: settings(adaptive: adaptive))!;
        expect(d.variant, CheckinVariant.goalReached);
        expect(d.reason.goal, GoalKind.lose);
        expect(d.reason.goalWeightKg, 75);
        expect(d.reason.trendWeightKg, 74.8);
      });

      test('trend exactly at the goal weight: D', () {
        final d = decide(s: settings(adaptive: adaptive), latest: row(trendKg: 75))!;
        expect(d.variant, CheckinVariant.goalReached);
      });

      test('trend above the goal weight: not reached', () {
        final d = decide(s: settings(adaptive: adaptive), latest: row(trendKg: 75.1));
        expect(d?.variant, isNot(CheckinVariant.goalReached));
      });
    });

    group('gain ($who)', () {
      test('trend above the goal weight: D', () {
        final d = decide(
            s: settings(adaptive: adaptive, goal: GoalKind.gain, goalKg: 80),
            latest: row(trendKg: 80.3))!;
        expect(d.variant, CheckinVariant.goalReached);
        expect(d.reason.goal, GoalKind.gain);
      });

      test('trend exactly at the goal weight: D', () {
        final d = decide(
            s: settings(adaptive: adaptive, goal: GoalKind.gain, goalKg: 80),
            latest: row(trendKg: 80))!;
        expect(d.variant, CheckinVariant.goalReached);
      });

      test('trend below the goal weight: not reached', () {
        final d = decide(
            s: settings(adaptive: adaptive, goal: GoalKind.gain, goalKg: 80),
            latest: row(trendKg: 79.9));
        expect(d?.variant, isNot(CheckinVariant.goalReached));
      });
    });
  }

  group('what D does', () {
    test('targets stay as they are until the user chooses', () {
      for (final adaptive in [true, false]) {
        final d = decide(s: settings(adaptive: adaptive))!;
        expect(d.newTargets, current);
        expect(d.oldTargets, current);
        expect(d.changesTargets, isFalse);
        expect(d.reason.limitHit, isNull);
      }
    });

    test('adaptive: carries the estimated expenditure for the maintenance targets', () {
      final d = decide(latest: row(tdee: 2410))!;
      expect(d.reason.tdee, 2410);
      expect(d.reason.tdeePrev, 2350);
    });

    test('fixed targets, or a learning or paused estimate: the formula at the trend', () {
      final fixed = decide(s: settings(adaptive: false))!;
      expect(fixed.reason.tdee, closeTo(formulaAt(74.8), 0.001));
      for (final state in [EnergyState.learning, EnergyState.paused]) {
        final d = decide(latest: row(state: state, tdee: 2600))!;
        expect(d.variant, CheckinVariant.goalReached);
        expect(d.reason.tdee, closeTo(formulaAt(74.8), 0.001));
      }
    });

    test('the maintenance targets are the expenditure itself, with no step cap', () {
      final t = phaseTargets(
        kind: PhaseKind.maintain,
        settings: settings(),
        tdee: 2410,
        weightKg: 74.8,
      );
      expect(t.targets.cals, 2410); // +510 on the current 1,900
      expect(t.pace.limitHit, isNull);
    });

    test('D is not a variant that applies targets or changes the phase', () {
      expect(CheckinVariant.goalReached.appliesTargets, isFalse);
      expect(CheckinVariant.goalReached.isPhaseChange, isFalse);
    });
  });

  group('when it is not D', () {
    test('maintain goals never reach a goal', () {
      final d = decide(s: settings(goal: GoalKind.maintain, goalKg: 75));
      expect(d?.variant, isNot(CheckinVariant.goalReached));
    });

    test('no goal weight set', () {
      final d = decide(s: settings(goalKg: null));
      expect(d?.variant, isNot(CheckinVariant.goalReached));
      final zero = decide(s: settings(goalKg: 0));
      expect(zero?.variant, isNot(CheckinVariant.goalReached));
    });

    test('no trend weight: the profile weight does not count as crossing', () {
      expect(decide(latest: row(trendKg: null), fallbackWeightKg: 70)?.variant,
          isNot(CheckinVariant.goalReached));
      expect(decide(s: settings(adaptive: false), noRow: true, fallbackWeightKg: 70), isNull);
    });
  });

  group('row 1 goes above the others', () {
    test('a learning or paused estimate: D, not C', () {
      for (final state in [EnergyState.learning, EnergyState.paused]) {
        expect(decide(latest: row(state: state))!.variant, CheckinVariant.goalReached);
      }
    });

    test('a phase due to end at the same time: D, not F', () {
      final losing = firstPhase(
          style: PlanStyle.phased,
          goal: GoalKind.lose,
          seq: 1,
          on: start,
          trendKg: 80,
          heightCm: 180);
      final plan = CheckinPlan(style: PlanStyle.phased, phases: [losing], on: week(16));
      final d = decide(latest: row(trendKg: 74.5), plan: plan)!;
      expect(d.variant, CheckinVariant.goalReached);
      expect(d.reason.phase, isNull);
    });

    test('a break due to end into more losing: still D', () {
      final phases = [
        firstPhase(style: PlanStyle.phased, goal: GoalKind.lose, seq: 1, on: start, trendKg: 80)
            .close(week(10), PhaseEndReason.reached),
        GoalPhase(
            seq: 2,
            kind: PhaseKind.maintain,
            startedOn: week(10),
            startTrendKg: 76,
            plannedWeeks: kMaintenanceWeeks),
      ];
      final plan = CheckinPlan(
          style: PlanStyle.phased, phases: phases, on: week(10 + kMaintenanceWeeks));
      expect(decide(latest: row(trendKg: 74.9), plan: plan)!.variant, CheckinVariant.goalReached);
    });

    test('a target within the no-change threshold: still D, not B', () {
      final d = decide(latest: row(tdee: 1900 + 460))!;
      expect(d.variant, CheckinVariant.goalReached);
    });
  });

  group('switching to maintenance (phases)', () {
    GoalPhase losing() => firstPhase(
        style: PlanStyle.phased, goal: GoalKind.lose, seq: 1, on: start, trendKg: 90, heightCm: 180);

    test('the open phase closes as goal_reached and a steady maintain phase starts', () {
      final out = switchToMaintenance([losing()], on: week(20), trendKg: 74.8)
          .applyTo([losing()]);
      expect(out, hasLength(2));
      expect(out[0].endReason, PhaseEndReason.goalReached);
      expect(out[0].endedOn, week(20));
      final next = out[1];
      expect(next.seq, 2);
      expect(next.kind, PhaseKind.maintain);
      expect(next.startedOn, week(20));
      expect(next.startTrendKg, 74.8);
      expect(next.plannedWeeks, isNull); // open-ended, like any steady plan
      expect(next.isOpen, isTrue);
      expect(currentPhase(out), next);
    });

    test('without an open phase it only starts maintaining', () {
      final out = switchToMaintenance(const [], on: week(2), trendKg: 74.8).applyTo(const []);
      expect(out.single.kind, PhaseKind.maintain);
      expect(out.single.seq, 1);
    });

    test('a new seq each time, after earlier phases', () {
      final done = [losing().close(week(5), PhaseEndReason.replanned)];
      final open = firstPhase(
          style: PlanStyle.steady, goal: GoalKind.lose, seq: 2, on: week(5), trendKg: 85);
      final out = switchToMaintenance([...done, open], on: week(9), trendKg: 74.8)
          .applyTo([...done, open]);
      expect(out.map((p) => p.seq), [1, 2, 3]);
      expect(out[2].kind, PhaseKind.maintain);
    });

    test('a plan that is already maintaining is left alone', () {
      final maintaining = firstPhase(
          style: PlanStyle.steady, goal: GoalKind.maintain, seq: 1, on: start, trendKg: 75);
      expect(switchToMaintenance([maintaining], on: week(3), trendKg: 75).isEmpty, isTrue);
    });
  });
}
