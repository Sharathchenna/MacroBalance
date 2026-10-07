import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/screens/TrackingPagesScreen.dart';
import 'package:macrotracker/screens/energy/energy_tab.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/trend_weight.dart';
import 'package:macrotracker/services/energy_sync_service.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

/// Serves fixed rows instead of the estimator's, so each state can be shown
/// with known numbers. Like the real cache, saving never drops old rows.
class _FixtureSync extends EnergySyncService {
  _FixtureSync(List<EnergyEstimate> rows)
      : _rows = {for (final r in rows) r.day: r};

  final Map<DateTime, EnergyEstimate> _rows;

  @override
  Map<DateTime, EnergyEstimate> loadCache() => Map.of(_rows);

  @override
  Future<Map<DateTime, EnergyEstimate>> save(List<EnergyEstimate> rows,
          {required DateTime today}) async =>
      Map.of(_rows);

  @override
  Set<String> pendingDays() => const {};
}

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);
DateTime ago(int n) => DateTime(_today.year, _today.month, _today.day - n);

EnergyEstimate est(
  int daysAgo, {
  double tdee = 2450,
  double sd = 88,
  EnergyState state = EnergyState.confident,
  bool updated = true,
  int completeDays = 12,
  int weighIns = 15,
  DateTime? lastUpdateDay,
}) {
  const intake = 2140.0, slope = -0.3 / 7, ed = 7230.0;
  return EnergyEstimate(
    day: ago(daysAgo),
    tdee: tdee,
    tdeeSd: sd,
    state: state,
    completeDays: completeDays,
    weighIns: weighIns,
    updated: updated,
    avgIntake: intake,
    slopeKgPerDay: slope,
    energyDensity: updated ? ed : null,
    observedTdee: updated ? intake - slope * ed : null,
    lastUpdateDay: lastUpdateDay ?? (updated ? ago(daysAgo) : null),
  );
}

List<EnergyEstimate> confidentRows() => [
      for (var n = 30; n >= 1; n--) est(n, tdee: n == 8 ? 2410 : 2450),
    ];

List<EnergyEstimate> estimatedRows() => [
      for (var n = 30; n >= 1; n--)
        est(n, tdee: 2380, sd: 236, state: EnergyState.estimated),
    ];

List<EnergyEstimate> pausedRows() => [
      for (var n = 30; n >= 10; n--) est(n),
      for (var n = 9; n >= 1; n--)
        est(n,
            updated: false,
            state: n <= 2 ? EnergyState.paused : EnergyState.confident,
            lastUpdateDay: ago(10)),
    ];

List<EnergyEstimate> learningRows() => [
      for (var n = 9; n >= 1; n--)
        est(n,
            tdee: 2300,
            sd: 300,
            state: EnergyState.learning,
            updated: false,
            completeDays: 3,
            weighIns: 2),
    ];

/// Inputs for the data-quality strip: food on every day but [untracked],
/// a weigh-in on each day in [weighed].
EstimatorInputs inputs({
  required DateTime start,
  Set<int> untracked = const {},
  Iterable<int>? weighed,
}) =>
    EstimatorInputs(
      learningStartedOn: start,
      formulaTdee: 2300,
      body: const BodyProfile(sex: Sex.male, heightCm: 180, age: 30),
      food: {
        for (var n = 40; n >= 1; n--)
          if (!untracked.contains(n)) ago(n): const FoodDay(loggedCals: 2200),
      },
      weights: [
        for (final n in weighed ?? [for (var n = 40; n >= 1; n--) n])
          WeightReading(ago(n), 80),
      ],
    );

Future<(EnergyProvider, GoalsProvider)> pumpTab(
  WidgetTester tester, {
  required List<EnergyEstimate> rows,
  required DateTime start,
  Set<int> untracked = const {},
  Iterable<int>? weighed,
  bool dark = true,
  VoidCallback? onLogWeight,
}) async {
  tester.view.physicalSize = const Size(1179, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final goals = GoalsProvider()..startLearning(start);
  final energy = EnergyProvider(
    sync: _FixtureSync(rows),
    inBackground: false,
    debounce: Duration.zero,
  )..inputs = () => inputs(
        start: goals.learningStartedOn!,
        untracked: untracked,
        weighed: weighed,
      );
  await tester.runAsync(energy.refresh);
  await tester.pumpWidget(testApp(
    Scaffold(body: EnergyTab(onLogWeight: onLogWeight)),
    goalsProvider: goals,
    energyProvider: energy,
    dark: dark,
  ));
  await tester.pump();
  return (energy, goals);
}

Future<void> scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(f, 200,
      scrollable: find.byType(Scrollable).first);
  await pumpFrames(tester, seconds: 1);
}

