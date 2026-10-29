import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/camera/ai_food_detail_page.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/foodDetail.dart';

import '../helpers/test_app.dart';

void main() {
  late FoodEntryProvider provider;
  final today = DateTime.now();
  final twoDaysAgo = DateTime(today.year, today.month, today.day - 2);

  final toast = AIFoodItem(
    name: 'Buttered toast',
    servingSizes: ['1 slice (35g)', '100g'],
    calories: [120, 343],
    protein: [3, 8.6],
    carbohydrates: [15, 43],
    fat: [5, 14.3],
    fiber: [1, 2.9],
  );

  setUp(() async {
    await setUpTestEnvironment();
    provider = FoodEntryProvider();
    await provider.ensureInitialized();
    for (final e in List.of(provider.entries)) {
      await provider.removeEntry(e.id);
    }
  });

  Future<void> openFromList(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AIFoodDetailPage(
                      food: toast, selectedMeal: 'Breakfast', logDate: twoDaysAgo),
                ),
              ),
              child: const Text('Results'),
            ),
          ),
        ),
      ),
      foodEntryProvider: provider,
      weightUnitProvider: WeightUnitProvider()..setMetric(true),
    ));
    await tester.tap(find.text('Results'));
    await pumpFrames(tester, seconds: 2);
  }

  /// The serving options scroll sideways; bring the by-weight one into view.
  Future<void> showGrams(WidgetTester tester) async {
    final servings = find.byWidgetPredicate(
        (w) => w is Scrollable && w.axisDirection == AxisDirection.right).first;
    await tester.ensureVisible(servings);
    await tester.scrollUntilVisible(find.text('Grams'), 100, scrollable: servings);
  }

  testWidgets('AI foods open in the shared food page and log by serving',
      (tester) async {
    await openFromList(tester);
    expect(find.byType(FoodDetailPage), findsOneWidget);
    expect(find.text('Buttered toast'), findsWidgets);
    expect(find.text('Health Score'), findsOneWidget);
    // Both AI servings plus entry by weight, since they give grams.
    expect(find.text('1 slice (35g)'), findsOneWidget);
    await showGrams(tester);
    expect(find.text('Grams'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Add half a serving'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.byTooltip('Add half a serving'));
    await pumpFrames(tester, seconds: 1);
    await tester.runAsync(() async {
      await tester.tap(find.text('Add to Breakfast').hitTestable());
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await pumpFrames(tester, seconds: 1);

    final logged = provider.getEntriesForMeal(twoDaysAgo, 'Breakfast').single;
    expect(logged.quantity, 52.5);
    expect(logged.unit, 'g');
    expect(FoodEntryProvider.nutrientForEntry(logged, 'calories'), 180);
    // Back on the list it was opened from.
    expect(find.text('Results'), findsOneWidget);
    expect(find.byType(FoodDetailPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('by weight, one-tap amounts fill in the grams', (tester) async {
    await openFromList(tester);
    await showGrams(tester);
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.text('Grams'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Amount (g)'), findsOneWidget);
    await tester.ensureVisible(find.text('150 g'));
    await tester.tap(find.text('150 g'));
    await pumpFrames(tester, seconds: 1);
    expect(find.widgetWithText(TextField, '150'), findsOneWidget);
    // 150 g at 120 cals per 35 g.
    expect(find.text('514'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
