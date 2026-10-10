import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/bmr.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/targets.dart';

/// Decision rows 2–3 (spec 6.8): a phase due to end changes the targets at
/// the check-in, for adaptive and fixed-target users alike.
void main() {
  // Monday check-ins; the plan started Monday Jul 20 2026.
  final start = DateTime(2026, 7, 20);
  DateTime week(int n) => DateTime(start.year, start.month, start.day + 7 * n);

  EnergyEstimate row({
    double tdee = 2400,
    EnergyState state = EnergyState.confident,
    double trendKg = 85.4,
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

  CheckinSettings settings({bool adaptive = true, Sex sex = Sex.male, double goalKg = 75}) =>
      CheckinSettings(
        adaptive: adaptive,
        goal: GoalKind.lose,
        pacePct: 0.5,
        sex: sex,
        heightCm: 180,
        age: 35,
        activityLevel: 3,
        goalWeightKg: goalKg,
      );

  const current = CheckinTargets(cals: 1900, protein: 160, carbs: 180, fat: 60);

  // 90 kg, lose 5% (to 85.5), 16 weeks at most.
  final losing = firstPhase(
      style: PlanStyle.phased, goal: GoalKind.lose, seq: 1, on: start, trendKg: 90, heightCm: 180);
  final maintaining = [
    losing.close(week(11), PhaseEndReason.reached),
    GoalPhase(
        seq: 2,
        kind: PhaseKind.maintain,
        startedOn: week(11),
        startTrendKg: 85.4,
        plannedWeeks: kMaintenanceWeeks),
  ];

  CheckinDecision? decide({
    CheckinSettings? s,
    EnergyEstimate? latest,
    bool noRow = false,
    List<GoalPhase>? phases,
    PlanStyle style = PlanStyle.phased,
    DateTime? on,
    bool noPlan = false,
    double? fallbackWeightKg,
  }) =>
      decideCheckin(
        settings: s ?? settings(),
        current: current,
        tdeePrev: 2350,
        latest: noRow ? null : latest ?? row(),
        fallbackWeightKg: fallbackWeightKg,
        plan: noPlan
            ? null
            : CheckinPlan(style: style, phases: phases ?? [losing], on: on ?? week(11)),
      );

  double ed(double kg) =>
      energyDensity(fatMassKg(weightKg: kg, heightCm: 180, age: 35, sex: Sex.male));

  double formulaAt(double kg) => formulaTdee(
      sex: Sex.male, weightKg: kg, heightCm: 180, age: 35, activityLevel: 3);

  group('row 2: to maintenance (F)', () {
    test('adaptive: the estimated expenditure, with no step cap', () {
      final d = decide()!;
      expect(d.variant, CheckinVariant.phaseToMaintain);
      expect(d.newTargets.cals, 2400); // +500, past the 150 step
      expect(d.oldTargets, current);
      expect(d.changesTargets, isTrue);
      expect(d.reason.tdee, 2400);
      expect(d.reason.tdeePrev, 2350);
      expect(d.reason.limitHit, isNull);
      final t = d.reason.phase!;
      expect(t.ended.endReason, PhaseEndReason.reached);
      expect(t.ended.endedOn, week(11));
      expect(t.next.kind, PhaseKind.maintain);
      expect(t.next.startTrendKg, 85.4);
      expect(d.reason.phaseWeeks, kMaintenanceWeeks);
    });

    test('maintenance macros come from the maintain split', () {
      final d = decide()!;
      final m = splitMacros(
          cals: 2400, goal: GoalKind.maintain, weightKg: 85.4, heightCm: 180);
      expect(d.newTargets,
          CheckinTargets(cals: 2400, protein: m.proteinG, carbs: m.carbsG, fat: m.fatG));
    });

    test('fixed targets: formula TDEE at the current trend', () {
      final d = decide(s: settings(adaptive: false))!;
      expect(d.variant, CheckinVariant.phaseToMaintain);
      expect(d.reason.tdee, closeTo(formulaAt(85.4), 0.001));
      expect(d.newTargets.cals, formulaAt(85.4).round());
    });

    test('adaptive while the estimate is learning or paused: the formula too, and F beats C', () {
      for (final state in [EnergyState.learning, EnergyState.paused]) {
        final d = decide(latest: row(state: state, tdee: 2600))!;
        expect(d.variant, CheckinVariant.phaseToMaintain);
        expect(d.reason.tdee, closeTo(formulaAt(85.4), 0.001));
      }
    });

    test('max duration and a requested end also lead to maintenance', () {
      final d = decide(latest: row(trendKg: 88), on: week(16))!;
      expect(d.variant, CheckinVariant.phaseToMaintain);
      expect(d.reason.phase!.ended.endReason, PhaseEndReason.maxDuration);

      final asked = requestPhaseEnd([losing], on: week(3)).applyTo([losing]);
      final e = decide(latest: row(trendKg: 89), phases: asked, on: week(4))!;
      expect(e.reason.phase!.ended.endReason, PhaseEndReason.userEnded);
    });

    test('without estimates the profile weight stands in for the trend', () {
      final d = decide(s: settings(adaptive: false), noRow: true, fallbackWeightKg: 85)!;
      expect(d.variant, CheckinVariant.phaseToMaintain);
      expect(d.reason.trendWeightKg, 85);
      expect(decide(s: settings(adaptive: false), noRow: true), isNull);
    });
  });

  group('row 3: back to losing (G)', () {
    test('adaptive: lose targets from the estimate at the current trend, no step cap', () {
      final d = decide(phases: maintaining, on: week(15), latest: row(trendKg: 86))!;
      expect(d.variant, CheckinVariant.phaseToLose);
      final want = targetForPace(
          goal: GoalKind.lose,
          pacePct: 0.5,
          tdee: 2400,
          sex: Sex.male,
          weightKg: 86,
          energyDensity: ed(86));
      expect(d.newTargets.cals, want.cals.round());
      final m = splitMacros(cals: want.cals, goal: GoalKind.lose, weightKg: 86, heightCm: 180);
      expect(d.newTargets.protein, m.proteinG);
      expect(d.reason.phase!.next.kind, PhaseKind.lose);
      expect(d.reason.phase!.next.targetPct, kPhasedLossPct);
      expect(d.reason.phase!.next.seq, 3);
      // 5% of 86 kg at about 0.5%/week: about 10 weeks.
      expect(d.reason.phaseWeeks, inInclusiveRange(9.5, 11));
      expect(d.reason.weeksToGoal, isNotNull);
    });

    test('a lose phase that can\'t reach X% in 16 weeks shows 16', () {
      final slow = CheckinSettings(
        adaptive: true,
        goal: GoalKind.lose,
        pacePct: 0.25,
        sex: Sex.male,
        heightCm: 180,
        age: 35,
        activityLevel: 3,
        goalWeightKg: 60,
      );
      final d = decide(s: slow, phases: maintaining, on: week(15), latest: row(trendKg: 86))!;
      expect(d.reason.phaseWeeks, kMaxLossPhaseWeeks);
    });

    test('diet breaks: back to 8 weeks of losing', () {
      final breaks = [
        firstPhase(style: PlanStyle.breaks, goal: GoalKind.lose, seq: 1, on: start, trendKg: 90)
            .close(week(8), PhaseEndReason.planned),
        GoalPhase(
            seq: 2,
            kind: PhaseKind.maintain,
            startedOn: week(8),
            startTrendKg: 87,
            plannedWeeks: kBreakWeeks),
      ];
      final d = decide(phases: breaks, style: PlanStyle.breaks, on: week(10))!;
      expect(d.variant, CheckinVariant.phaseToLose);
      expect(d.reason.phase!.next.plannedWeeks, kBreakEveryWeeks);
      expect(d.reason.phaseWeeks, kBreakEveryWeeks);
    });

    test('the safety limits still apply (floor), and are recorded', () {
      final small = CheckinSettings(
        adaptive: true,
        goal: GoalKind.lose,
        pacePct: 1.0,
        sex: Sex.female,
        heightCm: 160,
        age: 35,
        activityLevel: 1,
        goalWeightKg: 50,
      );
      final d = decide(
          s: small,
          phases: maintaining,
          on: week(15),
          latest: row(tdee: 1450, trendKg: 60))!;
      expect(d.newTargets.cals, kFloorFemale);
      expect(d.reason.limitHit, SafetyLimit.floor);
    });
  });

  group('when rows 2–3 don\'t apply', () {
    test('nothing due: rows 4–7 as before (fixed targets: no check-in)', () {
      expect(decide(on: week(5), latest: row(trendKg: 88))!.variant, CheckinVariant.changed);
      expect(decide(s: settings(adaptive: false), on: week(5), latest: row(trendKg: 88)), isNull);
    });

    test('steady plans and no plan fall through', () {
      expect(decide(style: PlanStyle.steady)!.variant, CheckinVariant.changed);
      expect(decide(noPlan: true)!.variant, CheckinVariant.changed);
    });

    test('the goal reached (row 1) comes before a phase ending', () {
      expect(decide(s: settings(goalKg: 86))!.variant, CheckinVariant.goalReached);
      expect(decide(s: settings(adaptive: false, goalKg: 86))!.variant, CheckinVariant.goalReached);
    });
  });

  test('the transition is kept in the reason and read back from the row', () {
    final d = decide()!;
    final c = GoalCheckin.fromDecision(d, weekStart: week(11), createdAt: DateTime.utc(2026, 10, 5));
    final json = c.toRemoteRow('u');
    expect((json['reason'] as Map)['phase'], isA<Map>());
    final back = GoalCheckin.fromJson(json)!;
    expect(back.reason.phase!.next, d.reason.phase!.next);
    expect(back.reason.phase!.ended, d.reason.phase!.ended);
    expect(back.reason.phaseWeeks, kMaintenanceWeeks);
    // Ordinary check-ins have none.
    final plain = decide(noPlan: true)!;
    expect(GoalCheckin.fromJson(GoalCheckin.fromDecision(plain,
                weekStart: week(11), createdAt: DateTime.utc(2026, 10, 5))
            .toCacheJson())!
        .reason
        .phase, isNull);
  });

  test('phaseTargets: what Keep losing and the sheet recompute from', () {
    final lose = phaseTargets(
        kind: PhaseKind.lose, settings: settings(), tdee: 2400, weightKg: 85.4);
    expect(lose.targets.cals, lessThan(2400));
    final keep = phaseTargets(
        kind: PhaseKind.maintain, settings: settings(), tdee: 2400, weightKg: 85.4);
    expect(keep.targets.cals, 2400);
  });

  test('variants that apply targets', () {
    expect(
        CheckinVariant.values.where((v) => v.appliesTargets),
        [CheckinVariant.changed, CheckinVariant.phaseToMaintain, CheckinVariant.phaseToLose]);
  });
}
