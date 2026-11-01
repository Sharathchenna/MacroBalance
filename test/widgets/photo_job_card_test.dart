import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/AI/gemini.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/screens/dashboard/components/dashboard_dock.dart';
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
    service = PhotoAnalysisService(analyzer: (_, {note}) {
      final call = Completer<List<AIFoodItem>>();
      calls.add(call);
      return call.future;
    });
  });

  Future<void> pumpPill(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(
      const Scaffold(body: Center(child: PhotoJobPill())),
      photoAnalysisService: service,
    ));
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> finish(WidgetTester tester, {List<AIFoodItem>? foods, Object? error}) async {
    final call = calls.last;
    if (error != null) {
      call.completeError(error);
    } else {
      call.complete(foods);
    }
    await settle(tester);
  }

  testWidgets('nothing shows with no photo', (tester) async {
    await pumpPill(tester);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('shows progress while the photo is analysed, and does nothing on tap',
      (tester) async {
    await pumpPill(tester);
    service.start(Uint8List.fromList(photo), meal: 'Lunch', date: today);
    await settle(tester);

    expect(find.text('Analyzing your lunch…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Analyzing your lunch…'));
    await settle(tester);
    expect(service.jobs, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('counts several photos being analysed', (tester) async {
    await pumpPill(tester);
    service
      ..start(Uint8List.fromList(photo), meal: 'Lunch', date: today)
      ..start(Uint8List.fromList(photo), meal: 'Dinner', date: today);
    await settle(tester);
    expect(find.text('Analyzing 2 photos…'), findsOneWidget);
  });

  testWidgets('once ready it stays until tapped', (tester) async {
    await pumpPill(tester);
    service.start(Uint8List.fromList(photo), meal: 'Lunch', date: today);
    await finish(tester, foods: [food('Rice'), food('Dal')]);

    expect(find.text('Your lunch is ready · Review'), findsOneWidget);
    await tester.pump(const Duration(minutes: 5));
    expect(find.text('Your lunch is ready · Review'), findsOneWidget);
    expect(find.byTooltip('Dismiss'), findsNothing);
  });

  testWidgets('a failure retries from the pill, and the retry can succeed', (tester) async {
    await pumpPill(tester);
    service.start(Uint8List.fromList(photo), meal: 'Lunch', date: today);
    await finish(tester, error: PhotoAnalysisException(PhotoAnalysisFailure.noConnection));

    expect(find.text("Couldn't analyze your lunch · Retry"), findsOneWidget);
    await tester.tap(find.text("Couldn't analyze your lunch · Retry"));
    await settle(tester);
    expect(calls, hasLength(2));
    expect(find.text('Analyzing your lunch…'), findsOneWidget);

    await finish(tester, foods: [food('Soup')]);
    expect(find.text('Your lunch is ready · Review'), findsOneWidget);
  });

  testWidgets('no food found offers a retake', (tester) async {
    await pumpPill(tester);
    service.start(Uint8List.fromList(photo), meal: 'Lunch', date: today);
    await finish(tester, error: PhotoAnalysisException(PhotoAnalysisFailure.noFood));
    expect(find.text('No food found · Retake'), findsOneWidget);
  });

  testWidgets('a failed photo can be dismissed', (tester) async {
    await pumpPill(tester);
    service.start(Uint8List.fromList(photo), meal: 'Lunch', date: today);
    await finish(tester, error: StateError('server down'));

    await tester.tap(find.byTooltip('Dismiss'));
    await settle(tester);
    expect(service.jobs, isEmpty);
    expect(find.textContaining("Couldn't analyze"), findsNothing);
  });
}
