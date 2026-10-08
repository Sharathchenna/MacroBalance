import 'dart:convert';
import 'dart:ui' show SemanticsFlag;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/screens/onboarding/pages/adaptive_page.dart';
import 'package:macrotracker/screens/onboarding/pages/goal_page.dart';
import 'package:macrotracker/screens/onboarding/pages/plan_style_page.dart';
import 'package:macrotracker/screens/onboarding/pages/set_new_goal_page.dart';
import 'package:macrotracker/screens/onboarding/pages/summary_page.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/phase_sync_service.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/widgets/plan_style_choice.dart';

import '../helpers/test_app.dart';

/// Phases kept in memory; nothing uploads.
class _Phases extends PhaseSyncService {
  _Phases([List<GoalPhase> seed = const []]) : _rows = List.of(seed);

  List<GoalPhase> _rows;

  @override
  List<GoalPhase> loadCache() => List.of(_rows);

  @override
  Future<List<GoalPhase>> edit(PhaseEdit edit) async => _rows = edit.applyTo(_rows);

  @override
  Future<void> upload() async {}

  @override
  Future<bool> sync() async => false;
}

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);
String _date(DateTime d) => d.toIso8601String().substring(0, 10);

void main() {
  late GoalsProvider goals;
  final events = <MethodCall>[];

  setUp(() async {
    await setUpTestEnvironment();
    for (final key in ['nutrition_goals', 'goal_settings', 'weight_history', 'unit_system']) {
      await StorageService().delete(key);
    }
    await StorageService().put('unit_system', 'metric');
    goals = GoalsProvider();
    events.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('posthog_flutter'), (call) async {
      if (call.method == 'capture') events.add(call);
      return null;
    });
  });

  List<Map> captured(String name) => [
        for (final c in events)
          if ((c.arguments as Map)['eventName'] == name)
            Map.of((c.arguments as Map)['properties'] as Map),
      ];

  Future<EnergyProvider> pump(WidgetTester tester, Widget child,
      {bool dark = true, List<GoalPhase> phases = const []}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final energy = EnergyProvider(inBackground: false, phaseSync: _Phases(phases));
    await tester.pumpWidget(
        testApp(child, goalsProvider: goals, energyProvider: energy, dark: dark));
    await pumpFrames(tester, seconds: 1);
    return energy;
  }

  Finder visible(Type page) => find.byType(page).hitTestable();

  bool selected(WidgetTester tester, Key key) => tester
      .getSemantics(find.byKey(key))
      .getSemanticsData()
      .hasFlag(SemanticsFlag.isSelected);

  Future<void> next(WidgetTester tester, [int times = 1]) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.text('Next'));
      await pumpFrames(tester, seconds: 1);
    }
  }

  group('page', () {
    for (final dark in [true, false]) {
      testWidgets('three styles, the outline for phased plans (${dark ? 'dark' : 'light'})',
          (tester) async {
        var style = PlanStyle.phased;
        const outline = PlanOutline(lossPhases: 3, breaks: 2, weeks: 34, lossWeeks: 26);
        await pump(
          tester,
          StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: PlanStylePage(
                style: style,
                lossPct: 10,
                recommended: PlanStyle.phased,
                outline: outline,
                onChanged: (s) => setState(() => style = s),
              ),
            ),
          ),
          dark: dark,
        );
        expect(find.text(PlanStyleCopy.question), findsOneWidget);
        expect(find.text('Steady'), findsOneWidget);
        expect(find.text('In phases'), findsOneWidget);
        expect(find.text('With diet breaks'), findsOneWidget);
        expect(find.text('Recommended'), findsOneWidget);
        expect(find.textContaining('Lose 10% at a time, then take a 4-week maintenance break'),
            findsOneWidget);
        expect(find.text('A 2-week break every 8 weeks.'), findsOneWidget);
        expect(selected(tester, const Key('plan_style_phased')), isTrue);
        expect(find.text('3 loss phases + 2 breaks · about 34 weeks'), findsOneWidget);

        await tester.tap(find.text('Steady'));
        await tester.pump();
        expect(style, PlanStyle.steady);
        expect(selected(tester, const Key('plan_style_steady')), isTrue);
        expect(find.byKey(const Key('plan_style_outline')), findsNothing);
      });
    }

    test('outline copy', () {
      expect(
          PlanStyleCopy.outline(
              const PlanOutline(lossPhases: 1, breaks: 0, weeks: 1, lossWeeks: 1)),
          '1 loss phase · about 1 week');
      expect(
          PlanStyleCopy.outline(
              const PlanOutline(lossPhases: 2, breaks: 1, weeks: 20, lossWeeks: 16)),
          '2 loss phases + 1 break · about 20 weeks');
    });
  });

  group('new users', () {
    testWidgets(
        'a big lose goal: asked after the goal weight, In phases picked; '
        'saved, summarised, tracked, and the first phase starts', (tester) async {
      final energy = await pump(tester, const OnboardingScreen());
      // welcome, sex, weight (70 kg), height, age, activity -> goal
      await next(tester, 6);
      tester.widget<GoalPage>(find.byType(GoalPage)).onGoalChanged(MacroCalculatorService.GOAL_LOSE);
      await pumpFrames(tester, seconds: 1);
      await next(tester);
      expect(visible(SetNewGoalPage), findsOneWidget);
      // 70 -> 60 kg: more than 10%.
      tester.widget<SetNewGoalPage>(find.byType(SetNewGoalPage)).onGoalWeightChanged(60);
      await pumpFrames(tester, seconds: 1);
      await next(tester);
      expect(visible(PlanStylePage), findsOneWidget);
      expect(selected(tester, const Key('plan_style_phased')), isTrue);
      expect(find.text('Recommended'), findsOneWidget);
      final outline = find.byKey(const Key('plan_style_outline'));
      expect(outline, findsOneWidget);
      final line = tester.widget<Text>(outline).data!;
      expect(line, matches(RegExp(r'^\d loss phases \+ \d breaks? · about \d+ weeks$')));

      await next(tester);
      expect(visible(AdaptivePage), findsOneWidget);
      // adaptive -> advanced -> Apple Health (its own buttons) -> summary
      await next(tester, 2);
      await tester.tap(find.text('Not now').hitTestable());
      await pumpFrames(tester, seconds: 1);
      expect(visible(SummaryPage), findsOneWidget);
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('In phases'), findsOneWidget);
      expect(find.text('Plan Length'), findsOneWidget);
      expect(find.text(line), findsOneWidget);

      await tester.tap(find.text('Calculate'));
      await pumpFrames(tester, seconds: 2);
      expect(find.byType(ResultsScreen), findsOneWidget);
      expect(
          find.textContaining(line, findRichText: true), findsOneWidget);
      expect(captured('plan_style_chosen').map((e) => e['style']), ['phased']);
      final saved = jsonDecode(StorageService().get('nutrition_goals') as String) as Map;
      expect(saved['plan_style'], 'phased');
      final first = energy.currentPhase!;
      expect(first.kind, PhaseKind.lose);
      expect(first.seq, 1);
      expect(first.targetPct, kPhasedLossPct);
      expect(first.maxWeeks, kMaxLossPhaseWeeks);
      expect(first.startTrendKg, 70);
      expect(first.startedOn, _today);
    });

    testWidgets('maintain: no plan style step, steady, no event', (tester) async {
      final energy = await pump(tester, const OnboardingScreen());
      // welcome, sex, weight, height, age, activity, goal (maintain) -> adaptive
      await next(tester, 7);
      expect(visible(AdaptivePage), findsOneWidget);
      await next(tester, 2);
      await tester.tap(find.text('Not now').hitTestable());
      await pumpFrames(tester, seconds: 1);
      expect(find.text('Plan'), findsNothing);
      await tester.tap(find.text('Calculate'));
      await pumpFrames(tester, seconds: 2);
      expect(find.byKey(const Key('results_plan_line')), findsNothing);
      expect(captured('plan_style_chosen'), isEmpty);
      final saved = jsonDecode(StorageService().get('nutrition_goals') as String) as Map;
      expect(saved['plan_style'], 'steady');
      expect(energy.currentPhase!.kind, PhaseKind.maintain);
    });
  });

  group('recalculate', () {
    final started = DateTime(_today.year, _today.month, _today.day - 30);
    final open = firstPhase(
        style: PlanStyle.steady, goal: GoalKind.lose, seq: 1, on: started, trendKg: 84);

    setUp(() async {
      await StorageService().put(
          'nutrition_goals',
          jsonEncode({
            'macro_targets': {'calories': 2100, 'protein': 150, 'carbs': 220, 'fat': 65},
            'sex': MacroCalculatorService.MALE,
            'height_cm': 180,
            'age': 30,
            'age_recorded_on': _date(_today),
            'activity_level': 3,
            'goal_type': MacroCalculatorService.GOAL_LOSE,
            'pace_pct_per_week': 0.5,
            'goal_weight_kg': 75,
            'current_weight_kg': 82,
            'tdee': 2500,
            'formula_tdee': 2500,
            'learning_started_on': _date(started),
            'adaptive_goals': false,
            'checkin_weekday': DateTime.monday,
            'plan_style': 'steady',
          }));
      goals = GoalsProvider();
      await goals.load();
    });

    Future<EnergyProvider> openRecalculate(WidgetTester tester) => pump(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const OnboardingScreen(recalculateOnly: true))),
              child: const Text('Open'),
            ),
          ),
          phases: [open],
        ).then((energy) async {
          await tester.tap(find.text('Open'));
          await pumpFrames(tester, seconds: 1);
          return energy;
        });

    Future<void> save(WidgetTester tester) async {
      await tester.tap(find.text('Calculate'));
      await pumpFrames(tester, seconds: 2);
      await tester.tap(find.text('Save New Goals'));
      await pumpFrames(tester, seconds: 2);
    }

    testWidgets('prefilled with the saved style; changing it starts a fresh sequence',
        (tester) async {
      final energy = await openRecalculate(tester);
      // weight -> activity -> goal -> goal weight -> plan style
      await next(tester, 4);
      expect(visible(PlanStylePage), findsOneWidget);
      // 82 -> 75 kg is under 10%: steady, as saved, nothing recommended.
      expect(selected(tester, const Key('plan_style_steady')), isTrue);
      expect(find.text('Recommended'), findsNothing);
      await tester.tap(find.text('With diet breaks'));
      await pumpFrames(tester, seconds: 1);
      await next(tester, 3);
      expect(visible(SummaryPage), findsOneWidget);
      expect(find.text('With diet breaks'), findsOneWidget);
      await save(tester);

      expect(energy.phases.map((p) => (p.seq, p.endReason)), [
        (1, PhaseEndReason.replanned),
        (2, null),
      ]);
      expect(energy.phases.first.endedOn, _today);
      final fresh = energy.currentPhase!;
      expect(fresh.plannedWeeks, kBreakEveryWeeks);
      expect(fresh.startTrendKg, 82);
      await goals.load();
      expect(goals.planStyle, PlanStyle.breaks);
      expect(captured('plan_style_chosen').map((e) => e['style']), ['breaks']);
    });

    testWidgets('nothing about the plan changed: the phase carries on', (tester) async {
      final energy = await openRecalculate(tester);
      await next(tester, 7);
      expect(visible(SummaryPage), findsOneWidget);
      await save(tester);
      expect(energy.phases, [open]);
    });

    testWidgets('a new pace replans too', (tester) async {
      final energy = await openRecalculate(tester);
      await next(tester, 3);
      tester.widget<SetNewGoalPage>(find.byType(SetNewGoalPage)).onPaceChanged(0.75);
      await pumpFrames(tester, seconds: 1);
      await next(tester, 4);
      await save(tester);
      expect(energy.phases.map((p) => p.seq), [1, 2]);
      expect(energy.phases.first.endReason, PhaseEndReason.replanned);
    });
  });
}
