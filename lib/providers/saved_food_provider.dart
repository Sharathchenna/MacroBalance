import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/food.dart';
import '../models/saved_food.dart';
import '../repositories/saved_food_repository.dart';
import '../screens/searchPage.dart' as search;

class SavedFoodProvider with ChangeNotifier {
  final SavedFoodRepository _repository = SavedFoodRepository();
  final Connectivity _connectivity = Connectivity();

  List<SavedFood> _savedFoods = [];
  bool _isInitialized = false;
  bool _isLoading = false;
  bool _disposed = false;
  bool _isLoadingMore = false;
  DateTime? _lastSyncTime;
  bool _hasNetworkConnection = true;
  int _failedSyncAttempts = 0;
  static const int _maxSyncRetries = 3;
  static const Duration _syncThreshold = Duration(minutes: 15);
  static const Duration _retryDelay = Duration(minutes: 1);

  // Cache settings
  static const int _maxCacheSize = 100;
  final Map<String, SavedFood> _foodCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(hours: 24);

  // Pagination settings
  static const int _pageSize = 20;
  int _currentPage = 0;
  bool _hasMoreData = true;

  // Getters
  List<SavedFood> get savedFoods => List.unmodifiable(_savedFoods);
  bool get isInitialized => _isInitialized;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMoreData => _hasMoreData;

