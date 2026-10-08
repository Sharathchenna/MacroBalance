import 'body_composition.dart';
import 'constants.dart';
import 'energy_estimator.dart';
import 'estimate_rows.dart' show dayKey, parseDay;
import 'targets.dart';

/// What a weekly check-in did (spec 6.8; plan 9.5 variants A–G). The codes
/// are `goal_checkins.variant`'s.
enum CheckinVariant {
  /// A: new targets applied (with the limit line, E, when a limit bit).
  changed('changed'),

  /// B: under [kNoChangeThreshold] from the current target.
  unchanged('unchanged'),

  /// C: the estimate is still learning or paused.
  insufficient('insufficient'),

  /// D (ticket 15).
  goalReached('goal_reached'),

  /// F (ticket 17).
  phaseToMaintain('phase_to_maintain'),

  /// G (ticket 17).
  phaseToLose('phase_to_lose');

  const CheckinVariant(this.code);

  final String code;

  static CheckinVariant? fromCode(Object? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }
}

/// `goal_checkins.reason.limit_hit` codes.
const Map<SafetyLimit, String> _limitCodes = {
  SafetyLimit.maxDeficit: 'max_deficit',
  SafetyLimit.maxLossPace: 'max_loss_pace',
  SafetyLimit.maxSurplus: 'max_surplus',
  SafetyLimit.maxGainPace: 'max_gain_pace',
  SafetyLimit.floor: 'floor',
  SafetyLimit.checkinStep: 'checkin_step',
};

SafetyLimit? _limitFromCode(Object? code) {
  for (final e in _limitCodes.entries) {
    if (e.value == code) return e.key;
  }
  return null;
}

