import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/screens/onboarding/pages/adaptive_page.dart';
import 'package:macrotracker/screens/onboarding/pages/advanced_settings_page.dart';
import 'package:macrotracker/screens/onboarding/pages/apple_health_page.dart';
import 'package:macrotracker/screens/onboarding/pages/goal_page.dart';
import 'package:macrotracker/screens/onboarding/pages/plan_style_page.dart';
import 'package:macrotracker/screens/onboarding/pages/set_new_goal_page.dart';
import 'package:macrotracker/screens/onboarding/pages/summary_page.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/widgets/onboarding/simple_plan_summary.dart';
import '../helpers/simple_copy_audit.dart';
import '../helpers/test_app.dart';

void main() {
  late GoalsProvider goals;
  final events = <MethodCall>[];
  setUp(() async {
    await setUpTestEnvironment();
    for (final key in [
      'nutrition_goals',
      'goal_settings',
      'weight_history',
      DetailedStatsProvider.storageKey
    ]) {
      await StorageService().delete(key);
    }
    await StorageService().put('unit_system', 'metric');
    goals = GoalsProvider();
    events.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('posthog_flutter'),
            (call) async {
      if (call.method == 'capture') events.add(call);
      return null;
    });
  });

  Future<void> pump(WidgetTester tester, Widget child,
      {bool dark = true}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(child,
        goalsProvider: goals,
        energyProvider: EnergyProvider(inBackground: false),
        detailedStatsProvider: DetailedStatsProvider(showDetailedStats: false),
        dark: dark));
    await pumpFrames(tester, seconds: 1);
  }

  Future<void> next(WidgetTester tester, [int count = 1]) async {
    for (var i = 0; i < count; i++) {
      await tester.tap(find.text('Next'));
      await pumpFrames(tester, seconds: 1);
    }
  }

  SetNewGoalPage pacePage(
      {String goal = 'lose',
      bool metric = true,
      double pace = 0.5,
      required ValueChanged<double> changed,
      PlanStyle? style}) {
    final options = goal == 'gain' ? kGainPaceOptions : kLosePaceOptions;
    return SetNewGoalPage(
        currentGoal: goal,
        currentWeightKg: 80,
        goalWeightKg: goal == 'gain' ? 85 : 65,
        paceChoices: [
          for (final p in options)
            PaceChoice(
                target: targetForPace(
                    goal: goal == 'gain' ? GoalKind.gain : GoalKind.lose,
                    pacePct: p,
                    tdee: 2000,
                    sex: Sex.male,
                    weightKg: 80,
                    energyDensity: 7700),
                date: DateTime(2027, 3, 3),
                weeks: 20),
        ],
        pacePct: pace,
        recommendedPacePct: goal == 'gain' ? .25 : .5,
        isMetricWeight: metric,
        onGoalWeightChanged: (_) {},
        onPaceChanged: changed,
        onWeightUnitChanged: (_) {},
        planStyle: style,
        onPlanStyleChanged: (_) {});
  }

  for (final dark in [true, false]) {
    testWidgets(
        'three simple pace cards show dates and select existing pace in ${dark ? 'dark' : 'light'}',
        (tester) async {
      double pace = .5;
      await pump(
          tester,
          StatefulBuilder(
              builder: (_, setState) => Scaffold(
                  body: pacePage(
                      pace: pace, changed: (p) => setState(() => pace = p)))),
          dark: dark);
      expect(find.byKey(const Key('simple_pace_relaxed')), findsOneWidget);
      expect(find.byKey(const Key('simple_pace_recommended')), findsOneWidget);
      expect(find.byKey(const Key('simple_pace_faster')), findsOneWidget);
      expect(find.text('Reach 65.0 kg by Mar 3'), findsNWidgets(3));
      expect(find.text('About 0.4 kg a week'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('simple_pace_faster')));
      await tester.tap(find.byKey(const Key('simple_pace_faster')));
      await tester.pump();
      expect(pace, .75);
      expectSimpleCopy(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('gain pace cards use pounds and friendly safety copy',
      (tester) async {
    await pump(
        tester,
        Scaffold(
            body: pacePage(
                goal: 'gain', metric: false, pace: .25, changed: (_) {})));
    expect(find.text('Reach 187 lbs by Mar 3'), findsNWidgets(3));
    expect(find.text('About 0.2 lbs a week'), findsOneWidget);
    expect(find.text('We’ve eased this pace to keep your target healthy.'),
        findsOneWidget);
    expectSimpleCopy(tester);
  });

  testWidgets(
      'saved faster detailed pace stays selected without changing the goal',
      (tester) async {
    double pace = 1;
    await pump(
        tester, Scaffold(body: pacePage(pace: pace, changed: (p) => pace = p)));
    final semantics = tester.widget<Semantics>(find
        .ancestor(
            of: find.byKey(const Key('simple_pace_faster')),
            matching: find.byType(Semantics))
        .first);
    expect(semantics.properties.selected, isTrue);
    expect(pace, 1);
    expectSimpleCopy(tester);
  });

  testWidgets(
      'More options is collapsed, keeps Steady, and reveals plain plan choices',
      (tester) async {
    await pump(tester,
        Scaffold(body: pacePage(changed: (_) {}, style: PlanStyle.steady)));
    expect(find.text('In phases'), findsNothing);
    await tester.ensureVisible(find.text('More options'));
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Steady'), findsOneWidget);
    expect(find.text('In phases'), findsOneWidget);
    expect(find.text('Diet breaks'), findsOneWidget);
    expectSimpleCopy(tester, allow: {'In phases'});
  });

  testWidgets(
      'adaptive choice is a recommended switch with explanation behind a tap',
      (tester) async {
    bool adaptive = true;
    await pump(
        tester,
        StatefulBuilder(
            builder: (_, setState) => Scaffold(
                body: AdaptivePage(
                    adaptive: adaptive,
                    onChanged: (v) => setState(() => adaptive = v)))));
    expect(
        tester
            .widget<SwitchListTile>(
                find.byKey(const Key('simple_adaptive_switch')))
            .value,
        isTrue);
    await tester.tap(find.byKey(const Key('simple_adaptive_switch')));
    await tester.pump();
    expect(adaptive, isFalse);
    await tester.tap(find.text('How it works'));
    await tester.pumpAndSettle();
    expect(find.textContaining('weekly check-in'), findsOneWidget);
    expect(find.text('Your plan. Your choice.'), findsOneWidget);
    expectSimpleCopy(tester);
  });

  for (final dark in [true, false]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
          'adaptive choice stays usable at 320pt, text scale $scale, ${dark ? 'dark' : 'light'}',
          (tester) async {
        bool adaptive = true;
        await pump(
            tester,
            StatefulBuilder(
                builder: (context, setState) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: Scaffold(
                        body: SizedBox(
                            height: 450,
                            child: AdaptivePage(
                                adaptive: adaptive,
                                onChanged: (v) =>
                                    setState(() => adaptive = v)))))),
            dark: dark);
        tester.view.physicalSize = const Size(960, 1704);
        await tester.pumpAndSettle();
        expect(find.text('A plan that\nkeeps up.'), findsOneWidget);
        final switchFinder = find.byKey(const Key('simple_adaptive_switch'));
        await tester.ensureVisible(switchFinder);
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        expect(adaptive, isFalse);
        expect(find.text('Your targets stay as calculated today.'),
            findsOneWidget);
        await tester.ensureVisible(switchFinder);
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();
        expect(adaptive, isTrue);
        final how = find.byKey(const Key('simple_adaptive_how'));
        await tester.ensureVisible(how);
        await tester.tap(how);
        await tester.pumpAndSettle();
        expect(find.textContaining('weekly check-in'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
        expectSimpleCopy(tester);
      });
    }
  }

  for (final goal in ['lose', 'gain']) {
    testWidgets(
        'simple $goal recalculate saves the right targets and keeps optional steps hidden',
        (tester) async {
      goals
        ..goalType = goal
        ..currentWeightKg = 80
        ..goalWeightKg = goal == 'gain' ? 85 : 65
        ..pacePctPerWeek = goal == 'gain' ? .25 : .5
        ..adaptiveGoals = true;
      await pump(tester, const OnboardingScreen(recalculateOnly: true));
      await next(tester, 3);
      expect(find.byType(SetNewGoalPage).hitTestable(), findsOneWidget);
      await next(tester);
      expect(find.byKey(const Key('simple_adaptive_switch')).hitTestable(),
          findsOneWidget);
      expect(find.byType(PlanStylePage).hitTestable(), findsNothing);
      await tester.tap(find.text('Back'));
      await pumpFrames(tester, seconds: 1);
      expect(find.byType(SetNewGoalPage).hitTestable(), findsOneWidget);
      await next(tester, 2);
      expect(find.byType(SummaryPage).hitTestable(), findsOneWidget);
      final card =
          tester.widget<SimplePlanSummary>(find.byType(SimplePlanSummary));
      expect(card.goalDate, isNotNull);
      expect(card.adaptive, isTrue);
      await tester.tap(find.text('Calculate'));
      await pumpFrames(tester, seconds: 2);
      expect(find.byType(ResultsScreen), findsOneWidget);
      final result =
          tester.widget<ResultsScreen>(find.byType(ResultsScreen)).results;
      expect(result['goal'], goal);
      expect(
          result['target_calories'],
          goal == 'gain'
              ? greaterThan(result['tdee'] as num)
              : lessThan(result['tdee'] as num));
      expectSimpleCopy(tester);
      await tester.tap(find.text('Save New Goals'));
      await pumpFrames(tester, seconds: 2);
      final saved =
          jsonDecode(StorageService().get('nutrition_goals') as String) as Map;
      expect(saved['goal_type'], goal);
      expect(saved['plan_style'], 'steady');
      expect(saved['adaptive_goals'], isTrue);
      final tracked = events.where(
          (c) => (c.arguments as Map)['eventName'] == 'adaptive_choice_made');
      expect(tracked.length, 1);
      expect((tracked.single.arguments as Map)['properties'],
          containsPair('context', 'recalculate'));
    });
  }

  testWidgets(
      'choosing In phases under More options keeps that plan in summary',
      (tester) async {
    goals
      ..goalType = 'lose'
      ..currentWeightKg = 80
      ..goalWeightKg = 65;
    await pump(tester, const OnboardingScreen(recalculateOnly: true));
    await next(tester, 3);
    await tester.ensureVisible(find.text('More options'));
    await tester.tap(find.text('More options'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('In phases'));
    await tester.tap(find.text('In phases'));
    await tester.pump();
    await next(tester, 2);
    expect(tester.widget<SummaryPage>(find.byType(SummaryPage)).planStyle,
        PlanStyle.phased);
    expect(find.text('In phases'), findsOneWidget);
    expectSimpleCopy(tester, allow: {'In phases'});
  });

  testWidgets('new simple lose plans default to Steady even for a large goal',
      (tester) async {
    await pump(tester, const OnboardingScreen());
    await next(tester, 6);
    tester.widget<GoalPage>(find.byType(GoalPage)).onGoalChanged('lose');
    await tester.pump();
    await next(tester);
    final page = tester.widget<SetNewGoalPage>(find.byType(SetNewGoalPage));
    page.onGoalWeightChanged(50);
    await tester.pump();
    expect(tester.widget<SetNewGoalPage>(find.byType(SetNewGoalPage)).planStyle,
        PlanStyle.steady);
    expect(
        tester.widget<SetNewGoalPage>(find.byType(SetNewGoalPage)).pacePct, .5);
    await next(tester);
    expect(find.byKey(const Key('simple_adaptive_switch')).hitTestable(),
        findsOneWidget);
  });

  testWidgets(
      'new maintain flow skips extra steps, saves switch choice and tracks onboarding',
      (tester) async {
    await pump(tester, const OnboardingScreen());
    await next(tester, 7);
    expect(find.byKey(const Key('simple_adaptive_switch')).hitTestable(),
        findsOneWidget);
    await tester.tap(find.byKey(const Key('simple_adaptive_switch')));
    await tester.pump();
    await next(tester);
    expect(find.byType(AppleHealthPage).hitTestable(), findsOneWidget);
    expect(find.byType(AdvancedSettingsPage).hitTestable(), findsNothing);
    await tester.tap(find.text('Not now').hitTestable());
    await pumpFrames(tester, seconds: 1);
    expect(find.byType(SummaryPage).hitTestable(), findsOneWidget);
    expect(find.text('Aim to hold your weight steady.'), findsOneWidget);
    expectSimpleCopy(tester);
    await tester.tap(find.text('Calculate'));
    await pumpFrames(tester, seconds: 2);
    expect(find.text('Your targets stay the same until you change them.'),
        findsOneWidget);
    expectSimpleCopy(tester);
    final saved =
        jsonDecode(StorageService().get('nutrition_goals') as String) as Map;
    expect(saved['adaptive_goals'], isFalse);
    final tracked = events.where(
        (c) => (c.arguments as Map)['eventName'] == 'adaptive_choice_made');
    expect(tracked.length, 1);
    final props = (tracked.single.arguments as Map)['properties'] as Map;
    expect(props['context'], 'onboarding');
    expect(props['choice'], 'fixed');
  });

  testWidgets(
      'simple recalculate preserves saved nutrition overrides while skipping advanced',
      (tester) async {
    await StorageService().put(
        'nutrition_goals',
        jsonEncode({
          'macro_targets': {
            'calories': 2300,
            'protein': 150,
            'carbs': 250,
            'fat': 70
          },
          'sex': 'male',
          'height_cm': 180,
          'age': 30,
          'activity_level': 3,
          'goal_type': 'maintain',
          'current_weight_kg': 80,
          'adaptive_goals': false,
          'body_fat_pct': 22,
          'protein_ratio': 2.1,
          'fat_ratio': .3,
        }));
    await goals.load();
    await pump(tester, const OnboardingScreen(recalculateOnly: true));
    await next(tester, 4);
    final summary = tester.widget<SummaryPage>(find.byType(SummaryPage));
    expect(summary.bodyFatPercentage, 22);
    expect(summary.proteinRatio, 2.1);
    expect(summary.fatRatio, .3);
    expect(find.byType(AdvancedSettingsPage).hitTestable(), findsNothing);
    await tester.tap(find.text('Calculate'));
    await pumpFrames(tester, seconds: 2);
    await tester.tap(find.text('Save New Goals'));
    await pumpFrames(tester, seconds: 2);
    final saved =
        jsonDecode(StorageService().get('nutrition_goals') as String) as Map;
    expect(saved['body_fat_pct'], 22);
    expect(saved['protein_ratio'], 2.1);
    expect(saved['fat_ratio'], .3);
  });

  testWidgets(
      'simple results read the goal and date from the real calculation map',
      (tester) async {
    final result = MacroCalculatorService().calculateAll(
        gender: 'male',
        weightKg: 80,
        heightCm: 180,
        age: 30,
        activityLevel: 3,
        goal: 'lose',
        goalWeightKg: 65,
        pacePct: .5);
    await pump(
        tester,
        ResultsScreen(
            recalculateOnly: true, isMetricWeight: false, results: result));
    expect(find.textContaining('Reach 143 lbs around'), findsOneWidget);
    expect(find.text('Aim to hold your weight steady.'), findsNothing);
    expect(find.text('Protein ${result['protein_g']} g'), findsOneWidget);
    expectSimpleCopy(tester);
  });

  testWidgets('capped simple summary shows the effective weekly change',
      (tester) async {
    await pump(
        tester,
        Scaffold(
            body: SummaryPage(
                gender: 'male',
                weightKg: 80,
                heightCm: 180,
                age: 30,
                activityLevel: 3,
                goal: 'lose',
                pacePct: 1,
                effectivePacePct: .3,
                proteinRatio: 1.6,
                fatRatio: .25,
                goalWeightKg: 65,
                onEdit: (_) {})));
    expect(find.text('About 0.2 kg a week'), findsOneWidget);
    expect(find.text('About 0.8 kg a week'), findsNothing);
    expectSimpleCopy(tester);
  });

  testWidgets(
      'simple summary leads with targets and date, learned copy is plain and plan edit returns to pace',
      (tester) async {
    Object? edited;
    await pump(
        tester,
        Scaffold(
            body: SummaryPage(
                gender: 'male',
                weightKg: 80,
                heightCm: 180,
                age: 30,
                activityLevel: 3,
                goal: 'lose',
                pacePct: .5,
                proteinRatio: 1.6,
                fatRatio: .25,
                goalWeightKg: 65,
                onEdit: (s) => edited = s,
                planStyle: PlanStyle.breaks,
                newTargets: const GoalTargets(
                    calories: 2451, protein: 128, carbs: 300, fat: 68),
                currentTargets: const GoalTargets(
                    calories: 2500, protein: 120, carbs: 320, fat: 68),
                learnedTdee: 2500,
                projectedDate: DateTime(2027, 3, 3))));
    expect(find.text('2,451 cals'), findsOneWidget);
    expect(find.text('Reach 65.0 kg around Mar 3.'), findsOneWidget);
    expect(find.text('Protein 128 g'), findsOneWidget);
    expect(find.text('Based on how your body has responded so far.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('With diet breaks'));
    await tester.tap(find.text('With diet breaks'));
    expect(edited.toString(), 'OnboardingStep.setNewGoal');
    expectSimpleCopy(tester);
  });
}
