import '../models/foodEntry.dart';
import '../services/storage_service.dart';

/// "Your usual breakfast": a meal the user has eaten, give or take a food,
/// on several of the last few days.
class MealRoutine {
  MealRoutine._();

  /// Days looked at, counting back from yesterday. Today never counts.
  static const int windowDays = 7;

  /// Days in the window that must look like the usual combination.
  static const int minMatchingDays = 3;

  /// How alike two days' foods must be to count as the same meal: shared
  /// food names over all food names (Jaccard). 0.6 lets one food in a
  /// three-food meal differ.
  static const double minSimilarity = 0.6;

  /// The usual [meal] to offer on [viewedDate], or null when there's none.
  /// Only today gets suggestions; past and future days never do.
  /// [entriesFor] returns that meal's entries on a given day.
  static RoutineSuggestion? suggest({
    required String meal,
    required DateTime viewedDate,
    required DateTime today,
    required List<FoodEntry> Function(DateTime day) entriesFor,
  }) {
    if (!_sameDay(viewedDate, today)) return null;

    // Newest first, so ties go to the most recent day.
    final days = <_Day>[];
    for (var i = 1; i <= windowDays; i++) {
      final day = DateTime(today.year, today.month, today.day - i);
      final entries = entriesFor(day);
      if (entries.isEmpty) continue;
      days.add(_Day(day, entries, nameSet(entries)));
    }

    // Each distinct combination is a candidate. The usual one is the one
    // eaten exactly most often (then the one most days resemble, then the
    // most recent) among those enough days resemble.
    final candidates = <_Candidate>[];
    final seen = <String>{};
    for (final day in days) {
      if (!seen.add(_keyOf(day.names))) continue;
      var support = 0;
      var exact = 0;
      for (final other in days) {
        if (similarity(day.names, other.names) >= minSimilarity) support++;
        if (_sameSet(day.names, other.names)) exact++;
      }
      if (support >= minMatchingDays) candidates.add(_Candidate(day, exact, support));
    }
    if (candidates.isEmpty) return null;
    // Candidates are newest first, so on a tie the earlier one is kept.
    var best = candidates.first;
    for (final c in candidates.skip(1)) {
      if (c.exact > best.exact || (c.exact == best.exact && c.support > best.support)) {
        best = c;
      }
    }

    // The first day seen with this combination is the most recent one, so
    // its quantities are what gets copied.
    return RoutineSuggestion(
      meal: meal,
      sourceDate: best.day.date,
      entries: best.day.entries,
      matchingDays: best.support,
    );
  }

  /// Food names in a meal, ignoring case, spacing and repeats.
  static Set<String> nameSet(List<FoodEntry> entries) =>
      {for (final e in entries) e.food.name.trim().toLowerCase()};

  /// Jaccard similarity of two sets of food names, from 0 to 1.
  static double similarity(Set<String> a, Set<String> b) {
    if (a.isEmpty && b.isEmpty) return 1;
    final shared = a.intersection(b).length;
    return shared / (a.length + b.length - shared);
  }

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  static String _keyOf(Set<String> names) => (names.toList()..sort()).join('\u0000');

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _Day {
  _Day(this.date, this.entries, this.names);
  final DateTime date;
  final List<FoodEntry> entries;
  final Set<String> names;
}

class _Candidate {
  _Candidate(this.day, this.exact, this.support);
  final _Day day;
  final int exact;
  final int support;
}

/// What to offer: the entries of the most recent day the usual meal was eaten.
class RoutineSuggestion {
  const RoutineSuggestion({
    required this.meal,
    required this.sourceDate,
    required this.entries,
    required this.matchingDays,
  });

  final String meal;
  final DateTime sourceDate;
  final List<FoodEntry> entries;

  /// Days in the window that resembled it.
  final int matchingDays;
}

/// Remembers when the user waved a usual-meal suggestion away, on this device.
///
/// "Not today" hides a meal's suggestion until tomorrow. Doing that
/// [dismissalsBeforeBackoff] times in a row, without adding it in between,
/// stops suggesting that meal for [backoff].
class RoutineDismissals {
  RoutineDismissals([StorageService? storage]) : _storage = storage ?? StorageService();

  final StorageService _storage;

  static const int dismissalsBeforeBackoff = 3;
  static const Duration backoff = Duration(days: 14);

  /// Day ("yyyy-mm-dd") the meal's suggestion was last hidden.
  static String hiddenOnKey(String meal) => 'usual_meal_hidden_on_$meal';

  /// "Not today" taps since the suggestion was last used.
  static String dismissStreakKey(String meal) => 'usual_meal_dismiss_streak_$meal';

  /// Day ("yyyy-mm-dd") suggestions for the meal may come back.
  static String pausedUntilKey(String meal) => 'usual_meal_paused_until_$meal';

  static List<String> keysFor(String meal) =>
      [hiddenOnKey(meal), dismissStreakKey(meal), pausedUntilKey(meal)];

  bool isHidden(String meal, DateTime today) {
    if (_storage.get(hiddenOnKey(meal)) == _dayKey(today)) return true;
    final until = DateTime.tryParse('${_storage.get(pausedUntilKey(meal)) ?? ''}');
    return until != null && _startOf(today).isBefore(until);
  }

  /// "Not today".
  Future<void> dismiss(String meal, DateTime today) async {
    await _storage.put(hiddenOnKey(meal), _dayKey(today));
    final streak = ((_storage.get(dismissStreakKey(meal)) as int?) ?? 0) + 1;
    if (streak >= dismissalsBeforeBackoff) {
      final until = DateTime(today.year, today.month, today.day + backoff.inDays);
      await _storage.put(pausedUntilKey(meal), _dayKey(until));
      await _storage.put(dismissStreakKey(meal), 0);
    } else {
      await _storage.put(dismissStreakKey(meal), streak);
    }
  }

  /// The suggestion was added, so earlier dismissals no longer count.
  Future<void> used(String meal) => _storage.put(dismissStreakKey(meal), 0);

  static DateTime _startOf(DateTime d) => DateTime(d.year, d.month, d.day);

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
