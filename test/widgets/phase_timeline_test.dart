import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/energy/goals_card.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy_sync_service.dart';
import 'package:macrotracker/services/phase_sync_service.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';
import '../helpers/simple_copy_audit.dart';

/// Ticket 19: the phase timeline and "End phase early" on the goals card.
class _Estimates extends EnergySyncService {
  _Estimates(this.rows);

  final List<EnergyEstimate> rows;

  @override
  Map<DateTime, EnergyEstimate> loadCache() => {for (final r in rows) r.day: r};

  @override
  Set<String> pendingDays() => const {};
}

class _Phases extends PhaseSyncService {
  _Phases() : super(userId: 'user-1');

  @override
  Future<void> upsertRemote(Map<String, Object?> row) async {}

  @override
  Future<void> deleteRemote(int seq) async {}

  @override
  Future<List<GoalPhase>> fetchRemote() async => const [];
}

void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

  final events = <Map>[];

  setUp(() async {
    await setUpTestEnvironment();
    for (final key in ['nutrition_goals', 'goal_settings', 'goal_phases:user-1']) {
      await StorageService().delete(key);
    }
    events.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('posthog_flutter'), (call) async {
      if (call.method == 'capture') events.add(call.arguments as Map);
      return null;
    });
  });

  Future<GoalsProvider> goals({PlanStyle style = PlanStyle.phased}) async {
    await StorageService().put(
        'nutrition_goals',
        jsonEncode({
          'macro_targets': {'calories': 2000, 'protein': 150, 'carbs': 190, 'fat': 65},
          'goal_type': 'lose',
          'pace_pct_per_week': 0.5,
          'goal_weight_kg': 70,
          'height_cm': 180,
          'plan_style': style.code,
          'learning_started_on': '2026-01-05',
          'adaptive_goals': true,
        }));
    return GoalsProvider();
  }

  Future<EnergyProvider> energy(List<GoalPhase> phases, {double? trend}) async {
    final sync = _Phases();
    await sync.edit(PhaseEdit(upserts: phases));
    return EnergyProvider(
      userId: 'user-1',
      sync: _Estimates([
        if (trend != null)
          EnergyEstimate(
            day: daysAgo(1),
            tdee: 2400,
            tdeeSd: 80,
            state: EnergyState.confident,
            completeDays: 20,
            weighIns: 20,
            updated: true,
            trendWeightKg: trend,
            avgIntake: 2000,
          ),
      ]),
      phaseSync: sync,
      inBackground: false,
      debounce: Duration.zero,
    );
  }

  Future<void> pump(WidgetTester tester, GoalsProvider g, EnergyProvider e,
      {bool dark = true, bool metric = true, bool simple = false}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      Scaffold(
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(16), child: GoalsCard(simple: simple))),
      goalsProvider: g,
      energyProvider: e,
      weightUnitProvider: WeightUnitProvider()..setMetric(metric),
      dark: dark,
    ));
    await pumpFrames(tester, seconds: 1);
  }

  GoalPhase losing({DateTime? on, double kg = 84, DateTime? requested}) => GoalPhase(
      seq: 1,
      kind: PhaseKind.lose,
      startedOn: on ?? daysAgo(21),
      startTrendKg: kg,
      targetPct: 5,
      maxWeeks: 16,
      endRequestedOn: requested);

  GoalPhase breakPhase() => GoalPhase(
      seq: 2,
      kind: PhaseKind.maintain,
      startedOn: daysAgo(9),
      startTrendKg: 79.7,
      plannedWeeks: 4);

  List<GoalPhase> afterLoss() => [
        losing(on: daysAgo(79)).close(daysAgo(9), PhaseEndReason.reached),
        breakPhase(),
      ];

  for (final dark in [true, false]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('losing: timeline and status line ($mode)', (tester) async {
      await pump(tester, await goals(), await energy([losing()], trend: 82.9), dark: dark);
      expect(find.byKey(const Key('phase_timeline')), findsOneWidget);
      expect(find.byKey(const Key('phase_marker')), findsOneWidget);
      expect(find.textContaining('Phase 1 · Losing · 1.1 of 4.2 kg · about '), findsOneWidget);
      expect(find.text('Losing'), findsOneWidget); // legend
      expect(find.text('Maintenance'), findsOneWidget);
    });

    testWidgets('break: week of weeks and when losing resumes ($mode)', (tester) async {
      await pump(tester, await goals(), await energy(afterLoss(), trend: 80), dark: dark);
      final resumes = DateTime(today.year, today.month, today.day - 9 + 28);
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      expect(
          find.text('Maintenance break · week 2 of 4 · then losing resumes '
              '${months[resumes.month - 1]} ${resumes.day}'),
          findsOneWidget);
    });
  }

  testWidgets('simple mode keeps the bar but drops the phase number', (tester) async {
    await pump(tester, await goals(), await energy([losing()], trend: 82.9), simple: true);
    expect(find.byKey(const Key('phase_timeline')), findsOneWidget);
    expect(find.textContaining('Losing · 1.1 of 4.2 kg · about '), findsOneWidget);
    expect(find.textContaining('Phase 1'), findsNothing);
    expect(find.byKey(const Key('energy_next_checkin')), findsOneWidget);
    expect(find.text('Weekly updates'), findsNothing);
    expectSimpleCopy(tester);
  });

  for (final isBreak in [false, true]) {
    testWidgets('simple ${isBreak ? 'break' : 'losing'} plan: plain menu and confirmation',
        (tester) async {
      final e = await energy(isBreak ? afterLoss() : [losing()], trend: 82.9);
      await pump(tester, await goals(), e, simple: true);
      expectSimpleCopy(tester);

      await tester.tap(find.byKey(const Key('phase_menu')));
      await pumpFrames(tester, seconds: 1);
      final action = isBreak ? 'End your break early' : 'Start your break early';
      expect(find.text(action), findsOneWidget);
      expectSimpleCopy(tester);

      await tester.tap(find.text(action));
      await pumpFrames(tester, seconds: 1);
      expect(find.text('$action?'), findsOneWidget);
      expectSimpleCopy(tester);
      expect(e.currentPhase!.endRequestedOn, isNull);

      await tester.tap(find.text(isBreak ? 'End break' : 'Start break'));
      await pumpFrames(tester, seconds: 1);
      expect(e.currentPhase!.endRequestedOn, today);
      expectSimpleCopy(tester);
      expect(events.where((x) => x['eventName'] == 'phase_action'), hasLength(1));

      await tester.tap(find.byKey(const Key('phase_menu')));
      await pumpFrames(tester, seconds: 1);
      expect(find.text('Ends at your next check-in'), findsOneWidget);
      expect(find.text(action), findsNothing);
      expectSimpleCopy(tester);
    });
  }

  testWidgets('pounds in the status line', (tester) async {
    await pump(tester, await goals(), await energy([losing()], trend: 82.9), metric: false);
    expect(find.textContaining('2.4 of 9.3 lbs'), findsOneWidget);
  });

  testWidgets('steady plans and fixed-goal users have no timeline or menu', (tester) async {
    await pump(tester, await goals(style: PlanStyle.steady), await energy([losing()], trend: 83));
    expect(find.byKey(const Key('phase_timeline')), findsNothing);
    expect(find.byKey(const Key('phase_menu')), findsNothing);
  });

  testWidgets('no phases yet: no timeline', (tester) async {
    await pump(tester, await goals(), await energy(const []));
    expect(find.byKey(const Key('phase_timeline')), findsNothing);
  });

  testWidgets('End phase early: confirm, then it ends at the next check-in', (tester) async {
    final e = await energy([losing()], trend: 82.9);
    await pump(tester, await goals(), e);
    await tester.tap(find.byKey(const Key('phase_menu')));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('End phase early'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('End this phase early?'), findsOneWidget);
    expect(find.textContaining('maintenance break'), findsOneWidget);
    expect(e.currentPhase!.endRequestedOn, isNull); // nothing before confirming

    await tester.tap(find.text('End phase'));
    await pumpFrames(tester, seconds: 1);
    expect(e.currentPhase!.endRequestedOn, today);
    expect(
        events.where((x) =>
            x['eventName'] == 'phase_action' &&
            (x['properties'] as Map)['action'] == 'end_early'),
        hasLength(1));
    expect(find.textContaining('ends at your next check-in'), findsOneWidget);

    // The menu now says so, and does nothing.
    await tester.tap(find.byKey(const Key('phase_menu')));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Ends at your next check-in'), findsOneWidget);
    expect(find.text('End phase early'), findsNothing);
  });

  testWidgets('End phase early: Cancel changes nothing', (tester) async {
    final e = await energy([losing()], trend: 82.9);
    await pump(tester, await goals(), e);
    await tester.tap(find.byKey(const Key('phase_menu')));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('End phase early'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Cancel'));
    await pumpFrames(tester, seconds: 1);
    expect(e.currentPhase!.endRequestedOn, isNull);
    expect(events.where((x) => x['eventName'] == 'phase_action'), isEmpty);
  });

  testWidgets('a break offers End phase early and says losing will start again',
      (tester) async {
    await pump(tester, await goals(), await energy(afterLoss(), trend: 80));
    await tester.tap(find.byKey(const Key('phase_menu')));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('End phase early'));
    await pumpFrames(tester, seconds: 1);
    expect(find.textContaining('losing will start again'), findsOneWidget);
  });
}
