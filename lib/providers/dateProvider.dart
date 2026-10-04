// ignore_for_file: file_names

import 'package:flutter/foundation.dart';

class DateProvider with ChangeNotifier {
  DateTime _selectedDate = _today();

  // True while the user is looking at "today" rather than a day they picked.
  bool _followsToday = true;

  DateTime get selectedDate => _selectedDate;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void setDate(DateTime date) {
    _selectedDate = DateTime(date.year, date.month, date.day);
    _followsToday = _selectedDate == _today();
    notifyListeners();
  }

  /// Call when the app returns to the foreground. If the user was on "today"
  /// and the calendar day has changed since, move to the new today so food
  /// isn't logged against yesterday.
  void refreshIfNewDay() {
    final today = _today();
    if (_followsToday && _selectedDate != today) {
      _selectedDate = today;
      notifyListeners();
    }
  }
}