const _unitKey = 'unit_system'; // WeightUnitProvider's setting

void main() {
  final events = <MethodCall>[];

  setUp(() async {
    await setUpTestEnvironment();
    await EnergySyncService().clearLocalState();
    await StorageService().put(_unitKey, 'metric');
    events.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('posthog_flutter'),
            (call) async {
      if (call.method == 'capture') events.add(call);
      return null;
    });
  });

  List<Map> captured(String name) => [
        for (final c in events)
          if ((c.arguments as Map)['eventName'] == name) c.arguments as Map,
      ];

  for (final dark in [true, false]) {
    group(dark ? 'dark' : 'light', () {
      testWidgets('confident: number, ±, week change, how we got this',
          (tester) async {
        await pumpTab(tester, rows: confidentRows(), start: ago(30), dark: dark);

        expect(find.text('Your daily expenditure'), findsOneWidget);
        expect(find.text('2,450'), findsOneWidget);
        expect(find.text('± 90'), findsOneWidget);
        expect(find.text('Confident'), findsOneWidget);
        expect(find.text('▲ 40 since last week'), findsOneWidget);
        expect(find.byKey(const Key('energy_learning_ring')), findsNothing);

        // The breakdown adds up: 2,140 + 310 = 2,450.
        expect(find.text('How we got this'), findsOneWidget);
        expect(find.text('Last 3 weeks'), findsOneWidget);
        expect(find.text('2,140 cals/day'), findsOneWidget);
        expect(find.text('12 complete days'), findsOneWidget);
        expect(find.text('−0.30 kg/week'), findsOneWidget);
        expect(find.text('≈ +310 cals/day'), findsOneWidget);
        expect(find.text('≈ 2,450 cals/day'), findsOneWidget);

        await scrollTo(tester, find.text('Reset learning'));
        expect(find.byKey(const Key('energy_quality_strip')), findsOneWidget);
        expect(find.textContaining('21 complete days · 21 weigh-ins'),
            findsOneWidget);
        expect(find.byKey(const Key('energy_tip_weighIn')), findsNothing);
        expect(find.byKey(const Key('energy_tip_finishDay')), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('estimated: wide ± and a settling note', (tester) async {
        await pumpTab(tester, rows: estimatedRows(), start: ago(30), dark: dark);

        expect(find.text('2,380'), findsOneWidget);
        expect(find.text('± 240'), findsOneWidget);
        expect(find.text('Estimated'), findsOneWidget);
        expect(find.textContaining('Still settling'), findsOneWidget);
        expect(find.byKey(const Key('energy_week_change')), findsNothing);
        expect(find.text('How we got this'), findsOneWidget);
        expect(find.text('Blended with earlier weeks, your expenditure is 2,380 cals.'),
            findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('paused: last updated date, breakdown from that window',
          (tester) async {
        await pumpTab(tester, rows: pausedRows(), start: ago(30), dark: dark);

        expect(find.text('Paused'), findsOneWidget);
        final when = ago(10);
        expect(
            find.textContaining(RegExp(
                r'^Last updated [A-Z][a-z]{2} \d{1,2}.* · log a few days to resume$')),
            findsOneWidget);
        expect(find.textContaining('${when.day}'), findsWidgets);
        expect(find.textContaining('3 weeks to '), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('learning: starting estimate and the progress ring',
          (tester) async {
        await pumpTab(tester,
            rows: learningRows(), start: ago(9), weighed: [8, 3], dark: dark);

        // The headline's label; the chart's legend has one too.
        expect(find.text('Starting estimate').first, findsOneWidget);
        expect(find.text('2,300'), findsOneWidget);
        expect(find.text('± 300'), findsNothing);
        expect(find.text('Learning'), findsOneWidget);
        expect(find.byKey(const Key('energy_learning_ring')), findsOneWidget);
        expect(find.text('Learning your metabolism'), findsOneWidget);
        expect(find.text('3 of 7 days logged'), findsOneWidget);
        expect(find.text('2 of 4 weigh-ins'), findsOneWidget);
        expect(find.text('How we got this'), findsNothing);

        // Days before the learning start don't count: 2 weigh-ins → tip.
        await scrollTo(tester, find.text('Reset learning'));
        expect(find.byKey(const Key('energy_tip_weighIn')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  }

  testWidgets('the weight change follows the unit setting', (tester) async {
    await StorageService().put(_unitKey, 'imperial');
    await pumpTab(tester, rows: confidentRows(), start: ago(30));
    expect(find.text('−0.66 lbs/week'), findsOneWidget);
  });

  testWidgets('finish-day tip when over 30% of days are gaps', (tester) async {
    await pumpTab(tester,
        rows: confidentRows(),
        start: ago(30),
        untracked: {1, 2, 3, 5, 8, 13, 17});
    await scrollTo(tester, find.text('Reset learning'));
    expect(find.byKey(const Key('energy_tip_finishDay')), findsOneWidget);
    expect(find.textContaining('14 complete days'), findsOneWidget);
  });

  testWidgets('no weigh-ins at all while learning offers to log one',
      (tester) async {
    var opened = false;
    await pumpTab(tester,
        rows: learningRows(),
        start: ago(9),
        weighed: [],
        onLogWeight: () => opened = true);
    await tester.tap(find.text('Log your weight'));
    expect(opened, isTrue);
  });

  testWidgets('reset learning asks first, restarts today, keeps history',
      (tester) async {
    final (energy, goals) =
        await pumpTab(tester, rows: confidentRows(), start: ago(30));

    await scrollTo(tester, find.text('Reset learning'));
    await tester.tap(find.text('Reset learning'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Reset learning?'), findsOneWidget);

    // Cancel changes nothing.
    await tester.tap(find.text('Cancel'));
    await pumpFrames(tester, seconds: 1);
    expect(goals.learningStartedOn, ago(30));
    expect(captured('learning_reset'), isEmpty);

    await tester.tap(find.text('Reset learning'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Reset'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await pumpFrames(tester, seconds: 1);

    expect(goals.learningStartedOn, _today);
    expect(energy.estimates, hasLength(30), reason: 'history is kept');
    expect(captured('learning_reset'), hasLength(1));
    await tester.scrollUntilVisible(find.text('Learning'), -200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Starting estimate').first, findsOneWidget);
    expect(find.text('Learning'), findsOneWidget);
    expect(find.text('How we got this'), findsNothing);
  });

  group('Progress tabs', () {
    testWidgets('Energy is first and opens by default; viewing it is tracked',
        (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final goals = GoalsProvider()..startLearning(ago(30));
      final energy =
          EnergyProvider(sync: _FixtureSync(confidentRows()), inBackground: false);

      await tester.pumpWidget(testApp(const TrackingPagesScreen(),
          goalsProvider: goals, energyProvider: energy));
      await pumpFrames(tester, seconds: 1);

      final tabs = tester.widgetList<Tab>(find.byType(Tab)).map((t) => t.text);
      expect(tabs, ['Energy', 'Weight', 'Nutrition', 'Steps', 'Workouts']);
      expect(find.text('Your daily expenditure'), findsOneWidget);
      expect(captured('energy_tab_viewed').single['properties'],
          containsPair('state', 'confident'));
      // The unit toggle belongs to the Weight tab.
      expect(find.byIcon(Icons.scale), findsNothing);

      await tester.tap(find.text('Weight'));
      await pumpFrames(tester, seconds: 1);
      expect(find.byIcon(Icons.scale), findsOneWidget);

      await tester.tap(find.text('Energy'));
      await pumpFrames(tester, seconds: 1);
      expect(captured('energy_tab_viewed'), hasLength(2));
    });

    testWidgets('initialPage still opens the named tab', (tester) async {
      await tester.pumpWidget(testApp(
          const TrackingPagesScreen(initialPage: TrackingPagesScreen.weightTab)));
      await pumpFrames(tester, seconds: 1);
      expect(find.byIcon(Icons.scale), findsOneWidget);
      expect(captured('energy_tab_viewed'), isEmpty);
    });
  });
}
