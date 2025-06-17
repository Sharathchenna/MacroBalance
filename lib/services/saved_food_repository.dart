import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saved_food.dart';
import '../services/storage_service.dart';

class SavedFoodRepository {
  static const String _storageKey = 'saved_foods';
  final StorageService _storage = StorageService();
  static const int _maxBatchSize = 50;
  static const Duration _timeout = Duration(seconds: 10);

  // Load saved foods from local storage with error handling
  Future<List<SavedFood>> loadFromLocal() async {
    print('SavedFoodRepository: Loading from local storage...');
    try {
      final String? savedFoodsJson = _storage.get(_storageKey);
      print('SavedFoodRepository: Retrieved JSON from storage: ${savedFoodsJson?.length ?? 0} characters');
      
      if (savedFoodsJson == null || savedFoodsJson.isEmpty) {
        print('SavedFoodRepository: No saved foods found in local storage');
        return [];
      }

      final List<dynamic> decodedList = jsonDecode(savedFoodsJson);
      print('SavedFoodRepository: Decoded ${decodedList.length} items from JSON');
      
      final savedFoods = decodedList
          .map((json) => SavedFood.fromJson(json as Map<String, dynamic>))
          .toList();
      
      print('SavedFoodRepository: Successfully loaded ${savedFoods.length} saved foods from local storage');
      return savedFoods;
    } catch (e) {
      print('SavedFoodRepository: Error loading saved foods from local storage: $e');
      debugPrint('Error loading saved foods from local storage: $e');
      // Try to recover corrupted data
      await _storage.delete(_storageKey);
      return [];
    }
  }

  // Save saved foods to local storage with retries
  Future<void> saveToLocal(List<SavedFood> savedFoods) async {
    print('SavedFoodRepository: Saving ${savedFoods.length} foods to local storage...');
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        final String encodedJson = jsonEncode(
            savedFoods.map((savedFood) => savedFood.toJson()).toList());
        print('SavedFoodRepository: Encoded JSON length: ${encodedJson.length} characters');
        await _storage.put(_storageKey, encodedJson);
        print('SavedFoodRepository: Successfully saved ${savedFoods.length} foods to local storage');
        return;
      } catch (e) {
        retryCount++;
        print('SavedFoodRepository: Error saving to local storage (attempt $retryCount): $e');
        debugPrint('Error saving to local storage (attempt $retryCount): $e');
        if (retryCount == maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
  }

  // Load saved foods from Supabase cloud with batch loading and pagination
  Future<List<SavedFood>> loadFromCloud({
    int page = 0,
    int pageSize = 20,
    bool useBatching = true,
  }) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        return [];
      }

      if (!useBatching || pageSize <= _maxBatchSize) {
        return _loadSingleBatch(user.id, page, pageSize);
      }

      // Calculate number of batches needed
      final numBatches = (pageSize / _maxBatchSize).ceil();
      final List<SavedFood> allFoods = [];

      // Load all batches concurrently with individual timeouts
      final futures = List.generate(numBatches, (batchIndex) {
        final batchSize = (batchIndex == numBatches - 1)
            ? pageSize - (numBatches - 1) * _maxBatchSize
            : _maxBatchSize;

        return _loadSingleBatch(
          user.id,
          page * numBatches + batchIndex,
          batchSize,
        ).timeout(_timeout);
      });

      // Wait for all batches
      final results = await Future.wait(futures);

      // Combine results
      for (var foods in results) {
        allFoods.addAll(foods);
      }

      return allFoods;
    } catch (e) {
      debugPrint('Error loading saved foods from cloud: $e');
      rethrow;
    }
  }

  // Helper method to load a single batch
  Future<List<SavedFood>> _loadSingleBatch(
    String userId,
    int page,
    int batchSize,
  ) async {
    try {
      final response = await Supabase.instance.client
          .from('saved_foods')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .range(page * batchSize, (page + 1) * batchSize - 1);

      return (response as List)
          .map((json) => SavedFood.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading batch (page: $page, size: $batchSize): $e');
      rethrow;
    }
  }

  // Save saved foods to Supabase cloud with batching
  Future<void> saveToCloud(List<SavedFood> savedFoods) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Split into batches if needed
      for (var i = 0; i < savedFoods.length; i += _maxBatchSize) {
        final end = (i + _maxBatchSize < savedFoods.length)
            ? i + _maxBatchSize
            : savedFoods.length;
        final batch = savedFoods.sublist(i, end);

        // Convert batch to JSON
        final List<Map<String, dynamic>> jsonBatch =
            batch.map((savedFood) => savedFood.toJson()).toList();

        // Insert or update batch in Supabase
        await Supabase.instance.client
            .from('saved_foods')
            .upsert(jsonBatch)
            .timeout(_timeout);
      }
    } catch (e) {
      debugPrint('Error saving saved foods to cloud: $e');
      rethrow;
    }
  }

  // Delete a saved food from Supabase cloud with retries
  Future<void> deleteFromCloud(String savedFoodId) async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        await Supabase.instance.client
            .from('saved_foods')
            .delete()
            .eq('id', savedFoodId)
            .timeout(_timeout);
        return;
      } catch (e) {
        retryCount++;
        debugPrint('Error deleting from cloud (attempt $retryCount): $e');
        if (retryCount == maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * retryCount));
      }
    }
  }
} 