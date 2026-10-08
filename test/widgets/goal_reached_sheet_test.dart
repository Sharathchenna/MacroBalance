import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/screens/energy/checkin_sheet.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/services/checkin_sync_service.dart';
import 'package:macrotracker/services/energy/checkin.dart';
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


final _open = firstPhase(
    style: PlanStyle.steady, goal: GoalKind.lose, seq: 1, on: _weeksAgo(20), trendKg: 90);

GoalCheckin _reached({DateTime? weekStart}) => GoalCheckin(
      weekStart: weekStart ?? _today,
      variant: CheckinVariant.goalReached,
      oldTargets: _lose,
      newTargets: _lose,
      reason: CheckinReason(
        state: EnergyState.confident,
        completeDays: 18,
        weighIns: 20,
        trendChangeKg: -0.4,
        tdee: 2450,
        tdeePrev: 2400,
        trendWeightKg: 74.8,
        goalWeightKg: 75,
        goal: GoalKind.lose,
        pacePct: 0.5,
      ),
      createdAt: _now,
    );

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
          'macro_targets': {'calories': 1950, 'protein': 160, 'carbs': 190, 'fat': 60},
          'tdee': 2400,
          'goal_type': 'lose',
          'pace_pct_per_week': 0.5,
          'goal_weight_kg': 75,
          'current_weight_kg': 74.8,
          'sex': 'male',
          'height_cm': 180,
          'age': 35,
          'activity_level': 3,
          'plan_style': 'steady',
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
          if ((c.arguments as Map)['eventName'] == 'goal_reached_action')
            ((c.arguments as Map)['properties'] as Map)['action'] as String?,
      ];

  group('copy (plan 9.5)', () {
    test('title with the goal weight, in the user\'s unit; nothing changes until they choose', () {
      final c = CheckinCopy(_reached());
      expect(c.title, "You've reached 75 kg 🎉");
      expect(c.subtitle,
          'Your trend weight is 74.8 kg. Your targets stay as they are until you choose.');
      expect(c.primaryAction, 'Got it');
      expect(c.footer, isNull);
      expect(c.whyLines, isEmpty);
      expect(c.limitLine, isNull);
      expect(c.summary, 'Goal weight reached');
      expect(CheckinCopy(_reached(), isKg: false).title, "You've reached 165.3 lbs 🎉");
    });

    test('the macros shown can be the maintenance ones on offer', () {
      const maintain = CheckinTargets(cals: 2450, protein: 136, carbs: 318, fat: 68);
      expect(CheckinCopy(_reached()).macroLineFor(maintain),
          'Protein 136 g (−24) · Carbs 318 g (+128) · Fat 68 g (+8)');
    });
  });

  group('sheet', () {
    Future<(EnergyProvider, GoalsProvider)> open(WidgetTester tester, GoalCheckin c,
        {List<GoalPhase>? phases, bool dark = true}) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final goals = _Goals();
      final energy = EnergyProvider(
        sync: _NoEstimates(),
        checkinSync: _SeededCheckins([c]),
        phaseSync: _Phases(phases ?? [_open]),
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
      testWidgets('D renders with both choices (${dark ? 'dark' : 'light'})', (tester) async {
        await open(tester, _reached(), dark: dark);
        expect(find.byKey(const Key('checkin_sheet_goal_reached')), findsOneWidget);
        expect(find.text("You've reached 75 kg 🎉"), findsOneWidget);
        expect(find.text('If you switch to maintenance'), findsOneWidget);
        expect(find.textContaining('2,450', findRichText: true), findsWidgets);
        expect(find.text('Switch to maintenance'), findsOneWidget);
        expect(find.text('Set a new goal'), findsOneWidget);
        expect(find.text('Got it'), findsNothing);
      });
    }

    testWidgets('Switch to maintenance: goal, targets and phases change, tracked', (tester) async {
      final (energy, goals) = await open(tester, _reached());
      await tester.tap(find.text('Switch to maintenance'));
      await pumpFrames(tester, seconds: 1);
      expect(find.byKey(const Key('checkin_sheet_goal_reached')), findsNothing);
      expect(actions(), ['switch_to_maintenance']);
      expect(goals.goalType, 'maintain');
      expect(goals.caloriesGoal, 2450);
      expect(goals.planStyle, PlanStyle.steady);
      expect(energy.phases.map((p) => (p.kind, p.endReason)), [
        (PhaseKind.lose, PhaseEndReason.goalReached),
        (PhaseKind.maintain, null),
      ]);
      expect(energy.lastCheckin!.seenAt, isNotNull);

      // Reopened (the chip, history): chosen already, so only Got it.
      await tester.tap(find.text('Open'));
      await pumpFrames(tester, seconds: 1);
      expect(find.text("You've reached 75 kg 🎉"), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
      expect(find.text('Switch to maintenance'), findsNothing);
      expect(find.text('Set a new goal'), findsNothing);
      expect(find.text('If you switch to maintenance'), findsNothing);
    });

    testWidgets('Set a new goal: opens recalculate, tracked, and changes nothing yet',
        (tester) async {
      final (energy, goals) = await open(tester, _reached());
      await tester.tap(find.text('Set a new goal'));
      await pumpFrames(tester, seconds: 1);
      expect(find.byKey(const Key('checkin_sheet_goal_reached')), findsNothing);
      final screen = tester.widget<OnboardingScreen>(find.byType(OnboardingScreen));
      expect(screen.recalculateOnly, isTrue);
      expect(screen.goalReached, isTrue);
      expect(actions(), ['set_new_goal']);
      expect(goals.goalType, 'lose');
      expect(goals.caloriesGoal, 1950);
      expect(energy.phases.single.isOpen, isTrue);
    });
  });
}
