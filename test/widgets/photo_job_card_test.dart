import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/AI/gemini.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/dashboard/components/meal_section.dart';
import 'package:macrotracker/screens/dashboard/components/photo_job_card.dart';
import 'package:macrotracker/services/photo_analysis_service.dart';
import 'package:provider/provider.dart';

import '../helpers/test_app.dart';

AIFoodItem food(String name) => AIFoodItem(
      name: name,
      servingSizes: ['1 serving'],
      calories: [200],
      protein: [10],
      carbohydrates: [20],
      fat: [8],
      fiber: [2],
    );

// A 1x1 transparent PNG.
final photo = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

void main() {
  late List<Completer<List<AIFoodItem>>> calls;
  late PhotoAnalysisService service;
  final today = DateTime.now();

  setUp(() async {
    await setUpTestEnvironment();
    calls = [];
    service = PhotoAnalysisService(analyzer: (_) {
      final call = Completer<List<AIFoodItem>>();
      calls.add(call);
      return call.future;
    });
  });

  Future<void> pumpCards(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      Scaffold(
        body: Consumer<PhotoAnalysisService>(
          builder: (_, s, __) => Column(
            children: [for (final job in s.jobs) PhotoJobCard(key: ValueKey(job.id), job: job)],
          ),
        ),
      ),
      photoAnalysisService: service,
    ));
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester, {List<AIFoodItem>? foods, Object? error}) async {
    final call = calls.last;
    if (error != null) {
      call.completeError(error);
    } else {
      call.complete(foods);
    }
    await tester.pump();
    await tester.pump();
  }

  testWidgets('shows progress while the photo is analysed', (tester) async {
    await pumpCards(tester);
    service.start(Uint8List.fromList(photo), meal: 'Lunch', date: today);
    await tester.pump();

    expect(find.text('Analyzing your meal…'), findsOneWidget);
    expect(find.text('You can keep using the app'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Review'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ready with several foods offers Review', (tester) async {
    await pumpCards(tester);
    service.start(Uint8List.fromList(photo), meal: 'Lunch', date: today);
    await finish(tester, foods: [food('Rice'), food('Dal'), food('Naan')]);

    expect(find.text('Your meal is ready'), findsOneWidget);
    expect(find.text('3 foods found · review before logging'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Review'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('ready with one food names it', (tester) async {
    await pumpCards(tester);
    service.start(Uint8List.fromList(photo), meal: 'Lunch', date: today);
    await finish(tester, foods: [food('Caesar salad')]);
    expect(find.text('Caesar salad'), findsOneWidget);
  });

  testWidgets('a failure can be retried, and the retry can succeed', (tester) async {
    await pumpCards(tester);
    service.start(Uint8List.fromList(photo), meal: 'Lunch', date: today);
    await finish(tester,
        error: PhotoAnalysisException(PhotoAnalysisFailure.noConnection));

    expect(find.text('No connection. Check your internet and try again'), findsOneWidget);
    expect(find.text('Your photo is kept, so you can retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(calls, hasLength(2));
    expect(find.text('Analyzing your meal…'), findsOneWidget);

    await finish(tester, foods: [food('Soup')]);
    expect(find.text('Your meal is ready'), findsOneWidget);
  });

  testWidgets('no food found suggests retaking the photo', (tester) async {
    await pumpCards(tester);
    service.start(Uint8List.fromList(photo), meal: 'Lunch', date: today);
    await finish(tester, error: PhotoAnalysisException(PhotoAnalysisFailure.noFood));

    expect(find.text("Couldn't find food in this photo"), findsOneWidget);
    expect(find.text('Try a clearer photo of the plate'), findsOneWidget);
    expect(find.text('Retake'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('a failed job can be dismissed', (tester) async {
    await pumpCards(tester);
    service.start(Uint8List.fromList(photo), meal: 'Lunch', date: today);
    await finish(tester, error: StateError('server down'));
    expect(find.byType(PhotoJobCard), findsOneWidget);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(service.jobs, isEmpty);
    expect(find.byType(PhotoJobCard), findsNothing);
  });

  testWidgets('the card shows inside the meal it was taken for', (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final provider = FoodEntryProvider();
    await tester.runAsync(provider.ensureInitialized);
    await tester.pumpWidget(testApp(
      const Scaffold(body: SingleChildScrollView(child: MealSection())),
      foodEntryProvider: provider,
      dateProvider: DateProvider(),
      photoAnalysisService: service,
    ));
    await tester.pump();

    service.start(Uint8List.fromList(photo), meal: 'Dinner', date: today);
    await pumpFrames(tester, seconds: 1);

    final card = find.byType(PhotoJobCard);
    expect(card, findsOneWidget);
    // It sits below the Dinner header, after Lunch.
    expect(tester.getTopLeft(card).dy,
        greaterThan(tester.getTopLeft(find.text('Dinner')).dy));
    expect(tester.getTopLeft(find.text('Lunch')).dy,
        lessThan(tester.getTopLeft(find.text('Dinner')).dy));
  });
}
