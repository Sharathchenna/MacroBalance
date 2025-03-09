// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import '../models/foodEntry.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FoodEntryProvider with ChangeNotifier {
  final List<FoodEntry> _entries = [];
  static const String _storageKey = 'food_entries';

  FoodEntryProvider() {
    _loadEntries();
  }

  List<FoodEntry> get entries => _entries;

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
      }
    } catch (e) {
      debugPrint('Error loading food entries: $e');
    }
  }

  Future<void> _saveEntries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String entriesJson = jsonEncode(
        _entries.map((entry) => entry.toJson()).toList(),
      );
      await prefs.setString(_storageKey, entriesJson);
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
}
