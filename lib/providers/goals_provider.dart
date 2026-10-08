import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:macrotracker/services/energy/age.dart';
import 'package:macrotracker/services/energy/bmr.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/checkin_day.dart' as checkin;
import 'package:macrotracker/services/energy/constants.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/services/weight_sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The single owner of the user's goals: daily calorie, macro and steps
/// targets, the energy numbers they came from, and the weight goal.
///
/// Every change is saved on the device (`nutrition_goals`) and synced to the
/// account's `user_macros` row. One instance belongs to one signed-in user;
/// main.dart starts a fresh one whenever the user changes.
class GoalsProvider with ChangeNotifier {
  GoalsProvider({this.userId, DateTime Function()? clock})
      : _clock = clock ?? DateTime.now {
    _readFromStorage();
  }

  final DateTime Function() _clock;

  /// The account these goals belong to, or null when signed out.
  final String? userId;

  static const String _storageKey = 'nutrition_goals';

  // Sign-in fallback keys: filled from `user_macros` before this device has
  // `nutrition_goals` of its own.
  static const String _caloriesKey = 'calories_goal';
  static const String _proteinKey = 'protein_goal';
  static const String _carbsKey = 'carbs_goal';
  static const String _fatKey = 'fat_goal';
  // The goal settings from `user_macros`, in `nutrition_goals`' key names.
  static const String _settingsKey = 'goal_settings';

  static const double _defaultCalories = 2000.0;
  static const double _defaultProtein = 150.0;
  static const double _defaultCarbs = 225.0;
  static const double _defaultFat = 65.0;

  // Daily targets
  double _caloriesGoal = _defaultCalories;
  double _proteinGoal = _defaultProtein;
  double _carbsGoal = _defaultCarbs;
  double _fatGoal = _defaultFat;
  int _stepsGoal = 10000;

  // Energy the targets were set from
  double _bmr = 1500.0;
  double _tdee = 2000.0;

  // Weight goal
  double _goalWeightKg = 0.0;
  double _currentWeightKg = 0.0;
  String _goalType = MacroCalculatorService.GOAL_MAINTAIN;
  double? _pacePct; // % of body weight a week; null: the recommended pace

  // The profile and settings [recalculateMacroGoals] works from, saved by
  // onboarding. Null means unknown or "use the default".
  String? _sex; // MacroCalculatorService.MALE / FEMALE
  int? _age; // as given on [_ageRecordedOn]; see [age]
  DateTime? _ageRecordedOn;
  int? _activityLevel; // 1–5
  double? _formulaTdee; // expenditure from the BMR formula and activity
  double _heightCm = 0.0;
  double? _bodyFatPct; // only from a scan or smart scale
  double? _proteinRatio; // g per kg of reference weight
  double? _fatRatio; // share of cals
  DateTime? _learningStartedOn; // the estimator's day 0; see [learningStartedOn]
  bool _adaptiveGoals = true; // targets follow the learned expenditure
  int? _checkinWeekday; // ISO, 1 = Monday; see [checkinWeekday]
  PlanStyle _planStyle = PlanStyle.steady; // lose goals only; see [planStyle]
  // Phase settings; null keeps the default (spec §5).
  double? _phaseLossPct;
  int? _maintenanceWeeks;
  int? _breakEveryWeeks;
  int? _breakWeeks;

  // The weight history restore started for this account, if any.
  Future<void>? _weightRestore;

  // Logged out: a check-in still in flight must not write these goals back.
  bool _cleared = false;

  // --- Getters ---
  double get caloriesGoal => _caloriesGoal;
  double get proteinGoal => _proteinGoal;
  double get carbsGoal => _carbsGoal;
  double get fatGoal => _fatGoal;
  int get stepsGoal => _stepsGoal;
  double get bmr => _bmr;
  double get tdee => _tdee;
  double get goalWeightKg => _goalWeightKg;
  double get currentWeightKg => _currentWeightKg;
  String get goalType => _goalType;

  /// MacroCalculatorService.MALE / FEMALE, or null when not known.
  String? get sex => _sex;

  /// 1–5, or null when not known.
  int? get activityLevel => _activityLevel;

  /// Null when not known.
  double? get heightCm => _heightCm > 0 ? _heightCm : null;

