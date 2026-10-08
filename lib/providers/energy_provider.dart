import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../services/checkin_sync_service.dart';
import '../services/energy/body_composition.dart';
import '../services/energy/checkin.dart';
import '../services/energy/checkin_day.dart';
import '../services/energy/energy_estimator.dart';
import '../services/energy/energy_summary.dart';
import '../services/energy/estimate_rows.dart';
import '../services/energy/trend_weight.dart';
import '../services/energy_sync_service.dart';
import '../services/macro_calculator_service.dart';
import '../services/storage_service.dart';
import '../utils/weight_trend.dart';
import 'day_status_provider.dart';
import 'foodEntryProvider.dart';
import 'goals_provider.dart';

/// Runs the expenditure estimator (spec 6.4) and keeps one estimate per day,
/// on the device and in `energy_estimates`.
///
/// It refreshes on app open and resume, when a weight is saved, when a day's
/// status changes, and when food is saved for a past day. After a refresh it
/// runs the weekly check-in when one is due (spec 6.8), which is the only
/// place it changes the goals.
///
/// Each refresh replays from the learning start through yesterday. The
/// estimator is deterministic and causal, so an unchanged day always gives
/// the same row (only changed rows upload), and a late edit to a past day
/// carries through every day after it.
class EnergyProvider with ChangeNotifier {
  EnergyProvider({
    this.userId,
    EnergySyncService? sync,
    CheckinSyncService? checkinSync,
    DateTime Function()? clock,
    this.inBackground = true,
    this.debounce = const Duration(milliseconds: 400),
  })  : _sync = sync ?? EnergySyncService(),
        _checkinSync = checkinSync ?? CheckinSyncService(),
        _clock = clock ?? DateTime.now {
    _rows = _sync.loadCache();
    _checkins = _checkinSync.loadCache();
  }

  /// The account this belongs to; a new instance is made when it changes.
  final String? userId;
  final EnergySyncService _sync;
  final CheckinSyncService _checkinSync;
  final DateTime Function() _clock;

  /// Replay on a background isolate (off in tests).
  final bool inBackground;

  /// How long triggers wait so a burst (app start) runs one refresh.
  final Duration debounce;

  Map<DateTime, EnergyEstimate> _rows = {};
  EstimatorInputs? Function()? _inputs;
  Timer? _timer;
  Future<void>? _running;
  bool _again = false;
  bool _pulled = false;
  bool _disposed = false;

  /// The goals check-ins read and change; set by [attach].
  GoalsProvider? goals;
  Map<String, GoalCheckin> _checkins = {};
  bool _checkinsPulled = false;

  // What the debug screen shows about the last run.
  EstimatorInputs? _lastInputs;
  DateTime? _lastRunAt;
  Duration? _lastRunTook;
  String? _lastError;

  /// Every stored estimate, oldest first.
  List<EnergyEstimate> get estimates =>
      _rows.values.toList()..sort((a, b) => a.day.compareTo(b.day));

  /// The most recent day's estimate, or null before the first.
  EnergyEstimate? get latest {
    EnergyEstimate? out;
    for (final r in _rows.values) {
      if (out == null || r.day.isAfter(out.day)) out = r;
    }
    return out;
  }

  /// The data-quality strip (spec 7.1 R4): the 21 days through yesterday,
  /// from the inputs of the last refresh. Empty before the first.
  List<QualityDay> dataQuality() {
    final inputs = _lastInputs;
    if (inputs == null) return const [];
    final now = _clock();
    return qualityStrip(
      through: DateTime(now.year, now.month, now.day - 1),
      learningStartedOn: inputs.learningStartedOn,
      food: inputs.food,
      weighInDays: [for (final w in inputs.weights) w.day],
      tdeeByDay: {for (final r in _rows.values) r.day: r.tdee},
      formulaTdee: inputs.formulaTdee,
    );
  }

  EstimatorInputs? get lastInputs => _lastInputs;
  DateTime? get lastRunAt => _lastRunAt;
  Duration? get lastRunTook => _lastRunTook;
  String? get lastError => _lastError;
  int get pendingUploads => _sync.pendingDays().length;
  bool get isRefreshing => _running != null;

  /// Where the estimator's inputs come from. main.dart wires the app's
  /// providers through [attach]; tests can set this directly.
  set inputs(EstimatorInputs? Function()? read) => _inputs = read;

  /// Reads the goals, food log, day statuses and weight history, and
  /// refreshes when food is saved for a past day or a day's status changes.
  void attach({
    required GoalsProvider goals,
    required FoodEntryProvider food,
    required DayStatusProvider dayStatus,
  }) {
    this.goals = goals;
    _inputs = () => inputsFrom(
          goals: goals,
          food: food,
          dayStatus: dayStatus,
          weights: storedWeights(),
          today: _clock(),
        );
    food.onEntriesChanged = (day) {
      if (day == null || _isPast(day)) scheduleRefresh();
    };
    dayStatus.onChanged = (_) => scheduleRefresh();
  }

