import 'package:flutter/foundation.dart';
import '../models/recipe.dart';
import '../models/meal_plan.dart';
import '../models/user_preferences.dart';
import '../services/meal_planning_service.dart';
import '../services/auth_service.dart';

class MealPlanningProvider with ChangeNotifier {
  final MealPlanningService _mealPlanningService;
  final AuthService _authService;

  // State
  bool _isLoading = false;
  String? _error;
  List<Recipe> _recipes = [];
  List<Recipe> _favoriteRecipes = [];
  DailyMealPlan? _currentMealPlan;
  List<DailyMealPlan> _weeklyMealPlans = [];
  bool _isGeneratingMealPlan = false;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Recipe> get recipes => _recipes;
  List<Recipe> get favoriteRecipes => _favoriteRecipes;
  DailyMealPlan? get currentMealPlan => _currentMealPlan;
  List<DailyMealPlan> get weeklyMealPlans => _weeklyMealPlans;
  bool get isGeneratingMealPlan => _isGeneratingMealPlan;

  MealPlanningProvider({
    MealPlanningService? mealPlanningService,
    AuthService? authService,
  })  : _mealPlanningService = mealPlanningService ?? MealPlanningService(),
        _authService = authService ?? AuthService() {
    _initialize();
  }

  Future<void> _initialize() async {
    await fetchRecipes();
  }

