import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/models/food.dart';
import 'package:macrotracker/models/saved_food.dart';
import 'package:macrotracker/providers/saved_food_provider.dart';
import 'package:macrotracker/services/saved_food_repository.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

SavedFood saved(String id, String name,
    {String brand = 'Generic', DateTime? createdAt, String? notes}) {
  return SavedFood(
    id: id,
    userId: 'user-1',
    notes: notes,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    food: FoodItem(
      id: 'food-$id',
      name: name,
      brandName: brand,
      foodType: 'Generic',
      nutrients: const {'Calories': 100},
      servings: [
        ServingInfo(
          description: '1 cup',
          amount: 1,
          unit: 'cup',
          metricAmount: 240,
          metricUnit: 'g',
          calories: 100,
          carbohydrate: 10,
          protein: 5,
          fat: 3,
          saturatedFat: 1,
        ),
      ],
    ),
  );
}

void main() {
  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('saved_foods');
  });

  group('mergeFoodLists', () {
    test('merges by id, so a food is never listed twice', () {
      final merged = SavedFoodProvider.mergeFoodLists(
        [saved('a', 'Oats'), saved('b', 'Rice')],
        [saved('b', 'Rice'), saved('c', 'Beans')],
      );
      expect(merged.map((f) => f.id).toSet(), {'a', 'b', 'c'});
      expect(merged, hasLength(3));
    });

    test('the cloud copy wins a conflict', () {
      final merged = SavedFoodProvider.mergeFoodLists(
        [saved('a', 'Oats', notes: 'local')],
        [saved('a', 'Oats', notes: 'cloud')],
      );
      expect(merged.single.notes, 'cloud');
    });

    test('newest saved first', () {
      final merged = SavedFoodProvider.mergeFoodLists(
        [saved('old', 'Oats', createdAt: DateTime(2026, 1, 1))],
        [
          saved('new', 'Rice', createdAt: DateTime(2026, 3, 1)),
          saved('mid', 'Beans', createdAt: DateTime(2026, 2, 1)),
        ],
      );
      expect(merged.map((f) => f.id), ['new', 'mid', 'old']);
    });
  });

  group('matching ("Your foods" in search)', () {
    final foods = [
      saved('1', 'Greek Yogurt', brand: 'Fage'),
      saved('2', 'Chicken breast'),
      saved('3', 'Protein bar', brand: 'Quest'),
    ];

    test('matches name or brand, ignoring case and spaces', () {
      expect(SavedFoodProvider.matching(foods, 'yogurt').map((f) => f.id), ['1']);
      expect(SavedFoodProvider.matching(foods, ' FAGE ').map((f) => f.id), ['1']);
      expect(SavedFoodProvider.matching(foods, 'quest').map((f) => f.id), ['3']);
      expect(SavedFoodProvider.matching(foods, 'e').length, 3);
    });

    test('nothing for an empty query or no match', () {
      expect(SavedFoodProvider.matching(foods, ''), isEmpty);
      expect(SavedFoodProvider.matching(foods, '   '), isEmpty);
      expect(SavedFoodProvider.matching(foods, 'pizza'), isEmpty);
    });

    test('shows at most five', () {
      final many = [for (var i = 0; i < 8; i++) saved('$i', 'Apple $i')];
      expect(SavedFoodProvider.matching(many, 'apple'), hasLength(5));
    });
  });

  group('offline behaviour', () {
    test('loads foods saved on this device while signed out, newest first', () async {
      await SavedFoodRepository().saveToLocal([
        saved('a', 'Oats', createdAt: DateTime(2026, 1, 1)),
        saved('b', 'Rice', createdAt: DateTime(2026, 2, 1)),
      ]);
      final provider = SavedFoodProvider();
      await provider.initialize();
      expect(provider.isInitialized, isTrue);
      expect(provider.savedFoods.map((f) => f.food.name), ['Rice', 'Oats']);
      expect(provider.isFoodSaved('food-a'), isTrue);
      expect(provider.isFoodSaved('food-z'), isFalse);
      expect(provider.getSavedFoodByFoodId('food-b')?.food.name, 'Rice');
      expect(provider.getSavedFoodByFoodId('food-z'), isNull);
    });

    test('loading more with nothing in the cloud stops paging', () async {
      final provider = SavedFoodProvider();
      await provider.initialize();
      expect(provider.hasMoreData, isTrue);
      await provider.loadMore();
      expect(provider.hasMoreData, isFalse);
    });

    test('clearUserData forgets the foods on this device', () async {
      await SavedFoodRepository().saveToLocal([saved('a', 'Oats')]);
      final provider = SavedFoodProvider();
      await provider.initialize();
      expect(provider.savedFoods, isNotEmpty);

      await provider.clearUserData();
      expect(provider.savedFoods, isEmpty);
      expect(provider.isInitialized, isFalse);
      expect(provider.isFoodSaved('food-a'), isFalse);
      expect(StorageService().get('saved_foods'), isNull);
      expect(await SavedFoodRepository().loadFromLocal(), isEmpty);
    });
  });
}
