import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
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
  // Monday Oct 12 2026, 09:00; check-ins on Mondays. A steady lose plan from
  // 90 kg to 75 kg that has just got there.
  var now = DateTime(2026, 10, 12, 9);
  final learning = DateTime(2026, 7, 20);
  DateTime d(int month, int day) => DateTime(2026, month, day);

  late _Cloud cloud;

  EnergyEstimate row(DateTime day, {double trend = 74.9, double tdee = 2500}) => EnergyEstimate(
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
      style: PlanStyle.steady, goal: GoalKind.lose, seq: 1, on: learning, trendKg: 90, heightCm: 180);

  Future<GoalsProvider> goals({
    bool adaptive = true,
    PlanStyle style = PlanStyle.steady,
    String goalType = 'lose',
  }) async {
    await StorageService().put(
        'nutrition_goals',
        jsonEncode({
          'macro_targets': {'calories': 2000, 'protein': 150, 'carbs': 190, 'fat': 65},
          'bmr': 1800,
          'tdee': 2400,
          'formula_tdee': 2400,
          'goal_type': goalType,
          'pace_pct_per_week': goalType == 'maintain' ? null : 0.5,
          'goal_weight_kg': 75,
          'current_weight_kg': 80,
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
        sync: _FixtureSync(rows ?? [row(d(10, 4), trend: 75.2), row(d(10, 11))]),
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

  group('variant D at the check-in', () {
    for (final adaptive in [true, false]) {
      test('${adaptive ? 'adaptive' : 'fixed targets'}: a row is stored and nothing else moves',
          () async {
        final g = await goals(adaptive: adaptive);
        final p = device(g);
        await p.refresh();

        final c = p.lastCheckin!;
        expect(c.weekStart, d(10, 12));
        expect(c.variant, CheckinVariant.goalReached);
        expect(c.oldTargets, c.newTargets);
        expect(g.caloriesGoal, 2000);
        expect(g.goalType, 'lose');
        expect(p.checkinToShow, same(c));
        expect(p.currentPhase!.seq, 1);
        expect(p.phases, hasLength(1));
        expect(cloud.checkins['2026-10-12']!['variant'], 'goal_reached');
        expect(cloud.phases.keys, [1]);
      });
    }

    test('runs once: a restart neither re-decides nor changes anything', () async {
      final g = await goals();
      await device(g).refresh();
      final again = device(g);
      await again.refresh();
      expect(cloud.checkins.keys, ['2026-10-05', '2026-10-12']);
      expect(g.caloriesGoal, 2000);
    });

    test('left unanswered, the next check-in asks again', () async {
      final g = await goals();
      final p = device(g);
      await p.refresh();
      await p.markCheckinSeen(p.lastCheckin!);
      now = DateTime(2026, 10, 19, 9);
      final next = device(g, rows: [row(d(10, 11)), row(d(10, 18), trend: 74.7)]);
      await next.refresh();
      expect(next.lastCheckin!.weekStart, d(10, 19));
      expect(next.lastCheckin!.variant, CheckinVariant.goalReached);
      expect(next.checkinToShow, isNotNull);
    });

    test('not reached yet: the usual check-in', () async {
      final g = await goals();
      final p = device(g, rows: [row(d(10, 4), trend: 75.4), row(d(10, 11), trend: 75.3)]);
      await p.refresh();
      expect(p.lastCheckin!.variant, isNot(CheckinVariant.goalReached));
    });
  });

  group('Switch to maintenance', () {
    test('adaptive: maintenance targets at the estimated expenditure, no step cap', () async {
      final g = await goals();
      final p = device(g);
      await p.refresh();
      final c = p.lastCheckin!;
      expect(p.canChooseGoal(c), isTrue);
      expect(p.maintenanceTargets(c)!.cals, 2500);

      await p.switchToMaintenance(c);

      expect(g.goalType, 'maintain');
      expect(g.planStyle, PlanStyle.steady);
      expect(g.pacePctPerWeek, 0);
      expect(g.caloriesGoal, 2500); // +500 on 2,000: past the 150 step
      expect(g.tdee, 2500);
      final m = splitMacros(cals: 2500, goal: GoalKind.maintain, weightKg: 74.9, heightCm: 180);
      expect(g.proteinGoal, m.proteinG);
      expect(g.fatGoal, m.fatG);
      expect(g.carbsGoal, m.carbsG);

      expect(p.phases.map((x) => (x.seq, x.kind, x.endReason)), [
        (1, PhaseKind.lose, PhaseEndReason.goalReached),
        (2, PhaseKind.maintain, null),
      ]);
      expect(p.currentPhase!.startedOn, d(10, 12));
      expect(cloud.phases.keys, unorderedEquals([1, 2]));
      expect(cloud.phases[1]!['end_reason'], 'goal_reached');
      expect(p.canChooseGoal(c), isFalse);
    });

    test('fixed targets: the formula expenditure at the trend weight', () async {
      final g = await goals(adaptive: false);
      final p = device(g);
      await p.refresh();
      await p.switchToMaintenance(p.lastCheckin!);
      final formula = g.checkinSettings.formulaTdeeAt(74.9);
      expect(g.goalType, 'maintain');
      expect(g.caloriesGoal, formula.round());
      expect(p.currentPhase!.kind, PhaseKind.maintain);
    });

    test('a gain goal that got there switches too', () async {
      final g = await goals(goalType: 'gain');
      final p = device(g, rows: [row(d(10, 4), trend: 74.8), row(d(10, 11), trend: 75.1)]);
      await p.refresh();
      expect(p.lastCheckin!.variant, CheckinVariant.goalReached);
      await p.switchToMaintenance(p.lastCheckin!);
      expect(g.goalType, 'maintain');
    });

    test('once only: a second tap, a refresh or a restart changes nothing more', () async {
      final g = await goals();
      final p = device(g);
      await p.refresh();
      final c = p.lastCheckin!;
      await p.switchToMaintenance(c);
      await p.switchToMaintenance(c);
      expect(p.phases, hasLength(2));

      now = now.add(const Duration(hours: 3));
      await p.refresh();
      final again = device(g);
      await again.refresh();
      expect(again.phases, hasLength(2));
      expect(g.caloriesGoal, 2500);
      expect(cloud.checkins.keys, ['2026-10-05', '2026-10-12']);
    });

    test('later check-ins are ordinary maintain check-ins, never D again', () async {
      final g = await goals();
      final p = device(g);
      await p.refresh();
      await p.switchToMaintenance(p.lastCheckin!);
      now = DateTime(2026, 10, 19, 9);
      final next = device(g, rows: [row(d(10, 11)), row(d(10, 18), trend: 74.6, tdee: 2600)]);
      await next.refresh();
      expect(next.lastCheckin!.weekStart, d(10, 19));
      expect(next.lastCheckin!.variant, CheckinVariant.changed);
      expect(next.lastCheckin!.newTargets.cals, 2600); // +100, under the 150 step
    });

    test('offline: the phases change on the device and upload later', () async {
      await _Phases(cloud).sync();
      final g = await goals();
      final p = device(g);
      await p.refresh();
      cloud.online = false;
      await p.switchToMaintenance(p.lastCheckin!);
      expect(g.goalType, 'maintain');
      expect(p.currentPhase!.kind, PhaseKind.maintain);
      expect(cloud.phases.keys, [1]);
      expect(cloud.phases[1]!['end_reason'], isNull);
      cloud.online = true;
      now = now.add(const Duration(hours: 2));
      await p.refresh();
      expect(cloud.phases.keys, unorderedEquals([1, 2]));
      expect(cloud.phases[2]!['kind'], 'maintain');
    });

    test('not offered when the goal has since changed, or for an older check-in', () async {
      final g = await goals();
      final p = device(g);
      await p.refresh();
      final c = p.lastCheckin!;
      g.goalWeightKg = 70; // a new goal weight, set elsewhere
      expect(p.canChooseGoal(c), isFalse);
      g.goalWeightKg = 75;
      expect(p.canChooseGoal(c), isTrue);
      g.goalType = 'maintain';
      expect(p.canChooseGoal(c), isFalse);

      final older = p.checkins.last; // last week's
      expect(p.canChooseGoal(older), isFalse);
      await p.switchToMaintenance(older);
      expect(p.phases, hasLength(1));
    });
  });

  group('notification for the check-in', () {
    test('fixed targets on a steady plan: set once the goal is reached', () async {
      final g = await goals(adaptive: false);
      final reached = device(g, rows: [row(d(10, 4), trend: 75.2), row(d(10, 11))]);
      await reached.refresh();
      await reached.markCheckinSeen(reached.lastCheckin!);
      expect(reached.checkinNotificationTime, DateTime(2026, 10, 19, 8));

      final not = device(await goals(adaptive: false),
          rows: [row(d(10, 4), trend: 76), row(d(10, 11), trend: 75.8)]);
      await not.refresh();
      expect(not.checkinNotificationTime, isNull);
    });
  });
}
