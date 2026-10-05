import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:macrotracker/utils/weight_range.dart';

void main() {
  setUpAll(() => initializeDateFormatting('en_US'));

  final now = DateTime(2026, 10, 5, 15, 30);
  DateTime daysAgo(int d) => DateTime(2026, 10, 5).subtract(Duration(days: d));

  test('ranges run from the selector in order, ending with All', () {
    expect(WeightRange.values.map((r) => r.label),
        ['1W', '1M', '3M', '6M', '1Y', 'All']);
  });

  test('a week covers today and the 6 days before it', () {
    expect(WeightRange.week.includes(daysAgo(0), now), isTrue);
    expect(WeightRange.week.includes(daysAgo(6), now), isTrue);
    expect(WeightRange.week.includes(daysAgo(7), now), isFalse);
  });

  test('month ranges use calendar months, including across a year end', () {
    expect(WeightRange.month.start(now), DateTime(2026, 9, 5));
    expect(WeightRange.threeMonths.start(now), DateTime(2026, 7, 5));
    expect(WeightRange.sixMonths.start(now), DateTime(2026, 4, 5));
    expect(WeightRange.year.start(now), DateTime(2025, 10, 5));
    expect(WeightRange.sixMonths.start(DateTime(2026, 2, 10)), DateTime(2025, 8, 10));
  });

  test('All includes everything', () {
    expect(WeightRange.all.start(now), isNull);
    expect(WeightRange.all.includes(DateTime(2001), now), isTrue);
  });

  test('filter keeps entries in range and sorts them oldest first', () {
    final entries = [
      {'date': daysAgo(2), 'w': 70.0},
      {'date': daysAgo(400), 'w': 80.0},
      {'date': daysAgo(100), 'w': 75.0},
      {'date': daysAgo(20), 'w': 72.0},
    ];
    DateTime dateOf(Map<String, Object> e) => e['date'] as DateTime;

    expect(WeightRange.week.filter(entries, dateOf, now: now).map((e) => e['w']), [70.0]);
    expect(WeightRange.month.filter(entries, dateOf, now: now).map((e) => e['w']), [72.0, 70.0]);
    expect(WeightRange.sixMonths.filter(entries, dateOf, now: now).map((e) => e['w']),
        [75.0, 72.0, 70.0]);
    expect(WeightRange.all.filter(entries, dateOf, now: now).map((e) => e['w']),
        [80.0, 75.0, 72.0, 70.0]);
  });

  test('filter of nothing is empty for every range', () {
    for (final r in WeightRange.values) {
      expect(r.filter(<DateTime>[], (d) => d, now: now), isEmpty);
    }
  });

  test('axis labels get coarser as the range grows', () {
    final d = DateTime(2026, 3, 9);
    expect(WeightRange.week.axisLabel(d), 'Mon');
    expect(WeightRange.month.axisLabel(d), '9');
    expect(WeightRange.sixMonths.axisLabel(d), 'Mar 9');
    expect(WeightRange.all.axisLabel(d), 'Mar 2026');
  });
}
