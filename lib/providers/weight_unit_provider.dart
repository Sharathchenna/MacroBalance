import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:macrotracker/services/storage_service.dart';

/// The user's unit system (metric or imperial). Despite the name, it drives
/// food amounts (g / oz) and onboarding defaults as well as weight.
///
/// Defaults from the phone's region until the user picks one in Settings.
class WeightUnitProvider extends ChangeNotifier {
  static const String _storageKey = 'unit_system';

  // Regions that use pounds, feet and ounces day to day.
  static const Set<String> _imperialRegions = {'US', 'LR', 'MM'};

  late bool _isMetric;

  WeightUnitProvider() {
    final stored = StorageService().get(_storageKey);
    _isMetric = stored is String ? stored == 'metric' : localeDefaultIsMetric();
  }

  static bool localeDefaultIsMetric() {
    // localeName looks like "en_US", "en-GB" or "fr_FR.UTF-8".
    final parts = Platform.localeName.split(RegExp(r'[_\-.]'));
    final region = parts.length > 1 ? parts[1].toUpperCase() : '';
    return !_imperialRegions.contains(region);
  }

  bool get isMetric => _isMetric;
  bool get isKg => _isMetric;

  String get unitLabel => _isMetric ? 'kg' : 'lbs';

  /// Small food amounts: grams or ounces.
  String get foodUnit => _isMetric ? 'g' : 'oz';

  void setMetric(bool metric) {
    if (_isMetric == metric) return;
    _isMetric = metric;
    StorageService().put(_storageKey, metric ? 'metric' : 'imperial');
    notifyListeners();
  }

  void toggleUnit() => setMetric(!_isMetric);

  /// Converts kg to display unit
  double convertFromKg(double kg) {
    if (_isMetric) return kg;
    return kg * 2.20462;
  }

  /// Converts display unit to kg
  double convertToKg(double value) {
    if (_isMetric) return value;
    return value / 2.20462;
  }
}
