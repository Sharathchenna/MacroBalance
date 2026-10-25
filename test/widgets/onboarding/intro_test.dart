import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/screens/intro/hello_screen.dart';
import 'package:macrotracker/screens/intro/story_screen.dart';
import 'package:macrotracker/widgets/brand/mb_logo.dart';

import '../../helpers/test_app.dart';

class _Quiz extends StatelessWidget {
  const _Quiz();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Text('quiz placeholder'));
}

void main() {
  setUp(() async {
    await setUpTestEnvironment();
  });

  void phone(WidgetTester tester, {Size size = const Size(1179, 2556), double dpr = 3}) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = dpr;
    addTearDown(tester.view.reset);
  }

  Widget stories() => testApp(StoryScreen(next: (_) => const _Quiz()));

  testWidgets('Hello shows the headline, logo and both buttons', (tester) async {
    phone(tester);
    await tester.pumpWidget(testApp(const HelloScreen()));
    await pumpFrames(tester, seconds: 2);

    expect(find.textContaining('Eat like you normally do.', findRichText: true), findsOneWidget);
    expect(find.textContaining('do the math', findRichText: true), findsOneWidget);
    expect(find.byType(MbMark), findsWidgets);
    expect(find.text('Build my plan'), findsOneWidget);
    expect(find.text('I already have an account'), findsOneWidget);
    expect(find.text('cals left today'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Hello ring counts down as chips land', (tester) async {
    phone(tester);
    await tester.pumpWidget(testApp(const HelloScreen()));
    await tester.pump();
    expect(find.text('2,234'), findsOneWidget);
    // Past the third chip, the count settles at 1,264.
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('1,264'), findsOneWidget);
  });

  testWidgets('Hello fits a 375x667 iPhone SE', (tester) async {
    phone(tester, size: const Size(750, 1334), dpr: 2);
    await tester.pumpWidget(testApp(const HelloScreen()));
    await pumpFrames(tester, seconds: 2);
    expect(tester.takeException(), isNull);
    expect(find.text('Build my plan').hitTestable(), findsOneWidget);
  });

  testWidgets('Hello at rest when animations are off', (tester) async {
    phone(tester);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true, size: Size(393, 852)),
      child: testApp(const HelloScreen()),
    ));
    await tester.pump();
    expect(find.text('1,264'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('Build my plan opens story 1', (tester) async {
    phone(tester);
    await tester.pumpWidget(testApp(const HelloScreen()));
    await pumpFrames(tester, seconds: 2);
    await tester.tap(find.text('Build my plan'));
    await pumpFrames(tester, seconds: 1);

    expect(find.byType(StoryScreen), findsOneWidget);
    expect(find.textContaining('Snap it, scan it,', findRichText: true), findsOneWidget);
  });

  testWidgets('Story 1 lists the scanned foods once the scan is done', (tester) async {
    phone(tester);
    await tester.pumpWidget(stories());
    for (var i = 0; i < 18; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.textContaining('Salmon fillet', findRichText: true), findsOneWidget);
    expect(find.textContaining('White rice', findRichText: true), findsOneWidget);
    expect(find.textContaining('Avocado', findRichText: true), findsOneWidget);
    expect(find.text('3 foods added to Lunch'), findsOneWidget);
    expect(find.text('638'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Continue and tap go from story 1 to story 2', (tester) async {
    phone(tester);
    await tester.pumpWidget(stories());
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Continue'));
    await pumpFrames(tester, seconds: 1);
    expect(find.textContaining('really burn.', findRichText: true), findsOneWidget);
    expect(find.text('Build my plan'), findsOneWidget);
  });

  testWidgets('Story 1 auto-advances after 6s', (tester) async {
    phone(tester);
    await tester.pumpWidget(stories());
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining('Snap it, scan it,', findRichText: true), findsOneWidget);
    await tester.pump(const Duration(seconds: 1, milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('really burn.', findRichText: true), findsOneWidget);
  });

  testWidgets('Story 2 ends in the quiz, after 6s or on Build my plan', (tester) async {
    phone(tester);
    await tester.pumpWidget(stories());
    await tester.pump();
    await tester.pump(const Duration(seconds: 6, milliseconds: 100));
    await pumpFrames(tester, seconds: 1);
    await tester.pump(const Duration(seconds: 6, milliseconds: 100));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('quiz placeholder'), findsOneWidget);

    // Back returns to story 2.
    Navigator.of(tester.element(find.text('quiz placeholder'))).pop();
    await pumpFrames(tester, seconds: 1);
    expect(find.textContaining('really burn.', findRichText: true), findsOneWidget);
  });

  testWidgets('Skip jumps to the quiz', (tester) async {
    phone(tester);
    await tester.pumpWidget(stories());
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Skip'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('quiz placeholder'), findsOneWidget);
  });

  testWidgets('Stories fit a 375x667 iPhone SE in both themes', (tester) async {
    phone(tester, size: const Size(750, 1334), dpr: 2);
    for (final dark in [true, false]) {
      await tester.pumpWidget(testApp(StoryScreen(key: ValueKey(dark), next: (_) => const _Quiz()), dark: dark));
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 250));
      }
      await tester.tap(find.text('Continue'));
      await pumpFrames(tester, seconds: 4);
      expect(tester.takeException(), isNull);
    }
  });
}
