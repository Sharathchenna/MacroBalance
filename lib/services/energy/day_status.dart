import 'constants.dart';

/// What the user said about a day (the `food_day_status.status` column).
enum ExplicitDayStatus {
  complete('complete'),
  partial('partial'),
  fasting('fasting');

  const ExplicitDayStatus(this.code);

  final String code;

  static ExplicitDayStatus? fromCode(Object? code) {
    for (final s in values) {
      if (s.code == code) return s;
    }
    return null;
  }
}

enum DayStatus { complete, partial, untracked, fasting }

/// A day's classification (spec 6.3).
class DayClassification {
  const DayClassification(this.status, {required this.inferred});

  final DayStatus status;

  /// True when the app decided; false when the user said so.
  final bool inferred;

  /// Whether the day goes into the intake average.
  bool get countsInIntake =>
      status == DayStatus.complete || status == DayStatus.fasting;

  /// The cals the day contributes to the intake average: a fasted day is 0
  /// whatever was logged. Only meaningful when [countsInIntake].
  double intakeCals(double loggedCals) =>
      status == DayStatus.fasting ? 0 : loggedCals;
}

/// Classifies one day, first match wins:
/// explicit fasting, complete, partial; no food entries -> untracked;
/// logged cals under [kPartialFraction] of [tdeeEstimate] -> partial;
/// otherwise complete.
///
/// Only past days are inferred. Today is classified only when the user
/// explicitly finished it; otherwise this returns null.
///
/// [tdeeEstimate] is the TDEE as of [day]: the formula TDEE until the
/// estimator exists.
DayClassification? classifyDay({
  required DateTime day,
  required DateTime today,
  required ExplicitDayStatus? explicit,
  required bool hasEntries,
  required double loggedCals,
  required double tdeeEstimate,
}) {
  switch (explicit) {
    case ExplicitDayStatus.fasting:
      return const DayClassification(DayStatus.fasting, inferred: false);
    case ExplicitDayStatus.complete:
      return const DayClassification(DayStatus.complete, inferred: false);
    case ExplicitDayStatus.partial:
      return const DayClassification(DayStatus.partial, inferred: false);
    case null:
      break;
  }

  final d = DateTime(day.year, day.month, day.day);
  final t = DateTime(today.year, today.month, today.day);
  if (!d.isBefore(t)) return null;

  if (!hasEntries) {
    return const DayClassification(DayStatus.untracked, inferred: true);
  }
  if (loggedCals < kPartialFraction * tdeeEstimate) {
    return const DayClassification(DayStatus.partial, inferred: true);
  }
  return const DayClassification(DayStatus.complete, inferred: true);
}
