import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/onboarding/building_screen.dart';
import 'package:macrotracker/screens/onboarding/onboarding_steps.dart';
import 'package:macrotracker/screens/onboarding/pages/acquisition_source_page.dart';
import 'package:macrotracker/screens/onboarding/pages/summary_page.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
import 'package:macrotracker/screens/onboarding/save_screen.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:intl/intl.dart';

import '../../helpers/test_app.dart';

void main() {
  setUp(() async {
    await setUpTestEnvironment();
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      child,
      detailedStatsProvider: DetailedStatsProvider(showDetailedStats: false),
      weightUnitProvider: WeightUnitProvider(),
    ));
    await pumpFrames(tester, seconds: 3);
  }

  Map<String, dynamic> plan(String goal) => MacroCalculatorService().calculateAll(
        gender: 'male',
        weightKg: 80,
        heightCm: 180,
        age: 30,
        activityLevel: 3,
        goal: goal,
        goalWeightKg: goal == 'maintain' ? null : (goal == 'lose' ? 72 : 85),
        pacePct: goal == 'maintain' ? null : .4,
      );

  group('Building', () {
    testWidgets('runs the work once and calls onDone after it', (tester) async {
      var worked = 0;
      var done = 0;
      await pump(
        tester,
        BuildingScreen(
          work: () async => worked++,
          onDone: () => done++,
        ),
      );
      expect(worked, 1);
      expect(find.text('Building your plan'), findsOneWidget);
      expect(done, 0);
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(worked, 1);
      expect(done, 1);
      expect(find.text('Your plan is ready'), findsOneWidget);
      // The old title is gone, not stacked under the new one.
      expect(find.text('Building your plan'), findsNothing);
    });

    testWidgets('waits for slow work before finishing', (tester) async {
      var done = 0;
      Future<void> slow() => Future<void>.delayed(const Duration(seconds: 20));
      await pump(tester, BuildingScreen(work: slow, onDone: () => done++));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250)); // 10 s
      }
      expect(done, 0);
      expect(find.text('Building your plan'), findsOneWidget);
      for (var i = 0; i < 80; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      expect(done, 1);
    });
  });

  group('Reveal', () {
    Finder rich(String text) => find.textContaining(text, findRichText: true);

    testWidgets('lose: target, macros, goal date and burn', (tester) async {
      final r = plan('lose');
      await pump(
        tester,
        ResultsScreen(
          results: r,
          isMetricWeight: true,
          goalWeightKg: 72,
          currentWeightKg: 80,
          projectedDate: DateTime(2027, 3, 13),
        ),
      );
      final cals = NumberFormat('#,###').format(r['target_calories']);
      expect(find.text(cals), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
      expect(rich('${r['protein_g'].round()} g'), findsWidgets);
      expect(rich('LOSE FAT'), findsOneWidget);
      expect(rich('72.0 kg'), findsWidgets);
      expect(rich('Mar 13'), findsWidgets);
      expect(find.text('Save my plan'), findsOneWidget);
      expect(find.textContaining('kg/wk'), findsOneWidget);
    });

    testWidgets('maintain: no goal date, holds the pace', (tester) async {
      final r = plan('maintain');
      await pump(
        tester,
        ResultsScreen(results: r, isMetricWeight: true, currentWeightKg: 80),
      );
      final cals = NumberFormat('#,###').format(r['target_calories']);
      expect(find.text(cals), findsOneWidget);
      expect(rich('MAINTAIN'), findsOneWidget);
      expect(find.text('Hold'), findsOneWidget);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.text('Carbs'), findsOneWidget);
      expect(find.text('Fat'), findsOneWidget);
      expect(rich('Goal ·'), findsNothing);
      expect(find.text('Healthy range'), findsOneWidget);
    });

    testWidgets('gain: rising projection to the goal', (tester) async {
      final r = plan('gain');
      await pump(
        tester,
        ResultsScreen(
          results: r,
          isMetricWeight: true,
          goalWeightKg: 85,
          currentWeightKg: 80,
          projectedDate: DateTime(2027, 2, 20),
        ),
      );
      final cals = NumberFormat('#,###').format(r['target_calories']);
      expect(find.text(cals), findsOneWidget);
      expect(rich('BUILD MUSCLE'), findsOneWidget);
      expect(rich('Feb 20'), findsWidgets);
      expect(find.text('Protein'), findsOneWidget);
      expect(find.textContaining('+'), findsWidgets);
    });

    testWidgets('"Review answers" calls onReview and hides when null', (tester) async {
      var reviewed = 0;
      await pump(
        tester,
        ResultsScreen(results: plan('lose'), onReview: () => reviewed++),
      );
      await tester.tap(find.text('Review answers'));
      expect(reviewed, 1);

      await pump(tester, ResultsScreen(results: plan('lose')));
      expect(find.text('Review answers'), findsNothing);
    });

    testWidgets('recalculate shows Save and calls onSave', (tester) async {
      var saved = 0;
      await pump(
        tester,
        ResultsScreen(
          results: plan('lose'),
          recalculateOnly: true,
          onSave: () async => saved++,
        ),
      );
      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Save my plan'), findsNothing);
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(saved, 1);
      await pumpFrames(tester, seconds: 1);
    });
  });

  group('Review', () {
    testWidgets('rows jump to their step', (tester) async {
      final edited = <OnboardingStep>[];
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
            goalWeightKg: 70,
            onEdit: edited.add,
          ),
        ),
      );
      Future<void> tap(String label) async {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
      }

      await tap('Goal weight');
      await tap('Pace');
      await tap('Age');
      await tap('Weight');
      await tap('Activity');
      await tap('Targets');
      expect(edited, [
        OnboardingStep.goalWeight,
        OnboardingStep.pace,
        OnboardingStep.aboutYou,
        OnboardingStep.weight,
        OnboardingStep.activity,
        OnboardingStep.adaptive,
      ]);
    });

    testWidgets('maintain has no goal weight or pace rows', (tester) async {
      await pump(
        tester,
        Scaffold(
          body: SummaryPage(
            gender: 'female',
            weightKg: 60,
            heightCm: 165,
            age: 28,
            activityLevel: 2,
            goal: 'maintain',
            pacePct: 0,
            proteinRatio: 1.6,
            fatRatio: .25,
            goalWeightKg: 60,
            onEdit: (_) {},
          ),
        ),
      );
      expect(find.text('Goal weight'), findsNothing);
      expect(find.text('Pace'), findsNothing);
      expect(find.text('Sex'), findsOneWidget);
    });
  });

  group('Source', () {
    testWidgets('"Somewhere else" text becomes other: <text>', (tester) async {
      String? picked;
      await pump(
        tester,
        Scaffold(
          body: AcquisitionSourcePage(onSourceSelected: (s) => picked = s),
        ),
      );
      await tester.tap(find.text('TikTok'));
      expect(picked, 'tiktok');
      await tester.enterText(find.byKey(const Key('source_other_field')), 'a podcast');
      expect(picked, 'other: a podcast');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('the new choices exist and the step skips', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const AcquisitionSourceStep())),
              child: const Text('Open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await pumpFrames(tester, seconds: 1);
      for (final label in ['YouTube', 'An ad', 'A friend', 'Gym, club or coach', 'App Store']) {
        expect(find.text(label), findsOneWidget);
      }
      await tester.tap(find.byKey(const Key('source_cta')));
      await pumpFrames(tester, seconds: 1);
      expect(find.byType(AcquisitionSourceStep), findsNothing);
    });
  });

  group('Save', () {
    testWidgets('offers Apple, Google and email, and switches to log in', (tester) async {
      await pump(tester, const SaveScreen());
      expect(find.text('Save your plan'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with email'), findsOneWidget);

      await tester.tap(find.text('Continue with email'));
      await pumpFrames(tester, seconds: 1);
      expect(find.byKey(const Key('save_name')), findsOneWidget);
      expect(find.byKey(const Key('save_email')), findsOneWidget);
      expect(find.byKey(const Key('save_password')), findsOneWidget);

      // Empty fields give an inline message, not a snackbar.
      await tester.tap(find.text('Create account'));
      await tester.pump();
      expect(find.byKey(const Key('save_error')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.textContaining('Log in', findRichText: true));
      await pumpFrames(tester, seconds: 1);
      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.byKey(const Key('save_name')), findsNothing);
      expect(find.byKey(const Key('save_email')), findsOneWidget);
      expect(find.text('Continue with Apple'), findsOneWidget);
    });
  });
}
