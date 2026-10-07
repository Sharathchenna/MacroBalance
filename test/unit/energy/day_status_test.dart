import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/day_status.dart';

void main() {
  const tdee = 2400.0;
  final today = DateTime(2026, 10, 7);
  final past = DateTime(2026, 10, 5);

  DayClassification? classify({
    ExplicitDayStatus? explicit,
    bool hasEntries = true,
    double loggedCals = 2200,
    DateTime? day,
  }) =>
      classifyDay(
        day: day ?? past,
        today: today,
        explicit: explicit,
        hasEntries: hasEntries,
        loggedCals: loggedCals,
        tdeeEstimate: tdee,
      );

  group('spec 6.3 table, first match wins', () {
    test('explicit fasting is fasting, counts as 0 cals', () {
      final c = classify(
          explicit: ExplicitDayStatus.fasting, hasEntries: false, loggedCals: 0)!;
      expect(c.status, DayStatus.fasting);
      expect(c.inferred, isFalse);
      expect(c.countsInIntake, isTrue);
      expect(c.intakeCals(0), 0);
    });

    test('explicit fasting beats logged food', () {
      final c = classify(explicit: ExplicitDayStatus.fasting, loggedCals: 900)!;
      expect(c.status, DayStatus.fasting);
      expect(c.intakeCals(900), 0);
    });

    test('explicit complete counts even when logged cals are tiny', () {
      final c = classify(explicit: ExplicitDayStatus.complete, loggedCals: 100)!;
      expect(c.status, DayStatus.complete);
      expect(c.inferred, isFalse);
      expect(c.countsInIntake, isTrue);
      expect(c.intakeCals(100), 100);
    });

    test('explicit complete with no entries still wins over untracked', () {
      final c = classify(
          explicit: ExplicitDayStatus.complete, hasEntries: false, loggedCals: 0)!;
      expect(c.status, DayStatus.complete);
    });

    test('explicit partial does not count even when cals are high', () {
      final c = classify(explicit: ExplicitDayStatus.partial, loggedCals: 3000)!;
      expect(c.status, DayStatus.partial);
      expect(c.inferred, isFalse);
      expect(c.countsInIntake, isFalse);
    });

    test('no entries and no explicit status is untracked', () {
      final c = classify(hasEntries: false, loggedCals: 0)!;
      expect(c.status, DayStatus.untracked);
      expect(c.inferred, isTrue);
      expect(c.countsInIntake, isFalse);
    });

    test('below the partial fraction of TDEE is partial (inferred)', () {
      final c = classify(loggedCals: kPartialFraction * tdee - 1)!;
      expect(c.status, DayStatus.partial);
      expect(c.inferred, isTrue);
      expect(c.countsInIntake, isFalse);
    });

    test('exactly at the partial fraction is complete (inferred)', () {
      final c = classify(loggedCals: kPartialFraction * tdee)!;
      expect(c.status, DayStatus.complete);
      expect(c.inferred, isTrue);
      expect(c.countsInIntake, isTrue);
    });

    test('normal logging is complete (inferred)', () {
      final c = classify(loggedCals: 2100)!;
      expect(c.status, DayStatus.complete);
      expect(c.inferred, isTrue);
    });

    test('entries that add up to zero cals are partial, not untracked', () {
      final c = classify(loggedCals: 0)!;
      expect(c.status, DayStatus.partial);
    });
  });

  group('today is never inferred', () {
    test('today without an explicit status is not classified', () {
      expect(classify(day: today, loggedCals: 2200), isNull);
      expect(classify(day: today, hasEntries: false, loggedCals: 0), isNull);
      expect(classify(day: today, loggedCals: 100), isNull);
    });

    test('today with an explicit status is classified', () {
      expect(classify(day: today, explicit: ExplicitDayStatus.complete)!.status,
          DayStatus.complete);
      expect(classify(day: today, explicit: ExplicitDayStatus.partial)!.status,
          DayStatus.partial);
      expect(classify(day: today, explicit: ExplicitDayStatus.fasting)!.status,
          DayStatus.fasting);
    });

    test('time of day is ignored when comparing days', () {
      final c = classifyDay(
        day: DateTime(2026, 10, 7, 23, 59),
        today: DateTime(2026, 10, 7, 0, 1),
        explicit: null,
        hasEntries: true,
        loggedCals: 2000,
        tdeeEstimate: tdee,
      );
      expect(c, isNull);
    });
  });

  group('explicit status codes', () {
    test('round trip through their stored names', () {
      for (final s in ExplicitDayStatus.values) {
        expect(ExplicitDayStatus.fromCode(s.code), s);
      }
      expect(ExplicitDayStatus.fromCode('nope'), isNull);
      expect(ExplicitDayStatus.fromCode(null), isNull);
      expect(ExplicitDayStatus.complete.code, 'complete');
      expect(ExplicitDayStatus.partial.code, 'partial');
      expect(ExplicitDayStatus.fasting.code, 'fasting');
    });
  });
}
