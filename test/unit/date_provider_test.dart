import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/dateProvider.dart';

void main() {
  late DateTime now;
  DateProvider dates() => DateProvider(now: () => now);

  setUp(() => now = DateTime(2026, 5, 10, 23, 50));

  test('starts on today at midnight', () {
    expect(dates().selectedDate, DateTime(2026, 5, 10));
  });

  test('setDate drops the time of day and notifies', () {
    final provider = dates();
    var notified = 0;
    provider.addListener(() => notified++);
    provider.setDate(DateTime(2026, 5, 8, 17, 42, 9));
    expect(provider.selectedDate, DateTime(2026, 5, 8));
    expect(notified, 1);
  });

  test('after midnight, a user on today moves to the new today', () {
    final provider = dates();
    var notified = 0;
    provider.addListener(() => notified++);

    now = DateTime(2026, 5, 11, 0, 5);
    provider.refreshIfNewDay();
    expect(provider.selectedDate, DateTime(2026, 5, 11));
    expect(notified, 1);
  });

  test('after midnight, a picked past day stays selected', () {
    final provider = dates()..setDate(DateTime(2026, 5, 7));
    now = DateTime(2026, 5, 11, 8);
    provider.refreshIfNewDay();
    expect(provider.selectedDate, DateTime(2026, 5, 7));
  });

  test('picking today again resumes following today', () {
    final provider = dates()
      ..setDate(DateTime(2026, 5, 7))
      ..setDate(DateTime(2026, 5, 10, 9));
    now = DateTime(2026, 5, 11, 8);
    provider.refreshIfNewDay();
    expect(provider.selectedDate, DateTime(2026, 5, 11));
  });

  test('on the same day nothing changes or notifies', () {
    final provider = dates();
    var notified = 0;
    provider.addListener(() => notified++);
    now = DateTime(2026, 5, 10, 23, 59);
    provider.refreshIfNewDay();
    expect(provider.selectedDate, DateTime(2026, 5, 10));
    expect(notified, 0);
  });
}
