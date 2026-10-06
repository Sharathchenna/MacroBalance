// ignore_for_file: file_names

import 'package:flutter/foundation.dart';

class DateProvider with ChangeNotifier {
  /// [now] defaults to the system clock; tests pass a fake one.
  DateProvider({DateTime Function()? now}) : _now = now ?? DateTime.now {
    _selectedDate = _today();
  }

  final DateTime Function() _now;

  late DateTime _selectedDate;

  // True while the user is looking at "today" rather than a day they picked.
  bool _followsToday = true;

  DateTime get selectedDate => _selectedDate;

  DateTime _today() {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Today, as a date. The latest day the user can look at.
  DateTime get today => _today();

  bool get isOnToday => _selectedDate == _today();

  /// Selects [date]'s day. Future days aren't allowed; they become today.
  void setDate(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final today = _today();
    _selectedDate = day.isAfter(today) ? today : day;
    _followsToday = _selectedDate == today;
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
