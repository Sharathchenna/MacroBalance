// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import '../models/foodEntry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/widget_service.dart';

class FoodEntryProvider with ChangeNotifier {
  final List<FoodEntry> _entries = [];
  static const String _storageKey = 'food_entries';
  
  // Daily nutrition goals
  double _caloriesGoal = 2000.0;
  double _proteinGoal = 150.0;
  double _carbsGoal = 225.0;
  double _fatGoal = 65.0;

  FoodEntryProvider() {
    _loadEntries();
    _loadNutritionGoals();
  }

  List<FoodEntry> get entries => _entries;
  
  double get caloriesGoal => _caloriesGoal;
  double get proteinGoal => _proteinGoal;
  double get carbsGoal => _carbsGoal;
  double get fatGoal => _fatGoal;
  
  set caloriesGoal(double value) {
    _caloriesGoal = value;
    _saveNutritionGoals();
    notifyListeners();
    _updateWidgets();
  }
  
  set proteinGoal(double value) {
    _proteinGoal = value;
    _saveNutritionGoals();
    notifyListeners();
    _updateWidgets();
  }
  
  set carbsGoal(double value) {
    _carbsGoal = value;
    _saveNutritionGoals();
    notifyListeners();
    _updateWidgets();
  }
  
  set fatGoal(double value) {
    _fatGoal = value;
    _saveNutritionGoals();
    notifyListeners();
    _updateWidgets();
  }

  Future<void> _loadEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? entriesJson = prefs.getString(_storageKey);
      if (entriesJson != null) {
        final List<dynamic> decodedEntries = jsonDecode(entriesJson);
        _entries.clear();
        _entries.addAll(
          decodedEntries.map((entry) => FoodEntry.fromJson(entry)).toList(),
        );
        notifyListeners();
        _updateWidgets();
      }
    } catch (e) {
      debugPrint('Error loading food entries: $e');
    }
  }
  
  Future<void> _loadNutritionGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _caloriesGoal = prefs.getDouble('calories_goal') ?? 2000.0;
      _proteinGoal = prefs.getDouble('protein_goal') ?? 150.0;
      _carbsGoal = prefs.getDouble('carbs_goal') ?? 225.0;
      _fatGoal = prefs.getDouble('fat_goal') ?? 65.0;
    } catch (e) {
      debugPrint('Error loading nutrition goals: $e');
    }
  }
  
  Future<void> _saveNutritionGoals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('calories_goal', _caloriesGoal);
      await prefs.setDouble('protein_goal', _proteinGoal);
      await prefs.setDouble('carbs_goal', _carbsGoal);
      await prefs.setDouble('fat_goal', _fatGoal);
    } catch (e) {
      debugPrint('Error saving nutrition goals: $e');
    }
  }

  Future<void> _saveEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String entriesJson = jsonEncode(
        _entries.map((entry) => entry.toJson()).toList(),
      );
      await prefs.setString(_storageKey, entriesJson);
      _updateWidgets();
    } catch (e) {
      debugPrint('Error saving food entries: $e');
    }
  }

  List<FoodEntry> getEntriesForDate(DateTime date) {
    return _entries
        .where((entry) =>
            entry.date.year == date.year &&
            entry.date.month == date.month &&
            entry.date.day == date.day)
        .toList();
  }

  List<FoodEntry> getEntriesForMeal(String meal, DateTime date) {
    return _entries
        .where((entry) =>
            entry.meal == meal &&
            entry.date.year == date.year &&
            entry.date.month == date.month &&
            entry.date.day == date.day)
        .toList();
  }

  Future<void> addEntry(FoodEntry entry) async {
    _entries.add(entry);
    notifyListeners();
    await _saveEntries();
  }

  Future<void> removeEntry(String id) async {
    _entries.removeWhere((entry) => entry.id == id);
    notifyListeners();
    await _saveEntries();
  }

  Future<void> clearEntries() async {
    _entries.clear();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }

  double getTotalCaloriesForDate(DateTime date) {
    final entriesForDate = getEntriesForDate(date);
    return entriesForDate.fold(0, (sum, entry) {
      double multiplier = entry.quantity;
      // Convert to grams if needed
      switch (entry.unit) {
        case "oz":
          multiplier *= 28.35;
          break;
        case "kg":
          multiplier *= 1000;
          break;
        case "lbs":
          multiplier *= 453.59;
          break;
      }
      multiplier /= 100; // Since calories are per 100g
      return sum + (entry.food.calories * multiplier);
    });
  }

  List<FoodEntry> getAllEntriesForDate(DateTime date) {
    return _entries
        .where((entry) =>
            entry.date.year == date.year &&
            entry.date.month == date.month &&
            entry.date.day == date.day)
        .toList();
  }

  /// Update iOS homescreen widgets with latest data
  Future<void> _updateWidgets() async {
    try {
      // Get today's entries
      final today = DateTime.now();
      final todayEntries = getEntriesForDate(today);
      
      if (todayEntries.isEmpty) return;
      
      // Calculate total macros for today
      double totalCalories = 0;
      double totalProtein = 0;
      double totalCarbs = 0;
      double totalFat = 0;
      
      for (var entry in todayEntries) {
        // Convert from per 100g to actual amount based on quantity
        totalCalories += entry.food.calories * entry.quantity / 100;
        totalProtein += (entry.food.nutrients['Protein'] ?? 0.0) * entry.quantity / 100;
        totalCarbs += (entry.food.nutrients['Carbohydrate, by difference'] ?? 0.0) * entry.quantity / 100;
        totalFat += (entry.food.nutrients['Total lipid (fat)'] ?? 0.0) * entry.quantity / 100;
      }
      
      // Update macro widget with current progress
      await WidgetService.updateMacroWidget(
        totalCalories,
        totalProtein,
        totalCarbs,
        totalFat,
        _caloriesGoal,
        _proteinGoal,
        _carbsGoal,
        _fatGoal,
      );
      
      // Update recent meals widget
      await WidgetService.updateRecentMeals(todayEntries);
      
    } catch (e) {
      debugPrint('Error updating widgets: $e');
    }
  }
}
