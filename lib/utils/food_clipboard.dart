import 'package:flutter/material.dart';

import '../models/foodEntry.dart';
import '../services/posthog_service.dart';
import '../widgets/app_toast.dart';

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

  /// Copies [entries] and tells the user to pick a meal on the paste bar.
  /// [source] says where the copy came from, for analytics.
  void copyAndAnnounce(List<FoodEntry> entries,
      {required String what, required String source, BuildContext? context}) {
    copy(entries);
    PostHogService.trackEvent('food_copied', properties: {
      'meal_type': entries.first.meal,
      'item_count': entries.length,
      'source': source,
    });
    AppToast.show('Copied $what · pick a meal to paste into',
        context: context != null && context.mounted ? context : null,
        icon: Icons.copy_rounded);
  }

  void clear() => value = const [];
}

/// The food being dragged on the dashboard, if any, so the dock can offer a
/// place to drop it for copying while meal cards take it to move.
class FoodDrag {
  FoodDrag._();

  static final ValueNotifier<FoodEntry?> active = ValueNotifier(null);
}
