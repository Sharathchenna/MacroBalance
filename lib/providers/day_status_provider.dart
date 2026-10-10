import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../services/day_status_sync_service.dart';
import '../services/energy/day_status.dart';
import '../services/posthog_service.dart';

/// Which days the user has finished, fasted or marked as not fully logged.
/// Cached on the device and synced through `food_day_status`.
class DayStatusProvider with ChangeNotifier {
  DayStatusProvider({this.userId, DayStatusSyncService? sync})
      : _sync = sync ?? DayStatusSyncService() {
    _status = _sync.loadCache();
  }

  /// The account this belongs to; a new instance is made when it changes.
  final String? userId;
  final DayStatusSyncService _sync;
  Map<String, ExplicitDayStatus> _status = {};

  static final DateFormat _dayFormat = DateFormat('yyyy-MM-dd');
  static String dayKey(DateTime day) => _dayFormat.format(day);

  /// Called after a status changes: with the day when the user sets one, or
  /// null when the cloud copy is merged in. The energy estimate refreshes
  /// from it.
  void Function(DateTime? day)? onChanged;

  ExplicitDayStatus? statusFor(DateTime day) => _status[dayKey(day)];

  /// Every day with a status, keyed by calendar day.
  Map<DateTime, ExplicitDayStatus> get statuses => {
        for (final e in _status.entries)
          if (DateTime.tryParse(e.key) case final day?) day: e.value,
      };

  bool isFinished(DateTime day) => _status.containsKey(dayKey(day));

  /// Pulls the cloud copy in and uploads anything still pending.
  Future<void> refresh() async {
    final merged = await _sync.sync();
    if (merged == null) return;
    _status = merged;
    notifyListeners();
    onChanged?.call(null);
  }

  /// Sets [day]'s status, or clears it with null ("Not finished").
  /// [inferredWas] is what the app would have guessed, for analytics.
  Future<void> setStatus(DateTime day, ExplicitDayStatus? status,
      {DayStatus? inferredWas}) async {
    final key = dayKey(day);
    if (status == null) {
      _status.remove(key);
    } else {
      _status[key] = status;
    }
    notifyListeners();
    if (status != null) {
      PostHogService.trackEvent('day_finished', properties: {
        'status': status.code,
        'inferred_was': inferredWas?.name ?? 'none',
      });
    }
    onChanged?.call(day);
    await _sync.set(key, status);
  }

  Future<void> clearUserData() async {
    _status = {};
    await _sync.clearLocalState();
    notifyListeners();
  }
}
