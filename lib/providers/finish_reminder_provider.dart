import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/energy/constants.dart';
import '../services/energy/finish_reminder.dart';
import '../services/finish_reminder_notifier.dart';
import '../services/notification_service.dart';
import '../services/posthog_service.dart';
import '../services/storage_service.dart';
import 'day_status_provider.dart';

/// Where the user was when they turned the reminder on, for
/// `finish_reminder_enabled{source}`.
enum FinishReminderSource {
  checkin('checkin'),
  dataQualityTip('data_quality_tip'),
  settings('settings');

  const FinishReminderSource(this.code);

  final String code;
}

/// The evening "Finish day" reminder (spec 8, decision 6). Off until the user
/// asks for it, from a check-in that's missing data, the Energy tab's
/// data-quality tip, or Settings → Notifications.
///
/// The choice and time live on the device (the notification is the device's).
/// The on/off flag is also written to `user_notification_preferences`, where
/// the server reads it to put the prompt on the user's meal reminder instead
/// of sending a second push ([FinishReminderMode.mergedIntoMeal]).
class FinishReminderProvider with ChangeNotifier {
  FinishReminderProvider({this.userId, FinishReminderNotifier? notifier, DateTime Function()? clock})
      : _notifier = notifier ?? FinishReminderNotifier.device,
        _clock = clock ?? DateTime.now {
    _load();
  }

  /// The account this belongs to; a new instance is made when it changes.
  final String? userId;
  final FinishReminderNotifier _notifier;
  final DateTime Function() _clock;

  bool _enabled = false;
  int _minutes = kFinishReminderMinutes;
  bool _mealRemindersOn = false;
  DayStatusProvider? _dayStatus;

  bool get enabled => _enabled;

  /// When the reminder goes out, in minutes after local midnight.
  int get minutes => _minutes;

  bool get mealRemindersOn => _mealRemindersOn;

  FinishReminderMode get mode =>
      finishReminderMode(enabled: _enabled, mealRemindersOn: _mealRemindersOn);

  String get _key => 'finish_reminder:${userId ?? 'signed_out'}';

  void _load() {
    final raw = StorageService().get(_key);
    if (raw is! String || raw.isEmpty) return;
    try {
      final map = jsonDecode(raw) as Map;
      _enabled = map['enabled'] == true;
      final m = map['minutes'];
      if (m is int && m >= 0 && m < 24 * 60) _minutes = m;
    } catch (_) {}
  }

  Future<void> _save() => StorageService().put(_key, jsonEncode({'enabled': _enabled, 'minutes': _minutes}));

  /// Follows [dayStatus]: finishing today takes tonight's reminder away.
  void attach(DayStatusProvider dayStatus) {
    if (identical(dayStatus, _dayStatus)) return;
    _dayStatus?.removeListener(_reschedule);
    _dayStatus = dayStatus..addListener(_reschedule);
  }

  @override
  void dispose() {
    _dayStatus?.removeListener(_reschedule);
    super.dispose();
  }

  void _reschedule() {
    apply();
  }

  /// Whether the OS lets the app show notifications.
  Future<bool> notificationsAllowed() => _notifier.isAllowed();

  /// Turns the reminder on from [source]. Returns false, leaving it off,
  /// when notifications aren't allowed (it never asks for permission).
  Future<bool> enable(FinishReminderSource source) async {
    if (!await _notifier.isAllowed()) return false;
    _enabled = true;
    await _save();
    PostHogService.trackEvent('finish_reminder_enabled', properties: {'source': source.code});
    notifyListeners();
    await refresh();
    return true;
  }

  Future<void> disable() async {
    _enabled = false;
    await _save();
    notifyListeners();
    await apply();
    await writeFlag(false);
  }

  Future<void> setMinutes(int minutes) async {
    _minutes = minutes.clamp(0, 24 * 60 - 1);
    await _save();
    notifyListeners();
    await apply();
  }

  /// Reads whether meal reminders are on, mirrors the flag to the cloud, and
  /// sets the notifications. Run at app open and after the meal-reminder
  /// switch changes.
  Future<void> refresh() async {
    try {
      _mealRemindersOn = await fetchMealReminders();
    } catch (e) {
      debugPrint('[FinishReminder] Could not read meal reminders: $e');
    }
    notifyListeners();
    await apply();
    if (_enabled) await writeFlag(true);
  }

  /// Sets or cancels the local notifications for the current mode: its own
  /// push only when meal reminders are off.
  Future<void> apply() async {
    final times = mode == FinishReminderMode.separate
        ? finishReminderTimes(
            now: _clock(),
            minutesOfDay: _minutes,
            isFinished: (day) => _dayStatus?.isFinished(day) ?? false,
          )
        : const <DateTime>[];
    await _notifier.update(times);
  }

  /// Logout: cancel the notifications and forget this account's choice.
  Future<void> clearUserData() async {
    _enabled = false;
    _mealRemindersOn = false;
    await _notifier.update(const []);
    await StorageService().delete(_key);
    notifyListeners();
  }

  /// Whether the user has meal reminders on (the cloud preference).
  @protected
  Future<bool> fetchMealReminders() async {
    final prefs = await NotificationService().getNotificationPreferences();
    return prefs?['meal_reminders'] == true;
  }

  /// Tells the server whether to add the prompt to the meal reminder. The
  /// preferences row belongs to Settings, which creates it; without one
  /// there's no meal reminder to join.
  @protected
  Future<void> writeFlag(bool on) async {
    try {
      final id = Supabase.instance.client.auth.currentUser?.id;
      if (id == null) return;
      await Supabase.instance.client
          .from('user_notification_preferences')
          .update({'finish_day_reminder': on}).eq('user_id', id);
    } catch (e) {
      debugPrint('[FinishReminder] Could not save the flag: $e');
    }
  }
}
