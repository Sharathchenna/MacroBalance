import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/targets.dart';

void main() {
  final day = DateTime(2026, 10, 11);

  EnergyEstimate row({
    double tdee = 2400,
    EnergyState state = EnergyState.confident,
    double? trendKg = 80,
    double? avgIntake = 2080,
    int completeDays = 18,
    int weighIns = 20,
  }) =>
      EnergyEstimate(
        day: day,
        tdee: tdee,
        tdeeSd: 90,
        state: state,
        completeDays: completeDays,
        weighIns: weighIns,
        updated: true,
        trendWeightKg: trendKg,
        avgIntake: avgIntake,
      );

  CheckinSettings settings({
    bool adaptive = true,
    GoalKind goal = GoalKind.maintain,
    double pacePct = 0,
    Sex sex = Sex.male,
    double? goalWeightKg,
  }) =>
      CheckinSettings(
        adaptive: adaptive,
        goal: goal,
        pacePct: pacePct,
        sex: sex,
        heightCm: 180,
        age: 35,
        goalWeightKg: goalWeightKg,
      );

  const current = CheckinTargets(cals: 2000, protein: 150, carbs: 220, fat: 65);

  CheckinDecision? decide({
    CheckinSettings? s,
    CheckinTargets targets = current,
    EnergyEstimate? latest,
    bool noRow = false,
    double tdeePrev = 2000,
    double? trendWeekAgoKg,
    double? fallbackWeightKg,
  }) =>
      decideCheckin(
        settings: s ?? settings(),
        current: targets,
        tdeePrev: tdeePrev,
        latest: noRow ? null : latest ?? row(),
        trendWeekAgoKg: trendWeekAgoKg,
        fallbackWeightKg: fallbackWeightKg,
      );

  double ed(double weightKg, {Sex sex = Sex.male}) => energyDensity(
      fatMassKg(weightKg: weightKg, heightCm: 180, age: 35, sex: sex));

  group('row 4: adaptive off', () {
    test('no check-in at all, whatever the data says', () {
      expect(decide(s: settings(adaptive: false), latest: row(tdee: 2600)), isNull);
      expect(decide(s: settings(adaptive: false), latest: row(state: EnergyState.learning)),
          isNull);
      expect(decide(s: settings(adaptive: false), noRow: true), isNull);
    });
  });

  group('row 5: learning or paused', () {
    for (final state in [EnergyState.learning, EnergyState.paused]) {
      test('${state.code}: insufficient, targets unchanged', () {
        final d = decide(latest: row(state: state, tdee: 2600, completeDays: 2, weighIns: 1))!;
        expect(d.variant, CheckinVariant.insufficient);
        expect(d.newTargets, current);
        expect(d.oldTargets, current);
        expect(d.changesTargets, isFalse);
        expect(d.reason.state, state);
        expect(d.reason.completeDays, 2);
        expect(d.reason.weighIns, 1);
      });
    }

    test('no estimate yet: insufficient', () {
      final d = decide(noRow: true)!;
      expect(d.variant, CheckinVariant.insufficient);
      expect(d.newTargets, current);
      expect(d.reason.state, EnergyState.learning);
      expect(d.reason.completeDays, 0);
    });

    test('no weight to work from: insufficient', () {
      final d = decide(latest: row(trendKg: null))!;
      expect(d.variant, CheckinVariant.insufficient);
    });

    test('estimated and confident both run', () {
      expect(decide(latest: row(state: EnergyState.estimated))!.variant,
          CheckinVariant.changed);
      expect(decide(latest: row(state: EnergyState.confident))!.variant,
          CheckinVariant.changed);
    });
  });

  group('row 6: under the no-change threshold', () {
    test('24 cals away: unchanged, targets kept as they are', () {
      final d = decide(latest: row(tdee: 2024))!;
      expect(d.variant, CheckinVariant.unchanged);
      expect(d.newTargets, current);
      expect(d.changesTargets, isFalse);
      expect(d.reason.tdee, 2024);
    });

    test('24 below: unchanged', () {
      expect(decide(latest: row(tdee: 1976))!.variant, CheckinVariant.unchanged);
    });

    test('fractions: the target is rounded to whole cals first, then compared', () {
      expect(decide(latest: row(tdee: 2024.4))!.variant, CheckinVariant.unchanged); // 2,024
      final up = decide(latest: row(tdee: 2024.5))!; // 2,025
      expect(up.variant, CheckinVariant.changed);
      expect(up.newTargets.cals, 2025);
      // Halves round up, so 1,975.5 is 1,976: 24 away.
      expect(decide(latest: row(tdee: 1975.5))!.variant, CheckinVariant.unchanged);
      expect(decide(latest: row(tdee: 1975.4))!.newTargets.cals, 1975);
    });

    test('exactly 25 away: changed', () {
      final up = decide(latest: row(tdee: 2025))!;
      expect(up.variant, CheckinVariant.changed);
      expect(up.newTargets.cals, 2025);
      final down = decide(latest: row(tdee: 1975))!;
      expect(down.variant, CheckinVariant.changed);
      expect(down.newTargets.cals, 1975);
    });

    test('the threshold uses the target after the limits', () {
      // The floor holds a 1,200 target: the raw number moving doesn't count.
      final s = settings(goal: GoalKind.lose, pacePct: 0.5, sex: Sex.female);
      final d = decide(
        s: s,
        targets: const CheckinTargets(cals: 1200, protein: 110, carbs: 110, fat: 40),
        latest: row(tdee: 1350, trendKg: 60),
      )!;
      expect(d.variant, CheckinVariant.unchanged);
      expect(d.reason.limitHit, SafetyLimit.floor);
      expect(d.newTargets.cals, 1200);
    });
  });

  group('row 7: changed', () {
    test('maintain: the target follows the expenditure', () {
      final d = decide(latest: row(tdee: 2100))!;
      expect(d.variant, CheckinVariant.changed);
      expect(d.newTargets.cals, 2100);
      expect(d.reason.limitHit, isNull);
      expect(d.changesTargets, isTrue);
    });

    test('lose: tdee minus the pace at the trend weight', () {
      final s = settings(goal: GoalKind.lose, pacePct: 0.5);
      final d = decide(
        s: s,
        targets: const CheckinTargets(cals: 2150, protein: 160, carbs: 220, fat: 65),
        latest: row(tdee: 2600, trendKg: 80),
      )!;
      final want = (2600 -
              paceDeltaCals(pacePct: 0.5, weightKg: 80, energyDensity: ed(80)))
          .round();
      expect(d.variant, CheckinVariant.changed);
      expect(d.newTargets.cals, want);
      expect(d.reason.limitHit, isNull);
    });

    test('gain: tdee plus the pace', () {
      final s = settings(goal: GoalKind.gain, pacePct: 0.25);
      final d = decide(s: s, latest: row(tdee: 2000, trendKg: 70))!;
      final want = (2000 +
              paceDeltaCals(pacePct: 0.25, weightKg: 70, energyDensity: ed(70)))
          .round();
      expect(d.newTargets.cals, want);
    });

    test('macros are split from the new cals at the trend weight', () {
      final s = settings(goal: GoalKind.lose, pacePct: 0.5);
      final d = decide(s: s, latest: row(tdee: 2600, trendKg: 80))!;
      final split = splitMacros(
        cals: d.newTargets.cals.toDouble(),
        goal: GoalKind.lose,
        weightKg: 80,
        heightCm: 180,
      );
      expect(d.newTargets.protein, split.proteinG);
      expect(d.newTargets.carbs, split.carbsG);
      expect(d.newTargets.fat, split.fatG);
    });

    test('the user\'s protein and fat settings carry through', () {
      final s = CheckinSettings(
        adaptive: true,
        goal: GoalKind.maintain,
        pacePct: 0,
        sex: Sex.male,
        heightCm: 180,
        age: 35,
        proteinPerKg: 2.2,
        fatRatio: 0.35,
      );
      final d = decide(s: s, latest: row(tdee: 2100, trendKg: 75))!;
      final split = splitMacros(
        cals: 2100,
        goal: GoalKind.maintain,
        weightKg: 75,
        heightCm: 180,
        proteinPerKg: 2.2,
        fatRatio: 0.35,
      );
      expect(d.newTargets.protein, split.proteinG);
      expect(d.newTargets.fat, split.fatG);
    });

    test('without a trend weight, the fallback weight is used', () {
      final d = decide(latest: row(tdee: 2300, trendKg: null), fallbackWeightKg: 75)!;
      expect(d.variant, CheckinVariant.changed);
      expect(d.reason.trendWeightKg, 75);
    });
  });

  group('the ±150 check-in step', () {
    test('caps a rise at 150', () {
      final d = decide(latest: row(tdee: 2400))!;
      expect(d.variant, CheckinVariant.changed);
      expect(d.newTargets.cals, 2000 + kMaxCheckinStep);
      expect(d.reason.limitHit, SafetyLimit.checkinStep);
    });

    test('caps a drop at 150', () {
      final d = decide(latest: row(tdee: 1700))!;
      expect(d.newTargets.cals, 2000 - kMaxCheckinStep);
      expect(d.reason.limitHit, SafetyLimit.checkinStep);
    });

    test('exactly 150 is not a cap', () {
      final d = decide(latest: row(tdee: 2150))!;
      expect(d.newTargets.cals, 2150);
      expect(d.reason.limitHit, isNull);
    });
  });

  group('limit_hit (variant E)', () {
    test('the sex floor', () {
      // Female, 60 kg, losing: the pace asks for about 1,100; the floor holds 1,200.
      final s = settings(goal: GoalKind.lose, pacePct: 0.5, sex: Sex.female);
      final d = decide(
        s: s,
        targets: const CheckinTargets(cals: 1300, protein: 110, carbs: 130, fat: 42),
        latest: row(tdee: 1300, trendKg: 60),
      )!;
      expect(d.variant, CheckinVariant.changed);
      expect(d.newTargets.cals, 1200);
      expect(d.reason.limitHit, SafetyLimit.floor);
    });

    test('the deficit cap', () {
      // 1% a week at 120 kg is far past 25% below expenditure.
      final s = settings(goal: GoalKind.lose, pacePct: 1.0);
      final d = decide(
        s: s,
        targets: const CheckinTargets(cals: 2100, protein: 180, carbs: 180, fat: 70),
        latest: row(tdee: 2800, trendKg: 120),
      )!;
      expect(d.newTargets.cals, 2100);
      expect(d.variant, CheckinVariant.unchanged);
      expect(d.reason.limitHit, SafetyLimit.maxDeficit);
    });

    test('the step beats an earlier limit when it sets the final target', () {
      final s = settings(goal: GoalKind.lose, pacePct: 1.0);
      final d = decide(
        s: s,
        targets: const CheckinTargets(cals: 2400, protein: 180, carbs: 250, fat: 75),
        latest: row(tdee: 2800, trendKg: 120),
      )!;
      expect(d.newTargets.cals, 2250);
      expect(d.reason.limitHit, SafetyLimit.checkinStep);
    });
  });

  group('reason', () {
    test('carries the window stats and the expenditure before and after', () {
      final d = decide(
        s: settings(goal: GoalKind.lose, pacePct: 0.5, goalWeightKg: 75),
        latest: row(tdee: 2450, trendKg: 80, avgIntake: 2080, completeDays: 6, weighIns: 9),
        tdeePrev: 2390,
        trendWeekAgoKg: 80.45,
      )!;
      final r = d.reason;
      expect(r.avgIntake, 2080);
      expect(r.completeDays, 6);
      expect(r.weighIns, 9);
      expect(r.trendChangeKg, closeTo(-0.45, 1e-9));
      expect(r.tdee, 2450);
      expect(r.tdeePrev, 2390);
      expect(r.trendWeightKg, 80);
      expect(r.goalWeightKg, 75);
      expect(r.goal, GoalKind.lose);
      expect(r.pacePct, 0.5);
      expect(r.weeksToGoal, isNotNull);
      expect(r.weeksToGoal, greaterThan(5));
    });

    test('no week-ago trend: no change', () {
      expect(decide()!.reason.trendChangeKg, isNull);
    });

    test('maintaining has no weeks to go', () {
      expect(decide(s: settings(goalWeightKg: 80))!.reason.weeksToGoal, isNull);
    });

    test('round-trips through json', () {
      final d = decide(
        s: settings(goal: GoalKind.lose, pacePct: 0.5, goalWeightKg: 75),
        latest: row(tdee: 2450),
        trendWeekAgoKg: 80.4,
      )!;
      final back = CheckinReason.fromJson(d.reason.toJson());
      expect(back.toJson(), d.reason.toJson());
      expect(d.reason.toJson().keys, containsAll(
          ['avg_intake', 'complete_days', 'weigh_ins', 'trend_change_kg', 'tdee', 'tdee_prev', 'limit_hit']));
    });
  });

  group('GoalCheckin record', () {
    test('round-trips through the remote row and the cache', () {
      final d = decide(latest: row(tdee: 2400))!;
      final c = GoalCheckin.fromDecision(d,
          weekStart: DateTime(2026, 10, 12), createdAt: DateTime.utc(2026, 10, 12, 7, 30));
      final remote = c.toRemoteRow('user-1');
      expect(remote['user_id'], 'user-1');
      expect(remote['week_start'], '2026-10-12');
      expect(remote['variant'], 'changed');
      expect(remote['old_targets'], {'cals': 2000, 'protein': 150, 'carbs': 220, 'fat': 65});
      expect((remote['reason'] as Map)['limit_hit'], 'checkin_step');
      final back = GoalCheckin.fromJson(remote)!;
      expect(back.weekStart, DateTime(2026, 10, 12));
      expect(back.variant, CheckinVariant.changed);
      expect(back.newTargets, c.newTargets);
      expect(back.reason.limitHit, SafetyLimit.checkinStep);
      expect(back.seenAt, isNull);
      expect(back.createdAt, c.createdAt);

      final seen = c.copyWith(seenAt: DateTime.utc(2026, 10, 12, 8));
      expect(GoalCheckin.fromJson(seen.toCacheJson())!.seenAt, seen.seenAt);
    });

    test('unreadable rows are skipped', () {
      expect(GoalCheckin.fromJson({'week_start': 'x'}), isNull);
      expect(GoalCheckin.fromJson('nope'), isNull);
    });

    test('variant codes match the table check', () {
      expect(CheckinVariant.values.map((v) => v.code), [
        'changed',
        'unchanged',
        'insufficient',
        'goal_reached',
        'phase_to_maintain',
        'phase_to_lose',
      ]);
    });
  });
}
