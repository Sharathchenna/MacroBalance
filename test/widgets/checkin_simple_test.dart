import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/energy/checkin_sheet.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';
import '../helpers/simple_copy_audit.dart';
import 'checkin_sheet_test.dart' as fixtures;

void main() {
  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().put('unit_system', 'metric');
  });

  Future<void> open(WidgetTester tester, GoalCheckin c, {bool dark = true}) async {
    tester.view.physicalSize = const Size(1206, 2622);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      Scaffold(body: CheckinSheet(checkin: c)),
      detailedStatsProvider: DetailedStatsProvider(showDetailedStats: false),
      weightUnitProvider: WeightUnitProvider(),
      dark: dark,
    ));
    await pumpFrames(tester, seconds: 1);
  }

  void expectPlain(WidgetTester tester) {
    expectSimpleCopy(tester);
    expect(tester.takeException(), isNull);
  }

  for (final dark in [true, false]) {
    testWidgets('changed target leads; Why expands and collapses ($dark)', (tester) async {
      await open(tester, fixtures.checkin(limit: SafetyLimit.checkinStep), dark: dark);
      expect(find.text('New daily target'), findsOneWidget);
      expect(find.textContaining('2,060', findRichText: true), findsOneWidget);
      expect(find.text('50 more than before'), findsOneWidget);
      expect(find.text('Protein 150 g · Carbs 220 g · Fat 65 g'), findsOneWidget);
      expect(find.byKey(const Key('checkin_why_details')), findsNothing);
      expectPlain(tester);
      await tester.tap(find.byKey(const Key('checkin_why_toggle')));
      await pumpFrames(tester);
      expect(find.byKey(const Key('checkin_why_details')), findsOneWidget);
      expect(find.textContaining('at most 150 cals a week'), findsOneWidget);
      expectPlain(tester);
      await tester.tap(find.byKey(const Key('checkin_why_toggle')));
      await pumpFrames(tester);
      expect(find.byKey(const Key('checkin_why_details')), findsNothing);
    });
  }

  for (final state in [EnergyState.learning, EnergyState.paused]) {
    testWidgets('missing logs explain unchanged target ($state)', (tester) async {
      await open(tester, fixtures.checkin(
        variant: CheckinVariant.insufficient, state: state,
        completeDays: 2, weighIns: 1,
      ));
      expect(find.text('Daily target'), findsOneWidget);
      expect(find.byKey(const Key('checkin_change')), findsNothing);
      expect(find.text('Remind me in the evening'), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkin_why_toggle')));
      await pumpFrames(tester);
      expectPlain(tester);
    });
  }

  for (final limit in [null, ...SafetyLimit.values]) {
    testWidgets('safety explanation stays plain ($limit)', (tester) async {
      await open(tester, fixtures.checkin(limit: limit));
      expect(find.byKey(const Key('checkin_why')), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkin_why_toggle')));
      await pumpFrames(tester);
      expectPlain(tester);
    });
  }

  testWidgets('unchanged target has no delta or unnecessary reminder', (tester) async {
    await open(tester, fixtures.checkin(variant: CheckinVariant.unchanged));
    expect(find.text('Daily target'), findsOneWidget);
    expect(find.byKey(const Key('checkin_change')), findsNothing);
    expect(find.byKey(const Key('finish_reminder_button')), findsNothing);
    expectPlain(tester);
  });
}
