import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/age.dart';

void main() {
  group('effectiveAge', () {
    final recorded = DateTime(2025, 6, 15);

    test('is the stored age on the day it was recorded', () {
      expect(effectiveAge(age: 30, recordedOn: recorded, today: recorded), 30);
    });

    test('does not change the day before the anniversary', () {
      expect(
          effectiveAge(
              age: 30, recordedOn: recorded, today: DateTime(2026, 6, 14)),
          30);
    });

    test('goes up on the anniversary', () {
      expect(
          effectiveAge(
              age: 30, recordedOn: recorded, today: DateTime(2026, 6, 15)),
          31);
    });

    test('counts every whole year elapsed', () {
      expect(
          effectiveAge(
              age: 30, recordedOn: recorded, today: DateTime(2029, 12, 31)),
          34);
    });

    test('ignores the time of day', () {
      expect(
          effectiveAge(
              age: 30,
              recordedOn: DateTime(2025, 6, 15, 23, 59),
              today: DateTime(2026, 6, 15, 0, 1)),
          31);
    });

    test('crosses a year boundary', () {
      final dec = DateTime(2025, 12, 31);
      expect(effectiveAge(age: 40, recordedOn: dec, today: DateTime(2026, 1, 1)), 40);
      expect(effectiveAge(age: 40, recordedOn: dec, today: DateTime(2026, 12, 31)), 41);
    });

    test('a 29 February record ages on 1 March in other years', () {
      final leap = DateTime(2024, 2, 29);
      expect(effectiveAge(age: 25, recordedOn: leap, today: DateTime(2025, 2, 28)), 25);
      expect(effectiveAge(age: 25, recordedOn: leap, today: DateTime(2025, 3, 1)), 26);
      expect(effectiveAge(age: 25, recordedOn: leap, today: DateTime(2028, 2, 29)), 29);
    });

    test('never goes down if the clock is before the record', () {
      expect(
          effectiveAge(
              age: 30, recordedOn: recorded, today: DateTime(2024, 1, 1)),
          30);
    });

    test('without a record date the stored age is used as is', () {
      expect(effectiveAge(age: 30, recordedOn: null, today: DateTime(2030, 1, 1)), 30);
    });

    test('is capped at the 100 the account allows', () {
      expect(
          effectiveAge(
              age: 99, recordedOn: recorded, today: DateTime(2035, 6, 15)),
          100);
    });
  });
}
