import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/NutritionTrendsScreen.dart';
import 'package:macrotracker/widgets/progress_card.dart';

import '../helpers/test_app.dart';

void main() {
  late FoodEntryProvider provider;

  setUp(() async {
    await setUpTestEnvironment();
    provider = FoodEntryProvider();
    await provider.ensureInitialized();
  });

  testWidgets('each card explains itself behind an info button',
      (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
        testApp(const NutritionTrendsScreen(), foodEntryProvider: provider));
    await pumpFrames(tester, seconds: 1);

    // The cards carry no explanatory paragraphs of their own.
    expect(find.textContaining('Within 10% of goal'), findsNothing);
    expect(find.textContaining('counted once it'), findsNothing);
    expect(find.textContaining('Per logged day'), findsNothing);

    for (final title in [
      'Daily intake',
      'Consistency',
      'Average macros',
      'Estimated maintenance',
    ]) {
      final button = find.byWidgetPredicate(
          (w) => w is InfoButton && w.info.title == title);
      await tester.scrollUntilVisible(button, 200,
          scrollable: find.byType(Scrollable).first);
      await pumpFrames(tester, seconds: 1);
      await tester.tap(button);
      await pumpFrames(tester, seconds: 1);
      expect(find.byType(BottomSheet), findsOneWidget, reason: title);
      expect(
          find.descendant(
              of: find.byType(BottomSheet), matching: find.text(title)),
          findsOneWidget);
      await tester.tapAt(const Offset(20, 40)); // dismiss
      await pumpFrames(tester, seconds: 1);
      expect(find.byType(BottomSheet), findsNothing);
    }
    expect(tester.takeException(), isNull);
  });
}