  /// The age to use today: the age given plus the whole years since it was
  /// recorded. Null when not known.
  int? get age => _age == null
      ? null
      : effectiveAge(age: _age!, recordedOn: _ageRecordedOn, today: _clock());

  /// Body fat % from a scan or smart scale; null estimates it.
  double? get bodyFatPct => _bodyFatPct;

  /// The expenditure the BMR formula and activity give (the estimator's
  /// prior). Null for accounts from before it was saved.
  double? get formulaTdee => _formulaTdee;

  /// The day the expenditure estimator starts learning from: set when
  /// onboarding completes and on "Reset learning", never by a recalculation.
  /// Null for accounts from before it existed.
  DateTime? get learningStartedOn => _learningStartedOn;

  /// Starts (or restarts) learning on [day], today by default.
  void startLearning([DateTime? day]) {
    _learningStartedOn = _dateOnly(day ?? _clock());
    _commit();
  }

  /// Whether weekly check-ins move the targets with the learned expenditure
  /// (adaptive goals). Off means the targets stay as calculated. On by
  /// default, as onboarding recommends.
  bool get adaptiveGoals => _adaptiveGoals;

  set adaptiveGoals(bool value) {
    if (_adaptiveGoals == value) return;
    _adaptiveGoals = value;
    _commit();
  }

  /// The ISO weekday (1 = Monday) check-ins fall on: the one chosen, else the
  /// weekday learning started (onboarding), else Monday for accounts from
  /// before either was kept.
  int get checkinWeekday =>
      _checkinWeekday ?? _learningStartedOn?.weekday ?? DateTime.monday;

  set checkinWeekday(int value) {
    RangeError.checkValueInInterval(value, DateTime.monday, DateTime.sunday, 'checkinWeekday');
    if (_checkinWeekday == value) return;
    _checkinWeekday = value;
    _commit();
  }

  /// The next scheduled check-in day (today on the check-in weekday), at
  /// least a week after learning started.
  DateTime get nextCheckinDay => checkin.nextCheckinDay(
        weekday: checkinWeekday,
        today: _clock(),
        learningStartedOn: _learningStartedOn,
      );

  /// The next check-in day once the check-in for [lastCheckin]'s week has
  /// run: a week after it at the earliest.
  DateTime nextCheckinDayAfter(DateTime? lastCheckin) => checkin.nextCheckinDay(
        weekday: checkinWeekday,
        today: _clock(),
        learningStartedOn: _learningStartedOn,
        lastCheckin: lastCheckin,
      );

  /// How the weight goal is arranged into phases. Only lose goals have
  /// phased or diet-break plans; anything else is steady.
  PlanStyle get planStyle =>
      _goalType == MacroCalculatorService.GOAL_LOSE ? _planStyle : PlanStyle.steady;

  /// The phase lengths and loss per phase, defaults where not set.
  PhaseSettings get phaseSettings => PhaseSettings(
        lossPct: _phaseLossPct,
        maintenanceWeeks: _maintenanceWeeks ?? kMaintenanceWeeks,
        breakEveryWeeks: _breakEveryWeeks ?? kBreakEveryWeeks,
        breakWeeks: _breakWeeks ?? kBreakWeeks,
      );

  /// What a weekly check-in works from (spec 6.8).
  CheckinSettings get checkinSettings => CheckinSettings(
        adaptive: _adaptiveGoals,
        goal: MacroCalculatorService.goalKindOf(_goalType),
        pacePct: pacePctPerWeek,
        // As in [_targetsFor]: an unknown sex gets the 1,200 floor.
        sex: _sex == null ? Sex.female : MacroCalculatorService.sexOf(_sex!),
        heightCm: heightCm,
        age: age,
        activityLevel: _activityLevel,
        bodyFatPct: _bodyFatPct,
        proteinPerKg: _proteinRatio,
        fatRatio: _fatRatio,
        goalWeightKg: _goalWeightKg > 0 ? _goalWeightKg : null,
      );

  /// The daily targets in whole cals and grams, as a check-in records them.
  CheckinTargets get checkinTargets => CheckinTargets(
        cals: _caloriesGoal.round(),
        protein: _proteinGoal.round(),
        carbs: _carbsGoal.round(),
        fat: _fatGoal.round(),
      );

