import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/screens/energy/checkin_history.dart';
import 'package:macrotracker/screens/energy/checkin_sheet.dart';
import 'package:macrotracker/screens/energy/energy_tab.dart';
import 'package:macrotracker/services/checkin_sync_service.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/estimate_rows.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/energy_sync_service.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/widgets/expenditure_chart.dart';

import '../helpers/test_app.dart';

/// Check-ins the test hands in; dismissals are recorded, nothing uploads.
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
  Future<bool> sync() async => false;
}

class _FixtureSync extends EnergySyncService {
  _FixtureSync(this.rows);

  final List<EnergyEstimate> rows;

  @override
  Map<DateTime, EnergyEstimate> loadCache() => {for (final r in rows) r.day: r};

  @override
  Set<String> pendingDays() => const {};
}

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);
DateTime ago(int n) => DateTime(_today.year, _today.month, _today.day - n);

List<EnergyEstimate> rows() => [
      for (var n = 30; n >= 1; n--)
        EnergyEstimate(
          day: ago(n),
          tdee: 2450,
          tdeeSd: 88,
          state: EnergyState.confident,
          completeDays: 12,
          weighIns: 15,
          updated: true,
          avgIntake: 2140,
        ),
    ];

GoalCheckin checkin(
  int daysAgo, {
  CheckinVariant variant = CheckinVariant.changed,
  int from = 2507,
  int to = 2451,
  double tdee = 2450,
  double tdeePrev = 2000,
  EnergyState state = EnergyState.confident,
}) =>
    GoalCheckin(
      weekStart: ago(daysAgo),
      variant: variant,
      oldTargets: CheckinTargets(cals: from, protein: 140, carbs: 344, fat: 70),
      newTargets: variant.appliesTargets
          ? CheckinTargets(cals: to, protein: 112, carbs: 348, fat: 68)
          : CheckinTargets(cals: from, protein: 140, carbs: 344, fat: 70),
      reason: CheckinReason(
        state: state,
        avgIntake: 2080,
        completeDays: 12,
        weighIns: 15,
        trendChangeKg: -0.3,
        tdee: tdee,
        tdeePrev: tdeePrev,
        trendWeightKg: 80,
        goal: GoalKind.maintain,
        pacePct: 0,
      ),
      createdAt: ago(daysAgo),
      seenAt: ago(daysAgo),
    );

