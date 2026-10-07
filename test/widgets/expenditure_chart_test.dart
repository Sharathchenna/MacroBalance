import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/screens/energy/energy_tab.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/widgets/expenditure_chart.dart';

import '../helpers/test_app.dart';

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);
DateTime ago(int n) => DateTime(_today.year, _today.month, _today.day - n);

EnergyEstimate est(int daysAgo, double tdee,
        {double sd = 90, EnergyState state = EnergyState.confident}) =>
    EnergyEstimate(
      day: ago(daysAgo),
      tdee: tdee,
      tdeeSd: sd,
      state: state,
      completeDays: 12,
      weighIns: 15,
      updated: state != EnergyState.learning,
    );

/// A learning run from [from] days ago to yesterday: 10 learning days at
/// [start], then 5 cals a day up, settling at +400.
List<EnergyEstimate> run(int from, {int to = 1, double start = 2000}) => [
      for (var n = from; n >= to; n--)
        if (from - n < 10)
          est(n, start, sd: 300, state: EnergyState.learning)
        else
          est(n, start + (5.0 * (from - n - 9)).clamp(0, 400),
              sd: (300 - 5.0 * (from - n - 9)).clamp(90, 300)),
    ];

Future<void> pumpCard(
  WidgetTester tester, {
  required List<EnergyEstimate> rows,
  DateTime? learningStartedOn,
  double formula = 2000,
  bool dark = true,
}) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(testApp(
    Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ExpenditureCard(
            estimates: rows,
            learningStartedOn: learningStartedOn ?? rows.first.day,
            formulaTdee: formula,
          ),
        ],
      ),
    ),
    dark: dark,
  ));
  await pumpFrames(tester, seconds: 1);
}

ExpenditureChart chart(WidgetTester tester) =>
    tester.widget<ExpenditureChart>(find.byType(ExpenditureChart));

String md(DateTime d) => d.year == _today.year
    ? DateFormat.MMMd().format(d)
    : DateFormat.yMMMd().format(d);

void main() {
  setUp(setUpTestEnvironment);

  for (final dark in [true, false]) {
    testWidgets('${dark ? 'dark' : 'light'}: line, band, formula and legend',
        (tester) async {
      await pumpCard(tester, rows: run(60), dark: dark);
      expect(tester.takeException(), isNull);
      expect(find.text('Expenditure'), findsOneWidget);
      expect(find.text('Likely range'), findsOneWidget);
      expect(find.text('Starting estimate'), findsOneWidget);
      expect(find.text('Before reset'), findsNothing);
      // 1M by default.
      final c = chart(tester);
      expect(c.formulaTdee, 2000);
      expect(c.series.first, isNot(ago(60)));
      expect(c.series.last, ago(1));
    });
  }

  testWidgets('range chips filter the rows; All draws a year', (tester) async {
    await pumpCard(tester, rows: run(400));
    final monthStart = DateTime(_today.year, _today.month - 1, _today.day);
    expect(chart(tester).series.first, monthStart);
    expect(chart(tester).start, monthStart);
    expect(find.text('over the past month'), findsOneWidget);

    await tester.tap(find.text('3M'));
    await pumpFrames(tester, seconds: 1);
    expect(chart(tester).series.first,
        DateTime(_today.year, _today.month - 3, _today.day));
    expect(find.text('over the past 3 months'), findsOneWidget);

    await tester.tap(find.text('6M'));
    await pumpFrames(tester, seconds: 1);
    expect(chart(tester).series.first,
        DateTime(_today.year, _today.month - 6, _today.day));

    // All: every row, and drawing it in stays well inside a frame.
    await tester.tap(find.text('All'));
    final watch = Stopwatch()..start();
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final perFrame = watch.elapsedMicroseconds / 40 / 1000;
    expect(chart(tester).series.rows, hasLength(400));
    expect(chart(tester).start, ago(400));
    expect(find.text('+400 cals'), findsOneWidget);
    expect(find.text('since ${md(ago(400))}'), findsOneWidget);
    expect(perFrame, lessThan(16), reason: 'avg $perFrame ms a frame');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a reset breaks the line and greys what came before',
      (tester) async {
    final rows = [...run(60, to: 21), ...run(20, start: 2300)];
    await pumpCard(tester, rows: rows, learningStartedOn: ago(20));
    await tester.tap(find.text('All'));
    await pumpFrames(tester, seconds: 1);

    final s = chart(tester).series;
    expect(s.segments, hasLength(2));
    expect(s.segments.first.preReset, isTrue);
    expect(s.segments.last.preReset, isFalse);
    expect(s.resets, [ago(20)]);
    expect(find.text('Before reset'), findsOneWidget);
    // The change never spans the reset.
    expect(find.text('since ${md(ago(20))}'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('touching the chart reads a day', (tester) async {
    await pumpCard(tester, rows: run(100));
    final box = tester.getRect(find.byType(ExpenditureChart));
    // Near the right edge: yesterday, settled at 2,400 ± 90.
    final gesture =
        await tester.startGesture(box.centerRight - const Offset(48, 0));
    // Past the press timeout, as a finger resting on the chart.
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('2,400 cals'), findsOneWidget);
    expect(find.text('${md(ago(1))} · ± 90'), findsOneWidget);
    await gesture.up();
    await tester.pump();
    expect(find.text('2,400 cals'), findsNothing);
  });

  testWidgets('touching a pre-reset day says so', (tester) async {
    final rows = [...run(60, to: 21), ...run(20, start: 2300)];
    await pumpCard(tester, rows: rows, learningStartedOn: ago(20));
    await tester.tap(find.text('All'));
    await pumpFrames(tester, seconds: 1);
    final box = tester.getRect(find.byType(ExpenditureChart));
    final gesture =
        await tester.startGesture(box.center - Offset(box.width / 4, 0));
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.textContaining('before you reset'), findsOneWidget);
    await gesture.up();
  });

  testWidgets('a range with no estimates says so', (tester) async {
    await pumpCard(tester, rows: run(90, to: 45));
    expect(find.text('No estimates over the past month'), findsOneWidget);
    await tester.tap(find.text('3M'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('No estimates over the past month'), findsNothing);
  });
}
