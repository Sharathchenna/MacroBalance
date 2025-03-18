import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:macrotracker/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';

// Constants for app group and widget kinds
const String APP_GROUP = 'group.com.sharathchenna.shared';
const String MACRO_DATA_KEY = 'macro_data';
const String DAILY_MEALS_KEY = 'daily_meals';

class WidgetService {
  static const String WIDGET_UPDATE_ACTION =
      "com.sharathchenna88.nutrino.WIDGET_UPDATE";

  /// Initialize the widget service
  static Future<void> initWidgetService() async {
    try {
      // Set up the app group identifier for sharing data with widgets
      await HomeWidget.setAppGroupId(APP_GROUP);

      // Listen for widget launcher taps (when user taps on widget to open app)
      HomeWidget.widgetClicked.listen(_handleWidgetClick);

      debugPrint('WidgetService initialized with app group: $APP_GROUP');
    } catch (e) {
      debugPrint('Error initializing widget service: $e');
    }
  }

  /// Handle when user taps on a widget
  static void _handleWidgetClick(Uri? uri) {
    if (uri != null) {
      debugPrint('Widget clicked with uri: $uri');

      // Extract route from URI and navigate to it
      final route = uri.path;
      if (route.isNotEmpty) {
        // Use navigatorKey to navigate from anywhere
        navigatorKey.currentState?.pushNamed(route);
      } else {
        // Default route if path is empty
        navigatorKey.currentState?.pushNamed(Routes.dashboard);
      }
    }
  }

  /// Update widget with macro data
  static Future<void> updateMacroWidget(
    double calories,
    double protein,
    double carbs,
    double fat,
    double caloriesGoal,
    double proteinGoal,
    double carbsGoal,
    double fatGoal,
  ) async {
    try {
      final data = {
        'calories': calories,
        'caloriesGoal': caloriesGoal,
        'protein': protein,
        'proteinGoal': proteinGoal,
        'carbs': carbs,
        'carbsGoal': carbsGoal,
        'fat': fat,
        'fatGoal': fatGoal,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      final jsonData = jsonEncode(data);

      // Save data using both methods to ensure compatibility
      // 1. Using HomeWidget plugin (primary method)
      bool primarySuccess = await _saveWithHomeWidget(MACRO_DATA_KEY, jsonData);

      // 2. Using UserDefaults directly with App Group (backup method)
      if (!primarySuccess) {
        await _saveToUserDefaults(MACRO_DATA_KEY, jsonData);
      }

      debugPrint(
          'Widget macro data updated: ${jsonData.substring(0, min(50, jsonData.length))}...');

      // Trigger widget update
      await _updateWidgets();
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }

  /// Update widget with recent meals
  static Future<void> updateRecentMeals(List<FoodEntry> entries) async {
    try {
      // Only take meals from today to ensure widget data is current
      final todayStart = DateTime(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final todayEntries =
          entries.where((entry) => entry.date.isAfter(todayStart)).toList();

      final meals = todayEntries
          .take(5)
          .map((entry) => {
                'name': entry.food.name,
                'calories': entry.food.calories * entry.quantity / 100,
                'meal': entry.meal,
                'timestamp': entry.date.millisecondsSinceEpoch,
              })
          .toList();

      final jsonData = jsonEncode(meals);

      // Save using both methods to ensure compatibility
      bool primarySuccess =
          await _saveWithHomeWidget(DAILY_MEALS_KEY, jsonData);

      if (!primarySuccess) {
        await _saveToUserDefaults(DAILY_MEALS_KEY, jsonData);
      }

      debugPrint('Widget meal data updated with ${meals.length} meals');

      // Trigger widget update
      await _updateWidgets();
    } catch (e) {
      debugPrint('Error updating meals widget: $e');
    }
  }

  /// Save using HomeWidget plugin
  static Future<bool> _saveWithHomeWidget(String key, String value) async {
    try {
      await HomeWidget.saveWidgetData(key, value);
      return true;
    } catch (e) {
      debugPrint('Error with HomeWidget data save: $e');
      return false;
    }
  }

  /// Save directly to SharedPreferences
  static Future<void> _saveToUserDefaults(String key, String value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
      debugPrint('Saved widget data using SharedPreferences: $key');
    } catch (e) {
      debugPrint('Error with SharedPreferences save: $e');
    }
  }

  /// Trigger a widget update
  static Future<void> _updateWidgets() async {
    try {
      // Try each update method to ensure widget refreshes

      // Method 1: With all parameters
      try {
        await HomeWidget.updateWidget(
          androidName: 'MacroTrackerWidgetProvider',
          iOSName: 'MacroTrackerWidget',
          qualifiedAndroidName:
              'com.sharathchenna88.nutrino.MacroTrackerWidgetProvider',
        );
        debugPrint('Widget update method 1 success');
      } catch (e) {
        debugPrint('Widget update method 1 failed: $e');

        // Method 2: iOS only
        try {
          await HomeWidget.updateWidget(
            iOSName: 'MacroTrackerWidget',
          );
          debugPrint('Widget update method 2 success');
        } catch (e2) {
          debugPrint('Widget update method 2 failed: $e2');

          // Method 3: Basic update
          try {
            await HomeWidget.updateWidget();
            debugPrint('Widget update method 3 success');
          } catch (e3) {
            debugPrint('All widget update methods failed');
          }
        }
      }
    } catch (e) {
      debugPrint('Critical error updating widgets: $e');
    }
  }

  // Add a new method to force a reload of all widget data
  static Future<void> forceWidgetRefresh() async {
    try {
      debugPrint('Forcing widget refresh...');

      // First try to clear any cached data
      try {
        final prefs = await SharedPreferences.getInstance();
        final keysToRefresh = [MACRO_DATA_KEY, DAILY_MEALS_KEY];

        // Get current data before clearing
        final currentData = <String, String>{};
        for (final key in keysToRefresh) {
          final value = prefs.getString(key);
          if (value != null) {
            currentData[key] = value;
          }
        }

        // Re-save the data to trigger an update
        for (final entry in currentData.entries) {
          await _saveWithHomeWidget(entry.key, entry.value);
        }
      } catch (e) {
        debugPrint('Error during force refresh: $e');
      }

      // Trigger the widget update
      await _updateWidgets();
    } catch (e) {
      debugPrint('Force widget refresh failed: $e');
    }
  }
}

// Extension method to get the minimum of two integers
int min(int a, int b) => a < b ? a : b;
