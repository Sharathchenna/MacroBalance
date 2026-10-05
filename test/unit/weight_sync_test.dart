import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/weight_sync_service.dart';

void main() {
  Map<String, dynamic> local(String iso, num kg) => {'date': iso, 'weight': kg};
  Map<String, dynamic> row(String day, num kg) =>
      {'recorded_on': day, 'weight_kg': kg};

  group('mergeHistory', () {
    test('keeps local-only days and adds cloud-only days, one per day', () {
      final merged = WeightSyncService.mergeHistory(
        [local('2026-03-02T08:00:00.000', 80.0)],
        [row('2026-03-01', 80.5)],
      );
      expect(merged.map((e) => e['weight']), [80.5, 80.0]);
      expect(merged.map((e) => WeightSyncService.dayKey(DateTime.parse(e['date']))),
          ['2026-03-01', '2026-03-02']);
    });

    test('the cloud value wins for a day both have, keeping the local time', () {
      final merged = WeightSyncService.mergeHistory(
        [local('2026-03-02T07:30:00.000', 80.0)],
        [row('2026-03-02', 79.4)],
      );
      expect(merged, [
        {'date': '2026-03-02T07:30:00.000', 'weight': 79.4},
      ]);
    });

    test('cloud-only days are placed at midday so they stay on their day', () {
      final merged = WeightSyncService.mergeHistory([], [row('2026-03-05', 81)]);
      final date = DateTime.parse(merged.single['date']);
      expect(date.hour, 12);
      expect(WeightSyncService.dayKey(date), '2026-03-05');
    });

    test('accepts whole-number weights from either side', () {
      final merged = WeightSyncService.mergeHistory(
        [local('2026-03-01T08:00:00.000', 80)],
        [row('2026-03-02', 79)],
      );
      expect(merged.map((e) => e['weight']), [80, 79.0]);
      expect(merged.last['weight'], isA<double>());
    });

    test('never drops local days the cloud does not have', () {
      final history = [
        for (var d = 1; d <= 5; d++) local('2026-04-0${d}T09:00:00.000', 70 + d),
      ];
      final merged = WeightSyncService.mergeHistory(history, []);
      expect(merged, history);
    });

    test('several local entries on one day collapse to the last one', () {
      final merged = WeightSyncService.mergeHistory([
        local('2026-03-02T07:00:00.000', 80.0),
        local('2026-03-02T21:00:00.000', 80.8),
      ], []);
      expect(merged.single['weight'], 80.8);
    });

    test('the result is sorted oldest first', () {
      final merged = WeightSyncService.mergeHistory(
        [local('2026-03-09T08:00:00.000', 78), local('2026-03-01T08:00:00.000', 80)],
        [row('2026-03-05', 79)],
      );
      expect(merged.map((e) => e['weight']), [80, 79.0, 78]);
    });
  });

  group('parseLocalHistory', () {
    test('nothing stored is an empty history', () {
      expect(WeightSyncService.parseLocalHistory(null), isEmpty);
      expect(WeightSyncService.parseLocalHistory(''), isEmpty);
    });

    test('reads stored entries, skipping ones without a date or weight', () {
      final raw = jsonEncode([
        local('2026-03-01T08:00:00.000', 80),
        {'date': '2026-03-02T08:00:00.000'},
        {'weight': 79.5},
        local('2026-03-03T08:00:00.000', 79.1),
      ]);
      expect(WeightSyncService.parseLocalHistory(raw)!.map((e) => e['weight']),
          [80, 79.1]);
    });

    test('unreadable history is null, so it is never overwritten', () {
      expect(WeightSyncService.parseLocalHistory('{not json'), isNull);
      expect(WeightSyncService.parseLocalHistory('{"date": 1}'), isNull);
      expect(WeightSyncService.parseLocalHistory('[1, 2]'), isNull);
    });
  });
}
