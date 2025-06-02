import 'package:flutter/material.dart';
import 'package:macrotracker/services/storage_service.dart'; // Import StorageService

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;
  bool _useSystemTheme = true;
  static const String _themeKey = 'isDarkMode';
  static const String _systemThemeKey = 'useSystemTheme';

  bool get isDarkMode => _useSystemTheme
      ? WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark
      : _isDarkMode;

  bool get useSystemTheme => _useSystemTheme;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    _useSystemTheme = false;
    _saveThemeToPrefs();
    notifyListeners();
  }

  void setUseSystemTheme(bool value) {
    _useSystemTheme = value;
    _saveThemeToPrefs();
    notifyListeners();
  }

  // No longer async as StorageService is synchronous after initialization
  void _loadThemeFromPrefs() {
    // Assuming StorageService is initialized in main.dart
    _isDarkMode = StorageService().get(_themeKey, defaultValue: false);
    _useSystemTheme = StorageService().get(_systemThemeKey, defaultValue: true); // Load system theme preference
    // notifyListeners(); // Consider if needed immediately or handled by toggle methods
  }

  // No longer async
  void _saveThemeToPrefs() {
    // Assuming StorageService is initialized in main.dart
    StorageService().put(_themeKey, _isDarkMode);
    StorageService().put(_systemThemeKey, _useSystemTheme); // Save system theme preference
  }
}
