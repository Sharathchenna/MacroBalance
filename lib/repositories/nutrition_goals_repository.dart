import 'dart:convert';
import '../services/storage_service.dart';
import '../models/nutrition_goals.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class NutritionGoalsRepository {
  final StorageService _storage = StorageService();

  /// Load nutrition goals from local storage with improved priority
  Future<NutritionGoals> loadGoals() async {
    try {
      // First check for the more structured JSON format (preferred)
      final String? goalsJson = _storage.get('nutrition_goals');
      debugPrint(
          '[NutritionGoalsRepository] nutrition_goals data: ${goalsJson?.substring(0, goalsJson.length.clamp(0, 100))}...');

      if (goalsJson != null && goalsJson.isNotEmpty) {
        final Map<String, dynamic> goalsData = jsonDecode(goalsJson);
        final goals = NutritionGoals.fromJson(goalsData);
        debugPrint(
            'Loaded goals from nutrition_goals JSON: calories=${goals.calories}');
        return goals;
      }

      // Fall back to individual keys (these are saved by auth flow)
      final calories = _storage.get('calories_goal');
      final protein = _storage.get('protein_goal');
      final carbs = _storage.get('carbs_goal');
      final fat = _storage.get('fat_goal');

      debugPrint(
          '[NutritionGoalsRepository] Individual keys - calories: $calories, protein: $protein, carbs: $carbs, fat: $fat');

      if (calories != null && protein != null && carbs != null && fat != null) {
        final goals = NutritionGoals(
          calories: (calories as num).toDouble(),
          protein: (protein as num).toDouble(),
          carbs: (carbs as num).toDouble(),
          fat: (fat as num).toDouble(),
        );
        debugPrint(
            'Loaded goals from individual keys: calories=${goals.calories}');
        return goals;
      }

      // Return default goals if nothing is found
      debugPrint('No stored goals found, using defaults: calories=2000');
      return NutritionGoals.defaultGoals();
    } catch (e) {
      print('Error loading nutrition goals: $e');
      return NutritionGoals.defaultGoals();
    }
  }

  /// Save nutrition goals to local storage
  Future<void> saveGoals(NutritionGoals goals) async {
    try {
      final String goalsJson = jsonEncode(goals.toJson());
      await _storage.put('nutrition_goals', goalsJson);

      // Also save individual keys for backwards compatibility
      await _storage.put('calories_goal', goals.calories);
      await _storage.put('protein_goal', goals.protein);
      await _storage.put('carbs_goal', goals.carbs);
      await _storage.put('fat_goal', goals.fat);

      debugPrint(
          '[NutritionGoalsRepository] Goals saved to storage: calories=${goals.calories}');
    } catch (e) {
      print('Error saving nutrition goals: $e');
    }
  }

  /// Sync goals to Supabase
  Future<void> syncGoalsToSupabase(NutritionGoals goals) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final Map<String, dynamic> goalsData = {
        'id': userId, // Note: user_macros uses 'id' instead of 'user_id'
        'calories_goal': goals.calories,
        'protein_goal': goals.protein,
        'carbs_goal': goals.carbs,
        'fat_goal': goals.fat,
        'steps_goal': goals.steps,
        'bmr': goals.bmr,
        'tdee': goals.tdee,
        'goal_weight_kg': goals.goalWeightKg,
        'current_weight_kg': goals.currentWeightKg,
        'goal_type': goals.goalType,
        'deficit_surplus': goals.deficitSurplus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'macro_targets': {
          'calories': goals.calories,
          'protein': goals.protein,
          'carbs': goals.carbs,
          'fat': goals.fat,
        },
      };

      await Supabase.instance.client
          .from('user_macros')
          .upsert(goalsData, onConflict: 'id');

      debugPrint('Successfully synced goals to Supabase user_macros table');
    } catch (e) {
      print('Error syncing goals to Supabase: $e');
    }
  }

  /// Load goals from Supabase
  Future<NutritionGoals?> loadGoalsFromSupabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      // First try nutrition_goals table
      final response = await Supabase.instance.client
          .from('nutrition_goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null) {
        debugPrint(
            '[NutritionGoalsRepository] Found data in nutrition_goals table: calories=${response['calories_goal']}');
        return NutritionGoals(
          calories: (response['calories_goal'] as num?)?.toDouble() ?? 2000.0,
          protein: (response['protein_goal'] as num?)?.toDouble() ?? 150.0,
          carbs: (response['carbs_goal'] as num?)?.toDouble() ?? 225.0,
          fat: (response['fat_goal'] as num?)?.toDouble() ?? 65.0,
          steps: response['steps_goal'] ?? 10000,
          bmr: (response['bmr'] as num?)?.toDouble() ?? 1500.0,
          tdee: (response['tdee'] as num?)?.toDouble() ?? 2000.0,
          goalWeightKg: (response['goal_weight_kg'] as num?)?.toDouble() ?? 0.0,
          currentWeightKg:
              (response['current_weight_kg'] as num?)?.toDouble() ?? 0.0,
          goalType: response['goal_type'] ?? 'maintain',
          deficitSurplus: response['deficit_surplus'] ?? 500,
        );
      }

      // Fallback to user_macros table (which has the actual data based on auth_gate logs)
      debugPrint(
          '[NutritionGoalsRepository] No data in nutrition_goals table, trying user_macros...');
      final userMacrosResponse = await Supabase.instance.client
          .from('user_macros')
          .select()
          .eq('id', userId)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (userMacrosResponse != null) {
        debugPrint(
            '[NutritionGoalsRepository] Found data in user_macros table: calories=${userMacrosResponse['calories_goal']}');
        return NutritionGoals(
          calories: (userMacrosResponse['calories_goal'] as num?)?.toDouble() ??
              2000.0,
          protein:
              (userMacrosResponse['protein_goal'] as num?)?.toDouble() ?? 150.0,
          carbs:
              (userMacrosResponse['carbs_goal'] as num?)?.toDouble() ?? 225.0,
          fat: (userMacrosResponse['fat_goal'] as num?)?.toDouble() ?? 65.0,
          steps: userMacrosResponse['steps_goal'] ?? 10000,
          bmr: (userMacrosResponse['bmr'] as num?)?.toDouble() ?? 1500.0,
          tdee: (userMacrosResponse['tdee'] as num?)?.toDouble() ?? 2000.0,
          goalWeightKg:
              (userMacrosResponse['goal_weight_kg'] as num?)?.toDouble() ?? 0.0,
          currentWeightKg:
              (userMacrosResponse['current_weight_kg'] as num?)?.toDouble() ??
                  0.0,
          goalType: userMacrosResponse['goal_type'] ?? 'maintain',
          deficitSurplus: userMacrosResponse['deficit_surplus'] ?? 500,
        );
      }

      debugPrint('[NutritionGoalsRepository] No data found in either table');
      return null;
    } catch (e) {
      print('Error loading goals from Supabase: $e');
      return null;
    }
  }

  /// Clear all stored goals
  Future<void> clearGoals() async {
    try {
      await _storage.delete('nutrition_goals');
      await _storage.delete('calories_goal');
      await _storage.delete('protein_goal');
      await _storage.delete('carbs_goal');
      await _storage.delete('fat_goal');
    } catch (e) {
      print('Error clearing nutrition goals: $e');
    }
  }
}
