import 'dart:async';

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

  /// `fetchRemote` fails while the rest works (a flaky read).
  bool fetchFails = false;

  /// The account's `user_macros` row (only what the tests look at).
  Map<String, Object?> macros = {
    'calories_goal': 2000,
    'protein_goal': 150,
    'carbs_goal': 220,
    'fat_goal': 65,
    'steps_goal': 10000,
    'tdee': 2000,
    'updated_at': '2026-09-01T08:00:00.000Z',
  };
  bool macrosOnline = true;
  int targetWrites = 0;
}

/// A signed-in device: the real cache and queue, with [_Cloud] for the table.
class _DeviceSync extends CheckinSyncService {
  _DeviceSync(this.cloud, {this.user = 'user-1', this.device});

  final _Cloud cloud;
  final String user;

  /// Another install of the same account keeps its own state.
  final String? device;

  /// Rows another device inserts just before this one (a race).
  Map<String, Object?>? raceWith;

  /// When set, inserts wait for it (an upload in flight).
  Completer<void>? insertGate;

  /// When set, reads wait for it (a pull in flight).
  Completer<void>? fetchGate;

  /// The app is killed the moment the check-in is being recorded.
  bool crashOnStore = false;

  @override
  String? get userId => user;

  @override
  String? get stateKey => device == null ? super.stateKey : '${super.stateKey}:$device';

  void _check() {
    if (!cloud.online) throw Exception('offline');
  }

  @override
  Future<void> stage(GoalCheckin checkin) {
    if (crashOnStore) throw StateError('killed');
    return super.stage(checkin);
  }

  @override
  Future<GoalCheckin?> insertRemote(Map<String, Object?> row) async {
    if (insertGate != null) await insertGate!.future;
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
    if (fetchGate != null) await fetchGate!.future;
    _check();
    if (cloud.fetchFails) throw Exception('read failed');
    return [for (final r in cloud.rows.values) GoalCheckin.fromJson(r)!];
  }
}

/// Goals whose `user_macros` row is [_Cloud.macros].
class _CloudGoals extends GoalsProvider {
  _CloudGoals(this.cloud, {required DateTime Function() clock})
      : _now = clock,
        super(userId: 'user-1', clock: clock);

  final _Cloud cloud;
  final DateTime Function() _now;

  /// The app is killed as the targets are applied.
  bool crashOnApply = false;

  @override
  void applyCheckinTargets(CheckinTargets targets, {required double tdee}) {
    if (crashOnApply) throw StateError('killed');
    super.applyCheckinTargets(targets, tdee: tdee);
  }

  @override
  Future<void> syncToCloud() async {
    if (!cloud.macrosOnline) return; // the real one logs and swallows it
    cloud.macros = {
      ...userMacrosPayload(),
      'updated_at': _now().toUtc().toIso8601String(),
    };
  }

  @override
  Future<RemoteTargets?> fetchRemoteTargets(String uid) async {
    if (!cloud.macrosOnline) throw Exception('offline');
    final m = cloud.macros;
    return RemoteTargets(
      CheckinTargets.fromJson({
        'cals': m['calories_goal'],
        'protein': m['protein_goal'],
        'carbs': m['carbs_goal'],
        'fat': m['fat_goal'],
      })!,
      tdee: (m['tdee'] as num?)?.toDouble(),
      updatedAt: DateTime.tryParse('${m['updated_at']}'),
    );
  }

