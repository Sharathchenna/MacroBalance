import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/targets.dart';

/// Spec §10 phase 3b: "A non-adaptive phased user's target changes only at
/// boundaries" (decision 5). A simulated user eats exactly their target and
/// checks in every week for over a year; the estimate wobbles around the
/// truth every week, which would move an adaptive user's targets.
void main() {
  final start = DateTime(2026, 1, 5); // a Monday

  ({List<int> changeWeeks, List<int> boundaryWeeks, List<CheckinVariant> variants})
      simulate({required bool adaptive, required PlanStyle style, int seed = 1}) {
    final rng = Random(seed);
    final settings = CheckinSettings(
      adaptive: adaptive,
      goal: GoalKind.lose,
      pacePct: 0.75,
      sex: Sex.female,
      heightCm: 165,
      age: 40,
      activityLevel: 2,
      goalWeightKg: 68,
    );
    var weight = 92.0;
    double trueTdee(double w) => 2350 + 12 * (w - 92);

    var phases = [
      firstPhase(
          style: style, goal: GoalKind.lose, seq: 1, on: start, trendKg: weight, heightCm: 165),
    ];
    var targets = phaseTargets(
            kind: PhaseKind.lose,
            settings: settings,
            tdee: settings.formulaTdeeAt(weight),
            weightKg: weight)
        .targets;
    var tdeeUsed = settings.formulaTdeeAt(weight);

    final changeWeeks = <int>[], boundaryWeeks = <int>[];
    final variants = <CheckinVariant>[];
    for (var w = 1; w <= 70; w++) {
      // A week of eating the target.
      final ed = settings.energyDensityAt(weight);
      weight += 7 * (targets.cals - trueTdee(weight)) / ed;
      final on = DateTime(start.year, start.month, start.day + 7 * w);
      final latest = EnergyEstimate(
        day: on.subtract(const Duration(days: 1)),
        tdee: trueTdee(weight) + (rng.nextDouble() - 0.5) * 300,
        tdeeSd: 90,
        state: EnergyState.confident,
        completeDays: 18,
        weighIns: 20,
        updated: true,
        trendWeightKg: weight,
      );
      final d = decideCheckin(
        settings: settings,
        current: targets,
        tdeePrev: tdeeUsed,
        latest: latest,
        plan: CheckinPlan(style: style, phases: phases, on: on),
      );
      if (d == null) continue;
      variants.add(d.variant);
      final t = d.reason.phase;
      if (t != null) {
        boundaryWeeks.add(w);
        phases = applyTransition(phases, t).applyTo(phases);
      }
      if (d.changesTargets && d.newTargets != targets) {
        changeWeeks.add(w);
        targets = d.newTargets;
        tdeeUsed = d.reason.tdee;
      }
      if (weight <= settings.goalWeightKg!) break;
    }
    return (changeWeeks: changeWeeks, boundaryWeeks: boundaryWeeks, variants: variants);
  }

  for (final style in [PlanStyle.phased, PlanStyle.breaks]) {
    test('fixed targets, ${style.name}: they change only at phase boundaries', () {
      for (var seed = 0; seed < 20; seed++) {
        final run = simulate(adaptive: false, style: style, seed: seed);
        // Lose → maintain → lose → … several times before the goal.
        expect(run.boundaryWeeks.length, greaterThanOrEqualTo(4), reason: 'seed $seed');
        expect(run.variants.toSet(),
            {CheckinVariant.phaseToMaintain, CheckinVariant.phaseToLose},
            reason: 'only F and G ever run');
        expect(run.changeWeeks, run.boundaryWeeks, reason: 'seed $seed');
      }
    });
  }

  test('the same user with adaptive goals on also changes between boundaries', () {
    final run = simulate(adaptive: true, style: PlanStyle.phased);
    expect(run.boundaryWeeks.length, greaterThanOrEqualTo(4));
    expect(run.changeWeeks.where((w) => !run.boundaryWeeks.contains(w)), isNotEmpty);
    expect(run.variants, contains(CheckinVariant.changed));
  });
}
