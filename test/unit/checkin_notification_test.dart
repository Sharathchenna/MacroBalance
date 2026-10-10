import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/services/checkin_notifier.dart';
import 'package:macrotracker/services/checkin_sync_service.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/energy_sync_service.dart';
import 'package:macrotracker/services/phase_sync_service.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

/// Records what would reach the device's notification centre.
class _FakeNotifier extends CheckinNotifier {
  bool permitted = true;
  final List<DateTime?> calls = [];
  DateTime? pending;

  @override
  Future<bool> allowed() async => permitted;

  @override
  Future<void> schedule(DateTime at) async {
    calls.add(at);
    pending = at;
  }

  @override
  Future<void> cancel() async {
    calls.add(null);
    pending = null;
  }
}

class _FixtureSync extends EnergySyncService {
  _FixtureSync(this.rows);

  final List<EnergyEstimate> rows;
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

class _Cloud {
  final Map<String, Map<String, Object?>> checkins = {};
  final Map<int, Map<String, Object?>> phases = {};
}

class _Checkins extends CheckinSyncService {
  _Checkins(this.cloud);

  final _Cloud cloud;

  @override
  String? get userId => 'user-1';

  @override
  Future<GoalCheckin?> insertRemote(Map<String, Object?> row) async {
    final week = row['week_start'] as String;
    final existing = cloud.checkins[week];
    if (existing != null) return GoalCheckin.fromJson(existing);
    cloud.checkins[week] = jsonDecode(jsonEncode(row)) as Map<String, Object?>;
    return null;
  }

  @override
  Future<void> markSeenRemote(DateTime weekStart, DateTime at) async {}

  @override
  Future<List<GoalCheckin>> fetchRemote() async =>
      [for (final r in cloud.checkins.values) GoalCheckin.fromJson(r)!];
}

class _Phases extends PhaseSyncService {
  _Phases(this.cloud);

  final _Cloud cloud;

  @override
  String? get userId => 'user-1';

  @override
  Future<void> upsertRemote(Map<String, Object?> row) async =>
      cloud.phases[row['seq'] as int] = Map.of(row);

  @override
  Future<void> deleteRemote(int seq) async => cloud.phases.remove(seq);

  @override
  Future<List<GoalPhase>> fetchRemote() async =>
      [for (final r in cloud.phases.values) GoalPhase.fromJson(r)!];
}

class _Goals extends GoalsProvider {
  _Goals({required super.clock}) : super(userId: 'user-1');

  @override
  Future<void> syncToCloud() async {}

  @override
  Future<RemoteTargets?> fetchRemoteTargets(String uid) async => null;

