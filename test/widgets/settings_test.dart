import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/WeightTrackingScreen.dart';
import 'package:macrotracker/screens/accountdashboard.dart';
import 'package:macrotracker/screens/delete_account_screen.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/widgets/weight_chart.dart';

import '../helpers/test_app.dart';

void main() {
  late GoalsProvider goals;

  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('nutrition_goals');
    await StorageService().delete('weight_history');
    await StorageService().delete('unit_system');
    goals = GoalsProvider();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('Units setting', () {
    testWidgets('picking Imperial, then Metric, updates the unit and subtitle',
        (tester) async {
      phone(tester);
      final units = WeightUnitProvider()..setMetric(true);
      await tester.pumpWidget(testApp(const AccountDashboard(),
          goalsProvider: goals, weightUnitProvider: units));
      await pumpFrames(tester, seconds: 1);

      await tester.scrollUntilVisible(find.text('Units'), 200,
          scrollable: find.byType(Scrollable).first);
      await pumpFrames(tester, seconds: 1);
      expect(find.text('Metric (kg, g, cm)'), findsOneWidget);

      await tester.tap(find.text('Units'));
      await pumpFrames(tester, seconds: 1);
      expect(find.text('Select Unit System'), findsOneWidget);
      await tester.tap(find.text('Imperial (lb, oz, ft)').last);
      await pumpFrames(tester, seconds: 1);

      expect(units.isMetric, isFalse);
      expect(StorageService().get('unit_system'), 'imperial');
      expect(find.text('Select Unit System'), findsNothing);
      expect(find.text('Imperial (lb, oz, ft)'), findsOneWidget);

      await tester.tap(find.text('Units'));
      await pumpFrames(tester, seconds: 1);
      await tester.tap(find.text('Metric (kg, g, cm)').last);
      await pumpFrames(tester, seconds: 1);
      expect(units.isMetric, isTrue);
      expect(find.text('Metric (kg, g, cm)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cancel leaves the unit unchanged', (tester) async {
      phone(tester);
      final units = WeightUnitProvider()..setMetric(false);
      await tester.pumpWidget(testApp(const AccountDashboard(),
          goalsProvider: goals, weightUnitProvider: units));
      await pumpFrames(tester, seconds: 1);
      await tester.scrollUntilVisible(find.text('Units'), 200,
          scrollable: find.byType(Scrollable).first);
      await pumpFrames(tester, seconds: 1);
      await tester.tap(find.text('Units'));
      await pumpFrames(tester, seconds: 1);
      await tester.tap(find.text('Cancel').last);
      await pumpFrames(tester, seconds: 1);
      expect(units.isMetric, isFalse);
      expect(find.text('Imperial (lb, oz, ft)'), findsOneWidget);
    });
  });

  group('Weight screen', () {
    Future<void> pumpWeight(WidgetTester tester, {bool metric = true}) async {
      phone(tester);
      await tester.pumpWidget(testApp(const WeightTrackingScreen(),
          goalsProvider: goals,
          weightUnitProvider: WeightUnitProvider()..setMetric(metric)));
      await pumpFrames(tester, seconds: 2);
    }

    testWidgets('with no goal weight, offers to set one', (tester) async {
      goals
        ..currentWeightKg = 82.4
        ..goalWeightKg = 0;
      await pumpWeight(tester);

      expect(find.text('82.4 kg'), findsWidgets);
      expect(find.text('Set goal'), findsOneWidget);
      expect(find.textContaining('0.0 kg'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with a goal weight, shows it and how far to go', (tester) async {
      goals
        ..currentWeightKg = 82.4
        ..goalWeightKg = 75;
      await pumpWeight(tester);
      await tester.scrollUntilVisible(find.text('Goal weight'), 200,
          scrollable: find.byType(Scrollable).first);
      await pumpFrames(tester, seconds: 1);

      expect(find.text('75.0 kg'), findsWidgets);
      expect(find.text('7.4 kg to go'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('imperial shows pounds everywhere', (tester) async {
      goals
        ..currentWeightKg = 82.4
        ..goalWeightKg = 75;
      await pumpWeight(tester, metric: false);
      await tester.scrollUntilVisible(find.text('Goal weight'), 200,
          scrollable: find.byType(Scrollable).first);
      await pumpFrames(tester, seconds: 1);

      expect(find.text('181.7 lbs'), findsWidgets); // 82.4 kg
      expect(find.text('165.3 lbs'), findsWidgets); // 75 kg
      expect(find.text('16.3 lbs to go'), findsOneWidget);
      expect(find.textContaining(' kg'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('logging a weight in pounds stores kilograms', (tester) async {
      goals
        ..currentWeightKg = 82.4
        ..goalWeightKg = 75;
      await pumpWeight(tester, metric: false);

      await tester.tap(find.text('Log'));
      await pumpFrames(tester, seconds: 1);
      await tester.enterText(find.byType(TextField), '180');
      await tester.tap(find.text('Save'));
      await pumpFrames(tester, seconds: 1);

      expect(find.text('180.0 lbs'), findsWidgets);
      expect(goals.currentWeightKg, closeTo(81.65, 0.01));
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping a weigh-in can delete it', (tester) async {
      final now = DateTime.now();
      await StorageService().put('weight_history', jsonEncode([
        {'date': now.subtract(const Duration(days: 10)).toIso8601String(), 'weight': 71.0},
        {'date': now.toIso8601String(), 'weight': 95.0},
      ]));
      goals.currentWeightKg = 95;
      await pumpWeight(tester);
      expect(find.text('95.0 kg'), findsWidgets);

      // Today's weigh-in sits at the right end of the plot.
      final chart = tester.getRect(find.byType(WeightChart));
      await tester.tapAt(Offset(chart.right - 40 - chart.width * 0.03, chart.center.dy));
      await pumpFrames(tester, seconds: 1);
      await tester.tap(find.text('Delete weigh-in'));
      await pumpFrames(tester, seconds: 1);

      expect(find.text('71.0 kg'), findsWidgets);
      expect(find.textContaining('95.0'), findsNothing);
      expect(goals.currentWeightKg, 71.0);
      expect(StorageService().get('weight_history'), isNot(contains('95.0')));
      expect(tester.takeException(), isNull);
    });

    testWidgets('rejects an impossible weight', (tester) async {
      goals.currentWeightKg = 82.4;
      await pumpWeight(tester);

      await tester.tap(find.text('Log'));
      await pumpFrames(tester, seconds: 1);
      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.text('Save'));
      await pumpFrames(tester, seconds: 1);

      expect(find.textContaining('Enter a weight between'), findsOneWidget);
      expect(goals.currentWeightKg, 82.4);
    });
  });

  group('Delete account', () {
    testWidgets('email users must enter their password', (tester) async {
      phone(tester);
      await tester.pumpWidget(
          testApp(const DeleteAccountScreen(), goalsProvider: goals));
      await pumpFrames(tester, seconds: 1);

      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(find.text('Please enter your password'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'hunter22');
      expect(form.validate(), isTrue);
      await tester.pump();
      expect(find.text('Please enter your password'), findsNothing);
    });
  });
}
