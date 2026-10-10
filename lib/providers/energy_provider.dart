import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../services/checkin_notifier.dart';
import '../services/checkin_sync_service.dart';
import '../services/energy/body_composition.dart';
import '../services/energy/checkin.dart';
import '../services/energy/checkin_day.dart';
import '../services/energy/energy_estimator.dart';
import '../services/energy/energy_summary.dart';
import '../services/energy/estimate_rows.dart';
import '../services/energy/phase_engine.dart';
import '../services/energy/phase_engine.dart' as engine show currentPhase, keepLosing, extendBreak, switchToMaintenance;
import '../services/energy/targets.dart';
import '../services/energy/trend_weight.dart';
import '../services/energy_sync_service.dart';
import '../services/macro_calculator_service.dart';
import '../services/phase_sync_service.dart';
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
/// place it changes the goals besides the user's phase choices.
///
/// It also keeps the goal phases (spec 6.7, `goal_phases`): a recalculation
/// starts a fresh sequence ([replan]), a check-in moves to the next phase,
/// and the check-in sheet's choices change it ([keepLosing], [extendBreak]).
///
/// It keeps the "check-in ready" notification (spec 8) scheduled for the
/// next check-in day, after every refresh and whenever the goals change.
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
    PhaseSyncService? phaseSync,
    CheckinNotifier? checkinNotifier,
    DateTime Function()? clock,
    this.inBackground = true,
    this.debounce = const Duration(milliseconds: 400),
  })  : _sync = sync ?? EnergySyncService(),
        _checkinSync = checkinSync ?? CheckinSyncService(userId: userId),
        _phaseSync = phaseSync ?? PhaseSyncService(userId: userId),
        _notifier = checkinNotifier ?? CheckinNotifier.device,
        _clock = clock ?? DateTime.now {
    _rows = _sync.loadCache();
    _checkins = _checkinSync.loadCache();
    _phases = _phaseSync.loadCache();
  }

  /// The account this belongs to; a new instance is made when it changes.
  final String? userId;
  final EnergySyncService _sync;
  final CheckinSyncService _checkinSync;
  final PhaseSyncService _phaseSync;
  final CheckinNotifier _notifier;
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

  /// The goals check-ins read and change; set by [attach]. A change to
  /// them (check-in day, adaptive goals, plan) reschedules the notification.
  GoalsProvider? get goals => _goals;
  GoalsProvider? _goals;

  set goals(GoalsProvider? value) {
    if (identical(value, _goals)) return;
    _goals?.removeListener(_queueNotification);
    _goals = value;
    value?.addListener(_queueNotification);
    _queueNotification();
  }

  bool _notificationQueued = false;
  Map<String, GoalCheckin> _checkins = {};
  bool _checkinsPulled = false;
  List<GoalPhase> _phases = const [];

  // Bumped on logout: work started before it stops at its next step.
  int _generation = 0;

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
          phases: _phases,
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
    // After each check-in (or none), for the next one.
    _queueNotification();
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

  /// When the "Your weekly check-in is ready" notification should go out:
  /// 08:00 on the next check-in day (spec 8), or null for none (signed out,
  /// or adaptive goals off with a steady plan).
  ///
  /// With adaptive goals off, a check-in only comes when the goal is reached
  /// or a phased or breaks plan changes phase, so it's the first check-in day
  /// (up to a year on) that would do either as things stand. A loss phase that ends by weight
  /// may come sooner than that; the notification moves when it does.
  DateTime? get checkinNotificationTime {
    final g = goals;
    if (g == null || g.userId == null || g.learningStartedOn == null) return null;
    final now = _clock();
    var at = checkinNotificationAt(day: g.nextCheckinDayAfter(lastCheckin?.weekStart), now: now);
    if (g.adaptiveGoals) return at;
    // Fixed targets: a check-in only when a phase changes or the goal is
    // reached. Steady plans have no phases to end.
    final weeks = g.planStyle == PlanStyle.steady ? 1 : 52;
    for (var week = 0; week < weeks; week++) {
      final v = _decide(g, now, on: _dateOnly(at))?.variant;
      if (v != null && (v.isPhaseChange || v == CheckinVariant.goalReached)) return at;
      at = DateTime(at.year, at.month, at.day + 7, at.hour);
    }
    return null;
  }

  /// Reschedules the notification once the current change is done (goals
  /// notify several times in a row).
  void _queueNotification() {
    if (_notificationQueued || _disposed) return;
    _notificationQueued = true;
    scheduleMicrotask(() {
      _notificationQueued = false;
      if (!_disposed) _notifier.update(checkinNotificationTime);
    });
  }

  /// What a check-in would decide if it ran now (the goals card's "likely
  /// +50 cals"), or null with adaptive goals off or nothing to go on.
  CheckinDecision? previewCheckin() {
    final g = goals;
    return g == null ? null : _decide(g, _clock());
  }

  // --- Phases (spec 6.7) ---

  /// Every phase of the account, oldest first.
  List<GoalPhase> get phases => List.unmodifiable(_phases);

  /// The open phase, or null without a plan.
  GoalPhase? get currentPhase => engine.currentPhase(_phases);

  /// Starts a fresh phase sequence today from [trendKg] (onboarding, and a
  /// recalculation that changed the plan style, goal or pace). The open
  /// phase closes as `replanned`.
  Future<void> replan({
    required PlanStyle style,
    required GoalKind goal,
    required double trendKg,
    double? heightCm,
    PhaseSettings settings = const PhaseSettings(),
  }) =>
      _editPhases(replanPhases(_phases,
          style: style,
          goal: goal,
          on: _dateOnly(_clock()),
          trendKg: trendKg,
          heightCm: heightCm,
          settings: settings));

  /// Whether [checkin]'s phase change can still be undone from its sheet
  /// ("Keep losing", "Extend break"): it's the latest check-in and the phase
  /// it started is still the open one, untouched.
  bool canChangePhase(GoalCheckin checkin) {
    final t = checkin.reason.phase;
    final latest = lastCheckin;
    return t != null &&
        latest != null &&
        latest.weekStart == checkin.weekStart &&
        engine.currentPhase(_phases) == t.next;
  }

  /// "Keep losing" on variant F: skips the maintenance break and goes back
  /// to lose targets, from the same expenditure the check-in used.
  Future<void> keepLosing(GoalCheckin checkin) async {
    final g = goals;
    if (g == null || !canChangePhase(checkin) || !checkin.reason.phase!.toMaintain) return;
    final edit = engine.keepLosing(_phases,
        style: g.planStyle, heightCm: g.heightCm, settings: g.phaseSettings);
    if (edit.isEmpty) return;
    final weight = checkin.reason.trendWeightKg ?? checkin.reason.phase!.next.startTrendKg;
    final lose = phaseTargets(
        kind: PhaseKind.lose, settings: g.checkinSettings, tdee: checkin.reason.tdee, weightKg: weight);
    await _userPhaseChange(checkin, edit, lose.targets, tdee: checkin.reason.tdee);
  }

  /// "Extend break" on variant G: the maintenance break runs
  /// [kExtendBreakWeeks] longer, on the targets it had.
  Future<void> extendBreak(GoalCheckin checkin) async {
    if (!canChangePhase(checkin) || checkin.reason.phase!.toMaintain) return;
    final edit = engine.extendBreak(_phases);
    if (edit.isEmpty) return;
    await _userPhaseChange(checkin, edit, checkin.oldTargets, tdee: checkin.reason.tdeePrev);
  }

  // --- Goal reached (spec 6.8 row 1, variant D) ---

  /// Whether [checkin]'s goal-reached choice can still be made: it's the
  /// latest check-in and the goal it reached is still the account's (not
  /// switched to maintenance or replaced by a new goal weight, here or on
  /// another device).
  bool canChooseGoal(GoalCheckin checkin) {
    final g = goals;
    final latest = lastCheckin;
    if (g == null || checkin.variant != CheckinVariant.goalReached) return false;
    if (latest == null || latest.weekStart != checkin.weekStart) return false;
    final r = checkin.reason;
    return g.checkinSettings.goal == r.goal &&
        r.goalWeightKg != null &&
        (g.goalWeightKg - r.goalWeightKg!).abs() < 0.06;
  }

  /// What "Switch to maintenance" would set for [checkin]: the expenditure it
  /// carries at the trend weight, with no step cap.
  CheckinTargets? maintenanceTargets(GoalCheckin checkin) {
    final g = goals;
    final weight = checkin.reason.trendWeightKg;
    if (g == null || weight == null || weight <= 0) return null;
    return phaseTargets(
            kind: PhaseKind.maintain,
            settings: g.checkinSettings,
            tdee: checkin.reason.tdee,
            weightKg: weight)
        .targets;
  }

  /// "Switch to maintenance": the plan becomes a steady maintain phase and
  /// the targets maintenance targets. The phases go first, through their
  /// durable queue, then the goals; both are idempotent, and the sheet stays
  /// unseen until this returns, so an interrupted choice is offered again.
  Future<void> switchToMaintenance(GoalCheckin checkin) async {
    final g = goals;
    final targets = maintenanceTargets(checkin);
    if (g == null || targets == null || !canChooseGoal(checkin)) return;
    final trend = checkin.reason.trendWeightKg!;
    await _editPhases(
        engine.switchToMaintenance(_phases, on: _dateOnly(_clock()), trendKg: trend),
        upload: false);
    g.switchToMaintenance(targets, tdee: checkin.reason.tdee);
    await _phaseSync.upload();
  }

  /// "End phase early": the open phase ends at the next check-in.
  Future<void> endPhaseEarly() =>
      _editPhases(requestPhaseEnd(_phases, on: _dateOnly(_clock())));

  /// The user's choice replaces what [checkin] applied: its queued apply is
  /// dropped so it can't come back, and the targets are saved like any goal
  /// edit.
  Future<void> _userPhaseChange(GoalCheckin checkin, PhaseEdit edit, CheckinTargets targets,
      {required double tdee}) async {
    final g = goals!;
    await _checkinSync.settleApply(dayKey(checkin.weekStart));
    await _editPhases(edit, upload: false);
    g.applyPhaseTargets(targets, tdee: tdee);
    await _phaseSync.upload();
  }

  Future<void> _editPhases(PhaseEdit edit, {bool upload = true}) async {
    if (edit.isEmpty) return;
    _phases = await _phaseSync.edit(edit);
    _notify();
    scheduleRefresh(); // phase switches restart the estimator's settle period
    if (upload) await _phaseSync.upload();
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

  /// The latest estimate of the current learning, or null before one.
  EnergyEstimate? _currentEstimate(GoalsProvider g) {
    final latest = this.latest;
    final start = g.learningStartedOn;
    // Rows from before a reset belong to the old learning.
    return latest != null && start != null && !latest.day.isBefore(start) ? latest : null;
  }

  /// Whether the estimates run through yesterday (or there are none yet).
  bool _upToDate(GoalsProvider g, DateTime now) {
    final current = _currentEstimate(g);
    final today = _dateOnly(now);
    return current == null || current.day == DateTime(today.year, today.month, today.day - 1);
  }

  /// The decision from the latest estimate (yesterday's) for the check-in
  /// [on] (today by default): null when there is none to make (adaptive off,
  /// no phase change) or the estimates aren't up to date.
  CheckinDecision? _decide(GoalsProvider g, DateTime now, {DateTime? on}) {
    if (!_upToDate(g, now)) return null;
    final current = _currentEstimate(g);
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
      plan: CheckinPlan(
        style: g.planStyle,
        phases: _phases,
        on: on ?? _dateOnly(now),
        settings: g.phaseSettings,
      ),
    );
  }

  /// Runs the check-in if one is due, and finishes any whose targets aren't
  /// applied yet. The `goal_checkins` row's existence is what makes it run
  /// once: across restarts here, and across devices through the cloud copy,
  /// which wins.
  ///
  /// The row is recorded on the device first and the targets are applied
  /// from it, so a restart at any point finishes the same check-in rather
  /// than deciding (and stepping) again. `user_macros` is written only once
  /// the row is the account's, so a device that loses the week never
  /// overwrites the winner's targets.
  Future<void> _checkIn(DateTime now) async {
    final g = goals;
    if (g == null || g.userId == null) return;
    final generation = _generation;
    bool gone() => generation != _generation || _disposed;
    DateTime? due() {
      final week = dueCheckinWeek(
        weekday: g.checkinWeekday,
        now: now,
        learningStartedOn: g.learningStartedOn,
        lastCheckin: lastCheckin?.weekStart,
      );
      // Decided already, with nothing to record (row 4).
      return week == null || dayKey(week) == _checkinSync.decidedWithoutRow ? null : week;
    }

    bool wanted() => due() != null && _decide(g, now, on: due()) != null;
    // Pull once for the history, before every check-in (another device may
    // have run it already or moved the phases), and while anything waits to
    // upload.
    if (!_checkinsPulled || wanted() || _checkinSync.hasWork || _phaseSync.hasWork) {
      _checkinsPulled = true;
      await Future.wait([_checkinSync.sync(), _phaseSync.sync()]);
      if (gone()) return;
      _checkins = _checkinSync.loadCache();
      _phases = _phaseSync.loadCache();
      _notify();
    }
    // Asked again with what came down: a row for the week means it ran, and
    // the history decides when the next one is due. A week with nothing to
    // record is decided once, so a phase can't end in the middle of it.
    final week = due();
    final decision = week == null || !_upToDate(g, now) ? null : _decide(g, now, on: week);
    if (week != null && _upToDate(g, now) && decision == null) {
      await _checkinSync.markDecidedWithoutRow(week);
      if (gone()) return;
    }
    if (week != null && decision != null) {
      final mine = GoalCheckin.fromDecision(decision, weekStart: week, createdAt: now);
      await _checkinSync.stage(mine);
      if (gone()) return;
      _checkins = _checkinSync.loadCache();
      await _applyCheckins(g, gone);
      if (gone()) return;
      _notify();
      await _checkinSync.upload();
      if (gone()) return;
      _checkins = _checkinSync.loadCache();
    }
    await _applyCheckins(g, gone);
    if (!gone()) _notify();
  }

  /// Applies the queued check-in targets on this device, then confirms them
  /// in `user_macros` once the row is the account's. A check-in another one
  /// has replaced, or targets the user has changed since, are left alone.
  Future<void> _applyCheckins(GoalsProvider g, bool Function() gone) async {
    final latest = lastCheckin;
    for (final MapEntry(key: week, value: ifCurrent) in _checkinSync.applyQueue().entries) {
      if (gone()) return;
      final c = _checkins[week];
      final now = g.checkinTargets;
      final stale = c == null ||
          latest == null ||
          c.weekStart != latest.weekStart ||
          (now != c.newTargets && !ifCurrent.contains(now));
      if (stale) {
        await _checkinSync.settleApply(week);
        continue;
      }
      if (now != c.newTargets) {
        g.applyCheckinTargets(c.newTargets,
            tdee: c.variant.appliesTargets ? c.reason.tdee : c.reason.tdeePrev);
      }
      if (_checkinSync.pendingInserts().contains(week)) continue;
      final confirmed = await g.uploadCheckinTargets(c);
      if (confirmed && !gone()) await _checkinSync.settleApply(week);
    }
    // The latest check-in's phase change, made once (here or on another
    // device): applying it again, or over a choice made since, changes
    // nothing.
    final t = latest?.reason.phase;
    if (t != null && !gone()) await _editPhases(applyTransition(_phases, t));
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
    List<GoalPhase> phases = const [],
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
      phaseStarts: phaseSwitchDays(phases),
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
    _generation++;
    _timer?.cancel();
    _rows = {};
    _checkins = {};
    _phases = const [];
    _lastInputs = null;
    await _sync.clearLocalState();
    await _checkinSync.clearLocalState();
    await _phaseSync.clearLocalState();
    await _notifier.update(null);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _goals?.removeListener(_queueNotification);
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
