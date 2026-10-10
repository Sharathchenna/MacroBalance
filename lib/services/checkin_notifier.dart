import 'package:flutter/foundation.dart';

import 'notification_service.dart';

/// The "Your weekly check-in is ready" local notification (spec 8). There's
/// one on the device at most: [update] moves it, or cancels it with null.
///
/// It goes through [NotificationService] and is only scheduled while the
/// user allows notifications; it never asks. Without permission any earlier
/// one is cancelled, and the next [update] checks again.
class CheckinNotifier {
  CheckinNotifier();

  /// The one shared by the app (the notification belongs to the device).
  /// Tests swap it for one that never reaches the device.
  static CheckinNotifier device = CheckinNotifier();

  static const int notificationId = 41001;
  static const String title = 'Weekly check-in';
  static const String body = 'Your weekly check-in is ready';
  static const String payload = 'checkin';

  /// What's scheduled now: a time, or null for none; [_known] once it's set.
  DateTime? _scheduled;
  bool _known = false;
  Future<void> _last = Future.value();

  /// When the notification is scheduled for, as far as this run knows.
  DateTime? get scheduledFor => _scheduled;

  /// Schedules the notification for [at], or cancels it when [at] is null.
  /// Asking for what's already scheduled does nothing. Calls run in order.
  Future<void> update(DateTime? at) => _last = _last.then((_) => _update(at));

  Future<void> _update(DateTime? at) async {
    try {
      if (at != null && !await allowed()) at = null;
      if (_known && at == _scheduled) return;
      if (at == null) {
        await cancel();
      } else {
        await schedule(at);
      }
      _scheduled = at;
      _known = true;
    } catch (e) {
      // Tried again on the next update.
      debugPrint('[CheckinNotifier] Could not update: $e');
      _known = false;
    }
  }

  /// Forgets what was scheduled, so the next [update] sets it again.
  void reset() => _known = false;

  /// Whether the device holds the notification now (the debug screen).
  Future<bool> isPending() async =>
      (await NotificationService().pendingNotificationIds()).contains(notificationId);

  @protected
  Future<bool> allowed() => NotificationService().notificationsAllowed();

  @protected
  Future<void> schedule(DateTime at) async {
    await cancel();
    await NotificationService().scheduleNotification(
      id: notificationId,
      title: title,
      body: body,
      scheduledDate: at,
      payload: payload,
    );
  }

  @protected
  Future<void> cancel() => NotificationService().cancelNotification(notificationId);
}
