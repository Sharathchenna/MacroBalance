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

  /// Expands [meal] if it isn't already.
  Future<void> openMeal(WidgetTester tester, String meal) async {
    // Collapsed meals still build their (hidden) content, so look for the
    // add button on screen, not just in the tree.
    await tester.ensureVisible(find.text(meal));
    await settle(tester);
    final addButton = find.text('Add Food to $meal');
    if (tester.getSize(addButton).width == 0) {
      await tester.tap(find.text(meal));
      await settle(tester);
    }
    await tester.ensureVisible(addButton);
    await settle(tester);
  }

  Finder repeatCard() => find.text('Same as yesterday?').hitTestable();

  testWidgets('meal headers have no options menu', (tester) async {
    await pumpMeals(tester);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty meals with nothing yesterday just say so', (tester) async {
    await pumpMeals(tester);
    for (final meal in ['Breakfast', 'Lunch', 'Snacks', 'Dinner']) {
      await openMeal(tester, meal);
      expect(repeatCard(), findsNothing, reason: meal);
    }
    expect(find.text('No entries yet'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty meal offers yesterday\'s food; Repeat adds it, Undo removes it',
      (tester) async {
    await tester.runAsync(() => provider.addEntry(
        testEntry(name: 'Toast', meal: 'Dinner', date: yesterday, calories: 75)));
    await tester.runAsync(() => provider.addEntry(
        testEntry(name: 'Soup', meal: 'Dinner', date: yesterday, calories: 150)));
    await pumpMeals(tester);
    await openMeal(tester, 'Dinner');

    expect(repeatCard(), findsOneWidget);
    expect(find.text('Toast and Soup · 225 kcal'), findsOneWidget);

    await tester.tap(find.text('Repeat'));
    await settle(tester);
    expect(provider.getEntriesForMeal(today, 'Dinner'), hasLength(2));
    expect(find.text('Copied 2 items to Dinner'), findsOneWidget);
    // Once the meal has food the suggestion goes away.
    expect(repeatCard(), findsNothing);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(provider.getEntriesForMeal(today, 'Dinner'), isEmpty);
    expect(repeatCard(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long lists are summarised', (tester) async {
    for (final name in ['Oats', 'Milk', 'Banana', 'Honey']) {
      await tester.runAsync(() => provider.addEntry(
          testEntry(name: name, meal: 'Breakfast', date: yesterday, calories: 50)));
    }
    await pumpMeals(tester);
    await openMeal(tester, 'Breakfast');
    expect(find.text('Oats, Milk and 2 more · 200 kcal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no suggestion once a meal has food', (tester) async {
    await tester.runAsync(() => provider.addEntry(
        testEntry(name: 'Rice', meal: 'Lunch', date: yesterday)));
    await tester.runAsync(() => provider.addEntry(
        testEntry(name: 'Salad', meal: 'Lunch', date: today)));
    await pumpMeals(tester);
    await openMeal(tester, 'Lunch');
    expect(repeatCard(), findsNothing);
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
    final twoDaysAgo = today.subtract(const Duration(days: 2));
    dates.setDate(yesterday);
    await tester.runAsync(() => provider.addEntry(
        testEntry(name: 'Toast', meal: 'Snacks', date: twoDaysAgo)));
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const Scaffold(body: SingleChildScrollView(child: MealSection())),
      foodEntryProvider: provider,
      dateProvider: dates,
      dark: false,
    ));
    await settle(tester);
    await openMeal(tester, 'Snacks');
    // "Yesterday" is relative to the day being viewed.
    expect(repeatCard(), findsOneWidget);
    await tester.tap(find.text('Repeat'));
    await settle(tester);
    expect(provider.getEntriesForMeal(yesterday, 'Snacks'), hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated foods are grouped', (tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => provider.addEntry(testEntry(
          name: 'Toast', meal: 'Dinner', date: yesterday, calories: 75, quantity: 1 + i * 0.001)));
    }
    await pumpMeals(tester);
    await openMeal(tester, 'Dinner');
    expect(find.text('Toast ×3 · 225 kcal'), findsOneWidget);
  });
}