  @override
  Future<bool> writeRemoteTargets(String uid, Map<String, dynamic> payload,
          {required DateTime? ifUpdatedAt}) async =>
      true;
}

void main() {
  // Thursday Oct 8 2026, 09:00. Learning started Monday Jul 20 at 90 kg.
  var now = DateTime(2026, 10, 8, 9);
  final learning = DateTime(2026, 7, 20);
  DateTime d(int month, int day, [int hour = 0]) => DateTime(2026, month, day, hour);

  late _Cloud cloud;
  late _FakeNotifier notifier;

  EnergyEstimate row(DateTime day, {double trend = 85.4}) => EnergyEstimate(
        day: day,
        tdee: 2500,
        tdeeSd: 90,
        state: EnergyState.confident,
        completeDays: 18,
        weighIns: 20,
        updated: true,
        trendWeightKg: trend,
        avgIntake: 1950,
      );

  final inputs = EstimatorInputs(
    learningStartedOn: learning,
    formulaTdee: 2400,
    body: const BodyProfile(sex: Sex.male, heightCm: 180, age: 35),
  );

  Future<GoalsProvider> goals({
    bool adaptive = true,
    PlanStyle style = PlanStyle.steady,
    int weekday = DateTime.monday,
  }) async {
    await StorageService().put(
        'nutrition_goals',
        jsonEncode({
          'macro_targets': {'calories': 2000, 'protein': 150, 'carbs': 190, 'fat': 65},
          'bmr': 1800,
          'tdee': 2400,
          'formula_tdee': 2400,
          'goal_type': 'lose',
          'pace_pct_per_week': 0.5,
          'goal_weight_kg': 75,
          'current_weight_kg': 85.4,
          'sex': 'male',
          'height_cm': 180,
          'age': 35,
          'age_recorded_on': '2026-01-01',
          'activity_level': 3,
          'learning_started_on': '2026-07-20',
          'adaptive_goals': adaptive,
          'checkin_weekday': weekday,
          'plan_style': style.code,
        }));
    return _Goals(clock: () => now);
  }

  EnergyProvider device(GoalsProvider g, {double trend = 85.4}) => EnergyProvider(
        userId: 'user-1',
        sync: _FixtureSync([row(d(10, 1), trend: trend + 0.5), row(d(10, 7), trend: trend)]),
        checkinSync: _Checkins(cloud),
        phaseSync: _Phases(cloud),
        checkinNotifier: notifier,
        clock: () => now,
        inBackground: false,
        debounce: Duration.zero,
      )
        ..inputs = (() => inputs)
        ..goals = g;

  // Monday Oct 5's check-in ran (or [week]'s).
  void seedLastCheckin([String week = '2026-10-05']) => cloud.checkins[week] = {
        'user_id': 'user-1',
        'week_start': week,
        'variant': 'unchanged',
        'old_targets': {'cals': 2000, 'protein': 150, 'carbs': 190, 'fat': 65},
        'new_targets': {'cals': 2000, 'protein': 150, 'carbs': 190, 'fat': 65},
        'reason': {'tdee': 2400, 'tdee_prev': 2400, 'state': 'confident'},
        'seen_at': '2026-10-05T08:00:00Z',
        'created_at': '2026-10-05T08:00:00Z',
      };

  void seedLosing() {
    final losing = firstPhase(
        style: PlanStyle.phased, goal: GoalKind.lose, seq: 1, on: learning, trendKg: 90, heightCm: 180);
    cloud.phases[1] = {'user_id': 'user-1', ...losing.toJson()};
  }

  /// Lets the queued reschedule run.
  Future<void> settle() => pumpEventQueue();

  setUp(() async {
    await setUpTestEnvironment();
    for (final key in ['nutrition_goals', 'goal_checkins:user-1', 'goal_phases:user-1']) {
      await StorageService().delete(key);
    }
    now = d(10, 8, 9);
    cloud = _Cloud();
    notifier = _FakeNotifier();
    seedLastCheckin();
  });

  test('adaptive: 08:00 on the next check-in day', () async {
    final p = device(await goals());
    await p.refresh();
    await settle();
    expect(p.checkinNotificationTime, d(10, 12, 8));
    expect(notifier.pending, d(10, 12, 8));
  });

  test('changing the check-in day to tomorrow moves it to tomorrow 08:00', () async {
    // The last check-in was Friday Oct 2, a week before tomorrow; check-ins
    // are on Saturdays, so the next is Saturday Oct 10.
    cloud.checkins.clear();
    seedLastCheckin('2026-10-02');
    final g = await goals(weekday: DateTime.saturday);
    final p = device(g);
    await p.refresh();
    await settle();
    expect(p.checkins, hasLength(1), reason: 'nothing was due today');
    expect(notifier.pending, d(10, 10, 8));

    g.checkinWeekday = DateTime.friday; // today + 1
    await settle();
    expect(notifier.pending, d(10, 9, 8));
    expect(notifier.calls.last, d(10, 9, 8));
  });

  test('after a check-in runs, it moves to the week after', () async {
    cloud.checkins.clear();
    final g = await goals(weekday: DateTime.thursday);
    final p = device(g);
    await p.refresh();
    await settle();
    expect(p.lastCheckin!.weekStart, d(10, 8), reason: "today's check-in ran");
    expect(notifier.pending, d(10, 15, 8));
  });

  test('moving the day right after a check-in waits a full week', () async {
    final g = await goals();
    final p = device(g);
    await p.refresh();
    g.checkinWeekday = DateTime.friday;
    await settle();
    // Monday Oct 5 ran, so not this Friday: the next one.
    expect(notifier.pending, d(10, 16, 8));
  });

  test('on the check-in day before 08:00 (and before it runs), it is that morning', () async {
    now = d(10, 12, 3);
    final p = device(await goals());
    await p.refresh();
    await settle();
    expect(notifier.pending, d(10, 12, 8));
  });

  test('asking again for the same time does nothing', () async {
    final p = device(await goals());
    await p.refresh();
    await p.refresh();
    await settle();
    expect(notifier.calls, [d(10, 12, 8)]);
  });

  test('turning adaptive goals off with a steady plan cancels it', () async {
    final g = await goals();
    final p = device(g);
    await p.refresh();
    await settle();
    expect(notifier.pending, isNotNull);

    g.adaptiveGoals = false;
    await settle();
    expect(p.checkinNotificationTime, isNull);
    expect(notifier.pending, isNull);
    expect(notifier.calls.last, isNull);
  });

  test('fixed targets on a phased plan: the day a phase would change', () async {
    seedLosing(); // 5% from 90 kg: ends at 85.5
    final g = await goals(adaptive: false, style: PlanStyle.phased);
    final p = device(g); // trend 85.4: the phase ends at the next check-in
    await p.refresh();
    await settle();
    expect(notifier.pending, d(10, 12, 8));
  });

  test('fixed targets on a phased plan: no change soon means the 16-week end', () async {
    seedLosing();
    final g = await goals(adaptive: false, style: PlanStyle.phased);
    final p = device(g, trend: 88); // far from 85.5
    await p.refresh();
    await settle();
    // Jul 20 + 16 weeks = Nov 9, a Monday.
    expect(notifier.pending, d(11, 9, 8));
  });

  test('without notification permission nothing is scheduled; granting it later does', () async {
    notifier.permitted = false;
    final g = await goals();
    final p = device(g);
    await p.refresh();
    await settle();
    expect(notifier.pending, isNull);

    notifier.permitted = true;
    await p.refresh();
    await settle();
    expect(notifier.pending, d(10, 12, 8));
  });

  test('signing out cancels it', () async {
    final p = device(await goals());
    await p.refresh();
    await settle();
    expect(notifier.pending, isNotNull);

    await p.clearUserData();
    await settle();
    expect(notifier.pending, isNull);
  });
}
