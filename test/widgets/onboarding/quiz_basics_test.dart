import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/screens/onboarding/pages/about_you_page.dart';
import 'package:macrotracker/screens/onboarding/pages/activity_level_page.dart';
import 'package:macrotracker/screens/onboarding/pages/goal_page.dart';
import 'package:macrotracker/screens/onboarding/pages/goal_weight_page.dart';
import 'package:macrotracker/screens/onboarding/pages/pace_page.dart';
import 'package:macrotracker/screens/onboarding/pages/weight_page.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';

import '../../helpers/test_app.dart';

void main() {
  setUp(() async {
    await setUpTestEnvironment();
  });

  Future<void> pumpPage(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      Scaffold(body: SafeArea(child: page)),
      detailedStatsProvider: DetailedStatsProvider(showDetailedStats: true),
    ));
    await pumpFrames(tester, seconds: 2);
  }

  group('GoalPage', () {
    testWidgets('shows the three goals and reports the tapped one', (tester) async {
      String? picked;
      await pumpPage(
          tester,
          GoalPage(
              currentGoal: MacroCalculatorService.GOAL_LOSE,
              onGoalChanged: (g) => picked = g));
      expect(find.text('What do you want to change?'), findsOneWidget);
      await tester.tap(find.text('Build muscle'));
      expect(picked, MacroCalculatorService.GOAL_GAIN);
      await tester.tap(find.text('Maintain'));
      expect(picked, MacroCalculatorService.GOAL_MAINTAIN);
      await tester.tap(find.text('Lose fat'));
      expect(picked, MacroCalculatorService.GOAL_LOSE);
    });
  });

  group('AboutYouPage', () {
    Widget page({
      required void Function(String) onSex,
      required void Function(int) onAge,
      required void Function(double) onHeight,
      void Function(bool)? onUnit,
      bool metric = true,
      double heightCm = 178,
    }) =>
        AboutYouPage(
          gender: MacroCalculatorService.MALE,
          onGenderChanged: onSex,
          age: 30,
          onAgeChanged: onAge,
          heightCm: heightCm,
          isMetricHeight: metric,
          onHeightChanged: onHeight,
          onHeightUnitChanged: onUnit ?? (_) {},
        );

    testWidgets('renders the copy and reports sex', (tester) async {
      String? sex;
      await pumpPage(tester, page(onSex: (s) => sex = s, onAge: (_) {}, onHeight: (_) {}));
      expect(find.text('A few basics'), findsOneWidget);
      await tester.tap(find.text('Female'));
      expect(sex, MacroCalculatorService.FEMALE);
    });

    testWidgets('typing an age and a height reports them', (tester) async {
      int? age;
      double? height;
      await pumpPage(tester,
          page(onSex: (_) {}, onAge: (a) => age = a, onHeight: (h) => height = h));
      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(2));
      await tester.enterText(fields.at(0), '35');
      expect(age, 35);
      await tester.enterText(fields.at(1), '182');
      expect(height, 182);
    });

    testWidgets('an out of range age is not reported', (tester) async {
      int? age;
      await pumpPage(
          tester, page(onSex: (_) {}, onAge: (a) => age = a, onHeight: (_) {}));
      await tester.enterText(find.byType(TextField).first, '12');
      expect(age, isNull);
    });

    testWidgets('the cm / ft toggle reports the choice', (tester) async {
      bool? metric;
      await pumpPage(
          tester,
          page(
              onSex: (_) {},
              onAge: (_) {},
              onHeight: (_) {},
              onUnit: (m) => metric = m));
      await tester.tap(find.text('ft'));
      expect(metric, false);
    });

    testWidgets('feet mode shows ft and in fields and still reports cm', (tester) async {
      double? height;
      await pumpPage(
          tester,
          page(
              onSex: (_) {},
              onAge: (_) {},
              onHeight: (h) => height = h,
              metric: false,
              heightCm: 178));
      // Age plus feet plus inches.
      expect(find.byType(TextField), findsNWidgets(3));
      expect(find.text('ft'), findsWidgets);
      expect(find.text('in'), findsOneWidget);
      expect(find.text('≈ 178 cm'), findsOneWidget);

      // 178 cm is 5 ft 10 in. 6 ft 10 in is 82 in; 5 ft 1 in is 61 in.
      await tester.enterText(find.byType(TextField).at(1), '6');
      expect(height, (82 * 2.54).roundToDouble());
      await tester.enterText(find.byType(TextField).at(2), '1');
      expect(height, (61 * 2.54).roundToDouble());
    });
  });

  group('WeightPage', () {
    Widget page({
      required void Function(double) onWeight,
      bool metric = true,
      double kg = 82.4,
      double? trendKg,
      VoidCallback? onUseTrend,
    }) =>
        WeightPage(
          currentWeightKg: kg,
          isMetric: metric,
          onWeightChanged: onWeight,
          onUnitChanged: (_) {},
          trendKg: trendKg,
          onUseTrend: onUseTrend,
        );

    testWidgets('renders the title and reports a typed kg weight', (tester) async {
      double? kg;
      await pumpPage(tester, page(onWeight: (v) => kg = v));
      expect(find.text('What do you weigh today?'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '75.5');
      expect(kg, 75.5);
    });

    testWidgets('lb mode reports kg', (tester) async {
      double? kg;
      await pumpPage(tester, page(onWeight: (v) => kg = v, metric: false, kg: 80));
      // 80 kg is shown as 176.4 lb.
      expect(find.text('176.4'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '165');
      expect(kg, closeTo(165 / 2.20462, 0.01));
    });

    testWidgets('offers the trend weight in one tap', (tester) async {
      var used = false;
      await pumpPage(
          tester, page(onWeight: (_) {}, trendKg: 81.9, onUseTrend: () => used = true));
      await tester.tap(find.text('Use 81.9 kg (your trend)'));
      expect(used, isTrue);
    });
  });

  group('ActivityLevelPage', () {
    testWidgets('lists the five levels and reports the tapped one', (tester) async {
      int? level;
      await pumpPage(
          tester,
          ActivityLevelPage(
              currentActivityLevel: MacroCalculatorService.MODERATELY_ACTIVE,
              onActivityLevelChanged: (l) => level = l));
      expect(find.text('How active is a normal week?'), findsOneWidget);
      for (final t in [
        'Sedentary',
        'Lightly active',
        'Moderately active',
        'Very active',
        'Extra active'
      ]) {
        expect(find.text(t), findsOneWidget);
      }
      await tester.tap(find.text('Very active'));
      expect(level, MacroCalculatorService.VERY_ACTIVE);
      await tester.tap(find.text('Sedentary'));
      expect(level, MacroCalculatorService.SEDENTARY);
    });
  });

  group('GoalWeightPage', () {
    Widget page({
      String goal = MacroCalculatorService.GOAL_LOSE,
      double goalKg = 74,
      required void Function(double) onGoal,
      bool metric = true,
      int? weeks = 21,
      DateTime? date,
    }) =>
        GoalWeightPage(
          goal: goal,
          currentWeightKg: 82.4,
          goalWeightKg: goalKg,
          minKg: 40,
          maxKg: 82.3,
          isMetricWeight: metric,
          onGoalWeightChanged: onGoal,
          weeks: weeks,
          projectedDate: date,
        );

    testWidgets('shows the distance, projection and weeks', (tester) async {
      await pumpPage(tester, page(onGoal: (_) {}, date: DateTime(2027, 3, 4)));
      expect(find.text('Where do you want to land?'), findsOneWidget);
      expect(find.textContaining('8.4 kg'), findsOneWidget);
      expect(find.textContaining('Goal · Mar 4'), findsOneWidget);
      expect(find.textContaining('21 weeks'), findsOneWidget);
      expect(find.textContaining('You’ll pick your pace next.'), findsOneWidget);
    });

    testWidgets('typing a goal weight reports it', (tester) async {
      double? kg;
      await pumpPage(tester, page(onGoal: (v) => kg = v));
      await tester.enterText(find.byType(TextField), '70.5');
      expect(kg, 70.5);
    });

    testWidgets('hides the date and weeks when there is no projection', (tester) async {
      await pumpPage(tester, page(onGoal: (_) {}, weeks: null));
      expect(find.text('Goal'), findsOneWidget);
      expect(find.textContaining('weeks'), findsNothing);
    });

    testWidgets('a gain goal renders too', (tester) async {
      await pumpPage(
          tester, page(goal: MacroCalculatorService.GOAL_GAIN, goalKg: 80, onGoal: (_) {}));
      expect(find.byType(GoalWeightPage), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('PacePage', () {
    PaceChoice choice(double pct, double cals,
            {double? effective, List<SafetyLimit> limits = const [], int weeks = 20}) =>
        PaceChoice(
          target: PaceTarget(
              pacePct: pct,
              cals: cals,
              effectivePacePct: effective ?? pct,
              limitsHit: limits),
          weeks: weeks,
          date: DateTime(2027, 3, 4),
        );

    final lose = [
      choice(0.25, 2325, weeks: 40),
      choice(0.5, 2095, weeks: 21),
      choice(0.75, 1915,
          effective: 0.7, limits: [SafetyLimit.maxDeficit], weeks: 17),
      choice(1.0, 1915,
          effective: 0.7, limits: [SafetyLimit.maxDeficit], weeks: 17),
    ];

    testWidgets('lists four lose paces with cals, weeks and the pill', (tester) async {
      await pumpPage(
          tester,
          PacePage(
              goal: MacroCalculatorService.GOAL_LOSE,
              paceChoices: lose,
              pacePct: 0.5,
              recommendedPacePct: 0.5,
              onPaceChanged: (_) {}));
      expect(find.text('How fast do you want to go?'), findsOneWidget);
      for (final t in ['Relaxed', 'Steady', 'Faster', 'Fastest']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.text('Recommended'), findsOneWidget);
      expect(find.text('2,095'), findsOneWidget);
      expect(find.text('cals a day'), findsNWidgets(4));
      expect(find.text('0.5% a week · about 21 weeks'), findsOneWidget);
      // Not capped, so the generic safety line shows instead of the limit note.
      expect(find.textContaining('We never set a target below what’s safe'), findsOneWidget);
    });

    testWidgets('reports the tapped pace', (tester) async {
      double? picked;
      await pumpPage(
          tester,
          PacePage(
              goal: MacroCalculatorService.GOAL_LOSE,
              paceChoices: lose,
              pacePct: 0.5,
              recommendedPacePct: 0.5,
              onPaceChanged: (p) => picked = p));
      await tester.tap(find.text('Faster'));
      expect(picked, 0.75);
    });

    testWidgets('a capped pace shows why', (tester) async {
      await pumpPage(
          tester,
          PacePage(
              goal: MacroCalculatorService.GOAL_LOSE,
              paceChoices: lose,
              pacePct: 1.0,
              recommendedPacePct: 0.5,
              onPaceChanged: (_) {}));
      expect(
          find.text(
              "We've set your pace to 0.7%/week so you eat no more than 25% below what you burn."),
          findsOneWidget);
      expect(find.textContaining('We never set a target below'), findsNothing);
    });

    testWidgets('gain shows three paces', (tester) async {
      await pumpPage(
          tester,
          PacePage(
              goal: MacroCalculatorService.GOAL_GAIN,
              paceChoices: [
                choice(0.1, 2600),
                choice(0.25, 2700),
                choice(0.5, 2900),
              ],
              pacePct: 0.25,
              recommendedPacePct: 0.25,
              onPaceChanged: (_) {}));
      expect(find.text('Relaxed'), findsOneWidget);
      expect(find.text('Steady'), findsOneWidget);
      expect(find.text('Faster'), findsOneWidget);
      expect(find.text('Fastest'), findsNothing);
      expect(find.text('Recommended'), findsOneWidget);
    });
  });
}
