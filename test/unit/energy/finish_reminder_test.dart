import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/finish_reminder.dart';

void main() {
  group('finishReminderMode', () {
    test('off stays off whatever the meal reminders are', () {
      expect(finishReminderMode(enabled: false, mealRemindersOn: false), FinishReminderMode.off);
      expect(finishReminderMode(enabled: false, mealRemindersOn: true), FinishReminderMode.off);
    });

    test('on is its own push without meal reminders', () {
      expect(finishReminderMode(enabled: true, mealRemindersOn: false), FinishReminderMode.separate);
    });

    test('on with meal reminders joins the meal reminder instead', () {
      expect(finishReminderMode(enabled: true, mealRemindersOn: true), FinishReminderMode.mergedIntoMeal);
    });
  });

  group('finishReminderTimes', () {
    bool none(DateTime d) => false;

    test('is 14 evenings at the chosen time, today first when it is still ahead', () {
      final times = finishReminderTimes(
          now: DateTime(2026, 10, 8, 14, 30), minutesOfDay: 21 * 60, isFinished: none);
      expect(times.length, 14);
      expect(times.first, DateTime(2026, 10, 8, 21));
      expect(times.last, DateTime(2026, 10, 21, 21));
    });

    test('skips today once the time has passed', () {
      final times = finishReminderTimes(
          now: DateTime(2026, 10, 8, 21, 0, 30), minutesOfDay: 21 * 60, isFinished: none);
      expect(times.first, DateTime(2026, 10, 9, 21));
      expect(times.length, 14);
    });

    test('skips today when the day is already finished', () {
      final times = finishReminderTimes(
          now: DateTime(2026, 10, 8, 9),
          minutesOfDay: 21 * 60,
          isFinished: (d) => d == DateTime(2026, 10, 8));
      expect(times.first, DateTime(2026, 10, 9, 21));
    });

    test('a finished day does not stop the days after it', () {
      final times = finishReminderTimes(
          now: DateTime(2026, 10, 8, 9),
          minutesOfDay: 21 * 60 + 30,
          isFinished: (d) => d == DateTime(2026, 10, 8));
      expect(times[1], DateTime(2026, 10, 10, 21, 30));
    });

    test('uses local wall-clock time across a clock change', () {
      final times = finishReminderTimes(
          now: DateTime(2026, 10, 30, 9), minutesOfDay: 21 * 60, isFinished: none, days: 5);
      expect([for (final t in times) t.hour], everyElement(21));
    });
  });

  group('copy', () {
    test('the merged line is appended to the meal reminder body', () {
      expect(mealReminderBodyWithFinishDay('Log your meal.'),
          'Log your meal. Done for today? Tap Finish day on Home.');
    });
  });

  test('formatReminderTime reads like a clock', () {
    expect(formatReminderTime(21 * 60), '9:00 PM');
    expect(formatReminderTime(7 * 60 + 5), '7:05 AM');
    expect(formatReminderTime(0), '12:00 AM');
    expect(formatReminderTime(12 * 60), '12:00 PM');
  });
}
