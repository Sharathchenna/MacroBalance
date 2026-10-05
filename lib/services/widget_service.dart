import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:macrotracker/main.dart';
import 'package:macrotracker/services/storage_service.dart'; // Import StorageService
import 'package:macrotracker/models/foodEntry.dart';

// Constants for app group and widget kinds
const String APP_GROUP = 'group.app.macrobalance.com';
const String MACRO_DATA_KEY = 'macro_data';
const String DAILY_MEALS_KEY = 'daily_meals';

class WidgetService {
  static const String WIDGET_UPDATE_ACTION =
      "app.macrobalance.com.WIDGET_UPDATE";

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

      // Save data using HomeWidget plugin
      await _saveWithHomeWidget(MACRO_DATA_KEY, jsonData);
      // Backup save method removed as it used the wrong container

      debugPrint(
          'Widget macro data updated: ${jsonData.substring(0, min(50, jsonData.length))}...');

      // Trigger widget update
      await _updateWidgets();
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }

  /// Update widget with today's most recent meals. [caloriesOf] must be the
  /// provider's own calculation so servings and AI foods are counted correctly.
  static Future<void> updateRecentMeals(
    List<FoodEntry> todayEntries,
    double Function(FoodEntry entry) caloriesOf,
  ) async {
    try {
      // Entries are dated at midnight of their day, so stamp them with "now"
      // (offset per item: the widget keys rows by name + timestamp).
      final now = DateTime.now().millisecondsSinceEpoch;
      final recent = todayEntries.reversed.take(5).toList();
      final meals = [
        for (var i = 0; i < recent.length; i++)
          {
            'name': recent[i].food.name,
            'calories': caloriesOf(recent[i]),
            'meal': recent[i].meal,
            'timestamp': now - i,
          }
      ];

      await _saveWithHomeWidget(DAILY_MEALS_KEY, jsonEncode(meals));
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

  // Removed _saveToUserDefaults as it saved to the wrong container for iOS widgets

  /// Trigger a widget update
  static Future<void> _updateWidgets() async {
    try {
      // Update the iOS widget specifically
      await HomeWidget.updateWidget(iOSName: 'MacroTrackerWidget');
      debugPrint('Widget update triggered for iOSName: MacroTrackerWidget');
    } catch (e) {
      debugPrint('Critical error updating widgets: $e');
    }
  }

  // Add a new method to force a reload of all widget data
  static Future<void> forceWidgetRefresh() async {
    try {
      debugPrint('Forcing widget refresh...');

      // Get current data from StorageService (synchronous)
      try {
        final keysToRefresh = [MACRO_DATA_KEY, DAILY_MEALS_KEY];
        final currentData = <String, String>{};
        for (final key in keysToRefresh) {
          // Use StorageService().get - it returns dynamic, cast if needed or handle null
          final dynamic value = StorageService().get(key);
          if (value != null && value is String) { // Ensure it's a non-null string
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