  // Recipe Management
  Future<void> fetchRecipes({
    String? searchQuery,
    List<String>? dietaryTags,
    int limit = 20,
    int offset = 0,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recipes = await _mealPlanningService.getRecipes(
        searchQuery: searchQuery,
        dietaryTags: dietaryTags,
        limit: limit,
        offset: offset,
      );
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch recipes: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Recipe?> getRecipeById(String id) async {
    try {
      return await _mealPlanningService.getRecipeById(id);
    } catch (e) {
      _error = 'Failed to get recipe: $e';
      notifyListeners();
      return null;
    }
  }

  Future<Recipe?> createRecipe(Recipe recipe) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final newRecipe = await _mealPlanningService.createRecipe(recipe);
      if (newRecipe != null) {
        _recipes = [..._recipes, newRecipe];
      }
      _isLoading = false;
      notifyListeners();
      return newRecipe;
    } catch (e) {
      _error = 'Failed to create recipe: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<Recipe?> updateRecipe(Recipe recipe) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedRecipe = await _mealPlanningService.updateRecipe(recipe);
      if (updatedRecipe != null) {
        _recipes =
            _recipes.map((r) => r.id == recipe.id ? updatedRecipe : r).toList();
        _favoriteRecipes = _favoriteRecipes
            .map((r) => r.id == recipe.id ? updatedRecipe : r)
            .toList();
      }
      _isLoading = false;
      notifyListeners();
      return updatedRecipe;
    } catch (e) {
      _error = 'Failed to update recipe: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteRecipe(String id) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success = await _mealPlanningService.deleteRecipe(id);
      if (success) {
        _recipes = _recipes.where((r) => r.id != id).toList();
        _favoriteRecipes = _favoriteRecipes.where((r) => r.id != id).toList();
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to delete recipe: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void toggleFavoriteRecipe(Recipe recipe) {
    final isCurrentlyFavorite = _favoriteRecipes.any((r) => r.id == recipe.id);

    if (isCurrentlyFavorite) {
      _favoriteRecipes =
          _favoriteRecipes.where((r) => r.id != recipe.id).toList();
    } else {
      _favoriteRecipes = [..._favoriteRecipes, recipe];
    }

    notifyListeners();
  }

  bool isRecipeFavorite(String recipeId) {
    return _favoriteRecipes.any((r) => r.id == recipeId);
  }

  // Meal Plan Management
  Future<void> fetchMealPlanForDate(DateTime date) async {
    if (_authService.currentUser == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final plan = await _mealPlanningService.getMealPlanForDate(
        _authService.currentUser!.id,
        date,
      );
      _currentMealPlan = plan;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch meal plan: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchWeeklyMealPlans(DateTime startDate) async {
    if (_authService.currentUser == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final endDate = startDate.add(const Duration(days: 6));
      final plans = await _mealPlanningService.getMealPlansForRange(
        _authService.currentUser!.id,
        startDate,
        endDate,
      );
      _weeklyMealPlans = plans;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to fetch weekly meal plans: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<DailyMealPlan?> createMealPlan(DailyMealPlan mealPlan) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final createdPlan = await _mealPlanningService.createMealPlan(mealPlan);
      if (createdPlan != null) {
        _currentMealPlan = createdPlan;
        _weeklyMealPlans = _updateWeeklyMealPlans(createdPlan);
      }
      _isLoading = false;
      notifyListeners();
      return createdPlan;
    } catch (e) {
      _error = 'Failed to create meal plan: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<DailyMealPlan?> updateMealPlan(DailyMealPlan mealPlan) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedPlan = await _mealPlanningService.updateMealPlan(mealPlan);
      if (updatedPlan != null) {
        _currentMealPlan = updatedPlan;
        _weeklyMealPlans = _updateWeeklyMealPlans(updatedPlan);
      }
      _isLoading = false;
      notifyListeners();
      return updatedPlan;
    } catch (e) {
      _error = 'Failed to update meal plan: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteMealPlan(String id, String userId, DateTime date) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final success =
          await _mealPlanningService.deleteMealPlan(id, userId, date);
      if (success) {
        if (_currentMealPlan?.id == id) {
          _currentMealPlan = null;
        }
        _weeklyMealPlans =
            _weeklyMealPlans.where((plan) => plan.id != id).toList();
      }
      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Failed to delete meal plan: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  List<DailyMealPlan> _updateWeeklyMealPlans(DailyMealPlan updatedPlan) {
    // Check if the plan is in the current week
    final existingIndex =
        _weeklyMealPlans.indexWhere((plan) => plan.id == updatedPlan.id);

    if (existingIndex >= 0) {
      return _weeklyMealPlans
          .map((plan) => plan.id == updatedPlan.id ? updatedPlan : plan)
          .toList();
    } else {
      // Check if the date is within the current week range
      if (_weeklyMealPlans.isNotEmpty) {
        final firstDate = _weeklyMealPlans.first.date;
        final lastDate = _weeklyMealPlans.last.date;

        if (updatedPlan.date
                .isAfter(firstDate.subtract(const Duration(days: 1))) &&
            updatedPlan.date.isBefore(lastDate.add(const Duration(days: 1)))) {
          return [..._weeklyMealPlans, updatedPlan]
            ..sort((a, b) => a.date.compareTo(b.date));
        }
      }

      return _weeklyMealPlans;
    }
  }

  // AI-powered meal generation
  Future<List<Recipe>> generateRecipes({
    required UserPreferences userPreferences,
    required int count,
    String? mealType,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final generatedRecipes = await _mealPlanningService.generateRecipes(
        userPreferences: userPreferences,
        count: count,
        mealType: mealType,
      );
      _isLoading = false;
      notifyListeners();
      return generatedRecipes;
    } catch (e) {
      _error = 'Failed to generate recipes: $e';
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  Future<DailyMealPlan?> generateMealPlan({
    required DateTime date,
    required UserPreferences userPreferences,
  }) async {
    if (_authService.currentUser == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return null;
    }

    _isGeneratingMealPlan = true;
    _error = null;
    notifyListeners();

    try {
      final generatedPlan = await _mealPlanningService.generateMealPlan(
        userId: _authService.currentUser!.id,
        date: date,
        userPreferences: userPreferences,
      );

      if (generatedPlan != null) {
        _currentMealPlan = generatedPlan;
        _weeklyMealPlans =
            _updateWeeklyMealPlans(generatedPlan);
      }

      _isGeneratingMealPlan = false;
      notifyListeners();
      return generatedPlan;
    } catch (e) {
      _error = 'Failed to generate meal plan: $e';
      _isGeneratingMealPlan = false;
      notifyListeners();
      return null;
    }
  }

  // Meal Logging
  Future<DailyMealPlan?> logMeal({
    required DateTime date,
    required Meal meal,
  }) async {
    if (_authService.currentUser == null) {
      _error = 'User not authenticated';
      notifyListeners();
      return null;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final updatedPlan = await _mealPlanningService.logMeal(
        userId: _authService.currentUser!.id,
        date: date,
        meal: meal,
      );

      if (updatedPlan != null) {
        _currentMealPlan = updatedPlan;
        _weeklyMealPlans = _updateWeeklyMealPlans(updatedPlan);
      }

      _isLoading = false;
      notifyListeners();
      return updatedPlan;
    } catch (e) {
      _error = 'Failed to log meal: $e';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // Clear state
  void clearState() {
    _recipes = [];
    _favoriteRecipes = [];
    _currentMealPlan = null;
    _weeklyMealPlans = [];
    _error = null;
    _isLoading = false;
    _isGeneratingMealPlan = false;
    _mealPlanningService.clearCache();
    notifyListeners();
  }
}
