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

    test('after a check-in, the next one is a week later at the earliest', () {
      // Monday Oct 12's check-in has run: Monday's card reads next week.
      expect(
          nextCheckinDay(
              weekday: DateTime.monday,
              today: DateTime(2026, 10, 12, 9),
              learningStartedOn: DateTime(2026, 9, 1),
              lastCheckin: DateTime(2026, 10, 12)),
          DateTime(2026, 10, 19));
      // An older check-in doesn't hold today's back.
      expect(
          nextCheckinDay(
              weekday: DateTime.monday,
              today: DateTime(2026, 10, 12, 9),
              learningStartedOn: DateTime(2026, 9, 1),
              lastCheckin: DateTime(2026, 10, 5)),
          DateTime(2026, 10, 12));
    });

    test('moving the weekday right after a check-in waits a full week', () {
      // Checked in Monday Oct 12, then moved to Thursday: not Oct 15.
      expect(
          nextCheckinDay(
              weekday: DateTime.thursday,
              today: DateTime(2026, 10, 13),
              lastCheckin: DateTime(2026, 10, 12)),
          DateTime(2026, 10, 22));
    });
  });

  group('dueCheckinWeek', () {
    final start = DateTime(2026, 9, 7); // a Monday

    DateTime? due(DateTime now, {DateTime? last, int weekday = DateTime.monday, DateTime? learning}) =>
        dueCheckinWeek(
          weekday: weekday,
          now: now,
          learningStartedOn: learning ?? start,
          lastCheckin: last,
        );

    test('on the check-in day from 04:00, the week starts that day', () {
      expect(due(DateTime(2026, 10, 12, 4)), DateTime(2026, 10, 12));
      expect(due(DateTime(2026, 10, 12, 23, 59), last: DateTime(2026, 10, 5)),
          DateTime(2026, 10, 12));
    });

    test('before 04:00 on the check-in day, nothing is due yet', () {
      expect(due(DateTime(2026, 10, 12, 3, 59), last: DateTime(2026, 10, 5)), isNull);
    });

    test('this week has run: nothing is due (restarts, other devices)', () {
      expect(due(DateTime(2026, 10, 12, 9), last: DateTime(2026, 10, 12)), isNull);
      expect(due(DateTime(2026, 10, 15), last: DateTime(2026, 10, 12)), isNull);
    });

    test('missed the day: the first open later that week runs it', () {
      // Never opened on Monday Oct 12; opens Wednesday.
      expect(due(DateTime(2026, 10, 14, 8), last: DateTime(2026, 10, 5)),
          DateTime(2026, 10, 12));
      // Away for weeks: one check-in, for the latest scheduled day.
      expect(due(DateTime(2026, 11, 4), last: DateTime(2026, 10, 5)),
          DateTime(2026, 11, 2));
    });

    test('not before a week of learning', () {
      // Learning started Wednesday Oct 7; the first Monday is Oct 12, too soon.
      final learning = DateTime(2026, 10, 7);
      expect(due(DateTime(2026, 10, 12, 9), learning: learning), isNull);
      expect(due(DateTime(2026, 10, 19, 9), learning: learning), DateTime(2026, 10, 19));
    });

    test('a weekday moved after a check-in waits a week from it', () {
      // Checked in Monday Oct 12, moved to Thursday: Oct 15 is too soon.
      expect(due(DateTime(2026, 10, 15, 9), last: DateTime(2026, 10, 12), weekday: DateTime.thursday),
          isNull);
      expect(due(DateTime(2026, 10, 22, 9), last: DateTime(2026, 10, 12), weekday: DateTime.thursday),
          DateTime(2026, 10, 22));
    });

    test('no learning start: nothing to check in on', () {
      expect(
          dueCheckinWeek(
              weekday: DateTime.monday, now: DateTime(2026, 10, 12, 9), learningStartedOn: null),
          isNull);
    });
  });
}
