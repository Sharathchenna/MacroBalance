import 'package:flutter/foundation.dart';
import 'package:macrotracker/services/storage_service.dart';

/// Settings › "Show detailed stats": off by default, so everyone gets the
/// simple Progress screens (one number and one sentence per card). On, the
/// adaptive goals screens show their working again: ranges, confidence,
/// "How we got this", pace in %/week and why a reading was ignored.
///
/// Only what's shown changes; the maths is the same either way. Stored on
/// the device, like the unit setting.
class DetailedStatsProvider extends ChangeNotifier {
  static const String storageKey = 'show_detailed_stats';

  /// [showDetailedStats] overrides the stored value without saving it
  /// (for tests and previews).
  DetailedStatsProvider({bool? showDetailedStats}) {
    _on = showDetailedStats ??
        StorageService().get(storageKey, defaultValue: false) == true;
  }

  late bool _on;

  bool get showDetailedStats => _on;

  set showDetailedStats(bool on) {
    if (_on == on) return;
    _on = on;
    StorageService().put(storageKey, on);
    notifyListeners();
  }
}
