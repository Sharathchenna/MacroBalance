import 'package:flutter/material.dart';

class WeightUnitProvider extends ChangeNotifier {
  bool _isKg = true;

  bool get isKg => _isKg;

  String get unitLabel => _isKg ? 'kg' : 'lbs';

  void toggleUnit() {
    _isKg = !_isKg;
    notifyListeners();
  }

  /// Converts kg to display unit
  double convertFromKg(double kg) {
    if (_isKg) return kg;
    return kg * 2.20462;
  }

  /// Converts display unit to kg
  double convertToKg(double value) {
    if (_isKg) return value;
    return value / 2.20462;
  }
}
