import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/screens/onboarding/pages/adaptive_page.dart';
import 'package:macrotracker/screens/onboarding/pages/apple_health_page.dart';
import 'package:macrotracker/screens/onboarding/pages/insight_page.dart';
import 'package:macrotracker/screens/onboarding/pages/notify_page.dart';
import 'package:macrotracker/screens/onboarding/pages/obstacles_page.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/widgets/brand/mb_logo.dart';

import '../../helpers/test_app.dart';

void main() {
  setUp(setUpTestEnvironment);

  Future<void> pump(WidgetTester tester, Widget page, {bool dark = true}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(Scaffold(body: SafeArea(child: page)), dark: dark));
    await pumpFrames(tester, seconds: 1);
  }

  for (final dark in [true, false]) {
    group(dark ? 'dark' : 'light', () {
      testWidgets('obstacles toggle and report the set', (tester) async {
        var selected = <String>{'logging_slow'};
        await pump(
          tester,
          StatefulBuilder(
            builder: (context, setState) => ObstaclesPage(
              selected: selected,
              onChanged: (s) => setState(() => selected = s),
            ),
          ),
          dark: dark,
        );
        expect(find.text('1 selected'), findsOneWidget);
        await tester.tap(find.text('I hit a plateau'));
        await tester.pump();
        expect(selected, {'logging_slow', 'plateau'});
        await tester.tap(find.text('Logging took too long'));
        await tester.pump();
        expect(selected, {'plateau'});
        expect(find.text('1 selected'), findsOneWidget);
        expect(kObstacleCodes, contains('plateau'));
      });

      testWidgets('insight shows one reply card per obstacle', (tester) async {
        await pump(
          tester,
          const InsightPage(
            goal: MacroCalculatorService.GOAL_LOSE,
            obstacles: {'logging_slow', 'weekends', 'unknown'},
          ),
          dark: dark,
        );
        expect(find.byKey(const Key('insight_reply_logging_slow')), findsOneWidget);
        expect(find.byKey(const Key('insight_reply_weekends')), findsOneWidget);
        expect(find.byKey(const Key('insight_reply_plateau')), findsNothing);
        expect(find.text('Fixed target'), findsOneWidget);
        expect(find.text('What you actually burn'), findsOneWidget);
      });

      testWidgets('adaptive toggling calls back', (tester) async {
        bool? last;
        await pump(
          tester,
          AdaptivePage(adaptive: true, onChanged: (v) => last = v),
          dark: dark,
        );
        await tester.tap(find.text('Keep my targets fixed'));
        expect(last, isFalse);
        await tester.tap(find.text('Yes, adjust weekly'));
        expect(last, isTrue);
        expect(find.text('Recommended'), findsOneWidget);
      });

      testWidgets('health: logo present, Not now skips', (tester) async {
        var skipped = false;
        await pump(tester, AppleHealthPage(onNext: () {}, onSkip: () => skipped = true),
            dark: dark);
        expect(find.byType(MbLogoTile), findsOneWidget);
        expect(find.text('Connect Apple Health'), findsOneWidget);
        await tester.tap(find.text('Not now'));
        expect(skipped, isTrue);
      });

      testWidgets('notify: Not now skips without asking permission', (tester) async {
        var skipped = false;
        var asked = false;
        await pump(
          tester,
          NotifyPage(
            onNext: () {},
            onSkip: () => skipped = true,
            requestPermission: () async => asked = true,
          ),
          dark: dark,
        );
        await tester.tap(find.text('Not now'));
        expect(skipped, isTrue);
        expect(asked, isFalse);
      });
    });
  }

  testWidgets('notify: Turn on reminders asks, then moves on', (tester) async {
    var asked = false;
    var next = false;
    await pump(
      tester,
      NotifyPage(
        onNext: () => next = true,
        onSkip: () {},
        requestPermission: () async => asked = true,
      ),
    );
    await tester.tap(find.text('Turn on reminders'));
    await tester.pump();
    await tester.pump();
    expect(asked, isTrue);
    expect(next, isTrue);
  });
}
