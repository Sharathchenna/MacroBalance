import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/services/checkin_sync_service.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/energy_sync_service.dart';
import 'package:macrotracker/services/phase_sync_service.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

/// Stored estimates are whatever the test says.
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

/// The account's tables, shared by every "device".
class _Cloud {
  final Map<String, Map<String, Object?>> checkins = {};
  final Map<int, Map<String, Object?>> phases = {};
  bool online = true;
}

class _Checkins extends CheckinSyncService {
  _Checkins(this.cloud, {this.device});

  final _Cloud cloud;
  final String? device;

  @override
  String? get userId => 'user-1';

  @override
  String? get stateKey => device == null ? super.stateKey : '${super.stateKey}:$device';

  @override
  Future<GoalCheckin?> insertRemote(Map<String, Object?> row) async {
    if (!cloud.online) throw Exception('offline');
    final week = row['week_start'] as String;
    final existing = cloud.checkins[week];
    if (existing != null) return GoalCheckin.fromJson(existing);
    cloud.checkins[week] = jsonDecode(jsonEncode(row)) as Map<String, Object?>;
    return null;
  }

  @override
  Future<void> markSeenRemote(DateTime weekStart, DateTime at) async {}

  @override
  Future<List<GoalCheckin>> fetchRemote() async {
    if (!cloud.online) throw Exception('offline');
    return [for (final r in cloud.checkins.values) GoalCheckin.fromJson(r)!];
  }
}

class _Phases extends PhaseSyncService {
  _Phases(this.cloud, {this.device});

  final _Cloud cloud;
  final String? device;

  @override
  String? get userId => 'user-1';

  @override
  String? get stateKey => device == null ? super.stateKey : '${super.stateKey}:$device';

  @override
  Future<void> upsertRemote(Map<String, Object?> row) async {
    if (!cloud.online) throw Exception('offline');
    cloud.phases[row['seq'] as int] = Map.of(row);
  }

  @override
  Future<void> deleteRemote(int seq) async {
    if (!cloud.online) throw Exception('offline');
    cloud.phases.remove(seq);
  }

  @override
  Future<List<GoalPhase>> fetchRemote() async {
    if (!cloud.online) throw Exception('offline');
    return [for (final r in cloud.phases.values) GoalPhase.fromJson(r)!];
  }
}

/// Goals whose `user_macros` writes go nowhere (the check-in apply path is
/// covered in checkin_provider_test).
class _Goals extends GoalsProvider {
  _Goals({required super.clock}) : super(userId: 'user-1');

  @override
  Future<void> syncToCloud() async {}

  @override
  Future<RemoteTargets?> fetchRemoteTargets(String uid) async => null;
}

