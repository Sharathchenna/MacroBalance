import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../models/recipe.dart';
import '../models/meal_plan.dart';
import '../models/user_preferences.dart';
import 'supabase_service.dart';
import 'storage_service.dart';
import 'package:flutter/foundation.dart';

class MealPlanningService {
  static final MealPlanningService _instance = MealPlanningService._internal();
  factory MealPlanningService() => _instance;
  MealPlanningService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  final StorageService _storageService = StorageService();
  final Uuid _uuid = const Uuid();

  // AI model for meal generation
  GenerativeModel? _model;

  // Cache for recipes and meal plans
  final Map<String, Recipe> _recipeCache = {};
  final Map<String, DailyMealPlan> _mealPlanCache = {};

  void initializeAI(String apiKey) {
    _model = GenerativeModel(
      model: 'gemini-pro',
      apiKey: apiKey,
    );
  }

  // Recipe Management
  Future<List<Recipe>> getRecipes({
    String? searchQuery,
    List<String>? dietaryTags,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('recipes')
          .select()
          .ilike('name', '%${searchQuery ?? ''}%')
          .order('name', ascending: true)
          .limit(limit)
          .range(offset, offset + limit - 1);

      final recipes =
          (response as List).map((data) => Recipe.fromJson(data)).toList();

      // Filter by dietary tags if provided
      if (dietaryTags != null && dietaryTags.isNotEmpty) {
        return recipes
            .where((recipe) =>
                recipe.dietaryTags.any((tag) => dietaryTags.contains(tag)))
            .toList();
      }

      // Update cache
      for (var recipe in recipes) {
        _recipeCache[recipe.id] = recipe;
      }

      return recipes;
    } catch (e) {
      debugPrint('Error fetching recipes: $e');
      return [];
    }
  }

  Future<Recipe?> getRecipeById(String id) async {
    // Check cache first
    if (_recipeCache.containsKey(id)) {
      return _recipeCache[id];
    }

    try {
      final response = await _supabaseService.supabaseClient
          .from('recipes')
          .select()
          .eq('id', id)
          .single();

      final recipe = Recipe.fromJson(response);
      _recipeCache[id] = recipe;
      return recipe;
    } catch (e) {
      debugPrint('Error fetching recipe $id: $e');
      return null;
    }
  }

  Future<Recipe?> createRecipe(Recipe recipe) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('recipes')
          .insert(recipe.toJson())
          .select()
          .single();

