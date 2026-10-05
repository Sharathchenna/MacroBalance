import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:macrotracker/utils/quick_log.dart';
import 'package:macrotracker/widgets/quick_log_tile.dart';

import '../helpers/test_app.dart';

void main() {
  late FoodEntryProvider provider;
  late DateProvider dates;
  final today = DateTime.now();
  final yesterday = DateTime(today.year, today.month, today.day - 1);
  final threeDaysAgo = DateTime(today.year, today.month, today.day - 3);

  setUp(() async {
    await setUpTestEnvironment();
    provider = FoodEntryProvider();
    await provider.ensureInitialized();
    for (final e in List.of(provider.entries)) {
      await provider.removeEntry(e.id);
    }
    dates = DateProvider();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('quickLogAgain', () {
    final template = testEntry(
        name: 'Oatmeal', meal: 'Breakfast', date: yesterday, calories: 150,
        quantity: 1.5, serving: '1 cup');

    Future<void> pumpButton(WidgetTester tester, {String? meal}) async {
      phone(tester);
      await tester.pumpWidget(testApp(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => quickLogAgain(context, template, meal: meal),
                child: const Text('Log again'),
              ),
            ),
          ),
        ),
        foodEntryProvider: provider,
        dateProvider: dates,
      ));
    }

    Future<void> tapLogAgain(WidgetTester tester) async {
      await tester.runAsync(() async {
        await tester.tap(find.text('Log again'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();
    }

    testWidgets('logs the same amount to the chosen meal on the selected day',
        (tester) async {
      dates.setDate(threeDaysAgo);
      await pumpButton(tester, meal: 'Dinner');
      await tapLogAgain(tester);

      final logged = provider.getEntriesForMeal(threeDaysAgo, 'Dinner');
      expect(logged, hasLength(1));
      final entry = logged.single;
      expect(entry.food.name, 'Oatmeal');
      expect(entry.quantity, 1.5);
      expect(entry.unit, template.unit);
      expect(entry.servingDescription, template.servingDescription);
      expect(entry.id, isNot(template.id));
      expect(provider.getAllEntriesForDate(today), isEmpty);
      expect(FoodEntryProvider.nutrientForEntry(entry, 'calories'), 225);
    });

    testWidgets('confirms with a snackbar whose Undo removes the entry',
        (tester) async {
      await pumpButton(tester, meal: 'Lunch');
      await tapLogAgain(tester);

      expect(find.text('Added Oatmeal to Lunch'), findsOneWidget);
      expect(provider.getEntriesForMeal(today, 'Lunch'), hasLength(1));

      await tester.tap(find.text('Undo'));
      await settle(tester);
      expect(provider.getEntriesForMeal(today, 'Lunch'), isEmpty);
    });

    testWidgets('without a meal, uses the suggested one for now', (tester) async {
      await pumpButton(tester);
      await tapLogAgain(tester);
      final entry = provider.getAllEntriesForDate(today).single;
      expect(['Breakfast', 'Lunch', 'Dinner', 'Snacks'], contains(entry.meal));
      expect(find.text('Added Oatmeal to ${entry.meal}'), findsOneWidget);
    });
  });

  group('QuickLogTile', () {
    testWidgets('+ logs, tapping the row opens', (tester) async {
      phone(tester);
      var added = 0, opened = 0;
      await tester.pumpWidget(testApp(Scaffold(
        body: QuickLogTile(
          title: 'Banana',
          subtitle: '1 medium',
          trailingLabel: '105 kcal',
          addTooltip: 'Add to Snacks',
          onAdd: () => added++,
          onOpen: () => opened++,
        ),
      )));
      expect(find.text('Banana'), findsOneWidget);
      expect(find.text('1 medium'), findsOneWidget);
      expect(find.text('105 kcal'), findsOneWidget);

      await tester.tap(find.byTooltip('Add to Snacks'));
      expect((added, opened), (1, 0));
      await tester.tap(find.text('Banana'));
      expect((added, opened), (1, 1));
    });
  });

  group('search recents', () {
    testWidgets('Recent lists foods newest first and + adds to the open meal',
        (tester) async {
      phone(tester);
      await tester.runAsync(() async {
        await provider.addEntry(testEntry(
            name: 'Toast', meal: 'Breakfast', date: threeDaysAgo, calories: 75));
        await provider.addEntry(testEntry(
            name: 'Apple', meal: 'Snacks', date: yesterday, calories: 95));
      });
      await tester.pumpWidget(testApp(
        const FoodSearchPage(selectedMeal: 'Lunch'),
        foodEntryProvider: provider,
        dateProvider: dates,
      ));
      await pumpFrames(tester, seconds: 1);

      expect(find.text('Tap + to add to Lunch'), findsOneWidget);
      final tiles = find.byType(QuickLogTile);
      expect(tiles, findsNWidgets(2));
      expect(tester.widget<QuickLogTile>(tiles.first).title, 'Apple');
      expect(tester.widget<QuickLogTile>(tiles.last).title, 'Toast');

      await tester.runAsync(() async {
        await tester.tap(find.byTooltip('Add to Lunch').last);
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await pumpFrames(tester, seconds: 1);

      final List<FoodEntry> lunch = provider.getEntriesForMeal(today, 'Lunch');
      expect(lunch.map((e) => e.food.name), ['Toast']);
      expect(find.text('Added Toast to Lunch'), findsOneWidget);
    });
  });
}
