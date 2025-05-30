import 'dart:convert';
import '../services/storage_service.dart';
import '../models/nutrition_goals.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NutritionGoalsRepository {
  final StorageService _storage = StorageService();

  /// Load nutrition goals from local storage
  Future<NutritionGoals> loadGoals() async {
    try {
      // Try individual keys first (these are saved by auth flow)
      final calories = _storage.get('calories_goal');
      final protein = _storage.get('protein_goal');
      final carbs = _storage.get('carbs_goal');
      final fat = _storage.get('fat_goal');

      if (calories != null && protein != null && carbs != null && fat != null) {
        return NutritionGoals(
          calories: (calories as num).toDouble(),
          protein: (protein as num).toDouble(),
          carbs: (carbs as num).toDouble(),
          fat: (fat as num).toDouble(),
        );
      }

      // Fall back to JSON format if individual keys not found
      final String? goalsJson = _storage.get('nutrition_goals');
      if (goalsJson != null && goalsJson.isNotEmpty) {
        final Map<String, dynamic> goalsData = jsonDecode(goalsJson);
        return NutritionGoals.fromJson(goalsData);
      }

      // Return default goals if nothing is found
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
        'user_id': userId,
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
      };

      await Supabase.instance.client.from('nutrition_goals').upsert(goalsData);
    } catch (e) {
      print('Error syncing goals to Supabase: $e');
    }
  }

  /// Load goals from Supabase
  Future<NutritionGoals?> loadGoalsFromSupabase() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return null;

    try {
      final response = await Supabase.instance.client
          .from('nutrition_goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) return null;

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
