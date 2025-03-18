import '../utils/json_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final supabaseClient = Supabase.instance.client;

  Future<void> fullSync(String userId) async {
    print('Starting full data sync with Supabase...');
    print('User ID: $userId');

    try {
      // First sync nutrition goals
      await syncNutritionGoals(userId);

      // Then sync food entries
      await syncFoodEntries(userId);

      // Verify the sync
      await verifySync(userId);

      print('All data sync process completed');
    } catch (e) {
      print('Error during full sync: $e');
      rethrow;
    }
  }

  Future<void> syncNutritionGoals(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localGoalsJson = prefs.getString('nutrition_goals');

      // Fetch current Supabase goals
      final supabaseGoals = await supabaseClient
          .from('nutrition_goals')
          .select()
          .eq('user_id', userId)
          .single();

      if (localGoalsJson == null || localGoalsJson.isEmpty) {
        // If no local goals, save Supabase goals locally
        if (supabaseGoals != null) {
          await prefs.setString('nutrition_goals', json.encode(supabaseGoals));
        }
        return;
      }

      final localGoals = json.decode(localGoalsJson);

      // Update Supabase if local goals exist
      await supabaseClient.from('nutrition_goals').upsert([
        {...localGoals, 'user_id': userId}
      ]);

      // Get latest goals from Supabase and update local storage
      final updatedGoals = await supabaseClient
          .from('nutrition_goals')
          .select()
          .eq('user_id', userId)
          .single();

      if (updatedGoals != null) {
        await prefs.setString('nutrition_goals', json.encode(updatedGoals));
      }
    } catch (e) {
      print('Error syncing nutrition goals: $e');
      rethrow;
    }
  }

  Future<void> syncFoodEntries(String userId) async {
    try {
      final foodEntries = await _getFoodEntriesFromLocal();

      // Fetch current Supabase entries
      final supabaseEntries = await supabaseClient
          .from('food_entries')
          .select()
          .eq('user_id', userId);

      if (foodEntries.isEmpty) {
        print('No local food entries, updating from Supabase');
        await _updateLocalFoodEntries(supabaseEntries);
        return;
      }

      print('Syncing food entries with Supabase...');

      // Compare and merge entries
      final localEntries = List<Map<String, dynamic>>.from(foodEntries);
      final remoteEntries = List<Map<String, dynamic>>.from(supabaseEntries);

      // Update remote entries that don't exist in Supabase
      for (var localEntry in localEntries) {
        if (!remoteEntries.any((remote) => remote['id'] == localEntry['id'])) {
          await supabaseClient.from('food_entries').upsert([
            {...localEntry, 'user_id': userId}
          ]);
        }
      }

      // Update local storage with latest Supabase data
      final updatedEntries = await supabaseClient
          .from('food_entries')
          .select()
          .eq('user_id', userId);
      await _updateLocalFoodEntries(updatedEntries);
    } catch (e) {
      print('Error syncing food entries: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> _getFoodEntriesFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final entriesJson = prefs.getString('food_entries');
    if (entriesJson == null || entriesJson.isEmpty) {
      return [];
    }
    return json.decode(entriesJson);
  }

  Future<void> _updateLocalFoodEntries(List<dynamic> supabaseEntries) async {
    final prefs = await SharedPreferences.getInstance();
    if (supabaseEntries.isNotEmpty) {
      await prefs.setString('food_entries', json.encode(supabaseEntries));
    }
  }

  Future<void> verifySync(String userId) async {
    try {
      print('Verifying sync by checking Supabase data...');

      // Check food_entries
      final foodEntryResponse = await supabaseClient
          .from('food_entries')
          .select()
          .eq('user_id', userId);

      // Check nutrition_goals
      final nutritionGoalsResponse = await supabaseClient
          .from('nutrition_goals')
          .select()
          .eq('user_id', userId);

      // Parse nutrition goals response
      if (nutritionGoalsResponse.isNotEmpty) {
        final macroData = nutritionGoalsResponse[0]['macro_targets'];
        final macroTargets = JsonHelper.safelyParseJson(macroData);
        print('Parsed macro targets: $macroTargets');
      }

      int totalEntriesFound =
          foodEntryResponse.length + nutritionGoalsResponse.length;
      print(
          'Verification successful: $totalEntriesFound entries found in Supabase');
    } catch (e) {
      print('Verification error: $e');
      rethrow;
    }
  }
}