  SavedFoodProvider() {
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      final hasConnection = result != ConnectivityResult.none;
      if (hasConnection != _hasNetworkConnection) {
        _hasNetworkConnection = hasConnection;
        if (hasConnection && _failedSyncAttempts > 0) {
          _retryFailedSync();
        }
      }
    });
  }

  // Safe notify listeners method
  void _safeNotifyListeners() {
    if (_disposed) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed) {
        notifyListeners();
      }
    });
  }

  // Initialize and load saved foods with optimizations
  Future<void> initialize() async {
    if (_isInitialized || _isLoading) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      // First try to load from cache
      _loadFromCache();

      // Then try to load from local storage
      final localFoods = await _repository.loadFromLocal();
      _updateFoodsList(localFoods);

      // Check network connectivity
      final connectivityResult = await _connectivity.checkConnectivity();
      _hasNetworkConnection = connectivityResult != ConnectivityResult.none;

      // Start background sync if network is available
      if (_hasNetworkConnection) {
        await _startBackgroundSync();
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize saved foods: $e');
      _savedFoods = [];
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // Retry failed sync operations
  Future<void> _retryFailedSync() async {
    if (!_hasNetworkConnection || _failedSyncAttempts >= _maxSyncRetries)
      return;

    try {
      await _startBackgroundSync();
      _failedSyncAttempts = 0;
    } catch (e) {
      _failedSyncAttempts++;
      if (_failedSyncAttempts < _maxSyncRetries) {
        Future.delayed(_retryDelay, _retryFailedSync);
      }
    }
  }

  // Background sync with improved error handling
  Future<void> _startBackgroundSync() async {
    if (_lastSyncTime != null &&
        DateTime.now().difference(_lastSyncTime!) < _syncThreshold) {
      return;
    }

    try {
      final cloudFoods = await _repository.loadFromCloud(
        page: 0,
        pageSize: _pageSize,
      );

      if (!_disposed) {
        // Merge cloud and local data
        final mergedFoods = _mergeFoodLists(_savedFoods, cloudFoods);
        _updateFoodsList(mergedFoods);
        _lastSyncTime = DateTime.now();
        await _repository.saveToLocal(_savedFoods);
        _safeNotifyListeners();
      }
    } catch (e) {
      debugPrint('Background sync failed: $e');
      if (_hasNetworkConnection) {
        _failedSyncAttempts++;
        if (_failedSyncAttempts < _maxSyncRetries) {
          Future.delayed(_retryDelay, _retryFailedSync);
        }
      }
    }
  }

  // Merge food lists with conflict resolution
  List<SavedFood> _mergeFoodLists(
      List<SavedFood> local, List<SavedFood> cloud) {
    final Map<String, SavedFood> merged = {};

    // Add all local foods
    for (final food in local) {
      merged[food.id] = food;
    }

    // Add or update with cloud foods (cloud takes precedence for conflicts)
    for (final food in cloud) {
      merged[food.id] = food;
    }

    return merged.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // Cache management with expiry
  void _loadFromCache() {
    final now = DateTime.now();
    _savedFoods = _foodCache.entries
        .where((entry) =>
            now.difference(_cacheTimestamps[entry.key]!) < _cacheExpiry)
        .map((entry) => entry.value)
        .toList();

    // Remove expired cache entries
    _cleanExpiredCache();
  }

  void _cleanExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = _cacheTimestamps.entries
        .where((entry) => now.difference(entry.value) >= _cacheExpiry)
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _foodCache.remove(key);
      _cacheTimestamps.remove(key);
    }
  }

  // Load more items (pagination)
  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMoreData || _disposed) return;

    _isLoadingMore = true;
    _safeNotifyListeners();

    try {
      final nextPage = await _repository.loadFromCloud(
        page: _currentPage + 1,
        pageSize: _pageSize,
      );

      if (nextPage.isEmpty) {
        _hasMoreData = false;
      } else {
        _currentPage++;
        _updateFoodsList([..._savedFoods, ...nextPage]);
      }
    } catch (e) {
      debugPrint('Error loading more saved foods: $e');
    } finally {
      _isLoadingMore = false;
      _safeNotifyListeners();
    }
  }

  void _updateCache(List<SavedFood> foods) {
    final now = DateTime.now();

    // Add new items to cache
    for (final food in foods) {
      _foodCache[food.id] = food;
      _cacheTimestamps[food.id] = now;
    }

    // Remove old items if cache is too large
    if (_foodCache.length > _maxCacheSize) {
      final oldestEntries = _cacheTimestamps.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final entriesToRemove =
          oldestEntries.take(_foodCache.length - _maxCacheSize);
      for (final entry in entriesToRemove) {
        _foodCache.remove(entry.key);
        _cacheTimestamps.remove(entry.key);
      }
    }
  }

  void _updateFoodsList(List<SavedFood> newFoods) {
    _savedFoods = newFoods;
    _updateCache(newFoods);
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
          polyunsaturatedFat: serving.nutrients['Polyunsaturated fat'],
          monounsaturatedFat: serving.nutrients['Monounsaturated fat'],
          transFat: serving.nutrients['Trans fat'],
          cholesterol: serving.nutrients['Cholesterol'],
          sodium: serving.nutrients['Sodium'],
          potassium: serving.nutrients['Potassium'],
          fiber: serving.nutrients['Fiber'],
          sugar: serving.nutrients['Sugar'],
          vitaminA: serving.nutrients['Vitamin A'],
          vitaminC: serving.nutrients['Vitamin C'],
          calcium: serving.nutrients['Calcium'],
          iron: serving.nutrients['Iron'],
        );
      }).toList();

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

    // Add to the list and cache
    _savedFoods.add(savedFood);
    _updateCache([savedFood]);
    _safeNotifyListeners();

    // Save to local and cloud
    try {
      await _repository.saveToLocal(_savedFoods);
      await _repository.saveToCloud([savedFood]); // Only save the new one
    } catch (e) {
      debugPrint('Failed to save food: $e');
      // Remove from list and cache if saving failed
      _savedFoods.remove(savedFood);
      _foodCache.remove(savedFood.id);
      _cacheTimestamps.remove(savedFood.id);
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
    _foodCache.remove(savedFoodId);
    _cacheTimestamps.remove(savedFoodId);
    _safeNotifyListeners();

    try {
      await _repository.saveToLocal(_savedFoods);
      await _repository.deleteFromCloud(savedFoodId);
    } catch (e) {
      debugPrint('Failed to remove saved food: $e');
      // Add back if deletion failed
      _savedFoods.insert(savedFoodIndex, savedFood);
      _updateCache([savedFood]);
      _safeNotifyListeners();
      rethrow;
    }
  }

  // Update a saved food
  Future<void> updateSavedFood(SavedFood updatedSavedFood) async {
    final index = _savedFoods.indexWhere((sf) => sf.id == updatedSavedFood.id);
    if (index == -1) return;

    // Update in the list and cache
    _savedFoods[index] = updatedSavedFood;
    _updateCache([updatedSavedFood]);
    _safeNotifyListeners();

    // Save locally and to cloud
    try {
      await _repository.saveToLocal(_savedFoods);
      await _repository.saveToCloud([updatedSavedFood]);
    } catch (e) {
      debugPrint('Failed to update saved food: $e');
      rethrow;
    }
  }

  // Get a saved food by ID
  SavedFood? getSavedFoodByFoodId(String foodId) {
    // Check cache first
    if (_foodCache.containsKey(foodId)) {
      return _foodCache[foodId];
    }

    // Fall back to list search
    try {
      return _savedFoods.firstWhere((savedFood) => savedFood.food.id == foodId);
    } catch (_) {
      return null;
    }
  }

  // Force refresh data
  Future<void> refresh() async {
    if (_isLoading || _disposed) return;

    _isLoading = true;
    _currentPage = 0;
    _hasMoreData = true;
    _safeNotifyListeners();

    try {
      final cloudFoods = await _repository.loadFromCloud(
        page: 0,
        pageSize: _pageSize,
      );

      _updateFoodsList(cloudFoods);
      await _repository.saveToLocal(_savedFoods);
      _lastSyncTime = DateTime.now();
    } catch (e) {
      debugPrint('Failed to refresh saved foods: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _foodCache.clear();
    _cacheTimestamps.clear();
    _savedFoods.clear();
    super.dispose();
  }
}
