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
import 'package:macrotracker/screens/onboarding/pages/notify_page.dart';
import 'package:macrotracker/screens/onboarding/pages/plan_style_page.dart';
import 'package:macrotracker/screens/onboarding/pages/goal_weight_page.dart';
import 'package:macrotracker/screens/onboarding/pages/pace_page.dart';
import 'package:macrotracker/screens/onboarding/pages/summary_page.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
import 'package:macrotracker/screens/onboarding/widgets/ob_widgets.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/widgets/adaptive_choice.dart';
import 'package:macrotracker/services/storage_service.dart';
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
      await tester.tap(find.text('Continue'));
      await pumpFrames(tester, seconds: 1);
    }
  }

  PacePage pacePage(
      {String goal = 'lose',
      double pace = 0.5,
      required ValueChanged<double> changed}) {
    final options = goal == 'gain' ? kGainPaceOptions : kLosePaceOptions;
    return PacePage(
        goal: goal,
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
        onPaceChanged: changed);
  }

  for (final dark in [true, false]) {
    testWidgets(
        'pace cards show the goal date and select an existing pace in ${dark ? 'dark' : 'light'}',
        (tester) async {
      double pace = .5;
      await pump(
          tester,
          StatefulBuilder(
              builder: (_, setState) => Scaffold(
                  body: pacePage(
                      pace: pace, changed: (p) => setState(() => pace = p)))),
          dark: dark);
      for (final p in kLosePaceOptions) {
        expect(find.byKey(Key('pace_option_$p')), findsOneWidget);
      }
      expect(find.textContaining('around Mar 3'), findsOneWidget);
      expect(find.text('Recommended'), findsOneWidget);
      final faster = find.byKey(const Key('pace_option_0.75'));
      await tester.ensureVisible(faster);
      await tester.tap(faster);
      await tester.pump();
      expect(pace, .75);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('gain pace cards offer the three gain paces',
      (tester) async {
    await pump(
        tester,
        Scaffold(
            body: pacePage(goal: 'gain', pace: .25, changed: (_) {})));
    for (final p in kGainPaceOptions) {
      expect(find.byKey(Key('pace_option_$p')), findsOneWidget);
    }
    expect(find.byKey(const Key('pace_option_1.0')), findsNothing);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.textContaining('around Mar 3'), findsOneWidget);
  });

  testWidgets(
      'saved faster detailed pace stays selected without changing the goal',
      (tester) async {
    double pace = 1;
    await pump(
        tester, Scaffold(body: pacePage(pace: pace, changed: (p) => pace = p)));
    final semantics = tester.widget<Semantics>(find
        .descendant(
            of: find.byKey(const Key('pace_option_1.0')),
            matching: find.byType(Semantics))
        .first);
    expect(semantics.properties.selected, isTrue);
    expect(pace, 1);
  });

  testWidgets(
      'simple mode has no plan style step, but a saved phased plan is kept and shown in the summary',
      (tester) async {
    await StorageService().put(
        'nutrition_goals',
        jsonEncode({
          'macro_targets': {'calories': 2000, 'protein': 150, 'carbs': 200, 'fat': 60},
          'goal_type': 'lose',
          'current_weight_kg': 80,
          'goal_weight_kg': 65,
          'pace_pct_per_week': .5,
          'plan_style': 'phased',
        }));
    await goals.load();
    await pump(tester, const OnboardingScreen(recalculateOnly: true));
    // weight -> activity -> goal -> goal weight -> pace -> adaptive -> summary
    await next(tester, 6);
    expect(find.byType(PlanStylePage), findsNothing);
    expect(tester.widget<SummaryPage>(find.byType(SummaryPage)).planStyle,
        PlanStyle.phased);
    expect(find.text('In phases'), findsOneWidget);
  });

  Widget adaptiveHost(bool Function() get, void Function(bool) set,
          {double scale = 1.0, double? height}) =>
      StatefulBuilder(
          builder: (context, setState) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                  body: SizedBox(
                      height: height,
                      child: AdaptivePage(
                          adaptive: get(),
                          onChanged: (v) => setState(() => set(v)))))));

  bool tileSelected(WidgetTester tester, String key) => tester
      .widget<Semantics>(find
          .descendant(
              of: find.byKey(Key(key)), matching: find.byType(Semantics))
          .first)
      .properties
      .selected!;

  testWidgets(
      'adaptive choice is a recommended option with its explanation on the page',
      (tester) async {
    bool adaptive = true;
    await pump(tester, adaptiveHost(() => adaptive, (v) => adaptive = v));
    expect(tileSelected(tester, 'adaptive_yes'), isTrue);
    expect(tileSelected(tester, 'adaptive_no'), isFalse);
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.text('Small updates. A better fit.'), findsOneWidget);
    expect(find.textContaining('weekly check-in'), findsOneWidget);
    await tester.tap(find.byKey(const Key('adaptive_no')));
    await pumpFrames(tester, seconds: 1);
    expect(adaptive, isFalse);
    expect(tileSelected(tester, 'adaptive_no'), isTrue);
    expect(find.text('Your plan. Your call.'), findsOneWidget);
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
            adaptiveHost(() => adaptive, (v) => adaptive = v,
                scale: scale, height: 450),
            dark: dark);
        tester.view.physicalSize = const Size(960, 1704);
        await pumpFrames(tester, seconds: 1);
        expect(find.text(AdaptiveChoiceCopy.question), findsOneWidget);
        final no = find.byKey(const Key('adaptive_no'));
        await tester.ensureVisible(no);
        await tester.tap(no);
        await pumpFrames(tester, seconds: 1);
        expect(adaptive, isFalse);
        expect(find.textContaining('Your targets stay where they are'),
            findsOneWidget);
        final yes = find.byKey(const Key('adaptive_yes'));
        await tester.ensureVisible(yes);
        await tester.tap(yes);
        await pumpFrames(tester, seconds: 1);
        expect(adaptive, isTrue);
        expect(find.textContaining('weekly check-in'), findsOneWidget);
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
      // weight -> activity -> goal -> goal weight -> pace
      await next(tester, 4);
      expect(find.byType(PacePage).hitTestable(), findsOneWidget);
      await next(tester);
      expect(find.byKey(const Key('adaptive_yes')).hitTestable(),
          findsOneWidget);
      expect(find.byType(PlanStylePage).hitTestable(), findsNothing);
      await tester.tap(find.byType(ObBackButton));
      await pumpFrames(tester, seconds: 1);
      expect(find.byType(PacePage).hitTestable(), findsOneWidget);
      await next(tester, 2);
      expect(find.byType(SummaryPage).hitTestable(), findsOneWidget);
      final summary = tester.widget<SummaryPage>(find.byType(SummaryPage));
      expect(summary.projectedDate, isNotNull);
      expect(summary.adaptiveGoals, isTrue);
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
      await tester.tap(find.text('Save'));
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

  testWidgets('new simple lose plans default to Steady even for a large goal',
      (tester) async {
    await pump(tester, const OnboardingScreen());
    tester.widget<GoalPage>(find.byType(GoalPage)).onGoalChanged('lose');
    await tester.pump();
    // goal -> about you -> weight -> activity -> goal weight
    await next(tester, 4);
    final page = tester.widget<GoalWeightPage>(find.byType(GoalWeightPage));
    page.onGoalWeightChanged(50);
    await tester.pump();
    await next(tester);
    expect(tester.widget<PacePage>(find.byType(PacePage)).pacePct, .5);
    // Simple mode has no plan style step: pace goes straight on to the
    // obstacles, and the plan stays Steady.
    await next(tester);
    expect(find.byType(PlanStylePage), findsNothing);
    await next(tester, 2);
    expect(find.byKey(const Key('adaptive_yes')).hitTestable(),
        findsOneWidget);
  });

  testWidgets(
      'new maintain flow skips extra steps, saves switch choice and tracks onboarding',
      (tester) async {
    await pump(tester, const OnboardingScreen());
    // goal -> about you -> weight -> activity -> obstacles -> insight -> adaptive
    await next(tester, 6);
    expect(find.byKey(const Key('adaptive_yes')).hitTestable(),
        findsOneWidget);
    expect(find.byType(GoalWeightPage), findsNothing);
    expect(find.byType(PacePage), findsNothing);
    await tester.tap(find.byKey(const Key('adaptive_no')));
    await tester.pump();
    await next(tester);
    expect(find.byType(AppleHealthPage).hitTestable(), findsOneWidget);
    expect(find.byType(AdvancedSettingsPage).hitTestable(), findsNothing);
    await tester.tap(find.text('Not now').hitTestable());
    await pumpFrames(tester, seconds: 1);
    expect(find.byType(NotifyPage).hitTestable(), findsOneWidget);
    await tester.tap(find.text('Not now').hitTestable());
    // New users go straight to the building screen, not the summary.
    await pumpFrames(tester, seconds: 12);
    expect(find.byType(SummaryPage), findsNothing);
    if (find.byType(ResultsScreen).evaluate().isEmpty) {
      await tester.tap(find.text('See my plan'));
      await pumpFrames(tester, seconds: 2);
    }
    expect(find.byType(ResultsScreen), findsOneWidget);
    expect(find.text('Your targets stay the same until you change them.'),
        findsOneWidget);
    final saved =
        jsonDecode(StorageService().get('nutrition_goals') as String) as Map;
    expect(saved['adaptive_goals'], isFalse);
    final tracked = events.where(
        (c) => (c.arguments as Map)['eventName'] == 'adaptive_choice_made');
    expect(tracked.length, 1);
    final props = (tracked.single.arguments as Map)['properties'] as Map;
    expect(props['context'], 'onboarding');
    expect(props['choice'], 'fixed');
    final completed = events.where(
        (c) => (c.arguments as Map)['eventName'] == 'onboarding_completed');
    expect(completed.length, 1);
    expect(((completed.single.arguments as Map)['properties'] as Map)
        .containsKey('obstacles_selected'), isTrue);
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
    // weight -> activity -> goal -> adaptive -> summary (maintain skips goal
    // weight and pace)
    await next(tester, 4);
    final summary = tester.widget<SummaryPage>(find.byType(SummaryPage));
    expect(summary.bodyFatPercentage, 22);
    expect(summary.proteinRatio, 2.1);
    expect(summary.fatRatio, .3);
    expect(find.byType(AdvancedSettingsPage).hitTestable(), findsNothing);
    await tester.tap(find.text('Calculate'));
    await pumpFrames(tester, seconds: 2);
    await tester.tap(find.text('Save'));
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
    expect(find.textContaining('143 lb', findRichText: true), findsWidgets);
    expect(find.textContaining('${result['protein_g'].round()} g', findRichText: true), findsWidgets);
    // The reveal now shows each macro's share ("160 g · 27%") in every mode.
    expectSimpleCopy(tester, allow: {
      for (final t in simpleModeCopy(tester))
        if (RegExp(r'^\d+ g · \d+%$').hasMatch(t)) t
    });
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
    expect(find.text('2,500 → 2,451 cals'), findsOneWidget);
    expect(find.text('120 → 128 g'), findsOneWidget);
    expect(find.text(SummaryPage.learnedExpenditureLine(2500)), findsOneWidget);
    await tester.ensureVisible(find.text('With diet breaks'));
    await tester.tap(find.text('With diet breaks'));
    expect(edited.toString(), 'OnboardingStep.planStyle');
    // The summary names the learned expenditure in every mode now.
    expectSimpleCopy(tester, allow: {SummaryPage.learnedExpenditureLine(2500)});
  });
}
