import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/app_shell.dart';
import 'package:macrotracker/screens/dashboard/components/calorie_tracker.dart';
import 'package:macrotracker/screens/energy/checkin_sheet.dart';
import 'package:macrotracker/screens/energy/goals_card.dart';
import 'package:macrotracker/services/checkin_sync_service.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/estimate_rows.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/energy_sync_service.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

/// Check-ins the test hands in; dismissals are recorded, nothing uploads.
class _SeededCheckins extends CheckinSyncService {
  _SeededCheckins(List<GoalCheckin> rows)
      : rows = {for (final c in rows) dayKey(c.weekStart): c};

  final Map<String, GoalCheckin> rows;

  @override
  Map<String, GoalCheckin> loadCache() => Map.of(rows);

  @override
  Future<GoalCheckin?> markSeen(DateTime weekStart, DateTime at) async =>
      rows[dayKey(weekStart)] = rows[dayKey(weekStart)]!.copyWith(seenAt: at);

  @override
  Future<bool> sync() async => false;
}

class _FixtureSync extends EnergySyncService {
  _FixtureSync(this.rows);

  final List<EnergyEstimate> rows;

  @override
  Map<DateTime, EnergyEstimate> loadCache() => {for (final r in rows) r.day: r};

  @override
  Set<String> pendingDays() => const {};
}

final _now = DateTime.now();
final _today = DateTime(_now.year, _now.month, _now.day);

const _old = CheckinTargets(cals: 2010, protein: 150, carbs: 208, fat: 65);
const _new = CheckinTargets(cals: 2060, protein: 150, carbs: 220, fat: 65);

GoalCheckin checkin({
  CheckinVariant variant = CheckinVariant.changed,
  CheckinTargets oldT = _old,
  CheckinTargets newT = _new,
  SafetyLimit? limit,
  EnergyState state = EnergyState.confident,
  int completeDays = 6,
  int weighIns = 9,
  double? trendChange = -0.45,
  DateTime? createdAt,
  DateTime? seenAt,
}) =>
    GoalCheckin(
      weekStart: _today,
      variant: variant,
      oldTargets: oldT,
      newTargets: variant == CheckinVariant.changed ? newT : oldT,
      reason: CheckinReason(
        state: state,
        avgIntake: 2080,
        completeDays: completeDays,
        weighIns: weighIns,
        trendChangeKg: trendChange,
        tdee: 2450,
        tdeePrev: 2390,
        limitHit: limit,
        trendWeightKg: 80,
        goalWeightKg: 75,
        goal: GoalKind.lose,
        pacePct: 0.5,
        weeksToGoal: 11.2,
      ),
      createdAt: createdAt ?? _now,
      seenAt: seenAt,
    );