  /// Applies a check-in's new targets on this device, set from the learned
  /// expenditure [tdee]. `user_macros` follows through
  /// [uploadCheckinTargets] once the check-in row is the account's.
  ///
  /// [tdee] becomes the expenditure the targets came from. The estimator's
  /// prior falls back to it when there's no formula TDEE, so an account
  /// without one first keeps the old value as its formula TDEE: a check-in
  /// never moves the starting estimate. Does nothing after logout.
  void applyCheckinTargets(CheckinTargets targets, {required double tdee}) {
    if (_cleared) return;
    _formulaTdee ??= _tdee;
    _tdee = tdee;
    _setTargets(targets);
    _save();
    notifyListeners();
  }

  /// Sets targets the user chose from a phase change ("Keep losing",
  /// "Extend break"), planned from [tdee]. An ordinary goal edit: saved and
  /// synced. Does nothing after logout.
  void applyPhaseTargets(CheckinTargets targets, {required double tdee}) {
    if (_cleared) return;
    _formulaTdee ??= _tdee;
    _tdee = tdee;
    _setTargets(targets);
    _commit();
  }

  void _setTargets(CheckinTargets t) {
    _caloriesGoal = t.cals.toDouble();
    _proteinGoal = t.protein.toDouble();
    _carbsGoal = t.carbs.toDouble();
    _fatGoal = t.fat.toDouble();
  }

  /// Brings `user_macros` in step with [checkin], whose targets this device
  /// has applied, without overwriting a newer change from another device:
  /// - the account already has them: done;
  /// - the row changed after the check-in, to something other than the
  ///   targets it started from: that change is newer, so it's taken here;
  /// - otherwise only the target fields are written, and only if the row is
  ///   still the one just read (another write in between retries).
  ///
  /// Returns false when it has to be tried again (offline, a write raced,
  /// signed out).
  Future<bool> uploadCheckinTargets(GoalCheckin checkin) async {
    final uid = userId;
    if (uid == null || _cleared) return false;
    try {
      final server = await fetchRemoteTargets(uid);
      if (_cleared) return false;
      if (server == null) return true; // no row to keep in step
      if (server.targets == checkin.newTargets) return true;
      final changed = server.updatedAt;
      if (changed != null &&
          changed.isAfter(checkin.createdAt) &&
          server.targets != checkin.oldTargets) {
        _setTargets(server.targets);
        if (server.tdee != null) _tdee = server.tdee!;
        _save();
        notifyListeners();
        return true;
      }
      final written = await writeRemoteTargets(uid, _targetsPayload(), ifUpdatedAt: changed);
      if (!written) debugPrint('[Goals] user_macros changed meanwhile; check-in targets retry.');
      return written;
    } catch (e) {
      debugPrint('[Goals] Check-in targets not in user_macros yet, will retry: $e');
      return false;
    }
  }

  /// Only the fields a check-in changes.
  Map<String, dynamic> _targetsPayload() => {
        'calories_goal': _caloriesGoal,
        'protein_goal': _proteinGoal,
        'carbs_goal': _carbsGoal,
        'fat_goal': _fatGoal,
        'macro_targets': _macroTargets(),
        'tdee': _tdee,
        if (_formulaTdee != null) 'formula_tdee': _formulaTdee!.round(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  /// The account's `user_macros` targets and when the row last changed, or
  /// null without a row.
  @visibleForTesting
  Future<RemoteTargets?> fetchRemoteTargets(String uid) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser?.id != uid) throw StateError('not signed in as $uid');
    final row = await client
        .from('user_macros')
        .select('calories_goal, protein_goal, carbs_goal, fat_goal, tdee, updated_at')
        .eq('id', uid)
        .maybeSingle()
        .timeout(const Duration(seconds: 15));
    final cals = _asDouble(row?['calories_goal']);
    if (row == null || cals == null) return null;
    int n(String key) => (_asDouble(row[key]) ?? 0).round();
    return RemoteTargets(
      CheckinTargets(
          cals: cals.round(), protein: n('protein_goal'), carbs: n('carbs_goal'), fat: n('fat_goal')),
      tdee: _asDouble(row['tdee']),
      updatedAt: DateTime.tryParse('${row['updated_at'] ?? ''}'),
    );
  }

