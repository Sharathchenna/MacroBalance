import 'package:flutter/foundation.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';

class NutritionGoalsProvider with ChangeNotifier {
  // Daily nutrition goals
  double _caloriesGoal = 2000.0;
  double _proteinGoal = 150.0;
  double _carbsGoal = 225.0;
  double _fatGoal = 65.0;
  int _stepsGoal = 10000;

  // BMR and TDEE
  double _bmr = 1500.0;
  double _tdee = 2000.0;
  
  // Goal parameters
  double _goalWeightKg = 0.0;
  double _currentWeightKg = 0.0;
  String _goalType = MacroCalculatorService.GOAL_MAINTAIN;
  int _deficitSurplus = 500;

  // User profile for calculations
  String _gender = MacroCalculatorService.MALE;
  int _age = 30;
  double _heightCm = 175;
  int _activityLevel = MacroCalculatorService.LIGHTLY_ACTIVE;
  double? _proteinRatio; // g/kg
  double? _fatRatio; // percentage

  // Getters
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
  String get gender => _gender;
  int get age => _age;
  double get heightCm => _heightCm;
  int get activityLevel => _activityLevel;
  double? get proteinRatio => _proteinRatio;
  double? get fatRatio => _fatRatio;

  int get goalTypeAsInt {
    switch (_goalType) {
      case MacroCalculatorService.GOAL_MAINTAIN:
        return 1;
      case MacroCalculatorService.GOAL_LOSE:
        return 2;
      case MacroCalculatorService.GOAL_GAIN:
        return 3;
      default:
        return 1;
    }
  }

