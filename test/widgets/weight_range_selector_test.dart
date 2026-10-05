import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/screens/WeightTrackingScreen.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/utils/weight_range.dart';
import 'package:macrotracker/widgets/weight_range_selector.dart';

import '../helpers/test_app.dart';

void main() {
  setUp(setUpTestEnvironment);

  testWidgets('selector shows every range and reports taps', (tester) async {
    WeightRange? picked;
    await tester.pumpWidget(testApp(Scaffold(
      body: Center(
        child: SizedBox(
          width: 360,
          child: WeightRangeSelector(
            selected: WeightRange.month,
            onChanged: (r) => picked = r,
          ),
        ),
      ),
    )));
    await settle(tester);

    for (final r in WeightRange.values) {
      expect(find.text(r.label), findsOneWidget);
    }
    await tester.tap(find.text('6M'));
    expect(picked, WeightRange.sixMonths);
    await tester.tap(find.text('All'));
    expect(picked, WeightRange.all);
    // Tapping the selected range does nothing.
    picked = null;
    await tester.tap(find.text('1M'));
    expect(picked, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selector fits a narrow phone', (tester) async {
    await tester.pumpWidget(testApp(Scaffold(
      body: Center(
        child: SizedBox(
          width: 280,
          child: WeightRangeSelector(selected: WeightRange.all, onChanged: (_) {}),
        ),
      ),
    )));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('weight screen switches through every range with a long history',
      (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final history = [
      for (var d = 0; d < 500; d += 9)
        {
          'date': now.subtract(Duration(days: d)).toIso8601String(),
          'weight': 72 - d / 100,
        }
    ];
    await StorageService().put('weight_history', jsonEncode(history));

    await tester.pumpWidget(testApp(const WeightTrackingScreen()));
    await pumpFrames(tester);

    for (final r in [...WeightRange.values, WeightRange.week]) {
      await tester.ensureVisible(find.text(r.label));
      await tester.tap(find.text(r.label));
      await pumpFrames(tester, seconds: 1);
      expect(tester.takeException(), isNull, reason: r.label);
    }

    // A range with no entries says so instead of drawing an empty chart.
    await StorageService().put('weight_history', jsonEncode([
      {'date': now.subtract(const Duration(days: 300)).toIso8601String(), 'weight': 70},
      {'date': now.subtract(const Duration(days: 200)).toIso8601String(), 'weight': 69},
    ]));
    await tester.pumpWidget(const SizedBox()); // fresh screen, reloads history
    await tester.pumpWidget(testApp(const WeightTrackingScreen()));
    await pumpFrames(tester);
    await tester.ensureVisible(find.text('1W'));
    await tester.tap(find.text('1W'));
    await pumpFrames(tester, seconds: 1);
    expect(find.textContaining('No weight logged'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
