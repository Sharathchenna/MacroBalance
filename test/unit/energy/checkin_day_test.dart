import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/checkin_day.dart';
import 'package:macrotracker/services/energy/constants.dart';

void main() {
  // Oct 7 2026 is a Wednesday.
  final wednesday = DateTime(2026, 10, 7);

  group('defaultCheckinWeekday', () {
    test('is the ISO weekday onboarding finished on', () {
      expect(defaultCheckinWeekday(wednesday), DateTime.wednesday);
      expect(defaultCheckinWeekday(DateTime(2026, 10, 11, 23, 59)), DateTime.sunday);
      expect(defaultCheckinWeekday(DateTime(2026, 10, 12, 0, 1)), DateTime.monday);
    });
  });

  group('nextCheckinDay', () {
    test('is today when today is the check-in weekday', () {
      expect(
          nextCheckinDay(
              weekday: DateTime.wednesday,
              today: DateTime(2026, 10, 7, 15, 30),
              learningStartedOn: DateTime(2026, 9, 1)),
          wednesday);
    });

    test('is the next matching weekday otherwise', () {
      expect(
          nextCheckinDay(
              weekday: DateTime.monday,
              today: wednesday,
              learningStartedOn: DateTime(2026, 9, 1)),
          DateTime(2026, 10, 12));
      expect(
          nextCheckinDay(
              weekday: DateTime.tuesday,
              today: wednesday,
              learningStartedOn: DateTime(2026, 9, 1)),
          DateTime(2026, 10, 13));
    });

    test('the first check-in is a full week after onboarding', () {
      // Onboarded today, check-in day = today's weekday: next week, not today.
      expect(
          nextCheckinDay(
              weekday: DateTime.wednesday, today: wednesday, learningStartedOn: wednesday),
          DateTime(2026, 10, 14));
      expect(kFirstCheckinAfterDays, 7);
    });

    test('a weekday changed soon after onboarding still waits the full week', () {
      // Onboarded Wednesday, switched to Thursday: Thursday the 8th is too soon.
      expect(
          nextCheckinDay(
              weekday: DateTime.thursday, today: wednesday, learningStartedOn: wednesday),
          DateTime(2026, 10, 15));
      // Switched to Tuesday: Tuesday the 13th is only 6 days in.
      expect(
          nextCheckinDay(
              weekday: DateTime.tuesday, today: wednesday, learningStartedOn: wednesday),
          DateTime(2026, 10, 20));
    });

    test('exactly 7 days after onboarding is allowed', () {
      expect(
          nextCheckinDay(
              weekday: DateTime.wednesday,
              today: DateTime(2026, 10, 10),
              learningStartedOn: DateTime(2026, 10, 7)),
          DateTime(2026, 10, 14));
    });

    test('no learning start: only today matters', () {
      expect(
          nextCheckinDay(weekday: DateTime.wednesday, today: wednesday),
          wednesday);
    });

    test('returns a date at midnight and steps across a DST change', () {
      // Europe/US clocks change on Oct 25 / Nov 1; date maths stays on whole days.
      final next = nextCheckinDay(
          weekday: DateTime.sunday, today: DateTime(2026, 10, 26, 8));
      expect(next, DateTime(2026, 11, 1));
      expect(next.hour, 0);
    });

    test('rejects a weekday outside 1–7', () {
      expect(() => nextCheckinDay(weekday: 0, today: wednesday), throwsArgumentError);
      expect(() => nextCheckinDay(weekday: 8, today: wednesday), throwsArgumentError);
    });
  });
}