  // Setters with auto-save and sync
  set caloriesGoal(double value) {
    _caloriesGoal = value;
    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  set proteinGoal(double value) {
    _proteinGoal = value;
    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  set carbsGoal(double value) {
    _carbsGoal = value;
    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  set fatGoal(double value) {
    _fatGoal = value;
    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  set stepsGoal(int value) {
    _stepsGoal = value;
    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  set goalWeightKg(double value) {
    _goalWeightKg = value;
    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  set currentWeightKg(double value) {
    if (_currentWeightKg != value) {
      _currentWeightKg = value;
      _saveGoals();
      notifyListeners();
      _syncToSupabase();
    }
  }

  set goalType(String value) {
    if (_goalType != value) {
      _goalType = value;
      _saveGoals();
      notifyListeners();
      _syncToSupabase();
      recalculateMacroGoals(_tdee);
    }
  }

  set goalTypeAsInt(int value) {
    String newGoalType;
    switch (value) {
      case 1:
        newGoalType = MacroCalculatorService.GOAL_MAINTAIN;
        break;
      case 2:
        newGoalType = MacroCalculatorService.GOAL_LOSE;
        break;
      case 3:
        newGoalType = MacroCalculatorService.GOAL_GAIN;
        break;
      default:
        newGoalType = MacroCalculatorService.GOAL_MAINTAIN;
    }
    goalType = newGoalType;
  }

  set deficitSurplus(int value) {
    if (_deficitSurplus != value) {
      _deficitSurplus = value;
      _saveGoals();
      notifyListeners();
      _syncToSupabase();
      recalculateMacroGoals(_tdee);
    }
  }

  // User profile setters
  set gender(String value) {
    _gender = value;
    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  set age(int value) {
    _age = value;
    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  set heightCm(double value) {
    _heightCm = value;
    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  set activityLevel(int value) {
    _activityLevel = value;
    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  set proteinRatio(double? value) {
    _proteinRatio = value;
    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  set fatRatio(double? value) {
    _fatRatio = value;
    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  // Bulk update method
  Future<void> updateNutritionGoals({
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

    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  // Macro calculation
  Future<void> recalculateMacroGoals(double calculatedTDEE) async {
    _tdee = calculatedTDEE;

    double targetCalories;
    int calorieAdjustment = _deficitSurplus;

    switch (_goalType) {
      case MacroCalculatorService.GOAL_LOSE:
        targetCalories = _tdee - calorieAdjustment;
        break;
      case MacroCalculatorService.GOAL_GAIN:
        targetCalories = _tdee + calorieAdjustment;
        break;
      case MacroCalculatorService.GOAL_MAINTAIN:
      default:
        targetCalories = _tdee;
        break;
    }

    final Map<String, double> macros = MacroCalculatorService.distributeMacros(
      targetCalories: targetCalories,
      weightKg: _currentWeightKg,
      gender: _gender,
      proteinRatio: _proteinRatio,
      fatRatio: _fatRatio,
    );

    _caloriesGoal = targetCalories;
    _proteinGoal = macros['protein_g'] ?? 150.0;
    _carbsGoal = macros['carb_g'] ?? 225.0;
    _fatGoal = macros['fat_g'] ?? 65.0;

    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  // Load goals from storage
  Future<void> loadGoals() async {
    debugPrint("[NutritionGoals] Loading nutrition goals...");

    // First check for individual keys (saved by auth flow)
    final caloriesFromStorage = StorageService().get('calories_goal');
    final proteinFromStorage = StorageService().get('protein_goal');
    final carbsFromStorage = StorageService().get('carbs_goal');
    final fatFromStorage = StorageService().get('fat_goal');

    bool updatedFromIndividualKeys = false;
    if (caloriesFromStorage != null) {
      _caloriesGoal = (caloriesFromStorage as num).toDouble();
      updatedFromIndividualKeys = true;
    }
    if (proteinFromStorage != null) {
      _proteinGoal = (proteinFromStorage as num).toDouble();
      updatedFromIndividualKeys = true;
    }
    if (carbsFromStorage != null) {
      _carbsGoal = (carbsFromStorage as num).toDouble();
      updatedFromIndividualKeys = true;
    }
    if (fatFromStorage != null) {
      _fatGoal = (fatFromStorage as num).toDouble();
      updatedFromIndividualKeys = true;
    }

    if (updatedFromIndividualKeys) {
      debugPrint("[NutritionGoals] Updated from individual keys");
      notifyListeners();
      return;
    }

    // Fall back to nutrition_goals object
    final goalsJson = StorageService().get('nutrition_goals');
    if (goalsJson != null) {
      try {
        final Map<String, dynamic> goals = jsonDecode(goalsJson);
        _caloriesGoal = (goals['calories_goal'] as num?)?.toDouble() ?? 2000.0;
        _proteinGoal = (goals['protein_goal'] as num?)?.toDouble() ?? 150.0;
        _carbsGoal = (goals['carbs_goal'] as num?)?.toDouble() ?? 225.0;
        _fatGoal = (goals['fat_goal'] as num?)?.toDouble() ?? 65.0;
        _stepsGoal = (goals['steps_goal'] as num?)?.toInt() ?? 10000;
        _bmr = (goals['bmr'] as num?)?.toDouble() ?? 1500.0;
        _tdee = (goals['tdee'] as num?)?.toDouble() ?? 2000.0;
        _goalWeightKg = (goals['goal_weight_kg'] as num?)?.toDouble() ?? 0.0;
        _currentWeightKg = (goals['current_weight_kg'] as num?)?.toDouble() ?? 0.0;
        _goalType = goals['goal_type'] as String? ?? MacroCalculatorService.GOAL_MAINTAIN;
        _deficitSurplus = (goals['deficit_surplus'] as num?)?.toInt() ?? 500;
        _gender = goals['gender'] as String? ?? MacroCalculatorService.MALE;
        _age = (goals['age'] as num?)?.toInt() ?? 30;
        _heightCm = (goals['height_cm'] as num?)?.toDouble() ?? 175;
        _activityLevel = (goals['activity_level'] as num?)?.toInt() ?? MacroCalculatorService.LIGHTLY_ACTIVE;
        _proteinRatio = (goals['protein_ratio'] as num?)?.toDouble();
        _fatRatio = (goals['fat_ratio'] as num?)?.toDouble();

        debugPrint("[NutritionGoals] Loaded from nutrition_goals object");
        notifyListeners();
      } catch (e) {
        debugPrint("[NutritionGoals] Error loading goals: $e");
      }
    }
  }

  // Save goals to storage
  void _saveGoals() {
    final Map<String, dynamic> goals = {
      'calories_goal': _caloriesGoal,
      'protein_goal': _proteinGoal,
      'carbs_goal': _carbsGoal,
      'fat_goal': _fatGoal,
      'steps_goal': _stepsGoal,
      'bmr': _bmr,
      'tdee': _tdee,
      'goal_weight_kg': _goalWeightKg,
      'current_weight_kg': _currentWeightKg,
      'goal_type': _goalType,
      'deficit_surplus': _deficitSurplus,
      'gender': _gender,
      'age': _age,
      'height_cm': _heightCm,
      'activity_level': _activityLevel,
      'protein_ratio': _proteinRatio,
      'fat_ratio': _fatRatio,
    };

    StorageService().put('nutrition_goals', jsonEncode(goals));
    debugPrint("[NutritionGoals] Goals saved locally");
  }

  // Sync to Supabase
  Future<void> _syncToSupabase() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final Map<String, dynamic> goalsData = {
        'id': user.id,
        'calories_goal': _caloriesGoal,
        'protein_goal': _proteinGoal,
        'carbs_goal': _carbsGoal,
        'fat_goal': _fatGoal,
        'steps_goal': _stepsGoal,
        'bmr': _bmr,
        'tdee': _tdee,
        'goal_weight_kg': _goalWeightKg,
        'current_weight_kg': _currentWeightKg,
        'goal_type': _goalType,
        'deficit_surplus': _deficitSurplus,
        'gender': _gender,
        'age': _age,
        'height_cm': _heightCm,
        'activity_level': _activityLevel,
        'protein_ratio': _proteinRatio,
        'fat_ratio': _fatRatio,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await Supabase.instance.client.from('user_macros').upsert(goalsData);
      debugPrint("[NutritionGoals] Synced to Supabase successfully");
    } catch (e) {
      debugPrint("[NutritionGoals] Error syncing to Supabase: $e");
    }
  }

  // Reset to defaults
  Future<void> resetToDefaults() async {
    _caloriesGoal = 2000.0;
    _proteinGoal = 150.0;
    _carbsGoal = 225.0;
    _fatGoal = 65.0;
    _stepsGoal = 10000;
    _bmr = 1500.0;
    _tdee = 2000.0;
    _goalWeightKg = 0.0;
    _currentWeightKg = 0.0;
    _goalType = MacroCalculatorService.GOAL_MAINTAIN;
    _deficitSurplus = 500;
    _gender = MacroCalculatorService.MALE;
    _age = 30;
    _heightCm = 175;
    _activityLevel = MacroCalculatorService.LIGHTLY_ACTIVE;
    _proteinRatio = null;
    _fatRatio = null;

    _saveGoals();
    notifyListeners();
    _syncToSupabase();
  }

  // Clear user data
  Future<void> clearUserData() async {
    await StorageService().delete('nutrition_goals');
    await resetToDefaults();
  }
} 