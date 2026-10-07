import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/day_status_provider.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/day_status.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/estimate_rows.dart';
import 'package:macrotracker/services/energy/trend_weight.dart';
import 'package:macrotracker/services/energy_sync_service.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

void main() {
  // "Now" is Oct 7 2026; learning started on Sep 7.
  final now = DateTime(2026, 10, 7, 9);
  final start = DateTime(2026, 9, 7);
  DateTime day(int n) => DateTime(start.year, start.month, start.day + n);
  const daysToYesterday = 30; // Sep 7 .. Oct 6

  /// Thirty days of 2,200 cals and a steady loss of 0.05 kg a day.
  EstimatorInputs inputs({Map<DateTime, FoodDay>? food}) => EstimatorInputs(
        learningStartedOn: start,
        formulaTdee: 2500,
        body: const BodyProfile(sex: Sex.male, heightCm: 180, age: 30),
        food: food ??
            {for (var d = 0; d < daysToYesterday; d++) day(d): const FoodDay(loggedCals: 2200)},
        weights: [
          for (var d = 0; d < daysToYesterday; d++)
            WeightReading(day(d), 80 - 0.05 * d),
        ],
      );

  setUp(() async {
    await setUpTestEnvironment();
    await EnergySyncService().clearLocalState();
  });

  EnergyProvider provider() => EnergyProvider(
        clock: () => now,
        inBackground: false,
        debounce: Duration.zero,
      );

  test('replays from the learning start through yesterday and caches the rows', () async {
    final p = provider()..inputs = () => inputs();
    await p.refresh();
    expect(p.estimates, hasLength(daysToYesterday));
    expect(p.estimates.first.day, start);
    expect(p.latest!.day, DateTime(2026, 10, 6));
    // Thirty days of data: the estimate has started moving.
    expect(p.latest!.state, isNot(EnergyState.learning));
    expect(p.estimates.where((r) => r.updated), isNotEmpty);
    expect(p.lastError, isNull);
    // Signed out in tests, so every day waits to upload.
    expect(p.pendingUploads, daysToYesterday);

    // A fresh provider (app restart) reads the same rows from the cache.
    final again = provider();
    expect(again.estimates.map((r) => r.toCacheJson()),
        p.estimates.map((r) => r.toCacheJson()));
  });

  test('is idempotent: running the same days again changes nothing', () async {
    final p = provider()..inputs = () => inputs();
    await p.refresh();
    final first = jsonEncode([for (final r in p.estimates) r.toCacheJson()]);
    final cache = EnergySyncService().loadCache();

    await p.refresh();
    expect(jsonEncode([for (final r in p.estimates) r.toCacheJson()]), first);
    final fresh = EnergyEstimator(inputs()).replay(through: DateTime(2026, 10, 6));
    expect(rowsToUpload(fresh.estimates, cache), isEmpty);
  });

  test('food saved for a past day changes that day onwards, not before', () async {
    final p = provider()..inputs = () => inputs();
    await p.refresh();
    final before = {for (final r in p.estimates) r.day: r.tdee};

    final edited = {
      for (var d = 0; d < daysToYesterday; d++)
        day(d): FoodDay(loggedCals: d == 20 ? 3200 : 2200),
    };
    p.inputs = () => inputs(food: edited);
    await p.refresh();
    for (final r in p.estimates) {
      if (r.day.isBefore(day(20))) {
        expect(r.tdee, before[r.day], reason: '${r.day}');
      }
    }
    expect(p.estimates.firstWhere((r) => r.day == day(20)).avgIntake,
        isNot(2200));
  });

  test('learning starting today has no rows yet', () async {
    final p = provider()
      ..inputs = () => EstimatorInputs(
            learningStartedOn: DateTime(2026, 10, 7),
            formulaTdee: 2500,
            body: const BodyProfile(sex: Sex.female, heightCm: 165, age: 40),
          );
    await p.refresh();
    expect(p.estimates, isEmpty);
    expect(p.latest, isNull);
    expect(p.lastError, isNull);
  });

  test('nothing runs without inputs (signed out, food not read yet)', () async {
    final p = provider()..inputs = () => null;
    await p.refresh();
    expect(p.estimates, isEmpty);
    expect(p.lastRunAt, isNull);
  });

  group('wired to the app providers', () {
    late GoalsProvider goals;
    late FoodEntryProvider food;
    late DayStatusProvider status;

    setUp(() async {
      for (final key in ['nutrition_goals', 'goal_settings', 'weight_history', 'food_day_status']) {
        await StorageService().delete(key);
      }
      goals = GoalsProvider(userId: 'u1', clock: () => now);
      food = FoodEntryProvider();
      await food.ensureInitialized();
      for (final e in List.of(food.entries)) {
        await food.removeEntry(e.id);
      }
      status = DayStatusProvider(userId: 'u1');
      await StorageService().put(
          'weight_history',
          jsonEncode([
            for (var d = 0; d < daysToYesterday; d++)
              {'date': day(d).add(const Duration(hours: 7)).toIso8601String(), 'weight': 80 - 0.05 * d},
          ]));
    });

    test('no inputs until the food log is read', () {
      expect(
          EnergyProvider.inputsFrom(
              goals: goals,
              food: food,
              dayStatus: status,
              weights: EnergyProvider.storedWeights(),
              today: now),
          isNull);
    });

    test('an account without a learning start starts at its first data day', () async {
      await food.loadEntriesForCurrentUser();
      final i = EnergyProvider.inputsFrom(
          goals: goals,
          food: food,
          dayStatus: status,
          weights: EnergyProvider.storedWeights(),
          today: now)!;
      expect(i.learningStartedOn, start);
      expect(goals.learningStartedOn, start);
      expect(i.weights, hasLength(daysToYesterday));
    });

    test('food for a past day and day status refresh; food for today does not', () async {
      await food.loadEntriesForCurrentUser();
      goals.startLearning(start);
      final p = provider()..attach(goals: goals, food: food, dayStatus: status);

      await food.addEntry(testEntry(name: 'Toast', meal: 'Lunch', date: now, calories: 300));
      await pumpEventQueue();
      expect(p.lastRunAt, isNull, reason: 'today does not refresh');

      await food.addEntry(testEntry(name: 'Soup', meal: 'Dinner', date: day(29), calories: 500));
      await pumpEventQueue();
      expect(p.lastRunAt, isNotNull);
      expect(p.latest!.day, day(29));
      final afterFood = p.lastInputs;

      await status.setStatus(day(28), ExplicitDayStatus.fasting);
      await pumpEventQueue();
      expect(identical(p.lastInputs, afterFood), isFalse, reason: 'ran again');
      expect(p.lastInputs!.food[day(28)]!.explicit, ExplicitDayStatus.fasting);
    });
  });
}