  bool _isPast(DateTime day) {
    final t = _clock();
    return DateTime(day.year, day.month, day.day)
        .isBefore(DateTime(t.year, t.month, t.day));
  }

  /// Refreshes after [debounce]; later calls in the meantime join it.
  void scheduleRefresh() {
    _timer?.cancel();
    _timer = Timer(debounce, refresh);
  }

  /// Replays and stores the estimates now. A call while one is running
  /// runs once more after it, so the latest data is always used.
  Future<void> refresh() async {
    _timer?.cancel();
    if (_running != null) {
      _again = true;
      return _running;
    }
    _running = _refresh();
    _notify();
    try {
      await _running;
    } finally {
      _running = null;
      _notify();
    }
    if (_again && !_disposed) {
      _again = false;
      await refresh();
    }
  }

  Future<void> _refresh() async {
    final inputs = _inputs?.call();
    if (inputs == null) return;
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final watch = Stopwatch()..start();
    try {
      if (!_pulled && userId != null) {
        _pulled = true;
        final pulled = await _sync.pull(today: today);
        if (pulled != null) _rows = pulled;
      }
      final run = inBackground
          ? await _replayInBackground(inputs, yesterday)
          : _replay(inputs, yesterday);
      _rows = await _sync.save(run.estimates, today: today);
      _lastError = null;
      await _checkIn(now);
    } catch (e) {
      debugPrint('[Energy] Refresh failed: $e');
      _lastError = '$e';
    }
    _lastInputs = inputs;
    _lastRunAt = now;
    _lastRunTook = watch.elapsed;
  }

  // --- Weekly check-in (spec 6.8) ---

  /// Every check-in, newest first.
  List<GoalCheckin> get checkins =>
      _checkins.values.toList()..sort((a, b) => b.weekStart.compareTo(a.weekStart));

  /// The latest check-in, or null before the first.
  GoalCheckin? get lastCheckin {
    GoalCheckin? out;
    for (final c in _checkins.values) {
      if (out == null || c.weekStart.isAfter(out.weekStart)) out = c;
    }
    return out;
  }

  /// This week's check-in while its sheet hasn't been dismissed: the app
  /// shows it on its own.
  GoalCheckin? get checkinToShow {
    final c = lastCheckin;
    if (c == null || c.seenAt != null) return null;
    final today = _dateOnly(_clock());
    final weekEnd = DateTime(c.weekStart.year, c.weekStart.month, c.weekStart.day + 7);
    return today.isBefore(weekEnd) ? c : null;
  }

  /// The check-in that ran today, if one did: the home card's chip reopens
  /// it until the day ends.
  GoalCheckin? get todaysCheckin {
    final c = lastCheckin;
    if (c == null) return null;
    return _dateOnly(c.createdAt.toLocal()) == _dateOnly(_clock()) ? c : null;
  }

  /// The next check-in day, a week after the last one at the earliest.
  DateTime? get nextCheckinDay => goals?.nextCheckinDayAfter(lastCheckin?.weekStart);

  /// What a check-in would decide if it ran now (the goals card's "likely
  /// +50 cals"), or null with adaptive goals off or nothing to go on.
  CheckinDecision? previewCheckin() {
    final g = goals;
    return g == null ? null : _decide(g, _clock());
  }

  /// Records that [checkin]'s sheet was dismissed.
  Future<void> markCheckinSeen(GoalCheckin checkin) async {
    if (checkin.seenAt != null) return;
    final key = dayKey(checkin.weekStart);
    _checkins[key] = checkin.copyWith(seenAt: _clock());
    _notify();
    final stored = await _checkinSync.markSeen(checkin.weekStart, _checkins[key]!.seenAt!);
    if (stored != null) _checkins[key] = stored;
  }

  /// The decision from the latest estimate (yesterday's): null when there
  /// is none to make (adaptive off) or the estimates aren't up to date.
  CheckinDecision? _decide(GoalsProvider g, DateTime now) {
    final latest = this.latest;
    final today = _dateOnly(now);
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    final start = g.learningStartedOn;
    // Rows from before a reset belong to the old learning.
    final current = latest != null && start != null && !latest.day.isBefore(start)
        ? latest
        : null;
    if (current != null && current.day != yesterday) return null;
    final weekAgo = current == null
        ? null
        : _rows[DateTime(current.day.year, current.day.month, current.day.day - 7)];
    return decideCheckin(
      settings: g.checkinSettings,
      current: g.checkinTargets,
      tdeePrev: g.tdee,
      latest: current,
      trendWeekAgoKg: weekAgo?.trendWeightKg,
      fallbackWeightKg: g.currentWeightKg > 0 ? g.currentWeightKg : null,
    );
  }