void main() {
  final events = <MethodCall>[];

  setUp(() async {
    await setUpTestEnvironment();
    for (final key in ['nutrition_goals', 'goal_settings', 'unit_system']) {
      await StorageService().delete(key);
    }
    await StorageService().put('unit_system', 'metric');
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

  EnergyProvider energyWith(List<GoalCheckin> checkins,
          {List<EnergyEstimate> rows = const [], GoalsProvider? goals}) =>
      EnergyProvider(
        sync: _FixtureSync(rows),
        checkinSync: _SeededCheckins(checkins),
        inBackground: false,
      )..goals = goals;

  group('copy', () {
    test('A: target, macro changes of 5 g or more, why, footer', () {
      final c = CheckinCopy(checkin());
      expect(c.title, 'Your new daily target');
      expect(c.macroLine, 'Protein 150 g · Carbs 220 g (+12) · Fat 65 g');
      expect(c.whyLines, [
        'You averaged 2,080 cals on 6 complete days in the last 3 weeks',
        'Your trend weight fell 0.45 kg this week (on pace for −0.5%/wk)',
        'Your expenditure is about 60 cals higher than we thought, about 2,450 cals a day',
      ]);
      expect(c.footer, 'This week: −0.45 kg · Goal 75 kg · about 11 weeks to go');
      expect(c.limitLine, isNull);
      expect(c.missing, isNull);
    });

    test('macro changes under 5 g are left out', () {
      final c = CheckinCopy(checkin(
          newT: const CheckinTargets(cals: 2030, protein: 146, carbs: 212, fat: 61)));
      expect(c.macroLine, 'Protein 146 g · Carbs 212 g · Fat 61 g');
    });

    test('off pace: no pace note, never a judgement', () {
      final c = CheckinCopy(checkin(trendChange: -0.1));
      expect(c.whyLines[1], 'Your trend weight fell 0.1 kg this week');
    });

    test('E: each limit has its line', () {
      String? line(SafetyLimit l) => CheckinCopy(checkin(limit: l)).limitLine;
      expect(line(SafetyLimit.floor),
          'We kept your target at 2,060 cals, our minimum, so your pace may be a little slower.');
      expect(line(SafetyLimit.checkinStep),
          'We moved it 150 cals, the most we change in one week. The rest follows at your next check-in.');
      expect(line(SafetyLimit.maxDeficit), contains('25% below what you burn'));
      expect(line(SafetyLimit.maxLossPace), contains('lose no more than 1% of your weight a week'));
      expect(line(SafetyLimit.maxSurplus), contains('15% above what you burn'));
      expect(line(SafetyLimit.maxGainPace), contains('gain no more than 0.5%'));
    });

    test('B: on track, same why lines', () {
      final c = CheckinCopy(checkin(variant: CheckinVariant.unchanged));
      expect(c.title, "You're right on track");
      expect(c.subtitle, 'Your targets stay the same.');
      expect(c.whyLines, hasLength(3));
      expect(c.limitLine, isNull);
    });

    test('C: what is missing, learning and paused', () {
      final learning = CheckinCopy(checkin(
          variant: CheckinVariant.insufficient,
          state: EnergyState.learning,
          completeDays: 2,
          weighIns: 1));
      expect(learning.title, 'Not enough data to update this week');
      expect(learning.missing, contains('So far: 2 complete days, 1 weigh-in.'));
      expect(learning.whyLines, isEmpty);
      expect(learning.footer, isNull);
      final paused =
          CheckinCopy(checkin(variant: CheckinVariant.insufficient, state: EnergyState.paused));
      expect(paused.missing, contains('paused'));
    });

    test('pounds when the user weighs in pounds', () {
      expect(CheckinCopy(checkin(), isKg: false).footer,
          'This week: −0.99 lbs · Goal 165.3 lbs · about 11 weeks to go');
    });

    test('likely change on the goals card', () {
      CheckinDecision d(CheckinVariant v, int to) => CheckinDecision(
          variant: v,
          oldTargets: _old,
          newTargets: CheckinTargets(cals: to, protein: 1, carbs: 1, fat: 1),
          reason: checkin().reason);
      expect(likelyChangeText(d(CheckinVariant.changed, 2060)), 'Likely +50 cals.');
      expect(likelyChangeText(d(CheckinVariant.changed, 1860)), 'Likely −150 cals.');
      expect(likelyChangeText(d(CheckinVariant.unchanged, 2010)), 'Likely no change.');
      expect(likelyChangeText(d(CheckinVariant.insufficient, 2010)), isNull);
      expect(likelyChangeText(null), isNull);
    });
  });

  group('sheet', () {
    Future<EnergyProvider> open(WidgetTester tester, GoalCheckin c,
        {bool dark = true, bool detailed = true}) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final energy = energyWith([c]);
      await tester.pumpWidget(testApp(
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showCheckinSheet(context, energy.lastCheckin!),
                child: const Text('open'),
              ),
            ),
          ),
        ),
        energyProvider: energy,
        weightUnitProvider: WeightUnitProvider(),
        detailedStatsProvider: DetailedStatsProvider(showDetailedStats: detailed),
        dark: dark,
      ));
      await tester.tap(find.text('open'));
      await settle(tester);
      return energy;
    }

    for (final dark in [true, false]) {
      testWidgets('A with the limit line, ${dark ? 'dark' : 'light'}', (tester) async {
        await open(tester, checkin(limit: SafetyLimit.checkinStep), dark: dark);
        expect(find.byKey(const Key('checkin_sheet_changed')), findsOneWidget);
        expect(find.text('Your new daily target'), findsOneWidget);
        expect(find.textContaining('2,010 → ', findRichText: true), findsOneWidget);
        expect(find.text('Protein 150 g · Carbs 220 g (+12) · Fat 65 g'), findsOneWidget);
        expect(find.byKey(const Key('checkin_limit_line')), findsOneWidget);
        expect(find.text('Why it changed'), findsOneWidget);
        expect(find.byKey(const Key('checkin_footer')), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('B and C', (tester) async {
      await open(tester, checkin(variant: CheckinVariant.unchanged));
      expect(find.text("You're right on track"), findsOneWidget);
      expect(find.text('This week'), findsOneWidget);
      expect(find.textContaining('→', findRichText: true), findsNothing);
      expect(find.byKey(const Key('finish_reminder_button')), findsNothing);
      await tester.tap(find.byKey(const Key('checkin_done')));
      await settle(tester);

      await open(tester,
          checkin(variant: CheckinVariant.insufficient, state: EnergyState.learning));
      expect(find.text('Not enough data to update this week'), findsOneWidget);
      expect(find.byKey(const Key('checkin_missing')), findsOneWidget);
      // C is one of the two places that offer the evening reminder.
      expect(find.text('Remind me in the evening'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('A has no reminder button', (tester) async {
      await open(tester, checkin());
      expect(find.byKey(const Key('finish_reminder_button')), findsNothing);
    });

    testWidgets('Got it dismisses, sets seen_at and tracks both events', (tester) async {
      final energy = await open(tester, checkin());
      expect(captured('checkin_shown'), [
        {'variant': 'changed', 'source': 'auto'}
      ]);
      await tester.tap(find.byKey(const Key('checkin_done')));
      await settle(tester);
      expect(find.byKey(const Key('checkin_sheet_changed')), findsNothing);
      expect(energy.lastCheckin!.seenAt, isNotNull);
      expect(energy.checkinToShow, isNull);
      final dismissed = captured('checkin_dismissed').single;
      expect(dismissed['variant'], 'changed');
      expect(dismissed['seconds'], isA<int>());
    });

    testWidgets('swiping it away counts as dismissing', (tester) async {
      final energy = await open(tester, checkin());
      await tester.tapAt(const Offset(200, 40)); // the scrim above the sheet
      await settle(tester);
      expect(find.byKey(const Key('checkin_sheet_changed')), findsNothing);
      expect(energy.lastCheckin!.seenAt, isNotNull);
      expect(captured('checkin_dismissed'), hasLength(1));
    });

    testWidgets('simple Got it dismisses, marks seen and keeps analytics', (tester) async {
      final energy = await open(tester, checkin(), detailed: false);
      expect(find.text('New daily target'), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkin_done')));
      await settle(tester);
      expect(find.byKey(const Key('checkin_sheet_changed')), findsNothing);
      expect(energy.lastCheckin!.seenAt, isNotNull);
      expect(energy.checkinToShow, isNull);
      expect(captured('checkin_shown').single['variant'], 'changed');
      expect(captured('checkin_dismissed').single['variant'], 'changed');
    });
  });

  group('home chip', () {
    Future<void> pumpCard(WidgetTester tester, EnergyProvider energy,
        {double width = 402}) async {
      tester.view.physicalSize = Size(width * 3, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(
        const Scaffold(body: SingleChildScrollView(child: CalorieTracker())),
        energyProvider: energy,
      ));
      await pumpFrames(tester, seconds: 1);
    }

    testWidgets('"New target" the day of a change; reopens the sheet', (tester) async {
      await pumpCard(tester, energyWith([checkin(seenAt: _now)]));
      expect(find.text('New target'), findsOneWidget);
      expect(find.text('Nutrition & Activity'), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkin_chip')));
      await settle(tester);
      expect(find.byKey(const Key('checkin_sheet_changed')), findsOneWidget);
      expect(captured('checkin_shown').single['source'], 'chip');
      expect(tester.takeException(), isNull);
    });

    testWidgets('"Check-in" when the targets stayed', (tester) async {
      await pumpCard(tester, energyWith([checkin(variant: CheckinVariant.unchanged)]));
      expect(find.text('Check-in'), findsOneWidget);
      expect(find.text('New target'), findsNothing);
    });

    testWidgets('narrow Home wraps the chip and macro circles without clipping', (tester) async {
      await pumpCard(tester, energyWith([checkin(seenAt: _now)]), width: 320);
      final header = tester.getRect(find.text('Nutrition & Activity'));
      final chip = tester.getRect(find.byKey(const Key('checkin_chip')));
      expect(chip.top, greaterThan(header.bottom));
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
      expect(find.text('Steps'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('checkin_chip')));
      await settle(tester);
      expect(find.text('New daily target'), findsOneWidget);
    });

    testWidgets('gone the next day, and never without a check-in', (tester) async {
      await pumpCard(tester,
          energyWith([checkin(createdAt: _now.subtract(const Duration(days: 1)))]));
      expect(find.byKey(const Key('checkin_chip')), findsNothing);
      await pumpCard(tester, energyWith(const []));
      expect(find.byKey(const Key('checkin_chip')), findsNothing);
    });
  });

  group('app shell', () {
    Future<void> pumpShell(WidgetTester tester, EnergyProvider energy) async {
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(const AppShell(), energyProvider: energy));
      await pumpFrames(tester);
    }

    testWidgets('shows an unseen check-in on its own, once', (tester) async {
      final energy = energyWith([checkin()]);
      await pumpShell(tester, energy);
      expect(find.byKey(const Key('checkin_sheet_changed')), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkin_done')));
      await pumpFrames(tester);
      expect(find.byKey(const Key('checkin_sheet_changed')), findsNothing);
      expect(captured('checkin_shown'), hasLength(1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a dismissed check-in stays closed', (tester) async {
      await pumpShell(tester, energyWith([checkin(seenAt: _now)]));
      expect(find.byKey(const Key('checkin_sheet_changed')), findsNothing);
      expect(find.text('New target'), findsOneWidget);
    });
  });

  group('goals card', () {
    testWidgets('next check-in next week once it ran; the likely change', (tester) async {
      final goals = GoalsProvider(userId: 'u')
        ..startLearning(_today.subtract(const Duration(days: 30)))
        ..currentWeightKg = 80
        ..goalType = MacroCalculatorService.GOAL_MAINTAIN
        ..checkinWeekday = _today.weekday;
      await goals.updateGoals(
          calories: 2000, protein: 150, carbs: 220, fat: 65, steps: 10000, bmr: 1700, tdee: 2000);
      final yesterday = DateTime(_today.year, _today.month, _today.day - 1);
      final energy = energyWith(
        [checkin(seenAt: _now)],
        goals: goals,
        rows: [
          EnergyEstimate(
            day: yesterday,
            tdee: 2050,
            tdeeSd: 90,
            state: EnergyState.confident,
            completeDays: 18,
            weighIns: 20,
            updated: true,
            trendWeightKg: 80,
          ),
        ],
      );
      tester.view.physicalSize = const Size(1206, 2622);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(testApp(
        const Scaffold(body: SingleChildScrollView(child: GoalsCard())),
        goalsProvider: goals,
        energyProvider: energy,
      ));
      await settle(tester);
      final next = DateTime(_today.year, _today.month, _today.day + 7);
      expect(find.textContaining(checkinDayText(next, _now), findRichText: true), findsOneWidget);
      expect(find.textContaining('Likely +50 cals.', findRichText: true), findsOneWidget);

      goals.adaptiveGoals = false;
      await settle(tester);
      expect(find.textContaining('Likely', findRichText: true), findsNothing);
    });
  });
}
