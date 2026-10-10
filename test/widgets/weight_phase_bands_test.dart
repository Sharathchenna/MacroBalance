import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/WeightTrackingScreen.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/phase_sync_service.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/widgets/weight_chart.dart';

import '../helpers/test_app.dart';

/// Ticket 18: phase boundaries on the Weight tab, and the "Expected" label
/// for the water and glycogen shift after a switch.
class _Phases extends PhaseSyncService {
  _Phases(this.rows);

  final List<GoalPhase> rows;

  @override
  List<GoalPhase> loadCache() => rows;
}

void main() {
  late GoalsProvider goals;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

  const label = 'Expected: water & glycogen after your phase change';

  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('nutrition_goals');
    await StorageService().delete('weight_history');
    await StorageService().delete('unit_system');
    goals = GoalsProvider()
      ..goalType = MacroCalculatorService.GOAL_MAINTAIN
      ..goalWeightKg = 60;
  });

  /// 30 days at 60 kg; from [switchAgo] days ago every other weigh-in is
  /// 62 kg (3.3% up: water after the diet ends).
  Future<void> history({required int switchAgo}) =>
      StorageService().put('weight_history', jsonEncode([
        for (var i = 29; i >= 0; i--)
          {
            'date': DateTime(today.year, today.month, today.day - i, 8)
                .toIso8601String(),
            'weight': i <= switchAgo && (switchAgo - i).isOdd ? 62.0 : 60.0,
          }
      ]));

  /// A loss phase, then maintenance from [switchAgo] days ago.
  List<GoalPhase> phased(int switchAgo) => [
        GoalPhase(
          seq: 1,
          kind: PhaseKind.lose,
          startedOn: daysAgo(60),
          startTrendKg: 64,
          targetPct: 5,
          maxWeeks: 16,
          endedOn: daysAgo(switchAgo),
          endReason: PhaseEndReason.reached,
        ),
        GoalPhase(
          seq: 2,
          kind: PhaseKind.maintain,
          startedOn: daysAgo(switchAgo),
          startTrendKg: 60,
          plannedWeeks: 4,
        ),
      ];

  Future<void> pump(WidgetTester tester, List<GoalPhase> phases,
      {bool detailed = true}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(const WeightTrackingScreen(),
        goalsProvider: goals,
        energyProvider:
            EnergyProvider(inBackground: false, phaseSync: _Phases(phases)),
        weightUnitProvider: WeightUnitProvider()..setMetric(true),
        // The legend and the "Expected" copy are the detailed stats view.
        detailedStatsProvider:
            DetailedStatsProvider(showDetailedStats: detailed)));
    await pumpFrames(tester, seconds: 2);
  }

  WeightChart chart(WidgetTester tester) =>
      tester.widget<WeightChart>(find.byType(WeightChart));

  testWidgets('after a switch: a band, the label, and the water is not ignored',
      (tester) async {
    await history(switchAgo: 5);
    await pump(tester, phased(5));

    expect(chart(tester).switches, [daysAgo(5)]);
    expect(find.text('Phase change'), findsOneWidget); // legend
    expect(find.text(label), findsOneWidget);
    expect(find.text('Ignored'), findsNothing);
    expect(chart(tester).ignored, everyElement(isFalse));
  });

  testWidgets('simple view: a quiet band and the plain water note',
      (tester) async {
    await history(switchAgo: 5);
    await pump(tester, phased(5), detailed: false);

    expect(chart(tester).switches, [daysAgo(5)]);
    expect(chart(tester).simple, isTrue);
    expect(
        find.text('Weight often jumps for a few days after a change. '
            'That\'s water, not fat.'),
        findsOneWidget);
    expect(find.text(label), findsNothing);
    expect(find.text('Phase change'), findsNothing);
  });

  testWidgets('no phases: no band or label, and the jump is ignored',
      (tester) async {
    await history(switchAgo: 5);
    await pump(tester, const []);

    expect(chart(tester).switches, isEmpty);
    expect(find.text('Phase change'), findsNothing);
    expect(find.text(label), findsNothing);
    expect(find.text('Ignored'), findsOneWidget);
  });

  testWidgets('a steady plan (one phase, no switch) has no band',
      (tester) async {
    await history(switchAgo: 5);
    await pump(tester, [
      GoalPhase(
          seq: 1, kind: PhaseKind.lose, startedOn: daysAgo(60), startTrendKg: 64),
    ]);

    expect(chart(tester).switches, isEmpty);
    expect(find.text('Phase change'), findsNothing);
    expect(find.text(label), findsNothing);
  });

  testWidgets('once the expected days are over the band stays, the label goes',
      (tester) async {
    await history(switchAgo: 20);
    await pump(tester, phased(20));

    expect(chart(tester).switches, [daysAgo(20)]);
    expect(find.text('Phase change'), findsOneWidget);
    expect(find.text(label), findsNothing);
  });

  testWidgets('the week range shows a switch 5 days ago', (tester) async {
    await history(switchAgo: 5);
    await pump(tester, phased(5));
    await tester.tap(find.text('1W'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Phase change'), findsOneWidget);
  });

  testWidgets('a band that ended before the range shown is left out',
      (tester) async {
    await history(switchAgo: 25);
    await pump(tester, phased(25));
    expect(find.text('Phase change'), findsOneWidget); // month
    await tester.tap(find.text('1W'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Phase change'), findsNothing);
  });
}