  /// Runs the check-in if one is due. The `goal_checkins` row's existence
  /// is what makes it run once: across restarts here, and across devices
  /// through the cloud copy, which wins.
  Future<void> _checkIn(DateTime now) async {
    final g = goals;
    if (g == null || g.userId == null) return;
    DateTime? due() => dueCheckinWeek(
          weekday: g.checkinWeekday,
          now: now,
          learningStartedOn: g.learningStartedOn,
          lastCheckin: lastCheckin?.weekStart,
        );
    final week = due();
    final wanted = week != null && _decide(g, now) != null;
    // Pull once for the history, and before every check-in: another device
    // may have run it already.
    if (!_checkinsPulled || wanted) {
      _checkinsPulled = true;
      await _syncCheckins(g);
    }
    if (!wanted) return;
    final key = dayKey(week);
    final existing = _checkins[key];
    if (existing != null) {
      _adopt(g, existing, ifCurrent: existing.oldTargets);
      return;
    }
    // A later check-in came down from the cloud.
    if (due() != week) return;

    final decision = _decide(g, now)!;
    if (decision.changesTargets) {
      await g.applyCheckinTargets(decision.newTargets, tdee: decision.reason.tdee);
    }
    final mine = GoalCheckin.fromDecision(decision, weekStart: week, createdAt: now);
    _checkins[key] = mine;
    _notify();
    final stored = await _checkinSync.add(mine);
    if (!identical(stored, mine)) {
      _checkins[key] = stored;
      _adopt(g, stored, ifCurrent: mine.newTargets);
      _notify();
    }
  }

  /// Pulls the account's check-ins. A week this device also checked in, but
  /// another device stored first, takes the other device's targets.
  Future<void> _syncCheckins(GoalsProvider g) async {
    final before = Map.of(_checkins);
    final result = await _checkinSync.sync();
    if (result == null) return;
    _checkins = Map.of(result.rows);
    result.adopted.forEach((week, winner) {
      final mine = before[week];
      if (mine != null) _adopt(g, winner, ifCurrent: mine.newTargets);
    });
    _notify();
  }

  /// Takes [checkin]'s targets when the goals are still [ifCurrent] (so a
  /// change the user made since is never overwritten).
  void _adopt(GoalsProvider g, GoalCheckin checkin, {required CheckinTargets ifCurrent}) {
    if (g.checkinTargets != ifCurrent || g.checkinTargets == checkin.newTargets) return;
    g.applyCheckinTargets(checkin.newTargets, tdee: checkin.reason.tdee);
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// The estimator inputs from the app's state, or null while there's nothing
  /// to run on: signed out, or the food log not read yet. Starts learning
  /// for an account from before the learning start existed (its first data
  /// day, see [defaultLearningStart]).
  static EstimatorInputs? inputsFrom({
    required GoalsProvider goals,
    required FoodEntryProvider food,
    required DayStatusProvider dayStatus,
    required List<WeightReading> weights,
    required DateTime today,
  }) {
    if (goals.userId == null || !food.isLoaded) return null;
    final cals = food.caloriesByDay();
    final statuses = dayStatus.statuses;
    var start = goals.learningStartedOn;
    if (start == null) {
      start = defaultLearningStart(
        today: today,
        dataDays: [...cals.keys, ...statuses.keys, for (final w in weights) w.day],
      );
      goals.startLearning(start);
    }
    final sex = goals.sex == null
        ? Sex.female
        : MacroCalculatorService.sexOf(goals.sex!);
    return EstimatorInputs(
      learningStartedOn: start,
      formulaTdee: goals.formulaTdee ?? goals.tdee,
      body: BodyProfile(
        sex: sex,
        heightCm: goals.heightCm ?? 170,
        age: goals.age ?? 30,
        bodyFatPct: goals.bodyFatPct,
      ),
      food: foodDaysFrom(calsByDay: cals, statuses: statuses),
      weights: weights,
    );
  }

  /// The weigh-ins the weight screen stores, one per day.
  static List<WeightReading> storedWeights() {
    final raw = StorageService().get('weight_history');
    if (raw is! String || raw.isEmpty) return const [];
    try {
      return [
        for (final e in parseWeightHistory(jsonDecode(raw) as List))
          WeightReading(e.day, e.kg),
      ];
    } catch (_) {
      return const [];
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Forgets this account's estimates on the device (logout, delete).
  Future<void> clearUserData() async {
    _timer?.cancel();
    _rows = {};
    _checkins = {};
    _lastInputs = null;
    await _sync.clearLocalState();
    await _checkinSync.clearLocalState();
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}

/// Top level, so the isolate closure only captures the inputs.
EstimatorRun _replay(EstimatorInputs inputs, DateTime through) =>
    inputs.learningStartedOn.isAfter(through)
        ? EstimatorRun(const [], EstimatorState.initial(inputs.formulaTdee))
        : EnergyEstimator(inputs).replay(through: through);

Future<EstimatorRun> _replayInBackground(
        EstimatorInputs inputs, DateTime through) =>
    Isolate.run(() => _replay(inputs, through));
