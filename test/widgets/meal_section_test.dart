import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/dashboard/components/meal_section.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/utils/meal_routine.dart';
import 'package:macrotracker/utils/meal_time.dart';

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
    for (final meal in MealTime.meals) {
      for (final key in RoutineDismissals.keysFor(meal)) {
        await StorageService().delete(key);
      }
    }
  });

  DateTime daysAgo(int n) => DateTime(today.year, today.month, today.day - n);

  /// Logs [foods] as [meal] on each of the [days] days before today.
  Future<void> addRoutine(WidgetTester tester, String meal, List<String> foods,
      {int days = 3, double calories = 75}) async {
    for (var d = 1; d <= days; d++) {
      for (var i = 0; i < foods.length; i++) {
        await tester.runAsync(() => provider.addEntry(testEntry(
            name: foods[i], meal: meal, date: daysAgo(d), calories: calories,
            quantity: 1 + i * 0.001)));
      }
    }
  }

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

  /// Scrolls [meal]'s card into view. Meals with food start open and empty
  /// ones show their suggestion inline, so there's nothing to expand.
  Future<void> openMeal(WidgetTester tester, String meal) async {
    await tester.ensureVisible(find.text(meal));
    await settle(tester);
  }

  Finder usualCard(String meal) =>
      find.text('Your usual ${meal.toLowerCase()}').hitTestable();

  testWidgets('meal headers have no options menu', (tester) async {
    await pumpMeals(tester);
    expect(find.byIcon(Icons.more_horiz), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty meals are one quiet row with no add button',
      (tester) async {
    // Eaten only once: not a routine.
    await tester.runAsync(() => provider.addEntry(
        testEntry(name: 'Toast', meal: 'Lunch', date: yesterday)));
    await pumpMeals(tester);
    for (final meal in MealTime.meals) {
      await openMeal(tester, meal);
      expect(usualCard(meal), findsNothing, reason: meal);
    }
    expect(find.text('Nothing logged yet'), findsNWidgets(MealTime.meals.length));
    expect(find.textContaining('Add Food to'), findsNothing);
    expect(find.text('0 items'), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('meals with food have no add button', (tester) async {
    await tester.runAsync(() => provider.addEntry(
        testEntry(name: 'Salad', meal: 'Lunch', date: today)));
    await pumpMeals(tester);
    await openMeal(tester, 'Lunch');
    expect(find.text('Salad'), findsOneWidget);
    expect(find.text('1 item'), findsOneWidget);
    expect(find.textContaining('Add Food to'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a routine meal offers the usual; Add adds it, Undo removes it',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await addRoutine(tester, 'Dinner', ['Toast', 'Soup']);
    await pumpMeals(tester);
    await openMeal(tester, 'Dinner');

    expect(usualCard('Dinner'), findsOneWidget);
    expect(find.text('Toast and Soup · 150 cals'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Add your usual dinner: Toast and Soup')),
        findsOneWidget);
    expect(find.bySemanticsLabel('Not today, hide your usual dinner'), findsOneWidget);

    await tester.tap(find.text('Add').hitTestable());
    await settle(tester);
    expect(provider.getEntriesForMeal(today, 'Dinner'), hasLength(2));
    expect(find.text('Added your usual dinner'), findsOneWidget);
    // Once the meal has food the suggestion goes away.
    expect(usualCard('Dinner'), findsNothing);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(provider.getEntriesForMeal(today, 'Dinner'), isEmpty);
    expect(usualCard('Dinner'), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('only the routine meal gets a suggestion', (tester) async {
    await addRoutine(tester, 'Lunch', ['Rice', 'Dal']);
    await tester.runAsync(() => provider.addEntry(
        testEntry(name: 'Pizza', meal: 'Dinner', date: daysAgo(1))));
    await tester.runAsync(() => provider.addEntry(
        testEntry(name: 'Burger', meal: 'Dinner', date: daysAgo(2))));
    await tester.runAsync(() => provider.addEntry(
        testEntry(name: 'Pasta', meal: 'Dinner', date: daysAgo(3))));
    await pumpMeals(tester);
    await openMeal(tester, 'Lunch');
    expect(usualCard('Lunch'), findsOneWidget);
    await openMeal(tester, 'Dinner');
    expect(usualCard('Dinner'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('any empty routine meal shows its usual without opening',
      (tester) async {
    // A meal that isn't the one for this time of day.
    final meal = MealTime.meals.firstWhere((m) => m != MealTime.forTime(DateTime.now()));
    await addRoutine(tester, meal, ['Apple']);
    await pumpMeals(tester);
    await openMeal(tester, meal);
    expect(usualCard(meal), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Not today" hides the suggestion', (tester) async {
    await addRoutine(tester, 'Snacks', ['Almonds']);
    await pumpMeals(tester);
    await openMeal(tester, 'Snacks');
    expect(usualCard('Snacks'), findsOneWidget);

    await tester.tap(find.text('Not today').hitTestable());
    await settle(tester);
    expect(usualCard('Snacks'), findsNothing);
    expect(find.text('Nothing logged yet').hitTestable(), findsWidgets);
    expect(provider.getEntriesForMeal(today, 'Snacks'), isEmpty);
    expect(RoutineDismissals().isHidden('Snacks', today), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long lists are summarised', (tester) async {
    await addRoutine(tester, 'Breakfast', ['Oats', 'Milk', 'Banana', 'Honey'], calories: 50);
    await pumpMeals(tester);
    await openMeal(tester, 'Breakfast');
    expect(find.text('Oats, Milk and 2 more · 200 cals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no suggestion once a meal has food', (tester) async {
    await addRoutine(tester, 'Lunch', ['Rice']);
    await tester.runAsync(() => provider.addEntry(
        testEntry(name: 'Salad', meal: 'Lunch', date: today)));
    await pumpMeals(tester);
    await openMeal(tester, 'Lunch');
    expect(usualCard('Lunch'), findsNothing);
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

  testWidgets('no suggestions on a past day, in light mode too', (tester) async {
    // A routine as seen from yesterday as well as from today.
    await addRoutine(tester, 'Snacks', ['Toast'], days: 4);
    dates.setDate(yesterday);
    await tester.runAsync(() => provider.removeEntry(
        provider.getEntriesForMeal(yesterday, 'Snacks').single.id));
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
    expect(usualCard('Snacks'), findsNothing);
    expect(find.text('Nothing logged yet').hitTestable(), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('repeated foods are grouped', (tester) async {
    for (var d = 1; d <= 3; d++) {
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => provider.addEntry(testEntry(
            name: 'Toast', meal: 'Dinner', date: daysAgo(d), calories: 75,
            quantity: 1 + i * 0.001)));
      }
    }
    await pumpMeals(tester);
    await openMeal(tester, 'Dinner');
    expect(find.text('Toast ×3 · 225 cals'), findsOneWidget);
  });
}
