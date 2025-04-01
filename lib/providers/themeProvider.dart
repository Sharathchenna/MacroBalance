import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  Future<void> _loadThemeFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    _useSystemTheme = prefs.getBool(_systemThemeKey) ?? true;
    notifyListeners();
  }

  Future<void> _saveThemeToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, _isDarkMode);
    await prefs.setBool(_systemThemeKey, _useSystemTheme);
  }
}