void main() {
  final events = <MethodCall>[];

  setUp(() async {
    await setUpTestEnvironment();
    for (final key in ['nutrition_goals', 'goal_settings', 'unit_system']) {
      await StorageService().delete(key);
    }
    await StorageService().put('unit_system', 'metric');
    events.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('posthog_flutter'), (call) async {
      if (call.method == 'capture') events.add(call);
      return null;
    });
  });

  List<Map> captured(String name) => [
        for (final c in events)
          if ((c.arguments as Map)['eventName'] == name)
            Map.of((c.arguments as Map)['properties'] as Map),
      ];

  Future<void> pumpTab(WidgetTester tester, List<GoalCheckin> checkins,
      {bool dark = true}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final goals = GoalsProvider()..startLearning(ago(30));
    final energy = EnergyProvider(
      sync: _FixtureSync(rows()),
      checkinSync: _SeededCheckins(checkins),
      inBackground: false,
      debounce: Duration.zero,
    );
    await tester.pumpWidget(testApp(
      const Scaffold(body: EnergyTab()),
      goalsProvider: goals,
      energyProvider: energy,
      dark: dark,
    ));
    await pumpFrames(tester, seconds: 1);
  }

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 200, scrollable: find.byType(Scrollable).first);
    await pumpFrames(tester, seconds: 1);
  }

  final history = [
    checkin(7),
    checkin(14, variant: CheckinVariant.unchanged, tdee: 2005),
    checkin(21, variant: CheckinVariant.insufficient, state: EnergyState.learning),
  ];

  group('history list', () {
    testWidgets('hidden with no check-ins, and no chart dots either', (tester) async {
      await pumpTab(tester, const []);
      await scrollTo(tester, find.text('Reset learning'));
      expect(find.byKey(const Key('checkin_history')), findsNothing);
      expect(find.text('Check-ins'), findsNothing);
      expect(find.text('Check-in'), findsNothing);
    });

    for (final dark in [true, false]) {
      testWidgets('rows newest first: date, old → new cals, one-line reason '
          '(${dark ? 'dark' : 'light'})', (tester) async {
        await pumpTab(tester, history, dark: dark);
        await scrollTo(tester, find.byKey(const Key('checkin_history')));
        expect(find.text('Check-ins'), findsOneWidget);

        final keys = [for (final c in history) Key('checkin_row_${dayKey(c.weekStart)}')];
        final tops = [for (final k in keys) tester.getTopLeft(find.byKey(k)).dy];
        expect(tops, orderedEquals([...tops]..sort()), reason: 'newest first');

        expect(find.text(CheckinHistoryRow.dateText(ago(7), _now)), findsOneWidget);
        expect(find.text('2,507 → 2,451 cals'), findsOneWidget);
        expect(find.text('Burning about 450 cals more than expected'), findsOneWidget);
        expect(find.text('2,507 cals'), findsNWidgets(2));
        expect(find.text('Right on track, no change'), findsOneWidget);
        expect(find.text('Not enough data yet, targets kept'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('tapping a row reopens that week\'s sheet', (tester) async {
      await pumpTab(tester, history);
      final row = find.byKey(Key('checkin_row_${dayKey(ago(14))}'));
      await scrollTo(tester, row);
      await tester.tap(row);
      await pumpFrames(tester, seconds: 1);

      expect(find.byKey(const Key('checkin_sheet_unchanged')), findsOneWidget);
      expect(find.text("You're right on track"), findsOneWidget);
      expect(captured('checkin_shown').single,
          {'variant': 'unchanged', 'source': 'history'});
    });

    testWidgets('shows four, then all on "Show all"', (tester) async {
      await pumpTab(tester, [for (var w = 1; w <= 6; w++) checkin(w * 4)]);
      await scrollTo(tester, find.textContaining('Show all'));
      expect(find.byType(CheckinHistoryRow), findsNWidgets(CheckinHistoryCard.shown));
      expect(find.text('Show all (2 more)'), findsOneWidget);

      await tester.tap(find.text('Show all (2 more)'));
      await pumpFrames(tester, seconds: 1);
      expect(find.byType(CheckinHistoryRow), findsNWidgets(6));
      expect(find.textContaining('Show all'), findsNothing);
    });
  });

  group('chart ticks', () {
    Future<void> showChart(WidgetTester tester) async {
      await tester.ensureVisible(find.byType(ExpenditureChart));
      await pumpFrames(tester, seconds: 1);
    }

    Finder tick(DateTime day) => find.byKey(ValueKey('expenditure_checkin_${day.toIso8601String()}'));

    testWidgets('each check-in in range is marked, with a legend entry', (tester) async {
      await pumpTab(tester, [...history, checkin(60)]);
      await showChart(tester);
      for (final c in history) {
        expect(tick(c.weekStart), findsOneWidget);
      }
      expect(tick(ago(60)), findsNothing, reason: 'outside 1M');
      expect(find.text('Check-in'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Check-in [A-Z][a-z]+ \d+$')), findsNWidgets(3));
    });

    testWidgets('tapping one opens its sheet', (tester) async {
      await pumpTab(tester, history);
      await showChart(tester);
      await tester.tap(tick(ago(7)));
      await pumpFrames(tester, seconds: 1);

      expect(find.byKey(const Key('checkin_sheet_changed')), findsOneWidget);
      expect(captured('checkin_shown').single, {'variant': 'changed', 'source': 'chart'});
    });

    testWidgets("today's check-in gets a dot though today has no estimate", (tester) async {
      await pumpTab(tester, [checkin(0)]);
      await showChart(tester);
      expect(tick(_today), findsOneWidget);
    });

    testWidgets('scrubbing a check-in day says so in the header', (tester) async {
      await pumpTab(tester, history);
      await showChart(tester);
      final dot = tester.getCenter(tick(ago(7)));
      // Above the dot, on the plot: scrubbing, not the dot's target.
      final gesture = await tester.startGesture(dot.translate(0, -60));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.textContaining('· check-in'), findsOneWidget);
      await gesture.up();
      await pumpFrames(tester, seconds: 1);
      expect(find.byKey(const Key('checkin_sheet_changed')), findsNothing);
    });
  });

  group('one-line reasons', () {
    String summary(GoalCheckin c, {int? phase}) =>
        CheckinCopy(c, lossPhaseNumber: phase).summary;

    test('changed: the expenditure difference, or the trend weight', () {
      expect(summary(checkin(7, tdee: 2200, tdeePrev: 2400)),
          'Burning about 200 cals less than expected');
      expect(summary(checkin(7, tdee: 2403, tdeePrev: 2400)), 'Adjusted to your trend weight');
    });

    test('insufficient: learning or paused', () {
      expect(summary(checkin(7, variant: CheckinVariant.insufficient)),
          'Not enough data yet, targets kept');
      expect(
          summary(checkin(7, variant: CheckinVariant.insufficient, state: EnergyState.paused)),
          'Estimate paused, targets kept');
    });

    test('phase changes', () {
      expect(summary(checkin(7, variant: CheckinVariant.phaseToMaintain)),
          'Maintenance break started');
      expect(summary(checkin(7, variant: CheckinVariant.phaseToLose)), 'Next loss phase started');
      expect(summary(checkin(7, variant: CheckinVariant.phaseToLose), phase: 2), 'Phase 2 started');
    });

    test('cals: old → new only when the target moved', () {
      expect(CheckinHistoryRow.calsText(checkin(7)), '2,507 → 2,451 cals');
      expect(CheckinHistoryRow.calsText(checkin(7, variant: CheckinVariant.unchanged)),
          '2,507 cals');
      expect(CheckinHistoryRow.calsText(checkin(7, to: 2507)), '2,507 cals');
    });

    test('dates carry the year only when it isn\'t this one', () {
      final now = DateTime(2026, 10, 8);
      expect(CheckinHistoryRow.dateText(DateTime(2026, 10, 5), now), 'Mon, Oct 5');
      expect(CheckinHistoryRow.dateText(DateTime(2025, 12, 29), now), 'Mon, Dec 29, 2025');
    });
  });
}
