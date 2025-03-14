import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';

// Constants for app group and widget kinds
const String APP_GROUP = 'group.com.sharathchenna88.nutrino'; // Updated with actual bundle ID
const String MACRO_DATA_KEY = 'macro_data';
const String DAILY_MEALS_KEY = 'daily_meals';

class WidgetService {
  static const String WIDGET_UPDATE_ACTION = "com.sharathchenna88.nutrino.WIDGET_UPDATE"; // Updated with actual bundle ID
  
  /// Initialize the widget service
  static Future<void> initWidgetService() async {
    try {
      // Set up the app group identifier for sharing data with widgets
      await HomeWidget.setAppGroupId(APP_GROUP);
      
      // Listen for widget launcher taps (when user taps on widget to open app)
      HomeWidget.widgetClicked.listen(_handleWidgetClick);
    } catch (e) {
      debugPrint('Error initializing widget service: $e');
    }
  }
  
  /// Handle when user taps on a widget
  static void _handleWidgetClick(Uri? uri) {
    if (uri != null) {
      debugPrint('Widget clicked with uri: $uri');
      // You can add navigation logic based on widget tap
      // For example, navigate to food details page if a food item was tapped
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
      
      // Save data to shared preferences for the widget to read
      await _safeWidgetDataSave(MACRO_DATA_KEY, jsonEncode(data));
      
      // Trigger widget update
      await _updateWidgets();
      
    } catch (e) {
      debugPrint('Error updating widget: $e');
    }
  }
  
  /// Update widget with recent meals
  static Future<void> updateRecentMeals(List<FoodEntry> entries) async {
    try {
      final meals = entries.take(5).map((entry) => {
        'name': entry.food.name,
        'calories': entry.food.calories * entry.quantity / 100,
        'meal': entry.meal,
        'timestamp': entry.date.millisecondsSinceEpoch,
      }).toList();
      
      await _safeWidgetDataSave(DAILY_MEALS_KEY, jsonEncode(meals));
      
      // Trigger widget update
      await _updateWidgets();
      
    } catch (e) {
      debugPrint('Error updating meals widget: $e');
    }
  }
  
  /// Safely save widget data, handling potential API differences
  static Future<void> _safeWidgetDataSave(String key, String value) async {
    try {
      // Try the standard API first
      await HomeWidget.saveWidgetData(key, value);
    } catch (e) {
      debugPrint('Error with primary widget data save: $e');
      
      // As a fallback, use SharedPreferences directly with the app group
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(key, value);
        debugPrint('Saved widget data using fallback method');
      } catch (e2) {
        debugPrint('Error with fallback widget data save: $e2');
      }
    }
  }
  
  /// Trigger a widget update 
  static Future<void> _updateWidgets() async {
    try {
      // Try to update the widget, catching any compatibility issues
      try {
        HomeWidget.updateWidget(
          androidName: 'MacroTrackerWidgetProvider',
          iOSName: 'MacroTrackerWidget',
          qualifiedAndroidName: 'com.sharathchenna88.nutrino.MacroTrackerWidgetProvider',
        );
      } catch (e) {
        debugPrint('Error updating widget, trying alternative approach: $e');
        
        // Alternative approach without optional parameters that might cause issues
        try {
          HomeWidget.updateWidget(
            androidName: 'MacroTrackerWidgetProvider',
            iOSName: 'MacroTrackerWidget',
          );
        } catch (e2) {
          debugPrint('Error with alternative widget update approach: $e2');
        }
      }
    } catch (e) {
      debugPrint('Failed to update widgets: $e');
    }
  }
} 