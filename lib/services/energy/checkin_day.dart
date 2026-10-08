import 'constants.dart';

/// The ISO weekday (1 = Monday … 7 = Sunday) check-ins fall on by default:
/// the weekday onboarding finished (spec 6.8).
int defaultCheckinWeekday(DateTime finishedOn) => finishedOn.weekday;

/// The next check-in day: the first [weekday] on or after [today], no sooner
/// than [kFirstCheckinAfterDays] after [learningStartedOn] (the first
/// check-in needs a week of data) and, once a check-in has run, no sooner
/// than a week after [lastCheckin]. Returned as a date at midnight.
DateTime nextCheckinDay({
  required int weekday,
  required DateTime today,
  DateTime? learningStartedOn,
  DateTime? lastCheckin,
}) {
  _checkWeekday(weekday);
  var from = _dateOnly(today);
  final earliest = _earliest(learningStartedOn, lastCheckin);
  if (earliest != null && earliest.isAfter(from)) from = earliest;
  final ahead = (weekday - from.weekday) % 7;
  return DateTime(from.year, from.month, from.day + ahead);
}

/// The check-in that's due at [now], as its `week_start`, or null when none
/// is (spec 6.8).
///
/// The week starts on the latest scheduled [weekday] (from [kCheckinHour] on
/// that day), so a user who doesn't open the app on the day gets it at the
/// first open later that week, and every device agrees on the date. It's due
/// when that day is at least a week after learning started and a week after
/// [lastCheckin] (the latest `week_start` with a row): a check-in that has
/// run, here or on another device, never runs again.
DateTime? dueCheckinWeek({
  required int weekday,
  required DateTime now,
  required DateTime? learningStartedOn,
  DateTime? lastCheckin,
}) {
  _checkWeekday(weekday);
  if (learningStartedOn == null) return null;
  final today = _dateOnly(now);
  var back = (today.weekday - weekday) % 7;
  if (back == 0 && now.hour < kCheckinHour) back = 7;
  final scheduled = DateTime(today.year, today.month, today.day - back);
  final earliest = _earliest(learningStartedOn, lastCheckin)!;
  return scheduled.isBefore(earliest) ? null : scheduled;
}

/// The first day a check-in may fall on, or null with nothing to wait for.
DateTime? _earliest(DateTime? learningStartedOn, DateTime? lastCheckin) {
  DateTime? out;
  for (final d in [learningStartedOn, lastCheckin]) {
    if (d == null) continue;
    final day = DateTime(d.year, d.month, d.day + kFirstCheckinAfterDays);
    if (out == null || day.isAfter(out)) out = day;
  }
  return out;
}

void _checkWeekday(int weekday) {
  if (weekday < DateTime.monday || weekday > DateTime.sunday) {
    throw ArgumentError.value(weekday, 'weekday', 'must be 1–7');
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
