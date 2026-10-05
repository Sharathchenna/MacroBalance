import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/dashboard/components/meal_section.dart';

import '../helpers/test_app.dart';

void main() {
  late FoodEntryProvider provider;
  late DateProvider dates;
  final today = DateTime.now();
  final yesterday = today.subtract(const Duration(days: 1));

  setUp(() async {
    await setUpTestEnvironment();
    provider = FoodEntryProvider();
    await provider.ensureInitialized();
    for (final e in List.of(provider.entries)) {
      await provider.removeEntry(e.id);
    }
    dates = DateProvider();
  });

  Future<void> pumpMeals(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const Scaffold(body: SingleChildScrollView(child: MealSection())),
      foodEntryProvider: provider,
      dateProvider: dates,
    ));
    await settle(tester);
  }

  Finder menuFor(String meal) => find.byTooltip('$meal options');

  testWidgets('options menu with nothing to copy opens and closes cleanly',
      (tester) async {
    await pumpMeals(tester);
    for (final meal in ['Breakfast', 'Lunch', 'Snacks', 'Dinner']) {
      await tester.ensureVisible(menuFor(meal));
      await tester.tap(menuFor(meal));
      await settle(tester);
      expect(find.text('Nothing logged for $meal the day before'), findsOneWidget);
      // The disabled item ignores taps; tapping outside closes the menu.
      await tester.tap(find.text('Nothing logged for $meal the day before'));
      await settle(tester);
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('copying from the day before adds the items, Undo removes them',
      (tester) async {
    await tester.runAsync(() => provider.addEntry(testEntry(name: 'Toast', meal: 'Dinner', date: yesterday)));
    await tester.runAsync(() => provider.addEntry(testEntry(name: 'Soup', meal: 'Dinner', date: yesterday)));
    await pumpMeals(tester);

    await tester.ensureVisible(menuFor('Dinner'));
    await tester.tap(menuFor('Dinner'));
    await settle(tester);
    await tester.tap(find.text('Copy 2 items from the day before'));
    await settle(tester);

    expect(provider.getEntriesForMeal(today, 'Dinner'), hasLength(2));
    expect(find.text('Copied 2 items to Dinner'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(provider.getEntriesForMeal(today, 'Dinner'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening the menu twice and copying twice stays consistent',
      (tester) async {
    await tester.runAsync(() => provider.addEntry(testEntry(name: 'Oats', meal: 'Breakfast', date: yesterday)));
    await pumpMeals(tester);
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(menuFor('Breakfast'));
      await tester.tap(menuFor('Breakfast'));
      await settle(tester);
      await tester.tap(find.text('Copy 1 item from the day before'));
      await settle(tester);
    }
    expect(provider.getEntriesForMeal(today, 'Breakfast'), hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('swipe to delete shows Undo, and Undo restores the entry',
      (tester) async {
    await tester.runAsync(() => provider.addEntry(testEntry(
        name: 'Eggs', meal: 'Lunch', date: today, calories: 140, serving: '2 large eggs')));
    await pumpMeals(tester);

    await tester.ensureVisible(find.text('Lunch'));
    if (find.text('Eggs').evaluate().isEmpty) {
      await tester.tap(find.text('Lunch'));
      await settle(tester);
    }
    expect(find.text('2 large eggs'), findsOneWidget);

    await tester.drag(find.text('Eggs'), const Offset(-500, 0));
    await settle(tester);
    expect(provider.getEntriesForMeal(today, 'Lunch'), isEmpty);
    expect(find.text('Removed Eggs'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(provider.getEntriesForMeal(today, 'Lunch'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('works on another day and in light mode', (tester) async {
    dates.setDate(yesterday);
    await tester.runAsync(() => provider.addEntry(testEntry(name: 'Toast', meal: 'Snacks', date: yesterday)));
    await tester.pumpWidget(testApp(
      const Scaffold(body: SingleChildScrollView(child: MealSection())),
      foodEntryProvider: provider,
      dateProvider: dates,
      dark: false,
    ));
    await settle(tester);
    await tester.ensureVisible(menuFor('Snacks'));
    await tester.tap(menuFor('Snacks'));
    await settle(tester);
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
