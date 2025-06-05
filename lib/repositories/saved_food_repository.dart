import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/saved_food.dart';
import '../services/storage_service.dart';

class SavedFoodRepository {
  static const String _storageKey = 'saved_foods';
  final StorageService _storage = StorageService();

  // Load saved foods from local storage
  Future<List<SavedFood>> loadFromLocal() async {
    try {
      final String? savedFoodsJson = _storage.get(_storageKey);
      if (savedFoodsJson == null || savedFoodsJson.isEmpty) {
        return [];
      }

      final List<dynamic> decodedList = jsonDecode(savedFoodsJson);
      return decodedList
          .map((json) => SavedFood.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading saved foods from local storage: $e');
      return [];
    }
  }

  // Save saved foods to local storage
  Future<void> saveToLocal(List<SavedFood> savedFoods) async {
    try {
      final String encodedJson = jsonEncode(
          savedFoods.map((savedFood) => savedFood.toJson()).toList());
      _storage.put(_storageKey, encodedJson);
    } catch (e) {
      debugPrint('Error saving saved foods to local storage: $e');
      rethrow;
    }
  }

  // Load saved foods from Supabase cloud
  Future<List<SavedFood>> loadFromCloud() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        return [];
      }

      final response = await Supabase.instance.client
          .from('saved_foods')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => SavedFood.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error loading saved foods from cloud: $e');
      return [];
    }
  }

  // Save saved foods to Supabase cloud
  Future<void> saveToCloud(List<SavedFood> savedFoods) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      // Convert to JSON
      final List<Map<String, dynamic>> jsonList =
          savedFoods.map((savedFood) => savedFood.toJson()).toList();

      // Insert or update in Supabase
      await Supabase.instance.client.from('saved_foods').upsert(jsonList);
    } catch (e) {
      debugPrint('Error saving saved foods to cloud: $e');
      rethrow;
    }
  }

  // Delete a saved food from Supabase cloud
  Future<void> deleteFromCloud(String savedFoodId) async {
    try {
      await Supabase.instance.client
          .from('saved_foods')
          .delete()
          .eq('id', savedFoodId);
    } catch (e) {
      debugPrint('Error deleting saved food from cloud: $e');
      rethrow;
    }
  }
}