  /// Writes [payload] to `user_macros` if its `updated_at` is still
  /// [ifUpdatedAt]. Returns whether it was written.
  @visibleForTesting
  Future<bool> writeRemoteTargets(String uid, Map<String, dynamic> payload,
      {required DateTime? ifUpdatedAt}) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser?.id != uid) throw StateError('not signed in as $uid');
    final query = client.from('user_macros').update(payload).eq('id', uid);
    final rows = await (ifUpdatedAt == null
            ? query.isFilter('updated_at', null)
            : query.eq('updated_at', ifUpdatedAt.toUtc().toIso8601String()))
        .select('id')
        .timeout(const Duration(seconds: 15));
    return rows.isNotEmpty;
  }

  /// Completes when the weight history restore started at sign-in has
  /// finished (at once if none was started).
  Future<void> get weightHistoryRestored => _weightRestore ?? Future.value();

  /// The chosen pace, % of body weight a week (0 when maintaining).
  double get pacePctPerWeek =>
      _pacePct ?? defaultPacePct(MacroCalculatorService.goalKindOf(_goalType));

  int get goalTypeAsInt {
    switch (_goalType) {
      case MacroCalculatorService.GOAL_LOSE:
        return 2;
      case MacroCalculatorService.GOAL_GAIN:
        return 3;
      default:
        return 1;
    }
  }

  // --- Setters ---
  set caloriesGoal(double value) {
    _caloriesGoal = value;
    _commit();
  }

  set proteinGoal(double value) {
    _proteinGoal = value;
    _commit();
  }

  set carbsGoal(double value) {
    _carbsGoal = value;
    _commit();
  }

  set fatGoal(double value) {
    _fatGoal = value;
    _commit();
  }

  set stepsGoal(int value) {
    _stepsGoal = value;
    _commit();
  }

  set goalWeightKg(double value) {
    _goalWeightKg = value;
    _commit();
  }

  set currentWeightKg(double value) {
    if (_currentWeightKg == value) return;
    _currentWeightKg = value;
    _commit();
  }

  set goalType(String value) {
    if (_goalType == value) return;
    _goalType = value;
    _commit();
    recalculateMacroGoals(_tdee);
  }

  set goalTypeAsInt(int value) {
    goalType = switch (value) {
      2 => MacroCalculatorService.GOAL_LOSE,
      3 => MacroCalculatorService.GOAL_GAIN,
      _ => MacroCalculatorService.GOAL_MAINTAIN,
    };
  }

  set pacePctPerWeek(double value) {
    if (_pacePct == value) return;
    _pacePct = value;
    _commit();
    recalculateMacroGoals(_tdee);
  }

  /// Sets the daily targets in one go (Edit Goals).
  Future<void> updateGoals({
    required double calories,
    required double protein,
    required double carbs,
    required double fat,
    required int steps,
    required double bmr,
    required double tdee,
  }) async {
    _caloriesGoal = calories;
    _proteinGoal = protein;
    _carbsGoal = carbs;
    _fatGoal = fat;
    _stepsGoal = steps;
    _bmr = bmr;
    _tdee = tdee;
    _commit();
  }

  /// Sets the calorie and macro targets from [tdee] and the weight goal at
  /// the chosen pace, through the safety limits.
  Future<void> recalculateMacroGoals(double tdee) async {
    debugPrint('[Goals] Recalculating with TDEE ${tdee.round()}');
    _tdee = tdee;

    if (_currentWeightKg <= 0) {
      debugPrint('[Goals] Cannot recalculate: current weight is not set.');
      return;
    }

    final next = _targetsFor(tdee: _tdee);
    _caloriesGoal = next.calories;
    _proteinGoal = next.protein;
    _carbsGoal = next.carbs;
    _fatGoal = next.fat;
    debugPrint(
        '[Goals] Cals=$_caloriesGoal, P=$_proteinGoal, C=$_carbsGoal, F=$_fatGoal');
    _commit();
  }

  /// The targets [tdee] gives at the chosen pace and weight goal, with the
  /// profile overridden by [sex], [heightCm] and [age] when given. Changes
  /// nothing.
  GoalTargets _targetsFor({
    required double tdee,
    Sex? sex,
    double? heightCm,
    int? age,
  }) {
    // Accounts from before onboarding saved the profile: an unknown sex gets
    // the lower (1,200) floor they had before, and an unknown height or age
    // the onboarding defaults.
    final goal = MacroCalculatorService.goalKindOf(_goalType);
    final sexUsed = sex ??
        (_sex == null ? Sex.female : MacroCalculatorService.sexOf(_sex!));
    final height = heightCm ?? (_heightCm > 0 ? _heightCm : null);
    final energyDensityPerKg = energyDensity(fatMassKg(
      weightKg: _currentWeightKg,
      heightCm: height ?? 170,
      age: age ?? this.age ?? 30,
      sex: sexUsed,
      bodyFatPct: _bodyFatPct,
    ));
    final targetCalories = targetForPace(
      goal: goal,
      pacePct: pacePctPerWeek,
      tdee: tdee,
      sex: sexUsed,
      weightKg: _currentWeightKg,
      energyDensity: energyDensityPerKg,
    ).cals;
    final macros = splitMacros(
      cals: targetCalories,
      goal: goal,
      weightKg: _currentWeightKg,
      heightCm: height,
      bodyFatPct: _bodyFatPct,
      proteinPerKg: _proteinRatio,
      fatRatio: _fatRatio,
    );
    return GoalTargets(
      calories: targetCalories,
      protein: macros.proteinG.toDouble(),
      carbs: macros.carbsG.toDouble(),
      fat: macros.fatG.toDouble(),
    );
  }

  // --- Profile (sex, height, age) ---

  /// The daily targets as they are now.
  GoalTargets get targets => GoalTargets(
      calories: _caloriesGoal,
      protein: _proteinGoal,
      carbs: _carbsGoal,
      fat: _fatGoal);

  /// What the targets would become if the profile changed to the given
  /// values (anything left null stays as it is). Needs a current weight;
  /// returns null without one. Changes nothing.
  ProfileChange? previewProfile({String? sex, double? heightCm, int? age}) {
    if (_currentWeightKg <= 0) return null;
    final change = _profileTdee(sex: sex, heightCm: heightCm, age: age);
    return ProfileChange(
      before: targets,
      after: _targetsFor(
        tdee: change.tdee,
        sex: change.sex,
        heightCm: change.heightCm,
        age: change.age,
      ),
    );
  }

  /// Saves a new sex, height or age (anything left null stays as it is),
  /// recomputes the targets with the current settings and syncs. A new age is
  /// recorded as of today. Without a current weight there is nothing to
  /// recompute, so only the profile is saved.
  Future<void> saveProfile({String? sex, double? heightCm, int? age}) async {
    final change = _currentWeightKg > 0
        ? _profileTdee(sex: sex, heightCm: heightCm, age: age)
        : null;
    if (sex != null) _sex = sex;
    if (heightCm != null) _heightCm = heightCm;
    if (age != null) {
      _age = age;
      _ageRecordedOn = _dateOnly(_clock());
    }
    if (change == null) {
      _commit();
      return;
    }
    _bmr = change.bmr;
    _formulaTdee = change.tdee;
    _activityLevel ??= MacroCalculatorService.MODERATELY_ACTIVE;
    await recalculateMacroGoals(change.tdee);
  }

  /// The formula expenditure for the profile with the given changes.
  ({Sex sex, double heightCm, int age, double bmr, double tdee}) _profileTdee({
    String? sex,
    double? heightCm,
    int? age,
  }) {
    final sexUsed = MacroCalculatorService.sexOf(sex ?? _sex ?? MacroCalculatorService.FEMALE);
    final heightUsed = heightCm ?? (_heightCm > 0 ? _heightCm : 170);
    final ageUsed = age ?? this.age ?? 30;
    final level = _activityLevel ?? MacroCalculatorService.MODERATELY_ACTIVE;
    final bmrValue = basalMetabolicRate(
      sex: sexUsed,
      weightKg: _currentWeightKg,
      heightCm: heightUsed,
      age: ageUsed,
      bodyFatPct: _bodyFatPct,
    );
    return (
      sex: sexUsed,
      heightCm: heightUsed,
      age: ageUsed,
      bmr: bmrValue,
      tdee: bmrValue * activityFactor(level),
    );
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // --- Device storage ---

  /// Reloads goals from this device, e.g. after something else wrote them.
  Future<void> load() async {
    _readFromStorage();
    notifyListeners();
  }

  /// `nutrition_goals` is written on every goal change, so it wins. The
  /// individual `*_goal` keys are only a fallback: they are filled from
  /// `user_macros` at sign-in, before `nutrition_goals` exists on this device.
  void _readFromStorage() {
    try {
      final storage = StorageService();
      final String? saved = storage.get(_storageKey);
      bool loadedMacros = false;
      final bool hasDeviceGoals = saved != null && saved.isNotEmpty;
      if (hasDeviceGoals) {
        final Map<String, dynamic> goals = jsonDecode(saved);

        // Older builds of Edit Goals wrote a flat {calories, protein, ...} map.
        final macroTargets =
            goals['macro_targets'] is Map ? goals['macro_targets'] as Map : goals;
        final calories = _asDouble(macroTargets['calories']);
        if (calories != null && calories > 0) {
          _caloriesGoal = calories;
          _proteinGoal = _asDouble(macroTargets['protein']) ?? _proteinGoal;
          _carbsGoal = _asDouble(macroTargets['carbs']) ?? _carbsGoal;
          _fatGoal = _asDouble(macroTargets['fat']) ?? _fatGoal;
          loadedMacros = true;
        }

        _stepsGoal =
            _asDouble(goals['steps_goal'] ?? goals['steps'])?.toInt() ?? _stepsGoal;
        _bmr = _asDouble(goals['bmr']) ?? _bmr;
        _tdee = _asDouble(goals['tdee']) ?? _tdee;
        _readSettings(goals);
      } else {
        final String? settings = storage.get(_settingsKey);
        if (settings != null && settings.isNotEmpty) _readSettings(jsonDecode(settings));
      }

      if (!loadedMacros) {
        final calories = _asDouble(storage.get(_caloriesKey));
        if (calories != null && calories > 0) {
          _caloriesGoal = calories;
          _proteinGoal = _asDouble(storage.get(_proteinKey)) ?? _proteinGoal;
          _carbsGoal = _asDouble(storage.get(_carbsKey)) ?? _carbsGoal;
          _fatGoal = _asDouble(storage.get(_fatKey)) ?? _fatGoal;
        }
      }
    } catch (e) {
      debugPrint('[Goals] Error loading goals: $e');
    }
  }

  /// The weight goal, pace and profile, from `nutrition_goals` or the
  /// sign-in fallback (same keys).
  void _readSettings(Map<String, dynamic> goals) {
    _goalWeightKg = _asDouble(goals['goal_weight_kg']) ?? _goalWeightKg;
    _currentWeightKg = _asDouble(goals['current_weight_kg']) ?? _currentWeightKg;
    _goalType = goals['goal_type'] as String? ?? _goalType;
    _pacePct = _asDouble(goals['pace_pct_per_week']);
    _sex = goals['sex'] as String?;
    _age = _asDouble(goals['age'])?.toInt();
    _ageRecordedOn = DateTime.tryParse('${goals['age_recorded_on'] ?? ''}');
    _activityLevel = _asDouble(goals['activity_level'])?.toInt();
    _formulaTdee = _asDouble(goals['formula_tdee']);
    _heightCm = _asDouble(goals['height_cm']) ?? _heightCm;
    _bodyFatPct = _asDouble(goals['body_fat_pct']);
    _proteinRatio = _asDouble(goals['protein_ratio']);
    _fatRatio = _asDouble(goals['fat_ratio']);
    final learning = DateTime.tryParse('${goals['learning_started_on'] ?? ''}');
    _learningStartedOn = learning == null ? null : _dateOnly(learning);
    _adaptiveGoals = goals['adaptive_goals'] as bool? ?? true;
    final weekday = _asDouble(goals['checkin_weekday'])?.toInt();
    _checkinWeekday =
        weekday != null && weekday >= 1 && weekday <= 7 ? weekday : null;
    _planStyle = PlanStyle.fromCode(goals['plan_style']);
    _phaseLossPct = _asDouble(goals['phase_loss_pct']);
    _maintenanceWeeks = _asDouble(goals['maintenance_weeks'])?.toInt();
    _breakEveryWeeks = _asDouble(goals['break_every_weeks'])?.toInt();
    _breakWeeks = _asDouble(goals['break_weeks'])?.toInt();
  }

  static String? _dateString(DateTime? d) => d == null
      ? null
      : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static double? _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  void _save() {
    final storage = StorageService();
    storage.put(
        _storageKey,
        jsonEncode({
          'macro_targets': _macroTargets(),
          'steps_goal': _stepsGoal,
          'bmr': _bmr,
          'tdee': _tdee,
          'goal_weight_kg': _goalWeightKg,
          'current_weight_kg': _currentWeightKg,
          'goal_type': _goalType,
          'pace_pct_per_week': _pacePct,
          'sex': _sex,
          'age': _age,
          'age_recorded_on': _dateString(_ageRecordedOn),
          'activity_level': _activityLevel,
          'formula_tdee': _formulaTdee,
          if (_heightCm > 0) 'height_cm': _heightCm,
          'body_fat_pct': _bodyFatPct,
          'protein_ratio': _proteinRatio,
          'fat_ratio': _fatRatio,
          'learning_started_on': _dateString(_learningStartedOn),
          'adaptive_goals': _adaptiveGoals,
          'checkin_weekday': _checkinWeekday,
          'plan_style': _planStyle.code,
          'phase_loss_pct': _phaseLossPct,
          'maintenance_weeks': _maintenanceWeeks,
          'break_every_weeks': _breakEveryWeeks,
          'break_weeks': _breakWeeks,
          'updated_at': DateTime.now().toIso8601String(),
        }));
    // Keep the sign-in fallback keys in step so they can never resurrect old goals.
    storage.put(_caloriesKey, _caloriesGoal);
    storage.put(_proteinKey, _proteinGoal);
    storage.put(_carbsKey, _carbsGoal);
    storage.put(_fatKey, _fatGoal);
  }

  /// Saves, tells listeners and syncs: the path every goal change takes.
  void _commit() {
    _save();
    notifyListeners();
    syncToCloud();
  }

  Map<String, double> _macroTargets() => {
        'calories': _caloriesGoal,
        'protein': _proteinGoal,
        'carbs': _carbsGoal,
        'fat': _fatGoal,
      };

  // --- Account sync (`user_macros`) ---

  /// The goals row written to `user_macros` whenever a goal changes.
  @visibleForTesting
  Map<String, dynamic> userMacrosPayload() => {
        'calories_goal': _caloriesGoal,
        'protein_goal': _proteinGoal,
        'carbs_goal': _carbsGoal,
        'fat_goal': _fatGoal,
        'steps_goal': _stepsGoal,
        'bmr': _bmr,
        'tdee': _tdee,
        'goal_type': _goalType,
        'pace_pct_per_week':
            _goalType == MacroCalculatorService.GOAL_MAINTAIN ? null : pacePctPerWeek,
        // A 0 or null here means "not known on this device", not a real value;
        // sending it would wipe what onboarding saved.
        if (_goalWeightKg > 0) 'goal_weight_kg': _goalWeightKg,
        if (_currentWeightKg > 0) 'current_weight_kg': _currentWeightKg,
        if (_sex != null) 'sex': _sex,
        if (_age != null) 'age': _age,
        if (_ageRecordedOn != null) 'age_recorded_on': _dateString(_ageRecordedOn),
        if (_activityLevel != null) 'activity_level': _activityLevel,
        if (_heightCm > 0) 'height_cm': _heightCm,
        if (_formulaTdee != null) 'formula_tdee': _formulaTdee!.round(),
        if (_learningStartedOn != null)
          'learning_started_on': _dateString(_learningStartedOn),
        'adaptive_goals': _adaptiveGoals,
        if (_checkinWeekday != null) 'checkin_weekday': _checkinWeekday,
        'plan_style': _planStyle.code,
        // Null is a real choice for these: not measured, or the default.
        'phase_loss_pct': _phaseLossPct,
        'maintenance_weeks': _maintenanceWeeks,
        'break_every_weeks': _breakEveryWeeks,
        'break_weeks': _breakWeeks,
        'body_fat_pct': _bodyFatPct,
        'protein_g_per_kg': _proteinRatio,
        'fat_ratio': _fatRatio,
        'macro_targets': _macroTargets(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

  /// Writes the goals to the account's `user_macros` row (the only goals
  /// table; sign-in restores from it).
  Future<void> syncToCloud() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('[Goals] Not syncing: user not logged in.');
      return;
    }
    try {
      await Supabase.instance.client
          .from('user_macros')
          .update(userMacrosPayload())
          .eq('id', userId);
      debugPrint('[Goals] Synced to user_macros.');
    } catch (e) {
      debugPrint('[Goals] Error syncing to user_macros: $e');
    }
  }

  /// Keeps an account's `user_macros` targets and goal settings on this
  /// device as the fallback [load] reads when the device has no goals of its
  /// own (sign-in restore).
  static Future<void> cacheUserMacros(Map<String, dynamic> row) async {
    final storage = StorageService();
    await storage.put(_caloriesKey, row['calories_goal'] ?? _defaultCalories);
    await storage.put(_proteinKey, row['protein_goal'] ?? _defaultProtein);
    await storage.put(_carbsKey, row['carbs_goal'] ?? _defaultCarbs);
    await storage.put(_fatKey, row['fat_goal'] ?? _defaultFat);
    await storage.put(
        _settingsKey,
        jsonEncode({
          for (final key in [
            'goal_weight_kg',
            'current_weight_kg',
            'goal_type',
            'pace_pct_per_week',
            'sex',
            'age',
            'age_recorded_on',
            'activity_level',
            'formula_tdee',
            'height_cm',
            'body_fat_pct',
            'fat_ratio',
            'learning_started_on',
            'adaptive_goals',
            'checkin_weekday',
            'plan_style',
            'phase_loss_pct',
            'maintenance_weeks',
            'break_every_weeks',
            'break_weeks',
          ])
            if (row[key] != null) key: row[key],
          if (row['protein_g_per_kg'] != null) 'protein_ratio': row['protein_g_per_kg'],
        }));
  }

  // --- Weight ---

  /// Backs up weight history kept on this device and restores it after a
  /// reinstall; keeps the current weight in step with the latest entry.
  Future<void> restoreWeightHistory() => _weightRestore = _restoreWeightHistory();

  Future<void> _restoreWeightHistory() async {
    try {
      final merged = await WeightSyncService().syncLocalHistory();
      if (merged == null || merged.isEmpty) return;
      final latest = (merged.last['weight'] as num).toDouble();
      if (latest > 0) currentWeightKg = latest;
    } catch (e) {
      debugPrint('[WeightSync] $e');
    }
  }

  // --- Sign-out ---

  /// Back to defaults, and forgets the goals and weight history on this device.
  Future<void> clearUserData() async {
    _cleared = true;
    _caloriesGoal = _defaultCalories;
    _proteinGoal = _defaultProtein;
    _carbsGoal = _defaultCarbs;
    _fatGoal = _defaultFat;
    _stepsGoal = 10000;
    _bmr = 1500.0;
    _tdee = 2000.0;
    _goalWeightKg = 0.0;
    _currentWeightKg = 0.0;
    _goalType = MacroCalculatorService.GOAL_MAINTAIN;
    _pacePct = null;
    _sex = null;
    _age = null;
    _ageRecordedOn = null;
    _activityLevel = null;
    _formulaTdee = null;
    _heightCm = 0.0;
    _bodyFatPct = null;
    _proteinRatio = null;
    _fatRatio = null;
    _learningStartedOn = null;
    _adaptiveGoals = true;
    _checkinWeekday = null;
    _planStyle = PlanStyle.steady;
    _phaseLossPct = null;
    _maintenanceWeeks = null;
    _breakEveryWeeks = null;
    _breakWeeks = null;

    for (final key in [
      _storageKey,
      _caloriesKey,
      _proteinKey,
      _carbsKey,
      _fatKey,
      _settingsKey,
      'macro_results',
      'weight_history',
      'last_sync_timestamp',
      'pending_weight_days',
      'weight_backfill_done',
    ]) {
      await StorageService().delete(key);
    }
    notifyListeners();
  }
}

/// The account's `user_macros` targets, as a check-in compares them.
@visibleForTesting
class RemoteTargets {
  const RemoteTargets(this.targets, {this.tdee, this.updatedAt});

  final CheckinTargets targets;
  final double? tdee;

  /// When the row last changed (null if never recorded).
  final DateTime? updatedAt;
}

/// Daily calorie and macro targets.
class GoalTargets {
  const GoalTargets({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double calories;
  final double protein;
  final double carbs;
  final double fat;
}

/// Targets before and after a profile change, for the confirm.
class ProfileChange {
  const ProfileChange({required this.before, required this.after});

  final GoalTargets before;
  final GoalTargets after;

  bool get isUnchanged =>
      before.calories == after.calories &&
      before.protein == after.protein &&
      before.carbs == after.carbs &&
      before.fat == after.fat;
}
