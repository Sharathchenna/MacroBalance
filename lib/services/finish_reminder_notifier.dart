import 'package:flutter/foundation.dart';

import 'finish_day_link.dart';
import 'notification_service.dart';

/// The evening "Finish day" local notifications (spec 8). One per upcoming
/// evening, so a day that's already finished can be left out; they're set
/// again whenever the app opens or a day is finished.
///
/// It goes through [NotificationService] and only schedules while the user
/// allows notifications; it never asks.
class FinishReminderNotifier {
  FinishReminderNotifier();

  /// The one shared by the app (the notifications belong to the device).
  static FinishReminderNotifier device = FinishReminderNotifier();

  /// Ids 42000 .. 42000 + [slots] - 1.
  static const int firstId = 42000;
  static const int slots = 14;
  static const String title = 'Finish your day';
  static const String body = 'Done logging? Tap Finish day so today counts.';

  List<DateTime> _scheduled = const [];
  bool _known = false;
  Future<void> _last = Future.value();

  /// What's scheduled now, as far as this run knows.
  List<DateTime> get scheduled => _scheduled;

  /// Schedules the reminder for [times] (at most [slots]), replacing any
  /// earlier ones; an empty list cancels. Asking for what's already there
  /// does nothing. Calls run in order.
  Future<void> update(List<DateTime> times) => _last = _last.then((_) => _update(times));

  Future<void> _update(List<DateTime> times) async {
    try {
      var wanted = times.take(slots).toList();
      if (wanted.isNotEmpty && !await allowed()) wanted = const [];
      if (_known && listEquals(wanted, _scheduled)) return;
      await cancel();
      for (var i = 0; i < wanted.length; i++) {
        await schedule(firstId + i, wanted[i]);
      }
      _scheduled = wanted;
      _known = true;
    } catch (e) {
      // Tried again on the next update.
      debugPrint('[FinishReminderNotifier] Could not update: $e');
      _known = false;
    }
  }

  /// Whether notifications are allowed now (a button asks before it saves).
  Future<bool> isAllowed() => allowed();

  @protected
  Future<bool> allowed() => NotificationService().notificationsAllowed();

  @protected
  Future<void> schedule(int id, DateTime at) => NotificationService().scheduleNotification(
        id: id,
        title: title,
        body: body,
        scheduledDate: at,
        payload: FinishDayLink.payload,
      );

  @protected
  Future<void> cancel() async {
    for (var i = 0; i < slots; i++) {
      await NotificationService().cancelNotification(firstId + i);
    }
  }
}
