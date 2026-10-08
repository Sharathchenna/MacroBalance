import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/services/checkin_sync_service.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/estimate_rows.dart';
import 'package:macrotracker/services/energy_sync_service.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

/// Stored estimates are whatever the test says, whatever the replay gives.
class _FixtureSync extends EnergySyncService {
  _FixtureSync(this.rows);

  List<EnergyEstimate> rows;
  Map<DateTime, EnergyEstimate> get _map => {for (final r in rows) r.day: r};

  @override
  Map<DateTime, EnergyEstimate> loadCache() => _map;

  @override
  Future<Map<DateTime, EnergyEstimate>> save(List<EnergyEstimate> rows,
          {required DateTime today}) async =>
      _map;

  @override
  Future<Map<DateTime, EnergyEstimate>?> pull({required DateTime today}) async => _map;

  @override
  Set<String> pendingDays() => const {};
}

/// The account's `goal_checkins`, shared by every "device".
class _Cloud {
  final Map<String, Map<String, Object?>> rows = {};
  bool online = true;
  int inserts = 0;
}

/// A signed-in device: the real cache and queue, with [_Cloud] for the table.
class _DeviceSync extends CheckinSyncService {
  _DeviceSync(this.cloud);

  final _Cloud cloud;

  /// Rows another device inserts just before this one (a race).
  Map<String, Object?>? raceWith;

  @override
  String? get userId => 'user-1';

  void _check() {
    if (!cloud.online) throw Exception('offline');
  }

  @override
  Future<GoalCheckin?> insertRemote(Map<String, Object?> row) async {
    _check();
    final week = row['week_start'] as String;
    if (raceWith != null) {
      cloud.rows[week] = raceWith!;
      raceWith = null;
    }
    final existing = cloud.rows[week];
    if (existing != null) return GoalCheckin.fromJson(existing);
    cloud.inserts++;
    cloud.rows[week] = Map.of(row);
    return null;
  }

  @override
  Future<void> markSeenRemote(DateTime weekStart, DateTime at) async {
    _check();
    final row = cloud.rows[dayKey(weekStart)];
    if (row != null && row['seen_at'] == null) {
      row['seen_at'] = at.toUtc().toIso8601String();
    }
  }

  @override
  Future<List<GoalCheckin>> fetchRemote() async {
    _check();
    return [for (final r in cloud.rows.values) GoalCheckin.fromJson(r)!];
  }
}