  @override
  Future<bool> writeRemoteTargets(String uid, Map<String, dynamic> payload,
      {required DateTime? ifUpdatedAt}) async {
    if (!cloud.macrosOnline) throw Exception('offline');
    if (DateTime.tryParse('${cloud.macros['updated_at']}') != ifUpdatedAt) return false;
    cloud.targetWrites++;
    cloud.macros = {
      ...cloud.macros,
      ...payload,
      'updated_at': _now().toUtc().toIso8601String(),
    };
    return true;
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
    for (final key in ['goal_checkins:user-1', 'goal_checkins:user-1:b', 'goal_checkins:user-2']) {
      await StorageService().delete(key);
    }
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
    final g = _CloudGoals(cloud, clock: () => now)
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
    expect(cloud.macros['calories_goal'], 2150);
    expect(cloud.macros['tdee'], 2400);
    expect(_DeviceSync(cloud).applyQueue(), isEmpty);
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
    final b = goals();
    final pb = device(b, rows: [row(yesterday, tdee: 2600)], sync: _DeviceSync(cloud, device: 'b'));
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
    expect(_DeviceSync(cloud).pendingWeeks(), {'2026-10-07'});

    cloud.online = true;
    await device(g).refresh();
    expect(cloud.rows.keys, ['2026-10-07']);
    expect(_DeviceSync(cloud).pendingWeeks(), isEmpty);
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

  group('Codex review (fix pass)', () {
    /// A second device's goals, still on the old targets, whose setup doesn't
    /// touch the cloud.
    GoalsProvider otherDevice() {
      final online = cloud.macrosOnline;
      cloud.macrosOnline = false;
      final g = goals();
      cloud.macrosOnline = online;
      return g;
    }

    Map<String, Object?> cloudRow(String week, {required int cals, String? seenAt}) => {
          'user_id': 'user-1',
          'week_start': week,
          'variant': 'changed',
          'old_targets': {'cals': 2000, 'protein': 150, 'carbs': 220, 'fat': 65},
          'new_targets': {'cals': cals, 'protein': 150, 'carbs': 245, 'fat': 65},
          'reason': {'tdee': 2300, 'tdee_prev': 2000, 'state': 'confident'},
          'seen_at': seenAt,
          'created_at': '2026-10-07T06:00:00Z',
        };

    test('P1 logout during an upload: the next account never sees the old one\'s check-ins',
        () async {
      cloud.online = false;
      final g = goals();
      final sync = _DeviceSync(cloud);
      await device(g, sync: sync).refresh(); // an offline check-in waits to upload

      // Back online, the next app open's upload stalls, and the user logs out.
      cloud.online = true;
      sync.insertGate = Completer();
      final p = device(g, sync: sync);
      final inFlight = p.refresh();
      await pumpEventQueue();
      await p.clearUserData();
      await g.clearUserData();
      sync.insertGate!.complete();
      await inFlight;

      expect(_DeviceSync(cloud, user: 'user-2').loadCache(), isEmpty,
          reason: "account B's device must not show A's history");
      expect(_DeviceSync(cloud).loadCache(), isEmpty, reason: 'logout forgets A here');
    });

    test('P1 logout while a check-in is being decided: nothing is applied or stored', () async {
      final g = goals();
      final sync = _DeviceSync(cloud)..fetchGate = Completer();
      final p = device(g, sync: sync);
      final inFlight = p.refresh();
      await pumpEventQueue();
      await p.clearUserData();
      await g.clearUserData();
      sync.fetchGate!.complete();
      await inFlight;

      expect(cloud.rows, isEmpty);
      expect(_DeviceSync(cloud, user: 'user-2').loadCache(), isEmpty);
      expect(_DeviceSync(cloud).loadCache(), isEmpty);
      expect(StorageService().get('nutrition_goals'), isNull,
          reason: "a late apply mustn't write A's targets back to the device");
    });

    test('P1 killed while recording the check-in: a restart doesn\'t step twice', () async {
      final g = goals();
      final p = device(g, sync: _DeviceSync(cloud)..crashOnStore = true);
      await p.refresh(); // the app dies here

      // Restart: the goals come back from the device.
      final restarted = _CloudGoals(cloud, clock: () => now);
      final p2 = device(restarted);
      await p2.refresh();
      await device(restarted).refresh();
      expect(restarted.caloriesGoal, 2150, reason: 'one ±150 step, never 2,300');
      expect(p2.checkins, hasLength(1));
      expect(cloud.inserts, 1);
    });

    test('killed after the row is recorded, before the targets: a restart applies them once',
        () async {
      final g = goals() as _CloudGoals..crashOnApply = true;
      await device(g).refresh(); // the app dies here
      expect(_DeviceSync(cloud).loadCache().keys, ['2026-10-07']);
      expect(cloud.macros['calories_goal'], 2000);

      final restarted = _CloudGoals(cloud, clock: () => now);
      expect(restarted.caloriesGoal, 2000);
      await device(restarted).refresh();
      await device(restarted).refresh();
      expect(restarted.caloriesGoal, 2150);
      expect(cloud.inserts, 1);
      expect(cloud.macros['calories_goal'], 2150);
    });

    test('P1 adopting another device\'s check-in keeps its newer manual edit', () async {
      // A checks in (2,000 → 2,150), then edits the targets by hand an hour later.
      final a = goals();
      await device(a, sync: _DeviceSync(cloud)).refresh();
      expect(cloud.macros['calories_goal'], 2150);
      now = now.add(const Duration(hours: 1));
      await a.updateGoals(
          calories: 2300, protein: 160, carbs: 250, fat: 70, steps: 12000, bmr: 1700, tdee: 2400);
      expect(cloud.macros['calories_goal'], 2300);

      // B, still on 2,000 with no check-ins on the device, pulls A's.
      final b = otherDevice();
      await device(b, sync: _DeviceSync(cloud, device: 'b')).refresh();
      expect(cloud.macros['calories_goal'], 2300, reason: "B mustn't write 2,150 over A's edit");
      expect(cloud.macros['steps_goal'], 12000, reason: 'nor any other setting');
      expect(b.caloriesGoal, 2300, reason: "B takes the account's newer targets");
    });

    test('P1 a failed user_macros write is retried, not counted as applied', () async {
      cloud.macrosOnline = false;
      final g = goals();
      final p = device(g);
      await p.refresh();
      expect(g.caloriesGoal, 2150);
      expect(cloud.rows.keys, ['2026-10-07']);
      expect(cloud.macros['calories_goal'], 2000);

      cloud.macrosOnline = true;
      await p.refresh();
      expect(cloud.macros['calories_goal'], 2150, reason: 'the same session retries');
    });

    test('P1 conflict adoption survives a failed fetch right after it', () async {
      // B checks in offline (2,150) while A stores 2,100 for the week.
      cloud.online = false;
      final b = goals();
      final p = device(b);
      await p.refresh();
      expect(b.caloriesGoal, 2150);
      cloud.rows['2026-10-07'] = cloudRow('2026-10-07', cals: 2100);
      cloud.macros = {...cloud.macros, 'calories_goal': 2100, 'carbs_goal': 245};

      // Back online: the insert loses, then the read fails.
      cloud.online = true;
      cloud.fetchFails = true;
      await device(b).refresh();
      expect(b.caloriesGoal, 2100, reason: "A's row won the week, so its targets apply");

      cloud.fetchFails = false;
      await device(b).refresh();
      expect(b.caloriesGoal, 2100);
      expect(cloud.macros['calories_goal'], 2100);
    });

    test('P2 pending uploads retry on the next refresh of the same session', () async {
      cloud.online = false;
      final g = goals();
      final p = device(g);
      await p.refresh();
      expect(cloud.rows, isEmpty);

      cloud.online = true;
      await p.refresh();
      expect(cloud.rows.keys, ['2026-10-07']);
    });

    test('P2 a dismissal made offline is uploaded when the insert loses', () async {
      cloud.online = false;
      final b = goals();
      final p = device(b);
      await p.refresh();
      await p.markCheckinSeen(p.lastCheckin!);
      cloud.rows['2026-10-07'] = cloudRow('2026-10-07', cals: 2100);

      cloud.online = true;
      await device(b).refresh();
      expect(cloud.rows['2026-10-07']!['seen_at'], isNotNull,
          reason: "other devices mustn't show the sheet again");
    });

    test('a dismissal during an upload isn\'t lost when the upload finishes', () async {
      cloud.online = false;
      final g = goals();
      final sync = _DeviceSync(cloud);
      final p = device(g, sync: sync);
      await p.refresh();
      cloud.online = true;
      sync.insertGate = Completer();
      final inFlight = device(g, sync: sync).refresh();
      await pumpEventQueue();
      final dismissed = p.markCheckinSeen(p.lastCheckin!); // waits for the upload
      sync.insertGate!.complete();
      await Future.wait([inFlight, dismissed]);
      expect(sync.loadCache()['2026-10-07']!.seenAt, isNotNull);
      await device(g, sync: sync).refresh();
      expect(cloud.rows['2026-10-07']!['seen_at'], isNotNull);
    });

    test('a learning reset the day before still gets the check-in (insufficient)', () async {
      seedCloud('2026-09-30'); // last Wednesday's
      final g = goals()..startLearning(DateTime(2026, 10, 6));
      final p = device(g, rows: [row(yesterday, state: EnergyState.learning)]);
      await p.refresh();
      expect(p.lastCheckin!.weekStart, DateTime(2026, 10, 7));
      expect(p.lastCheckin!.variant, CheckinVariant.insufficient);
      expect(g.caloriesGoal, 2000);
    });
  });
}
