import 'constants.dart';

/// How the evening "Finish day" prompt reaches the user (spec 8, decision 6).
enum FinishReminderMode {
  /// Not asked for: nothing is sent.
  off,

  /// Its own local notification at the chosen time.
  separate,

  /// Meal reminders are on, so the prompt rides on the last meal reminder
  /// (sent by the server) instead of a second push.
  mergedIntoMeal,
}

FinishReminderMode finishReminderMode({
  required bool enabled,
  required bool mealRemindersOn,
}) {
  if (!enabled) return FinishReminderMode.off;
  return mealRemindersOn ? FinishReminderMode.mergedIntoMeal : FinishReminderMode.separate;
}

/// The next [days] evenings to schedule the reminder for, as local times. Today is left out once the time has passed or the day is
/// finished (there's nothing left to remind about).
///
/// Each is built from the calendar day, so it keeps its wall-clock time
/// across a clock change.
List<DateTime> finishReminderTimes({
  required DateTime now,
  required int minutesOfDay,
  required bool Function(DateTime day) isFinished,
  int days = kFinishReminderDays,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final out = <DateTime>[];
  for (var i = 0; out.length < days; i++) {
    final day = DateTime(today.year, today.month, today.day + i);
    final at = DateTime(day.year, day.month, day.day, minutesOfDay ~/ 60, minutesOfDay % 60);
    if (i == 0 && (!at.isAfter(now) || isFinished(day))) continue;
    out.add(at);
  }
  return out;
}

/// The prompt added to the meal reminder when the two are merged.
const String finishDayPrompt = 'Done for today? Tap Finish day on Home.';

String mealReminderBodyWithFinishDay(String body) => '$body $finishDayPrompt';

/// "9:00 PM" for [minutesOfDay] after midnight.
String formatReminderTime(int minutesOfDay) {
  final h = minutesOfDay ~/ 60;
  final m = minutesOfDay % 60;
  final hour = h % 12 == 0 ? 12 : h % 12;
  return '$hour:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
}
