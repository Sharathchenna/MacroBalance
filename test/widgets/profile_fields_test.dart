import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/accountdashboard.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/screens/onboarding/pages/age_page.dart';
import 'package:macrotracker/screens/onboarding/pages/gender_page.dart';
import 'package:macrotracker/screens/onboarding/pages/weight_page.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

void main() {
  late GoalsProvider goals;

  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('nutrition_goals');
    await StorageService().delete('unit_system');
    await StorageService().put(
        'nutrition_goals',
        jsonEncode({
          'macro_targets': {'calories': 2000, 'protein': 150, 'carbs': 200, 'fat': 60},
          'current_weight_kg': 80,
          'goal_weight_kg': 75,
          'goal_type': MacroCalculatorService.GOAL_LOSE,
          'pace_pct_per_week': 0.5,
          'sex': MacroCalculatorService.MALE,
          'age': 34,
          'activity_level': 4,
          'height_cm': 182,
        }));
    goals = GoalsProvider();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  Future<void> openAccount(WidgetTester tester, {bool metric = true}) async {
    phone(tester);
    await tester.pumpWidget(testApp(const AccountDashboard(),
        goalsProvider: goals,
        weightUnitProvider: WeightUnitProvider()..setMetric(metric)));
    await pumpFrames(tester, seconds: 1);
    await tester.scrollUntilVisible(find.text('Height'), 200,
        scrollable: find.byType(Scrollable).first);
    await pumpFrames(tester, seconds: 1);
  }

  testWidgets('the account screen shows sex, height and age', (tester) async {
    await openAccount(tester);
    expect(find.text('Sex'), findsOneWidget);
    expect(find.text('Male'), findsOneWidget);
    expect(find.text('182 cm'), findsOneWidget);
    expect(find.text('34 years'), findsOneWidget);
  });

  testWidgets('height shows in feet and inches for imperial users', (tester) async {
    await openAccount(tester, metric: false);
    expect(find.text('6′0″'), findsOneWidget);
  });

  testWidgets('changing sex shows old -> new targets, and Update saves them', (tester) async {
    await openAccount(tester);
    final maleCals =
        goals.previewProfile(sex: MacroCalculatorService.MALE)!.after.calories;
    await tester.ensureVisible(find.text('Sex'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Sex'));
    await pumpFrames(tester, seconds: 1);
    expect(find.byType(GenderPage), findsOneWidget);

    tester.widget<GenderPage>(find.byType(GenderPage))
        .onGenderSelected(MacroCalculatorService.FEMALE);
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Save'));
    await pumpFrames(tester, seconds: 1);

    expect(find.text('Update your targets?'), findsOneWidget);
    expect(find.textContaining('2,000 →'), findsOneWidget);
    // Nothing changes until it is confirmed.
    expect(goals.sex, MacroCalculatorService.MALE);
    expect(goals.caloriesGoal, 2000);

    await tester.tap(find.text('Update'));
    await pumpFrames(tester, seconds: 1);
    expect(goals.sex, MacroCalculatorService.FEMALE);
    expect(goals.caloriesGoal, lessThan(maleCals));
    expect(find.byType(GenderPage), findsNothing);
    expect(find.text('Female'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Cancel on the confirm keeps the old sex and targets', (tester) async {
    await openAccount(tester);
    await tester.ensureVisible(find.text('Sex'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Sex'));
    await pumpFrames(tester, seconds: 1);
    tester.widget<GenderPage>(find.byType(GenderPage))
        .onGenderSelected(MacroCalculatorService.FEMALE);
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Save'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Cancel'));
    await pumpFrames(tester, seconds: 1);
    expect(goals.sex, MacroCalculatorService.MALE);
    expect(goals.caloriesGoal, 2000);
  });

  testWidgets('saving an unchanged value skips the confirm', (tester) async {
    await openAccount(tester);
    await tester.ensureVisible(find.text('Sex'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Sex'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Save'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Update your targets?'), findsNothing);
    expect(find.byType(GenderPage), findsNothing);
    expect(goals.sex, MacroCalculatorService.MALE);
  });

  testWidgets('the age picker cannot go below 18', (tester) async {
    await openAccount(tester);
    await tester.ensureVisible(find.text('Age'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Age'));
    await pumpFrames(tester, seconds: 1);
    final picker = tester.widget<CupertinoDatePicker>(find.byType(CupertinoDatePicker));
    final now = DateTime.now();
    expect(picker.maximumDate, DateTime(now.year - kMinimumAge, now.month, now.day));
  });

  testWidgets('recalculating starts at the weight, with the account profile', (tester) async {
    phone(tester);
    await tester.pumpWidget(testApp(
        Builder(
            builder: (context) => TextButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const OnboardingScreen(recalculateOnly: true))),
                child: const Text('Open'))),
        goalsProvider: goals));
    await tester.tap(find.text('Open'));
    await pumpFrames(tester, seconds: 1);
    expect(find.byType(WeightPage).hitTestable(), findsOneWidget);
    expect(find.byType(GenderPage).hitTestable(), findsNothing);
    // Activity comes from the account too.
    expect(goals.activityLevel, 4);
  });
}
