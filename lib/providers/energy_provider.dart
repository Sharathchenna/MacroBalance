import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../services/energy/body_composition.dart';
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
/// Shadow mode: nothing here changes the goals yet. It refreshes on app open
/// and resume, when a weight is saved, when a day's status changes, and when
/// food is saved for a past day.
///
/// Each refresh replays from the learning start through yesterday. The
/// estimator is deterministic and causal, so an unchanged day always gives
/// the same row (only changed rows upload), and a late edit to a past day
/// carries through every day after it.
class EnergyProvider with ChangeNotifier {
  EnergyProvider({
    this.userId,
    EnergySyncService? sync,
    DateTime Function()? clock,
    this.inBackground = true,
    this.debounce = const Duration(milliseconds: 400),
  })  : _sync = sync ?? EnergySyncService(),
        _clock = clock ?? DateTime.now {
    _rows = _sync.loadCache();
  }

  /// The account this belongs to; a new instance is made when it changes.
  final String? userId;
  final EnergySyncService _sync;
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
    } catch (e) {
      debugPrint('[Energy] Refresh failed: $e');
      _lastError = '$e';
    }
    _lastInputs = inputs;
    _lastRunAt = now;
    _lastRunTook = watch.elapsed;
  }

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
    _lastInputs = null;
    await _sync.clearLocalState();
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
