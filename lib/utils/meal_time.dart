/// Picks which meal a new food most likely belongs to.
class MealTime {
  static const List<String> meals = ['Breakfast', 'Lunch', 'Snacks', 'Dinner'];

  static String? _lastChosen;
  static DateTime? _lastChosenAt;

  // A manual choice is reused for a while, so logging several foods in a row
  // doesn't need the meal changed each time, but it doesn't stick for hours.
  static const Duration _rememberFor = Duration(minutes: 90);

  /// Breakfast before 11:00, Lunch before 16:00, Dinner before 21:00,
  /// otherwise Snacks.
  static String forTime(DateTime time) {
    final hour = time.hour;
    if (hour >= 4 && hour < 11) return 'Breakfast';
    if (hour >= 11 && hour < 16) return 'Lunch';
    if (hour >= 16 && hour < 21) return 'Dinner';
    return 'Snacks';
  }

  /// The meal to preselect when the screen wasn't opened from a specific meal.
  static String suggested() {
    final now = DateTime.now();
    if (_lastChosen != null &&
        _lastChosenAt != null &&
        now.difference(_lastChosenAt!) < _rememberFor) {
      return _lastChosen!;
    }
    return forTime(now);
  }

  /// Call when the user picks a meal by hand, or logs to one.
  static void remember(String meal) {
    _lastChosen = meal;
    _lastChosenAt = DateTime.now();
  }
}