void main() {
  // Wednesday Oct 7 2026, 09:00. Learning started Monday Sep 7.
  var now = DateTime(2026, 10, 7, 9);
  final start = DateTime(2026, 9, 7);
  final yesterday = DateTime(2026, 10, 6);

  EnergyEstimate row(DateTime day,
          {double tdee = 2400, EnergyState state = EnergyState.confident, double trend = 80}) =>
      EnergyEstimate(
        day: day,
        tdee: tdee,
        tdeeSd: 90,
        state: state,
        completeDays: 18,
        weighIns: 20,
        updated: true,
        trendWeightKg: trend,
        avgIntake: 2080,
      );

  final inputs = EstimatorInputs(
    learningStartedOn: start,
    formulaTdee: 2000,
    body: const BodyProfile(sex: Sex.male, heightCm: 180, age: 35),
  );

  late _Cloud cloud;

  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('nutrition_goals');
    await CheckinSyncService().clearLocalState();
    now = DateTime(2026, 10, 7, 9);
    cloud = _Cloud();
  });

  /// A check-in already stored for [week] (say, last week's).
  void seedCloud(String week) => cloud.rows[week] = {
        'user_id': 'user-1',
        'week_start': week,
        'variant': 'unchanged',
        'old_targets': {'cals': 2000, 'protein': 150, 'carbs': 220, 'fat': 65},
        'new_targets': {'cals': 2000, 'protein': 150, 'carbs': 220, 'fat': 65},
        'reason': {'tdee': 2010, 'tdee_prev': 2000, 'state': 'confident'},
        'seen_at': '2026-10-01T08:00:00Z',
        'created_at': '2026-10-01T08:00:00Z',
      };

  GoalsProvider goals({bool adaptive = true, int weekday = DateTime.wednesday}) {
    final g = GoalsProvider(userId: 'user-1', clock: () => now)
      ..startLearning(start)
      ..currentWeightKg = 80
      ..goalType = MacroCalculatorService.GOAL_MAINTAIN
      ..adaptiveGoals = adaptive
      ..checkinWeekday = weekday;
    g.updateGoals(
        calories: 2000, protein: 150, carbs: 220, fat: 65, steps: 10000, bmr: 1700, tdee: 2000);
    return g;
  }

  EnergyProvider device(GoalsProvider g,
      {List<EnergyEstimate>? rows, _DeviceSync? sync}) {
    final p = EnergyProvider(
      userId: 'user-1',
      sync: _FixtureSync(rows ?? [row(DateTime(2026, 9, 29), trend: 80.4), row(yesterday)]),
      checkinSync: sync ?? _DeviceSync(cloud),
      clock: () => now,
      inBackground: false,
      debounce: Duration.zero,
    )
      ..inputs = (() => inputs)
      ..goals = g;
    return p;
  }

  test('on the check-in day: decides, applies, stores, then the sheet is due', () async {
    final g = goals();
    final p = device(g);
    await p.refresh();

    final c = p.lastCheckin!;
    expect(c.weekStart, DateTime(2026, 10, 7));
    expect(c.variant, CheckinVariant.changed);
    expect(c.oldTargets.cals, 2000);
    expect(c.newTargets.cals, 2150); // the ±150 step
    expect(c.reason.tdee, 2400);
    expect(c.reason.tdeePrev, 2000);
    expect(c.reason.trendChangeKg, closeTo(-0.4, 1e-9));
    expect(g.caloriesGoal, 2150);
    expect(g.proteinGoal, c.newTargets.protein);
    // The targets now come from the learned expenditure; the prior stays.
    expect(g.tdee, 2400);
    expect(g.formulaTdee, 2000);
    expect(p.checkinToShow, same(c));
    expect(p.todaysCheckin, same(c));
    expect(cloud.rows.keys, ['2026-10-07']);
    expect(cloud.rows['2026-10-07']!['variant'], 'changed');
  });

  test('runs once: refreshes and restarts later that day change nothing', () async {
    final g = goals();
    await device(g).refresh();
    expect(g.caloriesGoal, 2150);

    final p = device(g);
    await p.refresh();
    await p.refresh();
    expect(g.caloriesGoal, 2150, reason: 'a second run would step again to 2,300');
    expect(p.checkins, hasLength(1));
    expect(cloud.inserts, 1);
    // The card's next check-in moves to next week.
    expect(p.nextCheckinDay, DateTime(2026, 10, 14));
  });

  test('another device got there first: its row and targets win', () async {
    // Device A checks in and dismisses the sheet.
    final a = goals();
    final pa = device(a);
    await pa.refresh();
    await pa.markCheckinSeen(pa.lastCheckin!);

    // Device B, a fresh install with the old targets.
    await CheckinSyncService().clearLocalState();
    final b = goals();
    final pb = device(b, rows: [row(yesterday, tdee: 2600)]);
    await pb.refresh();
    expect(cloud.inserts, 1);
    expect(b.caloriesGoal, 2150, reason: "A's targets, not B's own decision");
    expect(pb.lastCheckin!.newTargets.cals, 2150);
    expect(pb.checkinToShow, isNull, reason: 'A already dismissed it');
  });

  test('a race on insert: the stored row wins and its targets are taken', () async {
    final g = goals();
    final sync = _DeviceSync(cloud)
      ..raceWith = {
        'user_id': 'user-1',
        'week_start': '2026-10-07',
        'variant': 'changed',
        'old_targets': {'cals': 2000, 'protein': 150, 'carbs': 220, 'fat': 65},
        'new_targets': {'cals': 2100, 'protein': 150, 'carbs': 245, 'fat': 65},
        'reason': {'tdee': 2100, 'tdee_prev': 2000, 'state': 'confident'},
        'created_at': '2026-10-07T07:00:00Z',
      };
    final p = device(g, sync: sync);
    await p.refresh();
    expect(cloud.inserts, 0);
    expect(g.caloriesGoal, 2100);
    expect(g.carbsGoal, 245);
    expect(p.lastCheckin!.newTargets.cals, 2100);
  });

  test('offline: runs from the device copy and uploads later', () async {
    cloud.online = false;
    final g = goals();
    final p = device(g);
    await p.refresh();
    expect(g.caloriesGoal, 2150);
    expect(p.lastCheckin, isNotNull);
    expect(cloud.rows, isEmpty);
    expect(CheckinSyncService().pendingWeeks(), {'2026-10-07'});

    cloud.online = true;
    await device(g).refresh();
    expect(cloud.rows.keys, ['2026-10-07']);
    expect(CheckinSyncService().pendingWeeks(), isEmpty);
    expect(g.caloriesGoal, 2150);
  });

  test('adaptive off: no row, no sheet, targets untouched', () async {
    final g = goals(adaptive: false);
    final p = device(g);
    await p.refresh();
    expect(p.checkins, isEmpty);
    expect(p.checkinToShow, isNull);
    expect(g.caloriesGoal, 2000);
    expect(cloud.rows, isEmpty);
    expect(p.previewCheckin(), isNull);
  });

  test('not the check-in day: nothing runs', () async {
    seedCloud('2026-10-01'); // last Thursday's
    final g = goals(weekday: DateTime.thursday);
    final p = device(g);
    await p.refresh();
    expect(cloud.inserts, 0);
    expect(p.lastCheckin!.weekStart, DateTime(2026, 10, 1), reason: 'the history came down');
    expect(g.caloriesGoal, 2000);
    expect(p.nextCheckinDay, DateTime(2026, 10, 8));
  });

  test('before 04:00 on the day: not yet', () async {
    now = DateTime(2026, 10, 7, 3, 30);
    seedCloud('2026-09-30'); // last Wednesday's
    final g = goals();
    final p = device(g, rows: [row(yesterday)]);
    await p.refresh();
    expect(cloud.inserts, 0);
    expect(p.checkins.map((c) => c.weekStart), [DateTime(2026, 9, 30)]);
  });

  test('still learning: an insufficient check-in, targets unchanged', () async {
    final g = goals();
    final p = device(g, rows: [row(yesterday, state: EnergyState.learning)]);
    await p.refresh();
    expect(p.lastCheckin!.variant, CheckinVariant.insufficient);
    expect(g.caloriesGoal, 2000);
    expect(g.tdee, 2000);
    expect(p.checkinToShow, isNotNull);
  });

  test('estimates not up to date: waits for the refresh that catches up', () async {
    final g = goals();
    final p = device(g, rows: [row(DateTime(2026, 10, 4))]);
    await p.refresh();
    expect(p.checkins, isEmpty);
  });

  test('dismissing sets seen_at here and in the cloud; the chip stays today', () async {
    final g = goals();
    final p = device(g);
    await p.refresh();
    await p.markCheckinSeen(p.lastCheckin!);
    expect(p.lastCheckin!.seenAt, now);
    expect(p.checkinToShow, isNull);
    expect(p.todaysCheckin, isNotNull);
    expect(cloud.rows['2026-10-07']!['seen_at'], isNotNull);

    // A restart doesn't show it again.
    expect(device(g).checkinToShow, isNull);

    // The chip ends with the day.
    now = DateTime(2026, 10, 8, 0, 1);
    expect(p.todaysCheckin, isNull);
  });

  test('a missed day runs at the first open later in the week', () async {
    now = DateTime(2026, 10, 9, 10); // Friday
    seedCloud('2026-09-30');
    final g = goals();
    final p = device(g, rows: [row(DateTime(2026, 10, 8))]);
    await p.refresh();
    expect(p.lastCheckin!.weekStart, DateTime(2026, 10, 7));
    expect(p.todaysCheckin, isNotNull);
  });

  test('preview: what a check-in would do now', () async {
    seedCloud('2026-10-01');
    final g = goals(weekday: DateTime.thursday);
    final p = device(g);
    await p.refresh();
    final d = p.previewCheckin()!;
    expect(d.variant, CheckinVariant.changed);
    expect(d.newTargets.cals - d.oldTargets.cals, 150);
    expect(g.caloriesGoal, 2000, reason: 'a preview changes nothing');
  });
}