/// Daily targets in whole cals and grams, as stored in `old_targets` /
/// `new_targets`.
class CheckinTargets {
  const CheckinTargets({
    required this.cals,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final int cals;
  final int protein;
  final int carbs;
  final int fat;

  Map<String, int> toJson() =>
      {'cals': cals, 'protein': protein, 'carbs': carbs, 'fat': fat};

  static CheckinTargets? fromJson(Object? json) {
    if (json is! Map) return null;
    int? n(String k) => (json[k] as num?)?.round();
    final cals = n('cals');
    if (cals == null) return null;
    return CheckinTargets(
        cals: cals, protein: n('protein') ?? 0, carbs: n('carbs') ?? 0, fat: n('fat') ?? 0);
  }

  @override
  bool operator ==(Object other) =>
      other is CheckinTargets &&
      other.cals == cals &&
      other.protein == protein &&
      other.carbs == carbs &&
      other.fat == fat;

  @override
  int get hashCode => Object.hash(cals, protein, carbs, fat);

  @override
  String toString() => '$cals cals (P$protein C$carbs F$fat)';
}

/// The goal settings a check-in works from. Unknown height or age use the
/// onboarding defaults (170 cm, 30), as the goals do.
class CheckinSettings {
  const CheckinSettings({
    required this.adaptive,
    required this.goal,
    required this.pacePct,
    required this.sex,
    this.heightCm,
    this.age,
    this.bodyFatPct,
    this.proteinPerKg,
    this.fatRatio,
    this.goalWeightKg,
  });

  /// Adaptive goals on: check-ins move the targets.
  final bool adaptive;
  final GoalKind goal;

  /// % of body weight a week (0 when maintaining).
  final double pacePct;
  final Sex sex;
  final double? heightCm;
  final int? age;
  final double? bodyFatPct;
  final double? proteinPerKg;
  final double? fatRatio;
  final double? goalWeightKg;
}

/// Why a check-in came out as it did: `goal_checkins.reason`. The spec's
/// keys plus what the sheet needs to be drawn again from the row alone.
class CheckinReason {
  const CheckinReason({
    required this.state,
    required this.completeDays,
    required this.weighIns,
    required this.tdee,
    required this.tdeePrev,
    required this.goal,
    required this.pacePct,
    this.avgIntake,
    this.trendChangeKg,
    this.limitHit,
    this.trendWeightKg,
    this.goalWeightKg,
    this.weeksToGoal,
  });

  final EnergyState state;

  /// Mean cals of the window's complete days.
  final double? avgIntake;
  final int completeDays;
  final int weighIns;

  /// Trend weight now minus a week ago.
  final double? trendChangeKg;

  /// The expenditure this check-in used.
  final double tdee;

  /// The expenditure the targets came from before it.
  final double tdeePrev;

  /// The limit that set the new target, if one did.
  final SafetyLimit? limitHit;
  final double? trendWeightKg;
  final double? goalWeightKg;
  final GoalKind goal;
  final double pacePct;

  /// At the new target, from today's energy balance.
  final double? weeksToGoal;

  Map<String, Object?> toJson() => {
        'avg_intake': avgIntake?.round(),
        'complete_days': completeDays,
        'weigh_ins': weighIns,
        'trend_change_kg': _r(trendChangeKg, 2),
        'tdee': tdee.round(),
        'tdee_prev': tdeePrev.round(),
        'limit_hit': limitHit == null ? null : _limitCodes[limitHit],
        'state': state.code,
        'trend_weight_kg': _r(trendWeightKg, 2),
        'goal_weight_kg': _r(goalWeightKg, 1),
        'goal': goal.name,
        'pace_pct': pacePct,
        'weeks_to_goal': _r(weeksToGoal, 1),
      };

  static CheckinReason fromJson(Object? json) {
    final m = json is Map ? json : const {};
    double? d(String k) => (m[k] as num?)?.toDouble();
    return CheckinReason(
      state: EnergyState.fromCode(m['state']) ?? EnergyState.learning,
      avgIntake: d('avg_intake'),
      completeDays: (m['complete_days'] as num?)?.toInt() ?? 0,
      weighIns: (m['weigh_ins'] as num?)?.toInt() ?? 0,
      trendChangeKg: d('trend_change_kg'),
      tdee: d('tdee') ?? 0,
      tdeePrev: d('tdee_prev') ?? 0,
      limitHit: _limitFromCode(m['limit_hit']),
      trendWeightKg: d('trend_weight_kg'),
      goalWeightKg: d('goal_weight_kg'),
      goal: GoalKind.values.asNameMap()[m['goal']] ?? GoalKind.maintain,
      pacePct: d('pace_pct') ?? 0,
      weeksToGoal: d('weeks_to_goal'),
    );
  }

  static double? _r(double? v, int places) =>
      v == null ? null : double.parse(v.toStringAsFixed(places));
}

/// What a check-in decided.
class CheckinDecision {
  const CheckinDecision({
    required this.variant,
    required this.oldTargets,
    required this.newTargets,
    required this.reason,
  });

  final CheckinVariant variant;
  final CheckinTargets oldTargets;
  final CheckinTargets newTargets;
  final CheckinReason reason;

  bool get changesTargets => variant == CheckinVariant.changed;
}

/// The weekly check-in decision (spec 6.8), first match wins:
///
/// 1–3. Goal reached and phase ends: tickets 15 and 17 add them here, above
///      row 4, since they apply with adaptive goals off too.
/// 4.   Adaptive goals off: null (no row, no sheet).
/// 5.   No estimate yet, or it's learning or paused: [CheckinVariant.insufficient].
/// 6.   The new target, after every safety limit, is under
///      [kNoChangeThreshold] from [current]: [CheckinVariant.unchanged].
/// 7.   Otherwise [CheckinVariant.changed], with the ±[kMaxCheckinStep] cap.
///
/// The new target is the estimated expenditure ∓ the chosen pace at the trend
/// weight (6.6), through [applySafetyLimits] with the check-in step, and the
/// macros are split from it. [tdeePrev] is the expenditure the current
/// targets came from; [trendWeekAgoKg] the trend a week before [latest];
/// [fallbackWeightKg] is used when [latest] has no trend weight.
CheckinDecision? decideCheckin({
  required CheckinSettings settings,
  required CheckinTargets current,
  required double tdeePrev,
  required EnergyEstimate? latest,
  double? trendWeekAgoKg,
  double? fallbackWeightKg,
}) {
  if (!settings.adaptive) return null;

  final trend = latest?.trendWeightKg;
  final weight = trend ?? fallbackWeightKg;
  final tdee = latest?.tdee ?? tdeePrev;
  CheckinReason reason({SafetyLimit? limitHit, double? weeksToGoal}) => CheckinReason(
        state: latest?.state ?? EnergyState.learning,
        avgIntake: latest?.avgIntake,
        completeDays: latest?.completeDays ?? 0,
        weighIns: latest?.weighIns ?? 0,
        trendChangeKg:
            trend != null && trendWeekAgoKg != null ? trend - trendWeekAgoKg : null,
        tdee: tdee,
        tdeePrev: tdeePrev,
        limitHit: limitHit,
        trendWeightKg: weight,
        goalWeightKg: settings.goalWeightKg,
        goal: settings.goal,
        pacePct: settings.goal == GoalKind.maintain ? 0 : settings.pacePct,
        weeksToGoal: weeksToGoal,
      );
  CheckinDecision keep(CheckinVariant variant, CheckinReason why) => CheckinDecision(
      variant: variant, oldTargets: current, newTargets: current, reason: why);

  final learning = latest == null ||
      latest.state == EnergyState.learning ||
      latest.state == EnergyState.paused;
  if (learning || weight == null || weight <= 0) {
    return keep(CheckinVariant.insufficient, reason());
  }

  final ed = energyDensity(fatMassKg(
    weightKg: weight,
    heightCm: settings.heightCm ?? 170,
    age: settings.age ?? 30,
    sex: settings.sex,
    bodyFatPct: settings.bodyFatPct,
  ));
  final delta = paceDeltaCals(pacePct: settings.pacePct, weightKg: weight, energyDensity: ed);
  final raw = switch (settings.goal) {
    GoalKind.lose => tdee - delta,
    GoalKind.gain => tdee + delta,
    GoalKind.maintain => tdee,
  };
  final safe = applySafetyLimits(
    cals: raw,
    tdee: tdee,
    sex: settings.sex,
    weightKg: weight,
    energyDensity: ed,
    currentCals: current.cals.toDouble(),
  );
  final cals = safe.cals.round();
  final goalKg = settings.goalWeightKg;
  final why = reason(
    limitHit: safe.limitHit,
    weeksToGoal: settings.goal == GoalKind.maintain || goalKg == null || goalKg <= 0
        ? null
        : weeksToGoal(
            weightKg: weight,
            goalWeightKg: goalKg,
            tdee: tdee,
            cals: cals.toDouble(),
            energyDensity: ed,
          ),
  );

  if ((cals - current.cals).abs() < kNoChangeThreshold) {
    return keep(CheckinVariant.unchanged, why);
  }

  final macros = splitMacros(
    cals: cals.toDouble(),
    goal: settings.goal,
    weightKg: weight,
    heightCm: settings.heightCm,
    bodyFatPct: settings.bodyFatPct,
    proteinPerKg: settings.proteinPerKg,
    fatRatio: settings.fatRatio,
  );
  return CheckinDecision(
    variant: CheckinVariant.changed,
    oldTargets: current,
    newTargets: CheckinTargets(
        cals: cals, protein: macros.proteinG, carbs: macros.carbsG, fat: macros.fatG),
    reason: why,
  );
}

/// One `goal_checkins` row.
class GoalCheckin {
  const GoalCheckin({
    required this.weekStart,
    required this.variant,
    required this.oldTargets,
    required this.newTargets,
    required this.reason,
    required this.createdAt,
    this.seenAt,
  });

  factory GoalCheckin.fromDecision(
    CheckinDecision d, {
    required DateTime weekStart,
    required DateTime createdAt,
  }) =>
      GoalCheckin(
        weekStart: DateTime(weekStart.year, weekStart.month, weekStart.day),
        variant: d.variant,
        oldTargets: d.oldTargets,
        newTargets: d.newTargets,
        reason: d.reason,
        createdAt: createdAt,
      );

  /// The scheduled check-in day; one row per week.
  final DateTime weekStart;
  final CheckinVariant variant;
  final CheckinTargets oldTargets;
  final CheckinTargets newTargets;
  final CheckinReason reason;
  final DateTime createdAt;

  /// When the sheet was dismissed; null until then.
  final DateTime? seenAt;

  GoalCheckin copyWith({DateTime? seenAt}) => GoalCheckin(
        weekStart: weekStart,
        variant: variant,
        oldTargets: oldTargets,
        newTargets: newTargets,
        reason: reason,
        createdAt: createdAt,
        seenAt: seenAt ?? this.seenAt,
      );

  Map<String, Object?> toCacheJson() => {
        'week_start': dayKey(weekStart),
        'variant': variant.code,
        'old_targets': oldTargets.toJson(),
        'new_targets': newTargets.toJson(),
        'reason': reason.toJson(),
        'seen_at': seenAt?.toUtc().toIso8601String(),
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  Map<String, Object?> toRemoteRow(String userId) =>
      {'user_id': userId, ...toCacheJson()};

  /// From a cache entry or a `goal_checkins` row; null when unreadable.
  static GoalCheckin? fromJson(Object? json) {
    if (json is! Map) return null;
    final weekStart = parseDay(json['week_start']);
    final variant = CheckinVariant.fromCode(json['variant']);
    final oldTargets = CheckinTargets.fromJson(json['old_targets']);
    final newTargets = CheckinTargets.fromJson(json['new_targets']);
    if (weekStart == null || variant == null || oldTargets == null || newTargets == null) {
      return null;
    }
    return GoalCheckin(
      weekStart: weekStart,
      variant: variant,
      oldTargets: oldTargets,
      newTargets: newTargets,
      reason: CheckinReason.fromJson(json['reason']),
      createdAt: DateTime.tryParse('${json['created_at']}') ?? weekStart,
      seenAt: DateTime.tryParse('${json['seen_at'] ?? ''}'),
    );
  }
}
