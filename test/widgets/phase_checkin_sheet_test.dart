import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/screens/energy/checkin_sheet.dart';
import 'package:macrotracker/services/checkin_sync_service.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/estimate_rows.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/energy_sync_service.dart';
import 'package:macrotracker/services/phase_sync_service.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

class _SeededCheckins extends CheckinSyncService {
  _SeededCheckins(List<GoalCheckin> rows)
      : rows = {for (final c in rows) dayKey(c.weekStart): c};

  final Map<String, GoalCheckin> rows;

  @override
  Map<String, GoalCheckin> loadCache() => Map.of(rows);

  @override
  Future<GoalCheckin?> markSeen(DateTime weekStart, DateTime at) async =>
      rows[dayKey(weekStart)] = rows[dayKey(weekStart)]!.copyWith(seenAt: at);

  @override
  Future<void> settleApply(String week) async {}

  @override
  Future<bool> sync() async => false;
}

class _Phases extends PhaseSyncService {
  _Phases(List<GoalPhase> seed) : _rows = List.of(seed);

  List<GoalPhase> _rows;

  @override
  List<GoalPhase> loadCache() => List.of(_rows);

  @override
  Future<List<GoalPhase>> edit(PhaseEdit edit) async => _rows = edit.applyTo(_rows);

  @override
  Future<void> upload() async {}

  @override
  Future<bool> sync() async => false;
}

class _NoEstimates extends EnergySyncService {
  @override
  Map<DateTime, EnergyEstimate> loadCache() => const {};

  @override
  Set<String> pendingDays() => const {};
}

/// Goals that don't sync.
class _Goals extends GoalsProvider {
  @override
  Future<void> syncToCloud() async {}
}

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);
DateTime _weeksAgo(int n) => DateTime(_today.year, _today.month, _today.day - 7 * n);

const _lose = CheckinTargets(cals: 1950, protein: 160, carbs: 190, fat: 60);
const _maintain = CheckinTargets(cals: 2450, protein: 136, carbs: 318, fat: 68);

// Phase 1 lost its 5% over 11 weeks; F started the break today.
final _phase1 = firstPhase(
    style: PlanStyle.phased, goal: GoalKind.lose, seq: 1, on: _weeksAgo(11), trendKg: 90);
final _toMaintain = PhaseTransition(
  ended: _phase1.close(_today, PhaseEndReason.reached),
  next: GoalPhase(
      seq: 2,
      kind: PhaseKind.maintain,
      startedOn: _today,
      startTrendKg: 85.4,
      plannedWeeks: kMaintenanceWeeks),
);

// Phase 3 after a break: G started it today.
final _toLose = PhaseTransition(
  ended: GoalPhase(
          seq: 4,
          kind: PhaseKind.maintain,
          startedOn: _weeksAgo(4),
          startTrendKg: 81.5,
          plannedWeeks: kMaintenanceWeeks)
      .close(_today, PhaseEndReason.planned),
  next: firstPhase(
      style: PlanStyle.phased, goal: GoalKind.lose, seq: 5, on: _today, trendKg: 81.6),
);
final _historyBeforeG = [
  _phase1.close(_weeksAgo(19), PhaseEndReason.reached),
  GoalPhase(
          seq: 2,
          kind: PhaseKind.maintain,
          startedOn: _weeksAgo(19),
          startTrendKg: 85.4,
          plannedWeeks: kMaintenanceWeeks)
      .close(_weeksAgo(15), PhaseEndReason.planned),
  firstPhase(style: PlanStyle.phased, goal: GoalKind.lose, seq: 3, on: _weeksAgo(15), trendKg: 85.6)
      .close(_weeksAgo(4), PhaseEndReason.reached),
];

GoalCheckin _checkin(PhaseTransition t, {double? phaseWeeks, SafetyLimit? limit}) {
  final toMaintain = t.toMaintain;
  return GoalCheckin(
    weekStart: _today,
    variant: toMaintain ? CheckinVariant.phaseToMaintain : CheckinVariant.phaseToLose,
    oldTargets: toMaintain ? _lose : _maintain,
    newTargets: toMaintain ? _maintain : _lose,
    reason: CheckinReason(
      state: EnergyState.confident,
      completeDays: 18,
      weighIns: 20,
      tdee: 2450,
      tdeePrev: 2400,
      trendWeightKg: t.next.startTrendKg,
      goalWeightKg: 75,
      goal: GoalKind.lose,
      pacePct: 0.5,
      limitHit: limit,
      phase: t,
      phaseWeeks: phaseWeeks ?? (toMaintain ? 4 : 9.6),
    ),
    createdAt: _now,
  );
}

