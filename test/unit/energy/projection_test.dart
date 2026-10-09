import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/bmr.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/projection.dart';
import 'package:macrotracker/services/energy/targets.dart';

void main() {
  final today = DateTime(2026, 10, 12);
  const man = BodyProfile(sex: Sex.male, heightCm: 180, age: 35, activityLevel: 3);
  double tdeeOf(BodyProfile b, double kg) => formulaTdee(
      sex: b.sex,
      weightKg: kg,
      heightCm: b.heightCm!,
      age: b.age!,
      activityLevel: b.activityLevel!);

  Projection project({
    GoalKind goal = GoalKind.lose,
    double weightKg = 90,
    double? goalKg = 80,
    double pace = 0.5,
    BodyProfile body = man,
    double? tdee,
    bool adaptive = true,
    double? cals,
    PlanStyle style = PlanStyle.steady,
    GoalPhase? phase,
  }) =>
      projectToGoal(
        goal: goal,
        weightKg: weightKg,
        goalWeightKg: goalKg,
        tdee: tdee ?? tdeeOf(body, weightKg),
        pacePct: pace,
        body: body,
        adaptive: adaptive,
        cals: cals,
        style: style,
        phase: phase,
        on: today,
      );

  group('body profile', () {
    test('energy density from the fat mass at a weight; unknowns use the defaults', () {
      expect(
          man.energyDensityAt(90),
          energyDensity(
              fatMassKg(weightKg: 90, heightCm: 180, age: 35, sex: Sex.male)));
      const bare = BodyProfile(sex: Sex.female);
      expect(
          bare.energyDensityAt(70),
          energyDensity(
              fatMassKg(weightKg: 70, heightCm: 170, age: 30, sex: Sex.female)));
      expect(man.bmrMultiplier, 1.55);
      expect(bare.bmrMultiplier, 1.55); // unknown: moderately active
    });
  });

  group('steady loss', () {
    test('adaptive: the chosen pace of the current weight each week', () {
      final p = project();
      // 90 × 0.995^k = 80 at k = ln(80/90)/ln(0.995) ≈ 23.5 weeks.
      expect(p.weeks, closeTo(log(80 / 90) / log(0.995), 0.05));
      expect(p.reached, isTrue);
      expect(p.aboutWeeks, 24);
      for (final w in p.path) {
        final t = targetForPace(
            goal: GoalKind.lose,
            pacePct: 0.5,
            tdee: w.tdee,
            sex: Sex.male,
            weightKg: w.startKg,
            energyDensity: man.energyDensityAt(w.startKg));
        expect(w.cals, t.cals);
      }
    });

    test('each week: ΔW = 7·(cals − tdee)/ED, and tdee falls 10·ΔW·activity', () {
      final p = project(adaptive: false);
      for (var i = 0; i < p.path.length; i++) {
        final w = p.path[i];
        final dW = 7 * (w.cals - w.tdee) / man.energyDensityAt(w.startKg);
        expect(w.endKg, closeTo(w.startKg + dW, 1e-9));
        if (i + 1 < p.path.length) {
          final next = p.path[i + 1];
          expect(next.tdee, closeTo(w.tdee + 10 * dW * 1.55, 1e-9));
          expect(next.startKg, w.endKg);
        }
      }
      expect(p.path.last.tdee, lessThan(p.path.first.tdee - 100));
    });

    test('fixed targets keep their cals and slow down as expenditure falls', () {
      final fixed = project(adaptive: false);
      final adaptive = project();
      expect(fixed.path.map((w) => w.cals).toSet(), hasLength(1));
      expect(fixed.path.first.cals, adaptive.path.first.cals);
      expect(fixed.weeks!, greaterThan(adaptive.weeks! + 1));
    });

    test('fixed targets start from the current target when given', () {
      final p = project(adaptive: false, cals: 2100);
      expect(p.path.every((w) => w.cals == 2100), isTrue);
    });

    test('the range is 0.85× to 1.25×, and the date is that many weeks on', () {
      final p = project();
      final weeks = p.weeks!;
      expect(p.weeksLow, closeTo(0.85 * weeks, 1e-9));
      expect(p.weeksHigh, closeTo(1.25 * weeks, 1e-9));
      expect(p.date, DateTime(2026, 10, 12 + (weeks * 7).round()));
      expect(p.earliest, DateTime(2026, 10, 12 + (0.85 * weeks * 7).round()));
      expect(p.latest, DateTime(2026, 10, 12 + (1.25 * weeks * 7).round()));
    });
  });

  group('phased with breaks', () {
    test('in phases: loss phases, maintenance weeks and the total', () {
      // 100 → 80 kg at 0.5%/week, 180 cm: 10% (BMI 30.9) capped at 16
      // weeks, then 5% phases of 11 weeks, then the rest to the goal.
      final p = project(weightKg: 100, style: PlanStyle.phased);
      expect(p.lossPhases, 4);
      expect(p.breaks, 3);
      final kinds = [for (final ph in p.phases) ph.kind];
      expect(kinds, [
        PhaseKind.lose, PhaseKind.maintain, PhaseKind.lose, PhaseKind.maintain,
        PhaseKind.lose, PhaseKind.maintain, PhaseKind.lose,
      ]);
      expect(p.phases.first.weeks, kMaxLossPhaseWeeks);
      expect(p.phases.first.endReason, PhaseEndReason.maxDuration);
      expect(p.phases[2].endReason, PhaseEndReason.reached);
      expect(p.phases.last.endReason, PhaseEndReason.goalReached);
      for (final m in p.phases.where((ph) => ph.kind == PhaseKind.maintain)) {
        expect(m.weeks, kMaintenanceWeeks);
        expect(m.endKg, closeTo(m.startKg, 0.05)); // maintenance holds the weight
      }
      // The breaks add their weeks to the losing time.
      final losing = p.phases
          .where((ph) => ph.kind == PhaseKind.lose)
          .fold<double>(0, (a, ph) => a + ph.weeks);
      expect(p.weeks, closeTo(losing + 3 * kMaintenanceWeeks, 1e-9));
      expect(p.weeks!, inInclusiveRange(56, 57));
      expect(p.outline!.lossPhases, 4);
      expect(p.outline!.breaks, 3);
      expect(p.outline!.weeks, p.aboutWeeks);
    });

    test('diet breaks: a 2-week break every 8 weeks', () {
      final p = project(style: PlanStyle.breaks);
      // ~23.5 weeks of losing: 8 + 8 + 7.5, with 2 breaks between.
      expect((p.lossPhases, p.breaks), (3, 2));
      expect(p.weeks, closeTo(log(80 / 90) / log(0.995) + 2 * kBreakWeeks, 0.1));
    });

    test('fixed targets: each phase keeps the cals it started with', () {
      final p = project(weightKg: 100, style: PlanStyle.phased, adaptive: false);
      for (final ph in p.phases) {
        final cals = p.path.where((w) => w.phaseSeq == ph.seq).map((w) => w.cals).toSet();
        expect(cals, hasLength(1), reason: 'phase ${ph.seq}');
      }
      final maintain = p.phases.firstWhere((ph) => ph.kind == PhaseKind.maintain);
      final week = p.path.firstWhere((w) => w.phaseSeq == maintain.seq);
      expect(week.cals, week.tdee.roundToDouble()); // maintenance is the expenditure then
    });

    test('continues an open phase from where it is', () {
      // Phased, 84 → 79.8 kg, 3 weeks in at 82.9 kg.
      final open = GoalPhase(
          seq: 4,
          kind: PhaseKind.lose,
          startedOn: DateTime(2026, 9, 21),
          startTrendKg: 84,
          targetPct: 5,
          maxWeeks: 16);
      final p = project(weightKg: 82.9, goalKg: 70, style: PlanStyle.phased, phase: open);
      expect(p.phases.first.seq, 4);
      expect(p.phases.first.endReason, PhaseEndReason.reached);
      // ln(79.8/82.9)/ln(0.995) ≈ 7.6: due at the 8th weekly check.
      expect(p.phases.first.weeks, 8);
      expect(p.phases[1].kind, PhaseKind.maintain);

      // Barely losing 14 weeks in: the 16-week cap ends it 2 weeks from now.
      final late = GoalPhase(
          seq: 1,
          kind: PhaseKind.lose,
          startedOn: DateTime(2026, 10, 12 - 98),
          startTrendKg: 84,
          targetPct: 5,
          maxWeeks: 16);
      final slow = project(
          weightKg: 83.9, goalKg: 70, pace: 0.05, style: PlanStyle.phased, phase: late);
      expect(slow.phases.first.weeks, 2);
      expect(slow.phases.first.endReason, PhaseEndReason.maxDuration);
    });
  });

  group('gain', () {
    test('adaptive: the chosen pace up to the goal', () {
      final p = project(goal: GoalKind.gain, weightKg: 70, goalKg: 75, pace: 0.25);
      expect(p.weeks, closeTo(log(75 / 70) / log(1.0025), 0.05));
      expect(p.lossPhases, 0);
      expect(p.phases.single.kind, PhaseKind.gain);
    });

    test('plan styles only apply to losing', () {
      final p = project(
          goal: GoalKind.gain, weightKg: 70, goalKg: 75, pace: 0.25, style: PlanStyle.phased);
      expect(p.phases.single.kind, PhaseKind.gain);
    });
  });

  group('already at the goal, or no goal', () {
    test('at or past the goal: 0 weeks, today', () {
      for (final p in [
        project(weightKg: 80, goalKg: 80),
        project(weightKg: 79, goalKg: 80),
        project(goal: GoalKind.gain, weightKg: 75, goalKg: 75),
      ]) {
        expect(p.weeks, 0);
        expect(p.reached, isTrue);
        expect(p.aboutWeeks, 0);
        expect(p.date, today);
        expect(p.path, isEmpty);
      }
    });

    test('maintaining or no goal weight: nothing to project', () {
      expect(project(goal: GoalKind.maintain).weeks, isNull);
      expect(project(goalKg: null).weeks, isNull);
      expect(project(goalKg: 0).weeks, isNull);
      expect(project(goalKg: null).date, isNull);
    });
  });

  group('safety-limited pace', () {
    // 120 kg, 160 cm, 45, sedentary woman: 1%/week would be ~1,370 cals
    // under a ~2,180 expenditure, so the 25% deficit cap holds it.
    const woman = BodyProfile(sex: Sex.female, heightCm: 160, age: 45, activityLevel: 1);

    test('the capped pace is what the weeks follow', () {
      final one = project(body: woman, weightKg: 120, goalKg: 90, pace: 1.0);
      final threeQ = project(body: woman, weightKg: 120, goalKg: 90, pace: 0.75);
      expect(one.weeks!, greaterThan(log(90 / 120) / log(0.99) + 10));
      expect(one.weeks, closeTo(threeQ.weeks!, 0.5)); // both held by the cap
      for (final w in one.path) {
        expect(w.cals, greaterThanOrEqualTo(w.tdee * (1 - kMaxDeficitFrac) - 0.5));
      }
    });

    test('a target held at the floor above expenditure never gets there', () {
      final p = project(
          body: const BodyProfile(sex: Sex.female, heightCm: 150, age: 70, activityLevel: 1),
          weightKg: 50,
          goalKg: 45,
          tdee: 1150);
      expect(p.path.first.cals, kFloorFemale);
      expect(p.weeks, isNull);
      expect(p.reached, isFalse);
      expect(p.date, isNull);
      expect(p.aboutWeeks, isNull);
      expect(p.outline, isNull);
    });

    test('stops at 156 weeks', () {
      final p = project(weightKg: 90, goalKg: 60, pace: 0.05);
      expect(p.weeks, isNull);
      expect(p.path, hasLength(kMaxProjectionWeeks));
    });
  });
}
