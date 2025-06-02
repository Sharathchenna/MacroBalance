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

  // Persistent HTTP client for better connection reuse
  static http.Client? _httpClient;
  static http.Client get httpClient {
    _httpClient ??= http.Client();
    return _httpClient!;
  }

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

  /// Load entries from Supabase (optimized)
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
          .timeout(const Duration(seconds: 10)); // Reduced timeout for DB query

      // Batch process entries to avoid blocking UI
      List<FoodEntry> entries = [];

      // Group records by type for optimized processing
      final aiRecords = <Map<String, dynamic>>[];
      final regularRecords = <Map<String, dynamic>>[];

      for (final record in response) {
        final brandName = record['brand_name']?.toString() ?? '';
        if (brandName == 'AI Detected') {
          aiRecords.add(record);
        } else {
          regularRecords.add(record);
        }
      }

      // Process AI entries in batches (these are fast as they don't need API calls)
      for (int i = 0; i < aiRecords.length; i += 50) {
        final batch = aiRecords.skip(i).take(50).toList();
        final batchEntries =
            await _processBatchRecords(batch, isAiEntries: true);
        entries.addAll(batchEntries);

        // Add small delay to prevent blocking UI
        if (i + 50 < aiRecords.length) {
          await Future.delayed(const Duration(milliseconds: 1));
        }
      }

      // Process regular entries in smaller batches (these require API calls)
      for (int i = 0; i < regularRecords.length; i += 10) {
        final batch = regularRecords.skip(i).take(10).toList();
        final batchEntries =
            await _processBatchRecords(batch, isAiEntries: false);
        entries.addAll(batchEntries);

        // Add delay between batches to prevent overwhelming the API
        if (i + 10 < regularRecords.length) {
          await Future.delayed(const Duration(milliseconds: 100));
        }
      }

      print('Loaded ${entries.length} entries from Supabase (optimized)');
      return entries;
    } catch (e) {
      print('Error loading entries from Supabase (possibly offline): $e');
      return [];
    }
  }

  /// Process a batch of records efficiently
  Future<List<FoodEntry>> _processBatchRecords(
      List<Map<String, dynamic>> records,
      {required bool isAiEntries}) async {
    final List<FoodEntry> entries = [];

    if (isAiEntries) {
      // AI entries can be processed quickly without API calls
      for (final record in records) {
        try {
          final entry = await _createAiEntryFromRecord(record);
          if (entry != null) {
            entries.add(entry);
          }
        } catch (e) {
          print(
              'Error creating AI entry from record ${record['entry_id']}: $e');
          continue;
        }
      }
    } else {
      // Regular entries require API calls - process with timeouts
      await Future.wait(
        records.map((record) async {
          try {
            final entry = await _createEntryFromSupabaseRecord(record).timeout(
              const Duration(seconds: 8), // Reduced timeout per entry
            );
            if (entry != null) {
              entries.add(entry);
            }
          } catch (e) {
            print('Error creating entry from record ${record['entry_id']}: $e');
          }
        }),
        eagerError: false, // Don't stop on individual failures
      );
    }

    return entries;
  }

  /// Fast creation of AI entries (no API calls needed)
  Future<FoodEntry?> _createAiEntryFromRecord(
      Map<String, dynamic> record) async {
    try {
      final String entryId = record['entry_id']?.toString() ?? '';
      if (entryId.isEmpty) {
        return null;
      }

      final foodItem = FoodItem(
        fdcId: record['fdc_id']?.toString() ?? '',
        name: record['food_name'] ?? 'Unknown AI Food',
        brandName: 'AI Detected',
        mealType: record['meal'] ?? 'Unknown',
        calories: (record['calories_per_entry'] as num?)?.toDouble() ?? 0.0,
        nutrients: {
          'Protein': (record['protein_per_entry'] as num?)?.toDouble() ?? 0.0,
          'Carbohydrate, by difference':
              (record['carbs_per_entry'] as num?)?.toDouble() ?? 0.0,
          'Total lipid (fat)':
              (record['fat_per_entry'] as num?)?.toDouble() ?? 0.0,
          'Fiber': 0.0,
        },
        servingSize: 100.0,
        servings: [],
      );

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
      print('Error creating AI entry: $e');
      return null;
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
        // Use the optimized AI entry creation method
        return await _createAiEntryFromRecord(record);
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

  // Cache for FatSecret API responses to avoid duplicate calls
  static final Map<String, FoodItem?> _fatSecretCache = {};
  static final Map<String, DateTime> _fatSecretCacheTimestamp = {};
  static const Duration _fatSecretCacheDuration = Duration(hours: 24);

  /// Fetch food details from FatSecret API (optimized with caching)
  Future<FoodItem?> _fetchFoodDetailsFromFatSecret(String foodId) async {
    if (foodId.isEmpty) {
      print('Cannot fetch food details: Empty food ID');
      return null;
    }

    // Check cache first
    if (_fatSecretCache.containsKey(foodId)) {
      final cacheTime = _fatSecretCacheTimestamp[foodId];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime) < _fatSecretCacheDuration) {
        return _fatSecretCache[foodId];
      }
    }

    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      print('Cannot fetch food details: User not authenticated');
      return null;
    }

    try {
      final response = await httpClient
          .post(
        Uri.parse(_fatSecretProxyUrl),
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
          'Connection': 'keep-alive', // Optimize connection reuse
        },
        body: jsonEncode({
          'endpoint': 'get',
          'query': foodId,
        }),
      )
          .timeout(
        const Duration(seconds: 6), // Reduced timeout
        onTimeout: () {
          print('FatSecret API timeout for food ID $foodId');
          throw Exception('Request timed out');
        },
      );

      FoodItem? foodItem;
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        if (responseBody != null && responseBody['food'] != null) {
          foodItem = FoodItem.fromFatSecretJson(
              responseBody['food'] as Map<String, dynamic>);
        } else {
          print('Invalid response structure for food ID $foodId');
        }
      } else {
        print(
            'FatSecret API error for food ID $foodId: ${response.statusCode} ${response.body}');
      }

      // Cache the result (even if null to avoid repeated failed calls)
      _fatSecretCache[foodId] = foodItem;
      _fatSecretCacheTimestamp[foodId] = DateTime.now();

      // Clean up old cache entries periodically
      _cleanupFatSecretCache();

      return foodItem;
    } catch (e) {
      print('Error fetching food details for ID $foodId: $e');

      // Cache null result to avoid immediate retry
      _fatSecretCache[foodId] = null;
      _fatSecretCacheTimestamp[foodId] = DateTime.now();

      return null;
    }
  }

  /// Clean up old cache entries to prevent memory issues
  void _cleanupFatSecretCache() {
    if (_fatSecretCache.length > 1000) {
      // Keep cache size reasonable
      final now = DateTime.now();
      final keysToRemove = <String>[];

      _fatSecretCacheTimestamp.forEach((key, timestamp) {
        if (now.difference(timestamp) > _fatSecretCacheDuration) {
          keysToRemove.add(key);
        }
      });

      for (final key in keysToRemove) {
        _fatSecretCache.remove(key);
        _fatSecretCacheTimestamp.remove(key);
      }
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