void main() {
  final events = <MethodCall>[];

  setUp(() async {
    await setUpTestEnvironment();
    for (final key in ['nutrition_goals', 'goal_settings', 'unit_system']) {
      await StorageService().delete(key);
    }
    await StorageService().put('unit_system', 'metric');
    await StorageService().put(
        'nutrition_goals',
        jsonEncode({
          'macro_targets': {'calories': 2450, 'protein': 136, 'carbs': 318, 'fat': 68},
          'tdee': 2450,
          'goal_type': 'lose',
          'pace_pct_per_week': 0.5,
          'goal_weight_kg': 75,
          'current_weight_kg': 85.4,
          'sex': 'male',
          'height_cm': 180,
          'age': 35,
          'activity_level': 3,
          'plan_style': 'phased',
        }));
    events.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('posthog_flutter'), (call) async {
      if (call.method == 'capture') events.add(call);
      return null;
    });
  });

  List<String?> actions() => [
        for (final c in events)
          if ((c.arguments as Map)['eventName'] == 'phase_action')
            ((c.arguments as Map)['properties'] as Map)['action'] as String?,
      ];

  group('copy (plan 9.6)', () {
    test('F: break title by why the phase ended, the water note, the choices', () {
      final c = CheckinCopy(_checkin(_toMaintain));
      expect(c.title, "You've lost 5% — time for a maintenance break 🎉");
      expect(
          c.phaseBody,
          'Your target goes up to 2,450 cals for the next 4 weeks. Expect the scale to rise '
          '0.5–1.5 kg in the first few days. That\'s water and glycogen, not fat.');
      expect(c.macroLine, 'Protein 136 g (−24) · Carbs 318 g (+128) · Fat 68 g (+8)');
      expect(c.primaryAction, 'Start break');
      expect(c.secondaryAction, 'Keep losing instead');
      expect(c.whyLines, isEmpty);
      expect(c.footer, isNull);
      expect(CheckinCopy(_checkin(_toMaintain), isKg: false).phaseBody,
          contains('rise 1–3 lbs'));

      PhaseTransition endedBy(PhaseEndReason r, {int weeks = 16, bool breaks = false}) {
        final p = breaks
            ? firstPhase(
                style: PlanStyle.breaks, goal: GoalKind.lose, seq: 1, on: _weeksAgo(weeks), trendKg: 90)
            : _phase1;
        return PhaseTransition(
            ended: GoalPhase(
              seq: 1,
              kind: PhaseKind.lose,
              startedOn: _weeksAgo(weeks),
              startTrendKg: 90,
              targetPct: p.targetPct,
              plannedWeeks: p.plannedWeeks,
              maxWeeks: p.maxWeeks,
            ).close(_today, r),
            next: _toMaintain.next);
      }

      expect(CheckinCopy(_checkin(endedBy(PhaseEndReason.maxDuration))).title,
          '16 weeks of losing done — time for a maintenance break');
      expect(CheckinCopy(_checkin(endedBy(PhaseEndReason.planned, weeks: 8, breaks: true))).title,
          '8 weeks done — time for a diet break');
      expect(CheckinCopy(_checkin(endedBy(PhaseEndReason.userEnded))).title,
          'Time for a maintenance break');
    });

    test('G: the phase number, the loss it aims for and about how long', () {
      final c = CheckinCopy(_checkin(_toLose), lossPhaseNumber: 3);
      expect(c.title, 'Ready for phase 3');
      expect(c.phaseBody, 'New target 1,950 cals · aiming to lose 4.1 kg (5%) · about 10 weeks');
      expect(c.primaryAction, "Let's go");
      expect(c.secondaryAction, 'Extend break 2 weeks');
      expect(CheckinCopy(_checkin(_toLose)).title, 'Ready for your next phase');

      final breaks = PhaseTransition(
        ended: _toLose.ended,
        next: firstPhase(
            style: PlanStyle.breaks, goal: GoalKind.lose, seq: 5, on: _today, trendKg: 81.6),
      );
      expect(CheckinCopy(_checkin(breaks, phaseWeeks: 8)).phaseBody,
          'New target 1,950 cals · 8 weeks until your next break');
    });

    test('G: a limit that set the target gets its line', () {
      expect(CheckinCopy(_checkin(_toLose, limit: SafetyLimit.floor)).limitLine,
          contains('our minimum'));
    });
  });

  group('sheet', () {
    Future<(EnergyProvider, GoalsProvider)> open(WidgetTester tester, GoalCheckin c,
        {required List<GoalPhase> phases, bool dark = true}) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final goals = _Goals();
      final energy = EnergyProvider(
        sync: _NoEstimates(),
        checkinSync: _SeededCheckins([c]),
        phaseSync: _Phases(phases),
        inBackground: false,
      )..goals = goals;
      await tester.pumpWidget(testApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showCheckinSheet(context, energy.lastCheckin!),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        goalsProvider: goals,
        energyProvider: energy,
        dark: dark,
      ));
      await tester.tap(find.text('Open'));
      await pumpFrames(tester, seconds: 1);
      return (energy, goals);
    }

    for (final dark in [true, false]) {
      testWidgets('F renders with both choices (${dark ? 'dark' : 'light'})', (tester) async {
        final f = _checkin(_toMaintain);
        await open(tester, f,
            phases: [_toMaintain.ended, _toMaintain.next], dark: dark);
        expect(find.byKey(const Key('checkin_sheet_phase_to_maintain')), findsOneWidget);
        expect(find.text("You've lost 5% — time for a maintenance break 🎉"), findsOneWidget);
        expect(find.byKey(const Key('checkin_phase_body')), findsOneWidget);
        expect(find.text('Start break'), findsOneWidget);
        expect(find.text('Keep losing instead'), findsOneWidget);
        expect(find.textContaining('2,450', findRichText: true), findsWidgets);
      });
    }

    testWidgets('Start break: closes, tracked, nothing else changes', (tester) async {
      final (energy, goals) =
          await open(tester, _checkin(_toMaintain), phases: [_toMaintain.ended, _toMaintain.next]);
      await tester.tap(find.text('Start break'));
      await pumpFrames(tester, seconds: 1);
      expect(find.byKey(const Key('checkin_sheet_phase_to_maintain')), findsNothing);
      expect(actions(), ['start_break']);
      expect(energy.currentPhase!.kind, PhaseKind.maintain);
      expect(goals.caloriesGoal, 2450);
    });

    testWidgets('Keep losing instead: break skipped, lose targets back, tracked', (tester) async {
      final f = _checkin(_toMaintain);
      final (energy, goals) = await open(tester, f, phases: [_toMaintain.ended, _toMaintain.next]);
      await tester.tap(find.text('Keep losing instead'));
      await pumpFrames(tester, seconds: 1);
      expect(find.byKey(const Key('checkin_sheet_phase_to_maintain')), findsNothing);
      expect(actions(), ['keep_losing']);
      expect(energy.phases.map((p) => (p.kind, p.endReason)), [
        (PhaseKind.lose, PhaseEndReason.reached),
        (PhaseKind.maintain, PhaseEndReason.skipped),
        (PhaseKind.lose, null),
      ]);
      expect(goals.caloriesGoal, lessThan(2450));

      // Reopened (the chip, history): the choice is made; only the main button.
      await tester.tap(find.text('Open'));
      await pumpFrames(tester, seconds: 1);
      expect(find.text('Start break'), findsOneWidget);
      expect(find.text('Keep losing instead'), findsNothing);
    });

    testWidgets('G: "Ready for phase 3"; Extend break keeps maintenance 2 weeks longer',
        (tester) async {
      final g = _checkin(_toLose);
      final (energy, goals) = await open(tester, g,
          phases: [..._historyBeforeG, _toLose.ended, _toLose.next], dark: false);
      expect(find.text('Ready for phase 3'), findsOneWidget);
      expect(find.text("Let's go"), findsOneWidget);
      await tester.tap(find.text('Extend break 2 weeks'));
      await pumpFrames(tester, seconds: 1);
      expect(actions(), ['extend']);
      expect(energy.currentPhase!.kind, PhaseKind.maintain);
      expect(energy.currentPhase!.plannedWeeks, kMaintenanceWeeks + kExtendBreakWeeks);
      expect(energy.phases.map((p) => p.seq), [1, 2, 3, 4]);
      expect(goals.caloriesGoal, _maintain.cals);
    });

    testWidgets("Let's go: closes; no phase action", (tester) async {
      await open(tester, _checkin(_toLose), phases: [_toLose.ended, _toLose.next]);
      await tester.tap(find.text("Let's go"));
      await pumpFrames(tester, seconds: 1);
      expect(find.byKey(const Key('checkin_sheet_phase_to_lose')), findsNothing);
      expect(actions(), isEmpty);
    });
  });
}
