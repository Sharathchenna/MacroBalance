import '../utils/json_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:macrotracker/services/storage_service.dart'; // Import StorageService
import 'dart:convert';
import 'dart:io'; // Import dart:io for File operations
import 'package:image_picker/image_picker.dart'; // Import image_picker for XFile
import 'package:path/path.dart' as p; // Import path package for extension
import '../models/feedback.dart' as app_feedback; // Import the feedback model

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  static const String _lastSyncKey = 'last_sync_timestamp';

  // Use the client instance defined in the class
  final supabaseClient = Supabase.instance.client;

  // Check if Supabase connection is working
  Future<bool> checkConnection() async {
    try {
      print('Checking Supabase connection...');
      // Use supabaseClient here
      final response = await supabaseClient
          .from('health_check')
          .select()
          .limit(1)
          .maybeSingle();
      print('Supabase connection check response: $response');
      return true;
    } catch (e) {
      print('Supabase connection check failed: $e');
      return false;
    }
  }

  Future<void> syncOnAppStart(String userId) async {
    final lastSyncString = StorageService().get(_lastSyncKey);
    if (lastSyncString != null) {
      final lastSyncTime = DateTime.parse(lastSyncString);
      if (DateTime.now().difference(lastSyncTime) < const Duration(hours: 12)) {
        print('Skipping sync, last sync was less than 12 hours ago.');
        return;
      }
    }
    await fullSync(userId);
  }

  Future<void> fullSync(String userId) async {
    print('Starting full data sync with Supabase...');
    print('User ID: $userId');

    try {
      // First sync nutrition goals
      // await syncNutritionGoals(userId); // Commented out to prevent error on missing table

      // Then sync food entries
      await syncFoodEntries(userId);

      // Verify the sync
      await verifySync(userId);

      print('All data sync process completed');
      StorageService().put(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      print('Error during full sync: $e');
      rethrow;
    }
  }

  Future<void> syncNutritionGoals(String userId) async {
    try {
      // Get local goals from StorageService (synchronous)
      final localGoalsJson = StorageService().get('nutrition_goals');

      // Fetch current Supabase goals using supabaseClient
      final supabaseGoals = await supabaseClient
          .from('nutrition_goals')
          .select()
          .eq('user_id', userId)
          .maybeSingle(); // Use maybeSingle to handle null case gracefully

      if (localGoalsJson == null || localGoalsJson.isEmpty) {
      // If no local goals, save Supabase goals locally (synchronous)
      if (supabaseGoals != null) {
        StorageService().put('nutrition_goals', json.encode(supabaseGoals));
      }
      return;
      }

      final localGoals = json.decode(localGoalsJson);

      // Update Supabase if local goals exist using supabaseClient
      await supabaseClient.from('nutrition_goals').upsert([
        {...localGoals, 'user_id': userId}
      ]);

      // Get latest goals from Supabase and update local storage using supabaseClient
      final updatedGoals = await supabaseClient
          .from('nutrition_goals')
          .select()
          .eq('user_id', userId)
          .single(); // Assuming goals should exist after upsert

      // Save updated goals locally (synchronous)
      StorageService().put('nutrition_goals', json.encode(updatedGoals));
    } catch (e) {
      print('Error syncing nutrition goals: $e');
      rethrow;
    }
  }

  Future<void> syncFoodEntries(String userId) async {
    try {
      final foodEntries = await _getFoodEntriesFromLocal();

      // Fetch current Supabase entries using supabaseClient
      final supabaseEntries = await supabaseClient
          .from('food_entries')
          .select()
          .eq('user_id', userId);

      if (foodEntries.isEmpty) {
        print('No local food entries, updating from Supabase');
        _updateLocalFoodEntries(supabaseEntries); // Now synchronous
        return;
      }

      print('Syncing food entries with Supabase...');

      // Compare and merge entries
      final localEntries = List<Map<String, dynamic>>.from(foodEntries);
      final remoteEntries = List<Map<String, dynamic>>.from(supabaseEntries);

      // Update remote entries that don't exist in Supabase using supabaseClient
      for (var localEntry in localEntries) {
        // Ensure 'id' exists and is not null before comparing
        if (localEntry['id'] != null &&
            !remoteEntries.any((remote) => remote['id'] == localEntry['id'])) {
          await supabaseClient.from('food_entries').upsert([
            {...localEntry, 'user_id': userId}
          ]);
        }
      }

      // Update local storage with latest Supabase data using supabaseClient
      final updatedEntries = await supabaseClient
          .from('food_entries')
          .select()
          .eq('user_id', userId);
      _updateLocalFoodEntries(updatedEntries); // Now synchronous
    } catch (e) {
      print('Error syncing food entries: $e');
      rethrow;
    }
  }

  // Now synchronous
  List<dynamic> _getFoodEntriesFromLocal() {
    // Assuming StorageService is initialized
    final entriesJson = StorageService().get('food_entries');
    if (entriesJson == null || entriesJson.isEmpty || entriesJson is! String) {
      return [];
    }
    // Use safe parsing
    try {
      return json.decode(entriesJson) as List<dynamic>;
    } catch (e) {
      print("Error decoding local food entries: $e");
      StorageService().delete('food_entries'); // Clear corrupted data
      return [];
    }
  }

  // Now synchronous
  void _updateLocalFoodEntries(List<dynamic> supabaseEntries) {
    // Assuming StorageService is initialized
    // Ensure entries are not null before encoding
    if (supabaseEntries != null) {
       StorageService().put('food_entries', json.encode(supabaseEntries));
    } else {
       StorageService().delete('food_entries'); // Clear if null
    }
  }

  Future<void> verifySync(String userId) async {
    try {
      print('Verifying sync by checking Supabase data...');

      // Check food_entries using supabaseClient
      final foodEntryResponse = await supabaseClient
          .from('food_entries')
          .select()
          .eq('user_id', userId);

      // Check nutrition_goals using supabaseClient
      /*
      final nutritionGoalsResponse = await supabaseClient
          .from('nutrition_goals')
          .select()
          .eq('user_id', userId);

      // Parse nutrition goals response safely
      if (nutritionGoalsResponse != null && nutritionGoalsResponse.isNotEmpty) {
        final goalData = nutritionGoalsResponse[0];
        if (goalData != null && goalData['macro_targets'] != null) {
          final macroData = goalData['macro_targets'];
          // Assuming JsonHelper.safelyParseJson exists and works correctly
          final macroTargets = JsonHelper.safelyParseJson(macroData);
          print('Parsed macro targets: $macroTargets');
        } else {
          print('Macro targets data is null or missing.');
        }
      } else {
        print('Nutrition goals response is null or empty.');
      }
      */

      int totalFoodEntries = foodEntryResponse?.length ?? 0;
      // int totalGoalsEntries = nutritionGoalsResponse?.length ?? 0;
      print(
          'Verification successful: $totalFoodEntries food entries found in Supabase');
    } catch (e) {
      print('Verification error: $e');
      rethrow;
    }
  }

  // Method to add feedback/bug report to the 'feedback' table
  Future<void> addFeedback(app_feedback.Feedback feedback) async {
    try {
      // Use supabaseClient here
      await supabaseClient.from('feedback').insert(feedback.toJson());
      print('Feedback/Bug report saved successfully.');
    } catch (e) {
      print('Error saving feedback/bug report to Supabase: $e');
      // Rethrow the error to be handled by the caller
      rethrow;
    }
  }

  // Method to upload screenshot to Supabase Storage
  Future<String?> uploadScreenshot(XFile imageFile) async {
    try {
      final file = File(imageFile.path);
      final fileExt =
          p.extension(file.path); // Get file extension using path package
      final fileName = '${DateTime.now().millisecondsSinceEpoch}$fileExt';
      final filePath =
          'public/$fileName'; // Store in a 'public' folder within the bucket

      // Upload file to 'feedback-screenshots' bucket (hyphenated name)
      await supabaseClient.storage
          .from('feedback-screenshots') // Use the correct bucket name
          .upload(filePath, file);

      // Get the public URL of the uploaded file
      final response = supabaseClient.storage
          .from('feedback-screenshots') // Use the correct bucket name
          .getPublicUrl(filePath);

      print('Screenshot uploaded successfully: $response');
      return response;
    } catch (e) {
      print('Error uploading screenshot to Supabase Storage: $e');
      return null; // Return null if upload fails
    }
  }

  // Add other Supabase related methods here (if any were missed or corrupted)
} // End of SupabaseService class
