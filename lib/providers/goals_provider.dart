import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
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
  GoalsProvider({this.userId}) {
    _readFromStorage();
  }

  /// The account these goals belong to, or null when signed out.
  final String? userId;

  static const String _storageKey = 'nutrition_goals';

  // Sign-in fallback keys: filled from `user_macros` before this device has
  // `nutrition_goals` of its own.
  static const String _caloriesKey = 'calories_goal';
  static const String _proteinKey = 'protein_goal';
  static const String _carbsKey = 'carbs_goal';
  static const String _fatKey = 'fat_goal';

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
  int _deficitSurplus = 500;

  // Macro split inputs for [recalculateMacroGoals]. Not stored yet, so the
  // calculator's own defaults apply.
  final String _gender = MacroCalculatorService.MALE;
  final double? _proteinRatio = null; // g/kg
  final double? _fatRatio = null; // share of calories

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
  int get deficitSurplus => _deficitSurplus;

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

  set deficitSurplus(int value) {
    if (_deficitSurplus == value) return;
    _deficitSurplus = value;
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

  /// Sets the calorie and macro targets from [tdee] and the weight goal.
  Future<void> recalculateMacroGoals(double tdee) async {
    debugPrint('[Goals] Recalculating with TDEE ${tdee.round()}');
    _tdee = tdee;

    final double targetCalories;
    if (_goalType == MacroCalculatorService.GOAL_LOSE) {
      targetCalories = max(1200, _tdee - _deficitSurplus);
    } else if (_goalType == MacroCalculatorService.GOAL_GAIN) {
      targetCalories = _tdee + _deficitSurplus;
    } else {
      targetCalories = _tdee;
    }

    if (_currentWeightKg <= 0) {
      debugPrint('[Goals] Cannot recalculate: current weight is not set.');
      return;
    }

    final macros = MacroCalculatorService.distributeMacros(
      targetCalories: targetCalories,
      weightKg: _currentWeightKg,
      gender: _gender,
      proteinRatio: _proteinRatio,
      fatRatio: _fatRatio,
    );

    _caloriesGoal = targetCalories.roundToDouble();
    _proteinGoal = macros['protein_g']!.roundToDouble();
    _carbsGoal = macros['carb_g']!.roundToDouble();
    _fatGoal = macros['fat_g']!.roundToDouble();
    debugPrint(
        '[Goals] Cals=$_caloriesGoal, P=$_proteinGoal, C=$_carbsGoal, F=$_fatGoal');
    _commit();
  }

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
      if (saved != null && saved.isNotEmpty) {
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
        _goalWeightKg = _asDouble(goals['goal_weight_kg']) ?? _goalWeightKg;
        _currentWeightKg = _asDouble(goals['current_weight_kg']) ?? _currentWeightKg;
        _goalType = goals['goal_type'] as String? ?? _goalType;
        _deficitSurplus =
            (goals['deficit_surplus'] as num?)?.toInt() ?? _deficitSurplus;
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
          'deficit_surplus': _deficitSurplus,
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
        'deficit_surplus': _deficitSurplus,
        // A 0 here means "not loaded", not a real goal; sending it would wipe
        // the goal weight saved at onboarding.
        if (_goalWeightKg > 0) 'goal_weight_kg': _goalWeightKg,
        if (_currentWeightKg > 0) 'current_weight_kg': _currentWeightKg,
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

  /// Keeps an account's `user_macros` targets on this device as the fallback
  /// [load] reads when the device has no goals of its own (sign-in restore).
  static Future<void> cacheUserMacros(Map<String, dynamic> row) async {
    final storage = StorageService();
    await storage.put(_caloriesKey, row['calories_goal'] ?? _defaultCalories);
    await storage.put(_proteinKey, row['protein_goal'] ?? _defaultProtein);
    await storage.put(_carbsKey, row['carbs_goal'] ?? _defaultCarbs);
    await storage.put(_fatKey, row['fat_goal'] ?? _defaultFat);
  }

  // --- Weight ---

  /// Backs up weight history kept on this device and restores it after a
  /// reinstall; keeps the current weight in step with the latest entry.
  Future<void> restoreWeightHistory() async {
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
    _deficitSurplus = 500;

    for (final key in [
      _storageKey,
      _caloriesKey,
      _proteinKey,
      _carbsKey,
      _fatKey,
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
