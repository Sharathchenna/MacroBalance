import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/food.dart';
import '../models/saved_food.dart';
import '../repositories/saved_food_repository.dart';
import '../screens/searchPage.dart' as search;

class SavedFoodProvider with ChangeNotifier {
  final SavedFoodRepository _repository = SavedFoodRepository();

  List<SavedFood> _savedFoods = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _disposed = false;

  // Getters
  List<SavedFood> get savedFoods => List.unmodifiable(_savedFoods);
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;

  // Safe notify listeners method
  void _safeNotifyListeners() {
    if (_disposed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  // Initialize and load saved foods
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      // First try to load from local storage
      final localFoods = await _repository.loadFromLocal();

      // Update the list with local foods first
      _savedFoods = localFoods;
      _safeNotifyListeners();

      // Then try to load from cloud
      try {
        final cloudFoods = await _repository.loadFromCloud();

        // If cloud data exists, use it (it's more authoritative)
        if (cloudFoods.isNotEmpty) {
          _savedFoods = cloudFoods;
          // Save to local storage for offline access
          await _repository.saveToLocal(_savedFoods);
        } else if (localFoods.isNotEmpty) {
          // If we have local data but no cloud data, sync local to cloud
          await _repository.saveToCloud(localFoods);
        }
      } catch (e) {
        // Cloud sync failed, but we still have local data
        debugPrint('Cloud sync failed: $e');
      }
    } catch (e) {
      debugPrint('Failed to initialize saved foods: $e');
      _savedFoods = [];
    } finally {
      _isLoading = false;
      _isInitialized = true;
      _safeNotifyListeners();
    }
  }

  // Add a food item to saved foods
  Future<void> addSavedFood(dynamic food) async {
    // Convert from search.FoodItem to FoodItem if needed
    FoodItem foodItem;

    if (food is search.FoodItem) {
      // Convert search.FoodItem to our model's FoodItem
      List<ServingInfo> servings = food.servings.map((serving) {
        return ServingInfo(
          description: serving.description,
          amount: 1.0, // Default amount
          unit: serving.metricUnit,
          metricAmount: serving.metricAmount,
          metricUnit: serving.metricUnit,
          calories: serving.calories,
          protein: serving.nutrients['Protein'] ?? 0,
          carbohydrate: serving.nutrients['Carbohydrate, by difference'] ?? 0,
          fat: serving.nutrients['Total lipid (fat)'] ?? 0,
          saturatedFat: serving.nutrients['Saturated fat'] ?? 0,
          polyunsaturatedFat:
              serving.nutrients.containsKey('Polyunsaturated fat')
                  ? serving.nutrients['Polyunsaturated fat']
                  : null,
          monounsaturatedFat:
              serving.nutrients.containsKey('Monounsaturated fat')
                  ? serving.nutrients['Monounsaturated fat']
                  : null,
          transFat: serving.nutrients.containsKey('Trans fat')
              ? serving.nutrients['Trans fat']
              : null,
          cholesterol: serving.nutrients.containsKey('Cholesterol')
              ? serving.nutrients['Cholesterol']
              : null,
          sodium: serving.nutrients.containsKey('Sodium')
              ? serving.nutrients['Sodium']
              : null,
          potassium: serving.nutrients.containsKey('Potassium')
              ? serving.nutrients['Potassium']
              : null,
          fiber: serving.nutrients.containsKey('Fiber')
              ? serving.nutrients['Fiber']
              : null,
          sugar: serving.nutrients.containsKey('Sugar')
              ? serving.nutrients['Sugar']
              : null,
          vitaminA: serving.nutrients.containsKey('Vitamin A')
              ? serving.nutrients['Vitamin A']
              : null,
          vitaminC: serving.nutrients.containsKey('Vitamin C')
              ? serving.nutrients['Vitamin C']
              : null,
          calcium: serving.nutrients.containsKey('Calcium')
              ? serving.nutrients['Calcium']
              : null,
          iron: serving.nutrients.containsKey('Iron')
              ? serving.nutrients['Iron']
              : null,
        );
      }).toList();

      // Create a map of nutrients
      Map<String, double> nutrients = {
        'Protein': food.nutrients['Protein'] ?? 0,
        'Total lipid (fat)': food.nutrients['Total lipid (fat)'] ?? 0,
        'Carbohydrate, by difference':
            food.nutrients['Carbohydrate, by difference'] ?? 0,
      };

      foodItem = FoodItem(
        id: food.fdcId,
        name: food.name,
        brandName: food.brandName,
        foodType: '', // Default food type
        servings: servings,
        nutrients: nutrients,
      );
    } else if (food is FoodItem) {
      foodItem = food;
    } else {
      throw ArgumentError('Unsupported food type: ${food.runtimeType}');
    }

    // Check if this food is already saved
    if (isFoodSaved(foodItem.id)) {
      return; // Already saved
    }

    // Get the current user ID
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }

    // Create the saved food
    final savedFood = SavedFood(
      userId: user.id,
      food: foodItem,
    );

    // Add to the list
    _savedFoods.add(savedFood);
    _safeNotifyListeners();

    // Save to local and cloud
    try {
      await _repository.saveToLocal(_savedFoods);
      await _repository.saveToCloud([savedFood]); // Only save the new one
    } catch (e) {
      debugPrint('Failed to save food: $e');
      // Remove from list if saving failed
      _savedFoods.remove(savedFood);
      _safeNotifyListeners();
      rethrow;
    }
  }

  // Check if a food is already saved
  bool isFoodSaved(String foodId) {
    return _savedFoods.any((savedFood) => savedFood.food.id == foodId);
  }

  // Remove a saved food
  Future<void> removeSavedFood(String savedFoodId) async {
    final savedFoodIndex =
        _savedFoods.indexWhere((food) => food.id == savedFoodId);
    if (savedFoodIndex == -1) return; // Not found

    final savedFood = _savedFoods[savedFoodIndex];
    _savedFoods.removeAt(savedFoodIndex);
    _safeNotifyListeners();

    try {
      await _repository.saveToLocal(_savedFoods);
      await _repository.deleteFromCloud(savedFoodId);
    } catch (e) {
      debugPrint('Failed to remove saved food: $e');
      // Add back if deletion failed
      _savedFoods.insert(savedFoodIndex, savedFood);
      _safeNotifyListeners();
      rethrow;
    }
  }

  // Update a saved food
  Future<void> updateSavedFood(SavedFood updatedSavedFood) async {
    // Find the index of the saved food
    final index = _savedFoods.indexWhere((sf) => sf.id == updatedSavedFood.id);
    if (index == -1) return;

    // Update in the list
    _savedFoods[index] = updatedSavedFood;

    // Save locally
    await _repository.saveToLocal(_savedFoods);

    // Sync to Supabase
    _repository.saveToCloud([updatedSavedFood]);

    _safeNotifyListeners();
  }

  // Get a saved food by ID
  SavedFood? getSavedFoodByFoodId(String foodId) {
    try {
      return _savedFoods.firstWhere((savedFood) => savedFood.food.id == foodId);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
