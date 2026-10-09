import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/screens/onboarding/pages/activity_level_page.dart';
import 'package:macrotracker/screens/onboarding/pages/adaptive_page.dart';
import 'package:macrotracker/screens/onboarding/pages/goal_page.dart';
import 'package:macrotracker/screens/onboarding/pages/summary_page.dart';
import 'package:macrotracker/screens/onboarding/pages/weight_page.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy_sync_service.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

/// Serves fixed estimate rows (as in the Energy tab tests).
class _FixtureSync extends EnergySyncService {
  _FixtureSync(List<EnergyEstimate> rows) : _rows = {for (final r in rows) r.day: r};

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
DateTime ago(int n) => DateTime(_now.year, _now.month, _now.day - n);
String _date(DateTime d) => d.toIso8601String().substring(0, 10);

/// Daily estimates through yesterday, ending in [state] at [tdee].
List<EnergyEstimate> estimates(EnergyState state, {double tdee = 2450}) => [
      for (var n = 20; n >= 1; n--)
        EnergyEstimate(
          day: ago(n),
          tdee: tdee,
          tdeeSd: state == EnergyState.confident ? 90 : 240,
          state: state,
          completeDays: 14,
          weighIns: 16,
          updated: true,
        ),
    ];

void main() {
  late GoalsProvider goals;
  final learningStart = ago(40);

  setUp(() async {
    await setUpTestEnvironment();
    for (final key in ['nutrition_goals', 'goal_settings', 'weight_history']) {
      await StorageService().delete(key);
    }
    await StorageService().put('unit_system', 'metric');
    // An account losing weight, adaptive on, with targets from a check-in.
    await StorageService().put(
        'nutrition_goals',
        jsonEncode({
          'macro_targets': {'calories': 2451, 'protein': 112, 'carbs': 348, 'fat': 68},
          'sex': MacroCalculatorService.MALE,
          'height_cm': 180,
          'age': 30,
          'age_recorded_on': _date(DateTime.now()),
          'activity_level': 3,
          'goal_type': MacroCalculatorService.GOAL_LOSE,
          'pace_pct_per_week': 0.5,
          'goal_weight_kg': 75,
          'current_weight_kg': 82,
          'tdee': 2451,
          'formula_tdee': 2000,
          'learning_started_on': _date(learningStart),
          'adaptive_goals': true,
          'checkin_weekday': DateTime.monday,
        }));
    goals = GoalsProvider();
    await goals.load();
  });

  Future<void> open(WidgetTester tester,
      {EnergyState state = EnergyState.confident, bool dark = true}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final energy = EnergyProvider(
        sync: _FixtureSync(estimates(state)), inBackground: false);
    await tester.pumpWidget(testApp(detailedStatsProvider: DetailedStatsProvider(showDetailedStats: true),
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const OnboardingScreen(recalculateOnly: true))),
          child: const Text('Open'),
        ),
      ),
      goalsProvider: goals,
      energyProvider: energy,
      dark: dark,
    ));
    await tester.tap(find.text('Open'));
    await pumpFrames(tester, seconds: 1);
  }

  Finder visible(Type page) => find.byType(page).hitTestable();

  Future<void> next(WidgetTester tester, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.text('Next'));
      await pumpFrames(tester, seconds: 1);
    }
  }

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.text('Back'));
    await pumpFrames(tester, seconds: 1);
  }

  Map<String, dynamic> plan({double? tdee, double weightKg = 82}) =>
      MacroCalculatorService().calculateAll(
        gender: MacroCalculatorService.MALE,
        weightKg: weightKg,
        heightCm: 180,
        age: 30,
        activityLevel: 3,
        goal: MacroCalculatorService.GOAL_LOSE,
        pacePct: 0.5,
        goalWeightKg: 75,
        tdee: tdee,
      );

  Future<Map> saveFromSummary(WidgetTester tester) async {
    await tester.tap(find.text('Calculate'));
    await pumpFrames(tester, seconds: 2);
    await tester.tap(find.text('Save new goals'));
    await pumpFrames(tester, seconds: 2);
    return jsonDecode(StorageService().get('nutrition_goals') as String) as Map;
  }

  group('adaptive on and confident', () {
    testWidgets('activity is skipped both ways', (tester) async {
      await open(tester);
      expect(visible(WeightPage), findsOneWidget);
      await next(tester);
      expect(visible(GoalPage), findsOneWidget);
      expect(visible(ActivityLevelPage), findsNothing);
      await back(tester);
      expect(visible(WeightPage), findsOneWidget);
    });

    testWidgets('the summary shows old -> new targets from the learned expenditure',
        (tester) async {
      await open(tester);
      // weight -> goal -> goal weight -> plan style -> adaptive -> advanced -> summary
      await next(tester, 6);
      expect(visible(SummaryPage), findsOneWidget);

      final expected = plan(tdee: 2450);
      expect(find.text('Your Targets'), findsOneWidget);
      expect(find.text('2,451 → ${NumberFormat('#,###').format(expected['target_calories'])} cals'),
          findsOneWidget);
      expect(find.text('112 → ${expected['protein_g']} g'), findsOneWidget);
      expect(find.text('348 → ${expected['carb_g']} g'), findsOneWidget);
      expect(find.text('68 → ${expected['fat_g']} g'), findsOneWidget);
      expect(
          find.text('Using your learned expenditure (2,450 cals) instead of an activity estimate.'),
          findsOneWidget);
      expect(find.text('Activity Level'), findsNothing);
    });

    testWidgets('saving plans from the estimate and never resets learning', (tester) async {
      await open(tester);
      await next(tester, 6);
      final saved = await saveFromSummary(tester);

      final expected = plan(tdee: 2450);
      expect(saved['macro_targets']['calories'], expected['target_calories']);
      expect(saved['tdee'], 2450);
      // The estimator's starting point and learning start are untouched.
      expect(saved['formula_tdee'], 2000);
      expect(saved['learning_started_on'], _date(learningStart));
      await goals.load();
      expect(goals.learningStartedOn, learningStart);
      expect(goals.formulaTdee, 2000);
      expect(goals.caloriesGoal, expected['target_calories']);
    });

    testWidgets('turning adaptive off goes back to the formula and the activity level',
        (tester) async {
      await open(tester);
      await next(tester, 4);
      expect(visible(AdaptivePage), findsOneWidget);
      tester.widget<AdaptivePage>(find.byType(AdaptivePage)).onChanged(false);
      await pumpFrames(tester, seconds: 1);
      await next(tester, 2);
      expect(visible(SummaryPage), findsOneWidget);
      expect(find.textContaining('learned expenditure'), findsNothing);
      // Activity was passed while adaptive was on; it can be edited here.
      expect(find.text('Activity Level'), findsOneWidget);

      final saved = await saveFromSummary(tester);
      final formula = plan();
      expect(saved['tdee'], formula['tdee']);
      expect(saved['formula_tdee'], formula['formula_tdee']);
      expect(saved['macro_targets']['calories'], formula['target_calories']);
      expect(saved['adaptive_goals'], isFalse);
      expect(saved['learning_started_on'], _date(learningStart));
    });
  });

  for (final state in [EnergyState.learning, EnergyState.estimated, EnergyState.paused]) {
    testWidgets('a ${state.code} estimate asks activity and uses the formula', (tester) async {
      await open(tester, state: state);
      await next(tester);
      expect(visible(ActivityLevelPage), findsOneWidget);
      await next(tester, 6);
      expect(visible(SummaryPage), findsOneWidget);
      expect(find.textContaining('learned expenditure'), findsNothing);
      expect(find.text('Activity Level'), findsOneWidget);

      final saved = await saveFromSummary(tester);
      expect(saved['tdee'], isNot(2450));
      expect(saved['tdee'], saved['formula_tdee']);
      expect(saved['learning_started_on'], _date(learningStart));
    });
  }

  group('weight', () {
    Future<void> weighIns(List<(int, double)> readings) => StorageService().put(
        'weight_history',
        jsonEncode([
          for (final (daysAgo, kg) in readings)
            {'date': ago(daysAgo).toIso8601String(), 'weight': kg},
        ]));

    testWidgets('after a recent weigh-in: the trend, one tap away', (tester) async {
      // The scale says 81.0 today; the trend is higher.
      await weighIns([for (var n = 14; n >= 1; n--) (n, 82.0), (0, 81.0)]);
      await open(tester);
      final page = tester.widget<WeightPage>(find.byType(WeightPage));
      expect(page.currentWeightKg, 81.9);
      expect(page.trendKg, 81.9);
      expect(find.text('Use 81.9 kg (your trend)'), findsOneWidget);

      await tester.tap(find.text('Use 81.9 kg (your trend)'));
      await pumpFrames(tester, seconds: 1);
      expect(visible(GoalPage), findsOneWidget);
      await next(tester, 5);
      final saved = await saveFromSummary(tester);
      expect(saved['current_weight_kg'], 81.9);
    });

    testWidgets('in pounds, the button follows the unit', (tester) async {
      await StorageService().put('unit_system', 'imperial');
      await weighIns([(1, 80.0)]);
      await open(tester);
      expect(find.text('Use 176 lbs (your trend)'), findsOneWidget);
    });

    testWidgets('an older weigh-in still prefills the trend, without the button',
        (tester) async {
      await weighIns([(10, 79.0), (5, 79.4)]);
      await open(tester);
      final page = tester.widget<WeightPage>(find.byType(WeightPage));
      expect(page.currentWeightKg, closeTo(79.2, 0.1));
      expect(page.trendKg, isNull);
      expect(find.textContaining('(your trend)'), findsNothing);
    });

    testWidgets('without weigh-ins it starts at the profile weight', (tester) async {
      await open(tester);
      expect(tester.widget<WeightPage>(find.byType(WeightPage)).currentWeightKg, 82);
      expect(find.textContaining('(your trend)'), findsNothing);
    });
  });

  testWidgets('new users see no targets card or trend button', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(detailedStatsProvider: DetailedStatsProvider(showDetailedStats: true),
      Scaffold(
        body: SummaryPage(
          gender: MacroCalculatorService.MALE,
          weightKg: 80,
          heightCm: 180,
          age: 30,
          activityLevel: 3,
          goal: MacroCalculatorService.GOAL_MAINTAIN,
          pacePct: 0,
          proteinRatio: 1.6,
          fatRatio: 0.25,
          goalWeightKg: 80,
          onEdit: (_) {},
        ),
      ),
      goalsProvider: goals,
    ));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Your Targets'), findsNothing);
    expect(find.text('Activity Level'), findsOneWidget);
  });
}
