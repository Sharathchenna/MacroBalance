import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/TrackingPagesScreen.dart';
import 'package:macrotracker/screens/WeightTrackingScreen.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy_sync_service.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/widgets/weight_chart.dart';

import '../helpers/test_app.dart';
import '../helpers/simple_copy_audit.dart';

/// Fixed estimate rows, as in energy_tab_test.dart.
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
final _today = DateTime(_now.year, _now.month, _now.day);
DateTime _ago(int n) => DateTime(_today.year, _today.month, _today.day - n);

List<EnergyEstimate> _rows(EnergyState state, {double tdee = 2434}) => [
      for (var n = 20; n >= 1; n--)
        EnergyEstimate(
          day: _ago(n),
          tdee: tdee,
          tdeeSd: state == EnergyState.confident ? 90 : 300,
          state: state,
          completeDays: 12,
          weighIns: 15,
          updated: state != EnergyState.learning,
        ),
    ];

void main() {
  late GoalsProvider goals;

  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('nutrition_goals');
    await StorageService().delete('weight_history');
    await StorageService().delete('unit_system');
    await StorageService().delete(DetailedStatsProvider.storageKey);
    goals = GoalsProvider()
      ..goalType = MacroCalculatorService.GOAL_LOSE
      ..pacePctPerWeek = 0.5
      ..goalWeightKg = 70;
  });

  /// One weigh-in a day, oldest first, ending [endAgo] days ago.
  Future<void> history(List<double> weights, {int endAgo = 0}) {
    final n = weights.length;
    return StorageService().put('weight_history', jsonEncode([
      for (var i = 0; i < n; i++)
        {
          'date': DateTime(_today.year, _today.month,
                  _today.day - endAgo - (n - 1 - i), 8)
              .toIso8601String(),
          'weight': weights[i],
        }
    ]));
  }

  /// A steady loss of [kgPerDay] from 80 kg over [days] days.
  List<double> losing(double kgPerDay, {int days = 21}) =>
      [for (var i = 0; i < days; i++) 80 - kgPerDay * i];

  Future<DetailedStatsProvider> pump(
    WidgetTester tester, {
    bool metric = true,
    bool detailed = false,
    EnergyProvider? energy,
    VoidCallback? onOpenEnergy,
  }) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final detail = DetailedStatsProvider(showDetailedStats: detailed);
    await tester.pumpWidget(testApp(
        WeightTrackingScreen(onOpenEnergy: onOpenEnergy),
        goalsProvider: goals,
        energyProvider: energy,
        detailedStatsProvider: detail,
        weightUnitProvider: WeightUnitProvider()..setMetric(metric)));
    await pumpFrames(tester, seconds: 2);
    return detail;
  }

  Future<void> scrollTo(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 200,
        scrollable: find.byType(Scrollable).first);
    await pumpFrames(tester, seconds: 1);
  }

  group('headline', () {
    testWidgets('"Your weight" is the trend, with today\'s reading under it',
        (tester) async {
      await history([80, 80, 80, 80, 80, 80, 80, 80, 78.5]);
      await pump(tester);

      expect(find.text('Your weight'), findsOneWidget);
      expect(find.textContaining('79.8', findRichText: true), findsWidgets);
      expect(find.text('Today 78.5 kg'), findsOneWidget);
      expect(find.text('Trend weight'), findsNothing);
      expect(find.byKey(const Key('weight_pace_row')), findsNothing);
    });

    testWidgets('no "Today" line when there\'s no reading today',
        (tester) async {
      await history(List.filled(10, 80.0), endAgo: 2);
      await pump(tester);
      expect(find.textContaining('Today'), findsNothing);
    });

    testWidgets('on pace: the change over 4 weeks and "On track"',
        (tester) async {
      await history(losing(0.4 / 7, days: 60));
      await pump(tester);

      expect(find.textContaining(RegExp(r'^↓ \d\.\d kg in the last 4 weeks$')),
          findsOneWidget);
      expect(find.text('On track'), findsOneWidget);
    });

    testWidgets('shorter history: the window shrinks to whole weeks',
        (tester) async {
      await history(losing(0.4 / 7, days: 16));
      await pump(tester);
      expect(find.textContaining(RegExp(r'in the last 2 weeks$')),
          findsOneWidget);
    });

    testWidgets('flat while losing: "A bit slower than planned", in grey',
        (tester) async {
      await history(losing(0, days: 21));
      await pump(tester);

      expect(find.text('Steady over the last 2 weeks'), findsOneWidget);
      expect(find.text('A bit slower than planned'), findsOneWidget);
      final pill = tester.widget<Container>(
          find.byKey(const Key('weight_pace_pill')));
      final colors = Theme.of(tester.element(find.byKey(const Key('weight_pace_pill'))))
          .extension<CustomColors>()!;
      expect((pill.decoration as BoxDecoration).color,
          colors.textSecondary.withValues(alpha: 0.1));
    });

    testWidgets('losing fast: "Faster than planned"', (tester) async {
      await history(losing(0.15, days: 21));
      await pump(tester);
      expect(find.text('Faster than planned'), findsOneWidget);
      expect(
          tester.widget<Text>(find.byKey(const Key('weight_goal_when'))).data,
          startsWith('Your plan aims to reach 70 kg'));
      expect(find.textContaining('On track'), findsNothing);
    });

    testWidgets('under a week: no change or pill yet', (tester) async {
      await history([80, 79.9, 79.8]);
      await pump(tester);
      expect(find.text('Keep weighing in. Your progress shows after a week.'),
          findsOneWidget);
      expect(find.byKey(const Key('weight_pace_pill')), findsNothing);
    });

    testWidgets('pounds', (tester) async {
      await history(losing(0.1, days: 30));
      await pump(tester, metric: false);
      expect(find.textContaining(RegExp(r'^↓ \d+\.\d lbs in the last 4 weeks$')),
          findsOneWidget);
      expect(find.textContaining(' kg'), findsNothing);
    });
  });

  group('goal', () {
    for (final goal in ['lose', 'gain']) {
      testWidgets('$goal does not celebrate just before the goal is crossed',
          (tester) async {
        goals
          ..goalType = goal
          ..goalWeightKg = 80;
        await history(List.filled(21, goal == 'lose' ? 80.1 : 79.9));
        await pump(tester);
        expect(find.text('You reached 80 kg!'), findsNothing);
        expect(find.text('Nice work. Keep logging to stay there.'), findsNothing);
        expect(find.byKey(const Key('weight_goal_progress')), findsOneWidget);
      });
    }

    testWidgets('gaining shows upward progress and a gain goal date',
        (tester) async {
      goals
        ..goalType = MacroCalculatorService.GOAL_GAIN
        ..pacePctPerWeek = .25
        ..goalWeightKg = 85;
      await history([for (var i = 0; i < 60; i++) 80 + .2 / 7 * i]);
      await pump(tester);
      expect(find.textContaining(RegExp(r'^↑ \d\.\d kg in the last 4 weeks$')),
          findsOneWidget);
      expect(find.text('On track'), findsOneWidget);
      expect(
          tester
              .widget<Text>(find.byKey(const Key('weight_goal_progress')))
              .data,
          matches(RegExp(r'^\d\.\d of \d+(\.\d)? kg gained$')));
      expect(
          tester.widget<Text>(find.byKey(const Key('weight_goal_when'))).data,
          startsWith('On track to reach 85 kg'));
      expectSimpleCopy(tester);
    });

    testWidgets('a reached gain goal celebrates and does not promise more gain',
        (tester) async {
      goals
        ..goalType = MacroCalculatorService.GOAL_GAIN
        ..pacePctPerWeek = .25
        ..goalWeightKg = 81;
      await history([for (var i = 0; i < 60; i++) 80 + .2 / 7 * i]);
      await pump(tester);
      expect(find.text('You reached 81 kg!'), findsOneWidget);
      expect(
          find.text('Nice work. Keep logging to stay there.'), findsOneWidget);
      expectSimpleCopy(tester);
    });

    testWidgets('"X of Y kg lost" and when the plan gets there',
        (tester) async {
      await history(losing(0.4 / 7, days: 60));
      await pump(tester);

      final progress = tester
          .widget<Text>(find.byKey(const Key('weight_goal_progress')))
          .data!;
      expect(progress, matches(RegExp(r'^\d\.\d of \d+(\.\d)? kg lost$')));
      final when =
          tester.widget<Text>(find.byKey(const Key('weight_goal_when'))).data!;
      expect(when,
          matches(RegExp(r'^On track to reach 70 kg (around|in|within) .+\.$')));
    });

    testWidgets('off pace: "Stick with your plan"', (tester) async {
      await history(losing(0, days: 21));
      await pump(tester);
      expect(
          tester.widget<Text>(find.byKey(const Key('weight_goal_when'))).data,
          startsWith('Stick with your plan to reach 70 kg'));
    });

    testWidgets('one weigh-in: how far to go', (tester) async {
      goals
        ..currentWeightKg = 82.4
        ..goalWeightKg = 75;
      await pump(tester);
      expect(find.text('7.4 kg to go'), findsOneWidget);
      expect(find.text('Your goal'), findsOneWidget);
    });

    testWidgets('imperial', (tester) async {
      goals
        ..currentWeightKg = 82.4
        ..goalWeightKg = 75;
      await pump(tester, metric: false);
      expect(find.text('16.3 lbs to go'), findsOneWidget);
      expect(find.textContaining(' kg'), findsNothing);
    });

    testWidgets('reached: celebrates', (tester) async {
      goals.goalWeightKg = 78;
      await history(losing(0.1, days: 40));
      await pump(tester);
      expect(find.text('You reached 78 kg!'), findsOneWidget);
      expect(find.text('Nice work. Keep logging to stay there.'), findsOneWidget);
    });

    testWidgets('no goal weight: offers to set one', (tester) async {
      goals.goalWeightKg = 0;
      await history(List.filled(10, 80.0));
      await pump(tester);
      expect(find.text('Set goal'), findsOneWidget);
    });

    testWidgets('maintaining: "Holding steady around 75 kg"', (tester) async {
      goals.goalType = MacroCalculatorService.GOAL_MAINTAIN;
      await history(List.filled(14, 75.0));
      await pump(tester);
      expect(find.text('Holding steady'), findsOneWidget); // pill
      expect(find.text('Steady over the last week'), findsOneWidget);
      expect(find.text('Holding steady around 75 kg'), findsOneWidget);
    });
  });

  group('chart', () {
    testWidgets('quiet: no legend, ignored readings are just lighter dots',
        (tester) async {
      await history([80, 80, 80, 80, 80, 80, 80, 80, 84]);
      await pump(tester);
      final chart = tester.widget<WeightChart>(find.byType(WeightChart));
      expect(chart.simple, isTrue);
      expect(chart.ignored.last, isTrue);
      expect(find.text('Your journey'), findsOneWidget);
      for (final label in ['Ignored', 'Weigh-ins', 'Trend', 'Goal']) {
        expect(find.text(label), findsNothing, reason: label);
      }

      chart.onTapEntry!(chart.entries.length - 1);
      await pumpFrames(tester, seconds: 1);
      expect(find.text('This one looked unusual, so it counts less.'), findsOneWidget);
      expectSimpleCopy(tester);
    });
  });

  testWidgets('simple mode shows none of the detailed-stats jargon',
      (tester) async {
    await history([...losing(0.06, days: 40), 84]);
    await pump(tester,
        energy: EnergyProvider(
            sync: _FixtureSync(_rows(EnergyState.estimated)),
            inBackground: false),
        onOpenEnergy: () {});
    expectSimpleCopy(tester);
    await scrollTo(tester, find.byKey(const Key('weight_burn_card')));
    expectSimpleCopy(tester);
  });

  testWidgets('turning on detailed stats brings the detailed view back',
      (tester) async {
    await history(losing(0.4 / 7, days: 60));
    final detail = await pump(tester);
    expect(find.byKey(const Key('weight_headline')), findsOneWidget);
    expect(find.byKey(const Key('weight_pace_row')), findsNothing);

    detail.showDetailedStats = true;
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Trend weight'), findsOneWidget);
    expect(find.byKey(const Key('weight_pace_row')), findsOneWidget);
    expect(find.byKey(const Key('weight_headline')), findsNothing);
    expect(find.byKey(const Key('weight_journey')), findsNothing);
    expect(tester.widget<WeightChart>(find.byType(WeightChart)).simple, isFalse);
    addTearDown(() => StorageService().delete(DetailedStatsProvider.storageKey));
  });

  group('calories you burn', () {
    testWidgets('a known estimate: one line, rounded, and it opens Energy',
        (tester) async {
      await history(List.filled(10, 80.0));
      var opened = 0;
      await pump(tester,
          energy: EnergyProvider(
              sync: _FixtureSync(_rows(EnergyState.confident)),
              inBackground: false),
          onOpenEnergy: () => opened++);
      final card = find.byKey(const Key('weight_burn_card'));
      await scrollTo(tester, card);

      expect(find.text('You burn about 2,430 cals a day'), findsOneWidget);
      expect(find.text('This gets more accurate each week'), findsNothing);
      await tester.tap(card);
      await pumpFrames(tester, seconds: 1);
      expect(opened, 1);
    });

    testWidgets('estimated: adds that it gets more accurate', (tester) async {
      await history(List.filled(10, 80.0));
      await pump(tester,
          energy: EnergyProvider(
              sync: _FixtureSync(_rows(EnergyState.estimated)),
              inBackground: false),
          onOpenEnergy: () {});
      await scrollTo(tester, find.byKey(const Key('weight_burn_card')));
      expect(find.text('This gets more accurate each week'), findsOneWidget);
    });

    testWidgets('learning: "Getting to know you" and the day of 14',
        (tester) async {
      goals.startLearning(_ago(4));
      await history(List.filled(5, 80.0));
      await pump(tester,
          energy: EnergyProvider(
              sync: _FixtureSync(_rows(EnergyState.learning)),
              inBackground: false),
          onOpenEnergy: () {});
      await scrollTo(tester, find.byKey(const Key('weight_burn_card')));
      expect(find.text('Getting to know you'), findsOneWidget);
      expect(find.text('Day 5 of 14 · log food and weigh in'), findsOneWidget);
      expect(find.textContaining('You burn'), findsNothing);
    });

    testWidgets('not shown without somewhere to open', (tester) async {
      await history(List.filled(10, 80.0));
      await pump(tester);
      expect(find.byKey(const Key('weight_burn_card')), findsNothing);
    });

    testWidgets('in Progress, the card switches to the Energy tab',
        (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await history(List.filled(10, 80.0));
      await tester.pumpWidget(testApp(const TrackingPagesScreen(),
          goalsProvider: goals,
          energyProvider: EnergyProvider(
              sync: _FixtureSync(_rows(EnergyState.confident)),
              inBackground: false)));
      await pumpFrames(tester, seconds: 2);
      final card = find.byKey(const Key('weight_burn_card'));
      await tester.scrollUntilVisible(card, 200,
          scrollable: find
              .descendant(
                  of: find.byType(WeightTrackingScreen),
                  matching: find.byType(Scrollable))
              .first);
      await pumpFrames(tester, seconds: 1);
      await tester.tap(card);
      await pumpFrames(tester, seconds: 2);
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index,
          TrackingPagesScreen.energyTab);
    });
  });

  group('roughDate', () {
    final today = DateTime(2026, 10, 9);
    String at(int days) => roughDate(
        DateTime(2026, 10, 9 + days), days / 7, today);

    test('close: within a week, or a few weeks', () {
      expect(at(6), 'within a week');
      expect(at(25), 'in a few weeks');
    });

    test('a few months: early, mid or late month', () {
      expect(at(60), 'around early Dec'); // Dec 8
      expect(at(66), 'around mid-Dec'); // Dec 14
      expect(at(80), 'around late Dec'); // Dec 28
    });

    test('far out: the month, with the year when it isn\'t this one', () {
      expect(at(150), 'around March 2027');
      expect(
          roughDate(DateTime(2026, 12, 20), 20, DateTime(2026, 8, 1)),
          'around December');
    });
  });
}
