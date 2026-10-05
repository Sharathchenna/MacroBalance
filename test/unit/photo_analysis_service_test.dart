import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/AI/gemini.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/services/photo_analysis_service.dart';

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

void main() {
  final photo = Uint8List.fromList([1, 2, 3]);
  final lunchDay = DateTime(2026, 5, 10, 13, 45);

  late List<Completer<List<AIFoodItem>>> calls;
  late List<PhotoJob> announced;
  late PhotoAnalysisService service;

  setUp(() async {
    await setUpTestEnvironment();
    calls = [];
    announced = [];
    service = PhotoAnalysisService(
      onReady: announced.add,
      analyzer: (bytes) {
        expect(bytes, photo);
        final call = Completer<List<AIFoodItem>>();
        calls.add(call);
        return call.future;
      },
    );
  });

  tearDown(() => service.dispose());

  test('a new job is analyzing, for its meal and day (at midnight)', () {
    var notified = 0;
    service.addListener(() => notified++);
    service.start(photo, meal: 'Lunch', date: lunchDay);

    final job = service.jobs.single;
    expect(job.status, PhotoJobStatus.analyzing);
    expect(job.meal, 'Lunch');
    expect(job.date, DateTime(2026, 5, 10));
    expect(notified, 1);
    expect(calls, hasLength(1));
  });

  test('jobs are looked up by meal and day', () {
    service
      ..start(photo, meal: 'Lunch', date: lunchDay)
      ..start(photo, meal: 'Dinner', date: lunchDay)
      ..start(photo, meal: 'Lunch', date: lunchDay.add(const Duration(days: 1)));

    expect(service.jobsFor(DateTime(2026, 5, 10, 8), 'Lunch'), hasLength(1));
    expect(service.jobsFor(lunchDay, 'Dinner'), hasLength(1));
    expect(service.jobsFor(lunchDay, 'Breakfast'), isEmpty);
    expect(service.jobsFor(DateTime(2026, 5, 11), 'Lunch'), hasLength(1));
  });

  test('success makes the job ready with its foods and announces it', () async {
    service.start(photo, meal: 'Lunch', date: lunchDay);
    calls.single.complete([food('Rice'), food('Curry')]);
    await pumpEventQueue();

    final job = service.jobs.single;
    expect(job.status, PhotoJobStatus.ready);
    expect(job.foods.map((f) => f.name), ['Rice', 'Curry']);
    expect(job.error, isNull);
    expect(announced, [job]);
  });

  test('a photo with no food fails with that reason', () async {
    service.start(photo, meal: 'Lunch', date: lunchDay);
    calls.single.completeError(PhotoAnalysisException(PhotoAnalysisFailure.noFood));
    await pumpEventQueue();

    final job = service.jobs.single;
    expect(job.status, PhotoJobStatus.failed);
    expect(job.error!.kind, PhotoAnalysisFailure.noFood);
    expect(announced, [job]);
  });

  test('an unexpected error counts as a server failure', () async {
    service.start(photo, meal: 'Lunch', date: lunchDay);
    calls.single.completeError(StateError('boom'));
    await pumpEventQueue();

    final job = service.jobs.single;
    expect(job.status, PhotoJobStatus.failed);
    expect(job.error!.kind, PhotoAnalysisFailure.server);
  });

  test('retry analyses the same photo again and can then succeed', () async {
    service.start(photo, meal: 'Lunch', date: lunchDay);
    calls.single.completeError(PhotoAnalysisException(PhotoAnalysisFailure.noConnection));
    await pumpEventQueue();
    final job = service.jobs.single;

    service.retry(job);
    expect(job.status, PhotoJobStatus.analyzing);
    expect(job.error, isNull);
    expect(calls, hasLength(2));

    calls.last.complete([food('Salad')]);
    await pumpEventQueue();
    expect(job.status, PhotoJobStatus.ready);
    expect(job.foods.single.name, 'Salad');
  });

  test('dismiss removes the job; finishing later announces nothing', () async {
    service.start(photo, meal: 'Lunch', date: lunchDay);
    final job = service.jobs.single;
    service.dismiss(job);
    expect(service.jobs, isEmpty);

    var notified = 0;
    service.addListener(() => notified++);
    calls.single.complete([food('Rice')]);
    await pumpEventQueue();
    expect(service.jobs, isEmpty);
    expect(announced, isEmpty);
    expect(notified, 0);
  });
}
