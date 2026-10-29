import 'package:flutter/foundation.dart';

import '../models/foodEntry.dart';

/// Foods the user copied from a meal, waiting to be pasted into another meal
/// or day. Lives for the app session only; the dashboard shows a paste bar
/// while it holds anything.
class FoodClipboard extends ValueNotifier<List<FoodEntry>> {
  FoodClipboard._() : super(const []);

  static final FoodClipboard instance = FoodClipboard._();

  bool get isEmpty => value.isEmpty;

  /// "Coffee", or "Coffee and 2 more".
  String get summary {
    if (value.isEmpty) return '';
    final first = value.first.food.name;
    return value.length == 1 ? first : '$first and ${value.length - 1} more';
  }

  void copy(List<FoodEntry> entries) => value = List.unmodifiable(entries);

  void clear() => value = const [];
}
