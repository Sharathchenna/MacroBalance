import 'dart:async';
import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/screens/dashboard/components/dashboard_dock.dart';
import 'package:macrotracker/screens/dashboard_screen.dart';
import 'package:macrotracker/screens/foodDetail.dart';
import 'package:macrotracker/services/photo_analysis_service.dart';
import 'package:macrotracker/utils/food_clipboard.dart';

import '../helpers/test_app.dart';

// A 1x1 transparent PNG.
final photo = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

void main() {
  late FoodEntryProvider provider;
  late DateProvider dates;
  late PhotoAnalysisService service;
  late List<Completer<List<AIFoodItem>>> calls;
  final today = DateTime.now();
  final yesterday = DateTime(today.year, today.month, today.day - 1);

  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete(FoodEntryProvider.historyKey);
    provider = FoodEntryProvider();
    await provider.ensureInitialized();
    for (final e in List.of(provider.entries)) {
      await provider.removeEntry(e.id);
    }
    dates = DateProvider();
    calls = [];
    service = PhotoAnalysisService(analyzer: (_, {note}) {
      final call = Completer<List<AIFoodItem>>();
      calls.add(call);
      return call.future;
    });
    FoodClipboard.instance.clear();
  });

  Future<void> pumpDashboard(WidgetTester tester, {double height = 2556}) async {
    tester.view.physicalSize = Size(1179, height);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const Dashboard(),
      foodEntryProvider: provider,
      dateProvider: dates,
      photoAnalysisService: service,
    ));
    await pumpFrames(tester, seconds: 1);
  }

  Finder pill(String text) =>
      find.descendant(of: find.byType(PhotoJobPill), matching: find.text(text));

  testWidgets('a photo shows only as the pill, never inside its meal', (tester) async {
    await pumpDashboard(tester);
    service.start(photo, meal: 'Breakfast', date: today);
    await pumpFrames(tester, seconds: 1);
    expect(pill('Analyzing your breakfast…'), findsOneWidget);
    expect(find.textContaining('Analyzing'), findsOneWidget);

    calls.single.complete([
      AIFoodItem(
          name: 'Oats',
          servingSizes: ['1 bowl'],
          calories: [300],
          protein: [10],
          carbohydrates: [50],
          fat: [6],
          fiber: [8]),
    ]);
    await pumpFrames(tester, seconds: 1);
    expect(pill('Your breakfast is ready · Review'), findsOneWidget);
    expect(find.text('Oats'), findsNothing);
    expect(find.textContaining('ready'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('copied foods paste into the chosen meal of the day shown',
      (tester) async {
    final coffee = testEntry(name: 'Coffee', meal: 'Snacks', date: yesterday, calories: 40);
    await tester.runAsync(() => provider.addEntry(coffee));
    FoodClipboard.instance.copy([coffee]);
    await pumpDashboard(tester);

    expect(find.text('Paste Coffee'), findsOneWidget);
    expect(find.text('Tap the meal to add it to, today'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.descendant(
          of: find.byType(PasteBar), matching: find.text('Dinner')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await pumpFrames(tester, seconds: 1);

    final dinner = provider.getEntriesForMeal(today, 'Dinner');
    expect(dinner.map((e) => e.food.name), ['Coffee']);
    expect(dinner.single.id, isNot(coffee.id));
    expect(dinner.single.quantity, coffee.quantity);
    expect(FoodClipboard.instance.isEmpty, isTrue);
    expect(find.text('Paste Coffee'), findsNothing);
    expect(find.text('Pasted Coffee into Dinner'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(provider.getEntriesForMeal(today, 'Dinner'), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pasting works within the same day, and names another day',
      (tester) async {
    final eggs = testEntry(name: 'Eggs', meal: 'Breakfast', date: yesterday);
    await tester.runAsync(() => provider.addEntry(eggs));
    dates.setDate(yesterday);
    FoodClipboard.instance.copy([eggs]);
    await pumpDashboard(tester);
    expect(find.textContaining('Tap the meal to add it to, on '), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.descendant(
          of: find.byType(PasteBar), matching: find.text('Lunch')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await pumpFrames(tester, seconds: 1);
    expect(provider.getEntriesForMeal(yesterday, 'Lunch').map((e) => e.food.name), ['Eggs']);
    expect(provider.getEntriesForMeal(yesterday, 'Breakfast'), hasLength(1));
  });

  testWidgets('while dragging a food, a Copy zone appears; dropping there copies',
      (tester) async {
    final tea = testEntry(name: 'Tea', meal: 'Breakfast', date: today);
    await tester.runAsync(() => provider.addEntry(tea));
    await pumpDashboard(tester);
    expect(find.text('Drop here to copy'), findsNothing);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Tea')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(find.text('Drop here to copy'), findsOneWidget);
    expect(find.text('Or drop on a meal to move it there'), findsOneWidget);

    // Over a meal: it says the food will move there.
    await gesture.moveTo(tester.getCenter(find.text('Lunch')));
    await tester.pump();
    expect(find.text('Drop to move here'), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.byType(CopyDropZone)));
    await tester.pump();
    expect(find.text('Let go to copy'), findsOneWidget);
    await gesture.up();
    await pumpFrames(tester, seconds: 1);

    expect(FoodClipboard.instance.value.single.id, tea.id);
    expect(provider.getEntriesForMeal(today, 'Breakfast'), hasLength(1));
    expect(find.text('Drop here to copy'), findsNothing);
    expect(find.text('Paste Tea'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging a food near the bottom scrolls the page', (tester) async {
    await tester.runAsync(() async {
      for (var i = 0; i < 6; i++) {
        await provider.addEntry(testEntry(name: 'Item $i', meal: 'Breakfast', date: today));
      }
    });
    await pumpDashboard(tester, height: 2000);
    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first).position;
    expect(scroll.pixels, 0);

    final gesture = await tester.startGesture(tester.getCenter(find.text('Item 0')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 20));
    await gesture.moveTo(Offset(200, tester.view.physicalSize.height / 3 - 120));
    await pumpFrames(tester, seconds: 1);
    expect(scroll.pixels, greaterThan(100));
    await gesture.cancel();
    await pumpFrames(tester, seconds: 1);
    expect(FoodDrag.active.value, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('if the food goes away mid-drag, the Copy zone does too', (tester) async {
    final tea = testEntry(name: 'Tea', meal: 'Breakfast', date: today);
    await tester.runAsync(() => provider.addEntry(tea));
    await pumpDashboard(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Tea')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(find.text('Drop here to copy'), findsOneWidget);

    dates.setDate(yesterday); // Today's tiles are replaced.
    await pumpFrames(tester, seconds: 1);
    expect(FoodDrag.active.value, isNull);
    expect(find.text('Drop here to copy'), findsNothing);
    await gesture.up();
    await pumpFrames(tester, seconds: 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a logged food\'s page has a Copy button', (tester) async {
    final tea = testEntry(name: 'Tea', meal: 'Breakfast', date: today);
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => FoodDetailPage(food: tea.food, existingEntry: tea))),
            child: const Text('Open'),
          ),
        ),
      ),
      foodEntryProvider: provider,
      dateProvider: dates,
    ));
    await tester.tap(find.text('Open'));
    await pumpFrames(tester, seconds: 1);
    await tester.tap(find.byTooltip('Copy to another meal or day'));
    await pumpFrames(tester, seconds: 1);
    expect(FoodClipboard.instance.value.single.id, tea.id);
    expect(find.byType(FoodDetailPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the paste bar can be dismissed', (tester) async {
    FoodClipboard.instance
        .copy([testEntry(name: 'Tea', meal: 'Breakfast', date: today)]);
    await pumpDashboard(tester);
    expect(find.byType(FilledButton), findsNWidgets(4));
    await tester.tap(find.byTooltip('Cancel paste'));
    await pumpFrames(tester, seconds: 1);
    expect(find.textContaining('Paste Tea'), findsNothing);
    expect(provider.getAllEntriesForDate(today), isEmpty);
  });
}
