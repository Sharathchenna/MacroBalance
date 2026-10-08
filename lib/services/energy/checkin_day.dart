import 'constants.dart';

/// The ISO weekday (1 = Monday … 7 = Sunday) check-ins fall on by default:
/// the weekday onboarding finished (spec 6.8).
int defaultCheckinWeekday(DateTime finishedOn) => finishedOn.weekday;

/// The next check-in day: the first [weekday] on or after [today], and no
/// sooner than [kFirstCheckinAfterDays] after [learningStartedOn] (the first
/// check-in needs a week of data). Returned as a date at midnight.
///
/// This is the scheduled day only: whether this week's check-in has already
/// run is the check-in's own business.
DateTime nextCheckinDay({
  required int weekday,
  required DateTime today,
  DateTime? learningStartedOn,
}) {
  if (weekday < DateTime.monday || weekday > DateTime.sunday) {
    throw ArgumentError.value(weekday, 'weekday', 'must be 1–7');
  }
  var from = _dateOnly(today);
  if (learningStartedOn != null) {
    final start = _dateOnly(learningStartedOn);
    final earliest =
        DateTime(start.year, start.month, start.day + kFirstCheckinAfterDays);
    if (earliest.isAfter(from)) from = earliest;
  }
  final ahead = (weekday - from.weekday) % 7;
  return DateTime(from.year, from.month, from.day + ahead);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