void main() {
  // Monday Oct 12 2026, 09:00; check-ins on Mondays. The plan started Jul 20
  // at 90 kg: lose 5% (to 85.5), then 4 weeks of maintenance.
  var now = DateTime(2026, 10, 12, 9);
  final learning = DateTime(2026, 7, 20);
  DateTime d(int month, int day) => DateTime(2026, month, day);

  late _Cloud cloud;

  EnergyEstimate row(DateTime day, {double trend = 85.4, double tdee = 2500}) => EnergyEstimate(
        day: day,
        tdee: tdee,
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

  final losing = firstPhase(
      style: PlanStyle.phased, goal: GoalKind.lose, seq: 1, on: learning, trendKg: 90, heightCm: 180);

  Future<GoalsProvider> goals({bool adaptive = true, PlanStyle style = PlanStyle.phased}) async {
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
          'checkin_weekday': DateTime.monday,
          'plan_style': style.code,
        }));
    return _Goals(clock: () => now);
  }

  EnergyProvider device(GoalsProvider g, {List<EnergyEstimate>? rows, String? on}) =>
      EnergyProvider(
        userId: 'user-1',
        sync: _FixtureSync(rows ?? [row(d(10, 4), trend: 86), row(d(10, 11))]),
        checkinSync: _Checkins(cloud, device: on),
        phaseSync: _Phases(cloud, device: on),
        clock: () => now,
        inBackground: false,
        debounce: Duration.zero,
      )
        ..inputs = (() => inputs)
        ..goals = g;

  void seedPhases(List<GoalPhase> phases) {
    for (final p in phases) {
      cloud.phases[p.seq] = {'user_id': 'user-1', ...p.toJson()};
    }
  }

  // Last week's check-in ran, so this Monday's is due.
  void seedLastWeek() => cloud.checkins['2026-10-05'] = {
        'user_id': 'user-1',
        'week_start': '2026-10-05',
        'variant': 'unchanged',
        'old_targets': {'cals': 2000, 'protein': 150, 'carbs': 190, 'fat': 65},
        'new_targets': {'cals': 2000, 'protein': 150, 'carbs': 190, 'fat': 65},
        'reason': {'tdee': 2400, 'tdee_prev': 2400, 'state': 'confident'},
        'seen_at': '2026-10-05T08:00:00Z',
        'created_at': '2026-10-05T08:00:00Z',
      };

  setUp(() async {
    await setUpTestEnvironment();
    for (final key in [
      'nutrition_goals',
      'goal_checkins:user-1',
      'goal_checkins:user-1:b',
      'goal_phases:user-1',
      'goal_phases:user-1:b',
    ]) {
      await StorageService().delete(key);
    }
    now = DateTime(2026, 10, 12, 9);
    cloud = _Cloud();
    seedLastWeek();
    seedPhases([losing]);
  });

  group('variant F at the check-in', () {
    test('adaptive: maintenance targets from the estimate, phases moved, row stored', () async {
      final g = await goals();
      final p = device(g);
      await p.refresh();

      final c = p.lastCheckin!;
      expect(c.weekStart, d(10, 12));
      expect(c.variant, CheckinVariant.phaseToMaintain);
      expect(c.newTargets.cals, 2500); // +500: no step cap
      expect(g.caloriesGoal, 2500);
      expect(g.tdee, 2500);
      expect(p.checkinToShow, same(c));

      expect(p.phases.map((x) => (x.seq, x.kind, x.endReason)), [
        (1, PhaseKind.lose, PhaseEndReason.reached),
        (2, PhaseKind.maintain, null),
      ]);
      expect(p.currentPhase!.startedOn, d(10, 12));
      expect(cloud.phases.keys, unorderedEquals([1, 2]));
      expect(cloud.phases[1]!['end_reason'], 'reached');
      expect(cloud.checkins['2026-10-12']!['variant'], 'phase_to_maintain');
      expect(p.canChangePhase(c), isTrue);
    });

    test('fixed targets: they change at the boundary, from the formula at the trend', () async {
      final g = await goals(adaptive: false);
      final p = device(g);
      await p.refresh();
      final c = p.lastCheckin!;
      expect(c.variant, CheckinVariant.phaseToMaintain);
      final formula = g.checkinSettings.formulaTdeeAt(85.4);
      expect(c.reason.tdee, closeTo(formula, 0.5));
      expect(g.caloriesGoal, formula.round());
      expect(p.currentPhase!.kind, PhaseKind.maintain);
    });

    test('runs once: a restart neither re-decides nor moves the phases again', () async {
      final g = await goals();
      await device(g).refresh();
      final again = device(g);
      await again.refresh();
      expect(again.phases, hasLength(2));
      expect(cloud.checkins.keys, ['2026-10-05', '2026-10-12']);
      expect(g.caloriesGoal, 2500);
    });

    test('another device adopts the row and the phases without moving them twice', () async {
      final a = await goals();
      await device(a).refresh();
      final b = device(await goals(), on: 'b');
      await b.refresh();
      expect(b.lastCheckin!.variant, CheckinVariant.phaseToMaintain);
      expect(b.phases.map((x) => x.seq), [1, 2]);
      expect(cloud.phases.keys, unorderedEquals([1, 2]));
    });

    test('offline: phases move on the device and upload later', () async {
      await _Phases(cloud).sync(); // the device has its phases from an earlier open
      cloud.online = false;
      final g = await goals();
      final p = device(g);
      await p.refresh();
      expect(p.currentPhase!.kind, PhaseKind.maintain);
      expect(cloud.phases.keys, [1]);
      cloud.online = true;
      now = now.add(const Duration(hours: 2));
      await p.refresh();
      expect(cloud.phases.keys, unorderedEquals([1, 2]));
      expect(cloud.phases[2]!['kind'], 'maintain');
    });
  });

  group('the sheet\'s choices', () {
    test('Keep losing: the break is skipped and lose targets come back', () async {
      final g = await goals();
      final p = device(g);
      await p.refresh();
      final c = p.lastCheckin!;
      await p.keepLosing(c);

      expect(p.phases.map((x) => (x.seq, x.kind, x.endReason)), [
        (1, PhaseKind.lose, PhaseEndReason.reached),
        (2, PhaseKind.maintain, PhaseEndReason.skipped),
        (3, PhaseKind.lose, null),
      ]);
      final lose = phaseTargets(
          kind: PhaseKind.lose, settings: g.checkinSettings, tdee: 2500, weightKg: 85.4);
      expect(g.caloriesGoal, lose.targets.cals);
      expect(g.caloriesGoal, lessThan(2500));
      expect(p.canChangePhase(c), isFalse);
      expect(cloud.phases.keys, unorderedEquals([1, 2, 3]));

      // Later refreshes keep the choice: neither the F targets nor the phase
      // change come back.
      now = now.add(const Duration(hours: 3));
      await p.refresh();
      expect(g.caloriesGoal, lose.targets.cals);
      expect(p.phases, hasLength(3));
      // Only once.
      await p.keepLosing(c);
      expect(p.phases, hasLength(3));
    });

    test('Extend break: maintenance runs 2 weeks longer on its targets', () async {
      // Week 4 of the break: due to end today into phase 3.
      seedPhases([
        losing.close(d(9, 14), PhaseEndReason.reached),
        GoalPhase(
            seq: 2,
            kind: PhaseKind.maintain,
            startedOn: d(9, 14),
            startTrendKg: 85.4,
            plannedWeeks: kMaintenanceWeeks),
      ]);
      final g = await goals();
      await StorageService().put(
          'nutrition_goals',
          jsonEncode({
            ...jsonDecode(StorageService().get('nutrition_goals') as String) as Map,
            'macro_targets': {'calories': 2450, 'protein': 150, 'carbs': 300, 'fat': 70},
          }));
      await g.load();
      final p = device(g, rows: [row(d(10, 4), trend: 85.8), row(d(10, 11), trend: 85.9)]);
      await p.refresh();
      final c = p.lastCheckin!;
      expect(c.variant, CheckinVariant.phaseToLose);
      expect(g.caloriesGoal, lessThan(2450));
      expect(p.currentPhase!.seq, 3);

      await p.extendBreak(c);
      expect(p.phases.map((x) => x.seq), [1, 2]);
      expect(p.currentPhase!.plannedWeeks, kMaintenanceWeeks + kExtendBreakWeeks);
      expect(g.caloriesGoal, 2450);
      expect(cloud.phases.keys, unorderedEquals([1, 2]));
      expect(p.canChangePhase(c), isFalse);
      // F's "Keep losing" doesn't apply to G.
      await p.keepLosing(c);
      expect(p.phases, hasLength(2));
    });
  });

  test('fixed targets: a phase that ends mid-week waits for the next check-in', () async {
    // Monday: not there yet (85.6 > 85.5), nothing to record.
    final g = await goals(adaptive: false);
    final p = device(g, rows: [row(d(10, 4), trend: 86), row(d(10, 11), trend: 85.6)]);
    await p.refresh();
    expect(p.lastCheckin!.weekStart, d(10, 5));
    expect(p.currentPhase!.seq, 1);

    // Wednesday: it is now, but the week has been decided.
    now = DateTime(2026, 10, 14, 9);
    final wed = device(g, rows: [row(d(10, 6)), row(d(10, 13), trend: 85.3)]);
    await wed.refresh();
    expect(wed.lastCheckin!.weekStart, d(10, 5));
    expect(wed.currentPhase!.seq, 1);
    expect(g.caloriesGoal, 2000);

    // Next Monday: F.
    now = DateTime(2026, 10, 19, 9);
    final mon = device(g, rows: [row(d(10, 11)), row(d(10, 18), trend: 85.2)]);
    await mon.refresh();
    expect(mon.lastCheckin!.variant, CheckinVariant.phaseToMaintain);
    expect(mon.lastCheckin!.weekStart, d(10, 19));
    expect(mon.currentPhase!.kind, PhaseKind.maintain);
  });

  test('replan: the open phase closes and a fresh sequence starts today', () async {
    final g = await goals();
    final p = device(g, rows: [row(d(10, 4), trend: 87), row(d(10, 11), trend: 87)]);
    await p.refresh(); // pulls the phases; nothing due
    await p.replan(style: PlanStyle.breaks, goal: GoalKind.lose, trendKg: 87, heightCm: 180);
    expect(p.phases.map((x) => (x.seq, x.endReason)), [
      (1, PhaseEndReason.replanned),
      (2, null),
    ]);
    expect(p.currentPhase!.plannedWeeks, kBreakEveryWeeks);
    expect(p.currentPhase!.startedOn, d(10, 12));
    expect(cloud.phases.keys, unorderedEquals([1, 2]));
  });

  test('End phase early: requested today, ends at the next check-in', () async {
    final g = await goals();
    final p = device(g, rows: [row(d(10, 4), trend: 87), row(d(10, 11), trend: 87)]);
    await p.refresh();
    await p.endPhaseEarly();
    expect(p.currentPhase!.endRequestedOn, d(10, 12));
    expect(cloud.phases[1]!['end_requested_on'], '2026-10-12');

    now = DateTime(2026, 10, 19, 9);
    final next = device(g, rows: [row(d(10, 11), trend: 87), row(d(10, 18), trend: 86.8)]);
    await next.refresh();
    expect(next.lastCheckin!.variant, CheckinVariant.phaseToMaintain);
    expect(next.phases.first.endReason, PhaseEndReason.userEnded);
  });

  test('logout forgets the phases on the device', () async {
    final g = await goals();
    final p = device(g);
    await p.refresh();
    await p.clearUserData();
    expect(p.phases, isEmpty);
    expect(StorageService().get('goal_phases:user-1'), isNull);
  });
}
