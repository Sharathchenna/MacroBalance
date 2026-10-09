import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/WeightTrackingScreen.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/theme/app_theme.dart';

import '../helpers/test_app.dart';

void main() {
  late GoalsProvider goals;

  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('nutrition_goals');
    await StorageService().delete('weight_history');
    await StorageService().delete('unit_system');
    goals = GoalsProvider()
      ..goalType = MacroCalculatorService.GOAL_LOSE
      ..pacePctPerWeek = 0.5
      ..goalWeightKg = 70;
  });

  /// One weigh-in a day, oldest first, ending today.
  Future<void> history(List<double> weights) {
    final today = DateTime.now();
    final n = weights.length;
    return StorageService().put('weight_history', jsonEncode([
      for (var i = 0; i < n; i++)
        {
          'date': DateTime(today.year, today.month, today.day - (n - 1 - i), 8)
              .toIso8601String(),
          'weight': weights[i],
        }
    ]));
  }

  Future<void> pump(WidgetTester tester, {bool metric = true}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(const WeightTrackingScreen(),
        goalsProvider: goals,
        weightUnitProvider: WeightUnitProvider()..setMetric(metric),
        // The trend, pace row and legend are the detailed stats view.
        detailedStatsProvider: DetailedStatsProvider(showDetailedStats: true)));
    await pumpFrames(tester, seconds: 2);
  }

  BoxDecoration paceRow(WidgetTester tester) => tester
      .widget<Container>(find.byKey(const Key('weight_pace_row')))
      .decoration as BoxDecoration;

  CustomColors colors(WidgetTester tester) =>
      Theme.of(tester.element(find.byKey(const Key('weight_pace_row'))))
          .extension<CustomColors>()!;

  /// A steady loss of [kgPerDay] from 80 kg over [days] days.
  List<double> losing(double kgPerDay, {int days = 21}) =>
      [for (var i = 0; i < days; i++) 80 - kgPerDay * i];

  testWidgets('the headline is the trend, with the scale reading under it',
      (tester) async {
    await history([80, 80, 80, 80, 80, 80, 80, 80, 78.5]);
    await pump(tester);

    // 78.5 is under 3% off, so it moves the trend a tenth of the way: 79.85.
    expect(find.text('Trend weight'), findsOneWidget);
    expect(find.text('79.8 kg'), findsWidgets);
    expect(find.text('Scale 78.5 kg · today'), findsOneWidget);
  });

  testWidgets('an outlier does not move the headline', (tester) async {
    await history([80, 80, 80, 80, 80, 80, 80, 80, 84]);
    await pump(tester);
    expect(find.text('80.0 kg'), findsWidgets);
    expect(find.text('Scale 84.0 kg · today'), findsOneWidget);
    expect(find.text('Ignored'), findsOneWidget); // chart legend
  });

  testWidgets('on pace: a neutral row with kg and %', (tester) async {
    // 0.5%/wk of 80 kg is about 0.057 kg a day.
    await history(losing(0.4 / 7, days: 60));
    await pump(tester);

    expect(find.textContaining(RegExp(r'^−0\.\d kg/wk \(−0\.\d%\)$')),
        findsOneWidget);
    expect(find.text('Goal −0.5%/wk'), findsOneWidget);
    expect(paceRow(tester).color,
        colors(tester).textSecondary.withValues(alpha: 0.08));
  });

  testWidgets('off pace: a soft accent, never red', (tester) async {
    await history(losing(0, days: 21));
    await pump(tester);

    expect(find.text('0.0 kg/wk (0%)'), findsOneWidget);
    expect(paceRow(tester).color,
        colors(tester).accentPrimary.withValues(alpha: 0.12));
  });

  testWidgets('the pace row follows the unit setting', (tester) async {
    await history(losing(0.1, days: 21));
    await pump(tester, metric: false);

    // The trend lags the readings but falls about 0.7 kg a week, ~1.5 lbs.
    expect(find.textContaining(RegExp(r'^−1\.\d lbs/wk \(−0\.\d%\)$')),
        findsOneWidget);
    expect(find.textContaining('kg/wk'), findsNothing);
  });

  testWidgets('maintaining aims to hold steady', (tester) async {
    goals.goalType = MacroCalculatorService.GOAL_MAINTAIN;
    await history(List.filled(14, 75.0));
    await pump(tester);
    expect(find.text('Goal: hold steady'), findsOneWidget);
    expect(paceRow(tester).color,
        colors(tester).textSecondary.withValues(alpha: 0.08));
  });

  testWidgets('under a week of weigh-ins: says when the pace will show',
      (tester) async {
    await history([80, 79.9, 79.8]);
    await pump(tester);
    expect(find.text('Your weekly pace shows after a week of weigh-ins'),
        findsOneWidget);
  });

  testWidgets('goal progress uses the trend, not the last reading',
      (tester) async {
    await history([80, 80, 80, 80, 80, 80, 80, 80, 78.5]);
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Goal weight'), 200,
        scrollable: find.byType(Scrollable).first);
    await pumpFrames(tester, seconds: 1);

    // 79.85 − 70, not 78.5 − 70.
    expect(find.text('9.8 kg to go'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