      final createdRecipe = Recipe.fromJson(response);
      _recipeCache[createdRecipe.id] = createdRecipe;
      return createdRecipe;
    } catch (e) {
      debugPrint('Error creating recipe: $e');
      return null;
    }
  }

  Future<Recipe?> updateRecipe(Recipe recipe) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('recipes')
          .update(recipe.toJson())
          .eq('id', recipe.id)
          .select()
          .single();

      final updatedRecipe = Recipe.fromJson(response);
      _recipeCache[recipe.id] = updatedRecipe;
      return updatedRecipe;
    } catch (e) {
      debugPrint('Error updating recipe: $e');
      return null;
    }
  }

  Future<bool> deleteRecipe(String id) async {
    try {
      await _supabaseService.supabaseClient
          .from('recipes')
          .delete()
          .eq('id', id);

      _recipeCache.remove(id);
      return true;
    } catch (e) {
      debugPrint('Error deleting recipe: $e');
      return false;
    }
  }

  // Meal Plan Management
  Future<DailyMealPlan?> getMealPlanForDate(
      String userId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;
    final cacheKey = '${userId}_$dateStr';

    // Check cache first
    if (_mealPlanCache.containsKey(cacheKey)) {
      return _mealPlanCache[cacheKey];
    }

    try {
      final response = await _supabaseService.supabaseClient
          .from('daily_meal_plans')
          .select()
          .eq('user_id', userId)
          .eq('date', dateStr)
          .maybeSingle();

      if (response != null) {
        final mealPlan = DailyMealPlan.fromJson(response);
        _mealPlanCache[cacheKey] = mealPlan;
        return mealPlan;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching meal plan for $dateStr: $e');
      return null;
    }
  }

  Future<List<DailyMealPlan>> getMealPlansForRange(
      String userId, DateTime startDate, DateTime endDate) async {
    final startDateStr = startDate.toIso8601String().split('T').first;
    final endDateStr = endDate.toIso8601String().split('T').first;

    try {
      final response = await _supabaseService.supabaseClient
          .from('daily_meal_plans')
          .select('*')
          .eq('user_id', userId)
          .gte('date', startDateStr)
          .lte('date', endDateStr)
          .order('date');

      final List<DailyMealPlan> mealPlans = [];
      for (final data in response) {
        try {
          final plan = DailyMealPlan.fromJson(data);
          mealPlans.add(plan);

          // Update cache
          final cacheKey =
              '${userId}_${plan.date.toIso8601String().split('T').first}';
          _mealPlanCache[cacheKey] = plan;
        } catch (e) {
          debugPrint('Error parsing meal plan: $e');
          continue;
        }
      }

      return mealPlans;
    } catch (e) {
      debugPrint('Error fetching meal plans for range: $e');
      return [];
    }
  }

  Future<DailyMealPlan?> createMealPlan(DailyMealPlan mealPlan) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('daily_meal_plans')
          .insert(mealPlan.toJson())
          .select()
          .single();

      final createdPlan = DailyMealPlan.fromJson(response);
      final cacheKey =
          '${createdPlan.userId}_${createdPlan.date.toIso8601String().split('T').first}';
      _mealPlanCache[cacheKey] = createdPlan;
      return createdPlan;
    } catch (e) {
      debugPrint('Error creating meal plan: $e');
      return null;
    }
  }

  Future<DailyMealPlan?> updateMealPlan(DailyMealPlan mealPlan) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('daily_meal_plans')
          .update(mealPlan.toJson())
          .eq('id', mealPlan.id)
          .select()
          .single();

      final updatedPlan = DailyMealPlan.fromJson(response);
      final cacheKey =
          '${updatedPlan.userId}_${updatedPlan.date.toIso8601String().split('T').first}';
      _mealPlanCache[cacheKey] = updatedPlan;
      return updatedPlan;
    } catch (e) {
      debugPrint('Error updating meal plan: $e');
      return null;
    }
  }

  Future<bool> deleteMealPlan(String id, String userId, DateTime date) async {
    try {
      await _supabaseService.supabaseClient
          .from('daily_meal_plans')
          .delete()
          .eq('id', id);

      final cacheKey = '${userId}_${date.toIso8601String().split('T').first}';
      _mealPlanCache.remove(cacheKey);
      return true;
    } catch (e) {
      debugPrint('Error deleting meal plan: $e');
      return false;
    }
  }

  // AI-powered meal generation
  Future<List<Recipe>> generateRecipes({
    required UserPreferences userPreferences,
    required int count,
    String? mealType,
  }) async {
    if (_model == null) {
      throw Exception('API key not provided for recipe generation');
    }

    try {
      final dietaryTags = userPreferences.dietaryPreferences.dietaryTags;
      final allergies = userPreferences.dietaryPreferences.allergies;
      final dislikedFoods = userPreferences.dietaryPreferences.dislikedFoods;

      final prompt = '''
Generate $count healthy ${mealType ?? ''} recipes that match these criteria:
- Target calories: ${userPreferences.targetCalories / userPreferences.dietaryPreferences.mealsPerDay} calories per serving
- Target macros: Protein: ${userPreferences.targetProtein / userPreferences.dietaryPreferences.mealsPerDay}g, Carbs: ${userPreferences.targetCarbohydrates / userPreferences.dietaryPreferences.mealsPerDay}g, Fat: ${userPreferences.targetFat / userPreferences.dietaryPreferences.mealsPerDay}g
- Dietary preferences: ${dietaryTags.join(', ')}
- Allergies to avoid: ${allergies.join(', ')}
- Disliked foods to avoid: ${dislikedFoods.join(', ')}

For each recipe, provide:
1. Name
2. Description
3. Ingredients list
4. Cooking instructions
5. Preparation time
6. Cooking time
7. Servings
8. Nutrition information (calories, protein, carbs, fat, fiber)
9. Dietary tags

Format the response as a JSON array of recipe objects.
''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      final jsonStr = response.text?.trim() ?? '';

      // Extract JSON from the response if needed
      final jsonMatch = RegExp(r'\[.*\]', dotAll: true).firstMatch(jsonStr);
      final jsonData = jsonMatch != null ? jsonMatch.group(0) : jsonStr;

      if (jsonData == null) {
        throw Exception('Failed to parse generated recipes');
      }

      final List<dynamic> recipesData = json.decode(jsonData);
      return recipesData.map((data) {
        // Convert the AI-generated data to our Recipe model
        return Recipe(
          name: data['name'] ?? '',
          description: data['description'] ?? '',
          ingredients: List<String>.from(data['ingredients'] ?? []),
          instructions: List<String>.from(data['instructions'] ?? []),
          prepTimeMinutes:
              data['prep_time_minutes'] ?? data['preparation_time'] ?? 15,
          cookTimeMinutes:
              data['cook_time_minutes'] ?? data['cooking_time'] ?? 20,
          servings: data['servings'] ?? 1,
          calories: (data['calories'] ?? data['nutrition']?['calories'] ?? 0)
              .toDouble(),
          protein: (data['protein'] ?? data['nutrition']?['protein'] ?? 0)
              .toDouble(),
          carbohydrates:
              (data['carbohydrates'] ?? data['nutrition']?['carbs'] ?? 0)
                  .toDouble(),
          fat: (data['fat'] ?? data['nutrition']?['fat'] ?? 0).toDouble(),
          fiber: (data['fiber'] ?? data['nutrition']?['fiber'] ?? 0).toDouble(),
          dietaryTags: List<String>.from(data['dietary_tags'] ?? []),
          difficulty: data['difficulty'] ?? 'medium',
        );
      }).toList();
    } catch (e) {
      debugPrint('Error generating recipes: $e');
      return [];
    }
  }

  Future<DailyMealPlan?> generateMealPlan({
    required String userId,
    required DateTime date,
    required UserPreferences userPreferences,
  }) async {
    try {
      // Check if a meal plan already exists for this date
      final existingPlan = await getMealPlanForDate(userId, date);
      if (existingPlan != null) {
        return existingPlan;
      }

      // Generate breakfast, lunch, and dinner recipes
      final breakfastRecipes = await generateRecipes(
        userPreferences: userPreferences,
        count: 1,
        mealType: 'breakfast',
      );

      final lunchRecipes = await generateRecipes(
        userPreferences: userPreferences,
        count: 1,
        mealType: 'lunch',
      );

      final dinnerRecipes = await generateRecipes(
        userPreferences: userPreferences,
        count: 1,
        mealType: 'dinner',
      );

      // Create meal items from recipes
      final meals = <Meal>[];
      _uuid.v4();

      if (breakfastRecipes.isNotEmpty) {
        final breakfastItems = [
          MealItem.fromRecipe(breakfastRecipes.first,
              servings: 1.0, isLogged: false)
        ];
        meals.add(Meal(
          name: 'Breakfast',
          items: breakfastItems,
          time: DateTime(date.year, date.month, date.day, 8, 0),
        ));
      }

      if (lunchRecipes.isNotEmpty) {
        final lunchItems = [
          MealItem.fromRecipe(lunchRecipes.first,
              servings: 1.0, isLogged: false)
        ];
        meals.add(Meal(
          name: 'Lunch',
          items: lunchItems,
          time: DateTime(date.year, date.month, date.day, 13, 0),
        ));
      }

      if (dinnerRecipes.isNotEmpty) {
        final dinnerItems = [
          MealItem.fromRecipe(dinnerRecipes.first,
              servings: 1.0, isLogged: false)
        ];
        meals.add(Meal(
          name: 'Dinner',
          items: dinnerItems,
          time: DateTime(date.year, date.month, date.day, 19, 0),
        ));
      }

      // Create and save the meal plan
      final mealPlan = DailyMealPlan(
        userId: userId,
        date: date,
        targetCalories: userPreferences.targetCalories,
        targetProtein: userPreferences.targetProtein,
        targetCarbohydrates: userPreferences.targetCarbohydrates,
        targetFat: userPreferences.targetFat,
        plannedMeals: meals,
        loggedMeals: const [],
      );

      return await createMealPlan(mealPlan);
    } catch (e) {
      debugPrint('Error generating meal plan: $e');
      return null;
    }
  }

  // Log a meal
  Future<DailyMealPlan?> logMeal({
    required String userId,
    required DateTime date,
    required Meal meal,
  }) async {
    try {
      // Get the current meal plan
      final mealPlan = await getMealPlanForDate(userId, date);
      if (mealPlan == null) {
        // Create a new meal plan if none exists
        final newPlan = DailyMealPlan(
          userId: userId,
          date: date,
          targetCalories: 2000, // Default values
          targetProtein: 150,
          targetCarbohydrates: 200,
          targetFat: 65,
          plannedMeals: const [],
          loggedMeals: [meal],
        );
        return await createMealPlan(newPlan);
      } else {
        // Add the logged meal to existing plan
        final updatedLoggedMeals = [...mealPlan.loggedMeals, meal];
        final updatedPlan = mealPlan.copyWith(
          loggedMeals: updatedLoggedMeals,
        );
        return await updateMealPlan(updatedPlan);
      }
    } catch (e) {
      debugPrint('Error logging meal: $e');
      return null;
    }
  }

  // Clear cache
  void clearCache() {
    _recipeCache.clear();
    _mealPlanCache.clear();
  }

  // Local Storage for offline support
  Future<void> cacheMealPlan(DailyMealPlan mealPlan) async {
    try {
      final key =
          'meal_plan_${mealPlan.userId}_${mealPlan.date.toIso8601String().split('T')[0]}';
      await _storageService.put(key, json.encode(mealPlan.toJson()));
    } catch (e) {
      print('Error caching meal plan: $e');
    }
  }

  Future<DailyMealPlan?> getCachedMealPlan(String userId, DateTime date) async {
    try {
      final key = 'meal_plan_${userId}_${date.toIso8601String().split('T')[0]}';
      final cachedData = _storageService.get(key);

      if (cachedData != null && cachedData.isNotEmpty) {
        return DailyMealPlan.fromJson(json.decode(cachedData));
      }
      return null;
    } catch (e) {
      print('Error getting cached meal plan: $e');
      return null;
    }
  }

  // Search recipes
  Future<List<Recipe>> searchRecipes(String query) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('recipes')
          .select()
          .or('name.ilike.%$query%,description.ilike.%$query%')
          .limit(20);

      return (response as List).map((json) => Recipe.fromJson(json)).toList();
    } catch (e) {
      print('Error searching recipes: $e');
      return [];
    }
  }
}
