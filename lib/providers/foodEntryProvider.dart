// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import '../models/foodEntry.dart';

class FoodEntryProvider with ChangeNotifier {
  final List<FoodEntry> _entries = [];

  List<FoodEntry> get entries => _entries;

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

  void addEntry(FoodEntry entry) {
    _entries.add(entry);
    notifyListeners();
  }

  void removeEntry(String id) {
    _entries.removeWhere((entry) => entry.id == id);
    notifyListeners();
  }

  double getTotalCaloriesForDate(DateTime date) {
    final entriesForDate = getEntriesForDate(date);
    return entriesForDate.fold(0, (sum, entry) {
      final energy = entry.food.calories;
      return sum + (energy * entry.quantity);
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
