import 'dart:convert';
import '../models/foodEntry.dart';
import '../services/storage_service.dart';
import '../screens/searchPage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class FoodEntryRepository {
  static const String _storageKey = 'food_entries';
  static const String _fatSecretProxyUrl =
      'https://mdivtblabmnftdqlgysv.supabase.co/functions/v1/fatsecret-proxy';

  final StorageService _storage = StorageService();

  /// Load entries from local storage
  Future<List<FoodEntry>> loadFromLocal() async {
    try {
      final String? entriesJson = _storage.get(_storageKey);
      if (entriesJson == null || entriesJson.isEmpty) {
        return [];
      }

      final List<dynamic> decodedList = jsonDecode(entriesJson);
      return decodedList
          .map((json) => FoodEntry.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading entries from local storage: $e');
      return [];
    }
  }

  /// Save entries to local storage
  Future<void> saveToLocal(List<FoodEntry> entries) async {
    try {
      final String entriesJson =
          jsonEncode(entries.map((e) => e.toJson()).toList());
      await _storage.put(_storageKey, entriesJson);
    } catch (e) {
      print('Error saving entries to local storage: $e');
    }
  }

  /// Sync single entry to Supabase
  Future<void> syncEntryToSupabase(FoodEntry entry) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print('Cannot sync entry: User not logged in');
      return;
    }

    try {
      final Map<String, dynamic> entryData = {
        'entry_id': entry.id,
        'user_id': userId,
        'fdc_id': entry.food.fdcId,
        'food_name': entry.food.name,
        'brand_name': entry.food.brandName,
        'meal': entry.meal,
        'quantity': entry.quantity,
        'unit': entry.unit,
        'entry_date': entry.date.toUtc().toIso8601String(),
        'serving_description': entry.servingDescription,
        'calories_per_entry': entry.food.calories,
        'protein_per_entry': entry.food.nutrients['Protein'] ?? 0.0,
        'carbs_per_entry':
            entry.food.nutrients['Carbohydrate, by difference'] ?? 0.0,
        'fat_per_entry': entry.food.nutrients['Total lipid (fat)'] ?? 0.0,
      };

      await Supabase.instance.client.from('food_log').upsert(entryData);
      print('Successfully synced entry ${entry.id} to Supabase');
    } catch (e) {
      print('Error syncing entry ${entry.id} to Supabase: $e');
    }
  }

  /// Delete entry from Supabase
  Future<void> deleteFromSupabase(String entryId) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print('Cannot delete entry: User not logged in');
      return;
    }

    try {
      await Supabase.instance.client
          .from('food_log')
          .delete()
          .match({'entry_id': entryId, 'user_id': userId});
      print('Successfully deleted entry $entryId from Supabase');
    } catch (e) {
      print('Error deleting entry $entryId from Supabase: $e');
    }
  }

  /// Load entries from Supabase
  Future<List<FoodEntry>> loadFromSupabase() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        print('Cannot load entries: User not logged in');
        return [];
      }

      // Add timeout to the Supabase query itself
      final response = await Supabase.instance.client
          .from('food_log')
          .select()
          .eq('user_id', userId)
          .timeout(
              const Duration(seconds: 15)); // 15 second timeout for DB query

      List<FoodEntry> entries = [];
      for (final record in response) {
        try {
          // Try to create entry, but don't let individual failures block the whole operation
          final entry = await _createEntryFromSupabaseRecord(record).timeout(
              const Duration(seconds: 12)); // 12 second timeout per entry
          if (entry != null) {
            entries.add(entry);
          }
        } catch (e) {
          print('Error creating entry from record ${record['entry_id']}: $e');
          // Continue with other entries instead of failing completely
          continue;
        }
      }

      print('Loaded ${entries.length} entries from Supabase');
      return entries;
    } catch (e) {
      print('Error loading entries from Supabase (possibly offline): $e');
      return [];
    }
  }

  /// Create FoodEntry from Supabase record
  Future<FoodEntry?> _createEntryFromSupabaseRecord(
      Map<String, dynamic> record) async {
    try {
      final String entryId = record['entry_id']?.toString() ?? '';
      final String brandName = record['brand_name']?.toString() ?? '';
      final String foodId = record['fdc_id']?.toString() ?? '';

      if (entryId.isEmpty) {
        print('Warning: Empty entry ID in Supabase record');
        return null;
      }

      FoodItem? foodItem;

      if (brandName == 'AI Detected') {
        // Create FoodItem from stored Supabase data for AI entries
        foodItem = FoodItem(
          fdcId: foodId,
          name: record['food_name'] ?? 'Unknown AI Food',
          brandName: brandName,
          mealType: record['meal'] ?? 'Unknown',
          calories: (record['calories_per_entry'] as num?)?.toDouble() ?? 0.0,
          nutrients: {
            'Protein': (record['protein_per_entry'] as num?)?.toDouble() ?? 0.0,
            'Carbohydrate, by difference':
                (record['carbs_per_entry'] as num?)?.toDouble() ?? 0.0,
            'Total lipid (fat)':
                (record['fat_per_entry'] as num?)?.toDouble() ?? 0.0,
            'Fiber': 0.0, // Not stored for AI entries
          },
          servingSize: 100.0,
          servings: [],
        );
      } else {
        // Fetch full details from FatSecret for regular foods
        if (foodId.isEmpty) {
          print('Warning: Missing food ID for regular food entry $entryId');
          return null;
        }
        foodItem = await _fetchFoodDetailsFromFatSecret(foodId);
      }

      if (foodItem == null) {
        print('Warning: Could not create FoodItem for entry $entryId');
        return null;
      }

      return FoodEntry(
        id: entryId,
        food: foodItem,
        meal: record['meal'] ?? 'Unknown',
        quantity: (record['quantity'] as num?)?.toDouble() ?? 0.0,
        unit: record['unit'] ?? '',
        date: DateTime.parse(record['entry_date']).toLocal(),
        servingDescription: record['serving_description'],
      );
    } catch (e) {
      print('Error creating entry from Supabase record: $e');
      return null;
    }
  }

  /// Fetch food details from FatSecret API
  Future<FoodItem?> _fetchFoodDetailsFromFatSecret(String foodId) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      print('Cannot fetch food details: User not authenticated');
      return null;
    }

    if (foodId.isEmpty) {
      print('Cannot fetch food details: Empty food ID');
      return null;
    }

    try {
      final response = await http
          .post(
        Uri.parse(_fatSecretProxyUrl),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'endpoint': 'get',
          'query': foodId,
        }),
      )
          .timeout(
        const Duration(seconds: 10), // 10 second timeout
        onTimeout: () {
          print('FatSecret API timeout for food ID $foodId');
          throw Exception('Request timed out');
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody != null && responseBody['food'] != null) {
          return FoodItem.fromFatSecretJson(
              responseBody['food'] as Map<String, dynamic>);
        } else {
          print('Invalid response structure for food ID $foodId');
          return null;
        }
      } else {
        print(
            'FatSecret API error for food ID $foodId: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      print('Error fetching food details for ID $foodId: $e');
      return null;
    }
  }

  /// Clear all entries from local storage
  Future<void> clearLocal() async {
    try {
      await _storage.delete(_storageKey);
      print('Cleared all entries from local storage');
    } catch (e) {
      print('Error clearing entries from local storage: $e');
    }
  }

  /// Sync all entries to Supabase (batch operation)
  Future<void> syncAllToSupabase(List<FoodEntry> entries) async {
    for (final entry in entries) {
      await syncEntryToSupabase(entry);
    }
  }
}
