import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import '../models/fitness_profile.dart';
import '../services/storage_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/fitness_ai_service.dart'; // Import FitnessAIService

class FitnessDataService {
  static final FitnessDataService _instance = FitnessDataService._internal();
  factory FitnessDataService() => _instance;
  FitnessDataService._internal();

  final StorageService _storage = StorageService();
  final FitnessAIService _fitnessAIService =
      FitnessAIService(); // Add FitnessAIService instance

  // ================== DATA RETRIEVAL ==================

  /// Get the current user's fitness profile.
  /// It attempts to refresh the local cache from Supabase if a user is logged in,
  /// and then always tries to load from the local cache.
  Future<FitnessProfile> getCurrentFitnessProfile() async {
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser != null) {
      try {
        // Attempt to fetch from Supabase to refresh local cache
        final supabaseProfile =
            await _fitnessAIService.getFitnessProfile(currentUser.id);
        if (supabaseProfile != null) {
          // Update local storage (Hive) with the fresh profile from Supabase
          await _storage.put(
              'fitness_profile', json.encode(supabaseProfile.toJson()));
          log('[FitnessData] Refreshed local profile cache from Supabase for user ${currentUser.id}');
        }
      } catch (e) {
        log('[FitnessData] Error refreshing profile from Supabase, will use existing local cache if available: $e');
        // Proceed to try loading from local cache even if Supabase refresh failed
      }
    }

    // Always try to load from local storage (Hive) after attempting Supabase refresh
    try {
      final fitnessProfileJson = await _storage.get('fitness_profile');
      if (fitnessProfileJson != null) {
        log('[FitnessData] Loaded profile from local storage cache.');
        return FitnessProfile.fromJson(json.decode(fitnessProfileJson));
      }

      // Legacy fallback: Try to get from macro results if 'fitness_profile' key is empty
      // This might be relevant if data was stored under 'macro_results' previously.
      // Consider phasing this out if 'fitness_profile' becomes the sole local key.
      final macroResultsJson = await _storage.get('macro_results');
      if (macroResultsJson != null) {
        final macroResults = json.decode(macroResultsJson);
        if (macroResults['fitness_profile'] != null) {
          log('[FitnessData] Loaded profile from legacy local macro_results.');
          // Optionally, migrate this to the 'fitness_profile' key here
          // await _storage.put('fitness_profile', json.encode(macroResults['fitness_profile']));
          return FitnessProfile.fromJson(macroResults['fitness_profile']);
        }
      }
    } catch (e) {
      log('[FitnessData] Error retrieving fitness profile from local storage: $e');
    }

    log('[FitnessData] No fitness profile found in local cache (after Supabase check), returning empty profile');
    return FitnessProfile.empty;
  }

  /// Get macro and nutrition data for AI context
  Future<Map<String, dynamic>> getMacroData() async {
    try {
      final macroResultsJson = await _storage.get('macro_results');
      if (macroResultsJson != null) {
        return json.decode(macroResultsJson);
      }

      // Fallback to nutrition goals
      final nutritionGoalsJson = await _storage.get('nutrition_goals');
      if (nutritionGoalsJson != null) {
        final nutritionGoals = json.decode(nutritionGoalsJson);
        return {
          'target_calories':
              nutritionGoals['macro_targets']?['calories'] ?? 2000,
          'protein_g': nutritionGoals['macro_targets']?['protein'] ?? 150,
          'carb_g': nutritionGoals['macro_targets']?['carbs'] ?? 200,
          'fat_g': nutritionGoals['macro_targets']?['fat'] ?? 60,
          'goal_type': nutritionGoals['goal_type'] ?? 'maintain',
          'current_weight_kg': nutritionGoals['current_weight_kg'] ?? 70,
          'goal_weight_kg': nutritionGoals['goal_weight_kg'] ?? 70,
          'bmr': nutritionGoals['bmr'] ?? 1650,
          'tdee': nutritionGoals['tdee'] ?? 2200,
        };
      }

      log('[FitnessData] No macro data found, using defaults');
      return _getDefaultMacroData();
    } catch (e) {
      log('[FitnessData] Error retrieving macro data: $e');
      return _getDefaultMacroData();
    }
  }

  /// Get user's workout history for AI analysis
  Future<List<Map<String, dynamic>>> getWorkoutHistory({int? limitDays}) async {
    try {
      final historyJson = await _storage.get('workout_history');
      if (historyJson != null) {
        final List<dynamic> history = json.decode(historyJson);
        List<Map<String, dynamic>> workouts =
            history.cast<Map<String, dynamic>>();

        // Filter by date if limit is specified
        if (limitDays != null) {
          final cutoffDate = DateTime.now().subtract(Duration(days: limitDays));
          workouts = workouts.where((workout) {
            if (workout['generated_at'] != null) {
              final workoutDate = DateTime.parse(workout['generated_at']);
              return workoutDate.isAfter(cutoffDate);
            }
            return false;
          }).toList();
        }

        return workouts;
      }
    } catch (e) {
      log('[FitnessData] Error retrieving workout history: $e');
    }
    return [];
  }

  /// Get performance metrics for AI analysis
  Future<Map<String, dynamic>> getPerformanceData({int? lastDays}) async {
    try {
      final days = lastDays ?? 30;
      final workoutHistory = await getWorkoutHistory(limitDays: days);
      final fitnessProfile = await getCurrentFitnessProfile();

      // Calculate performance metrics
      final completedWorkouts = workoutHistory.length;
      final totalTargetWorkouts =
          (days / 7 * fitnessProfile.workoutsPerWeek).round();
      final consistencyPercentage = totalTargetWorkouts > 0
          ? (completedWorkouts / totalTargetWorkouts * 100).clamp(0, 100)
          : 0;

      final totalDuration = workoutHistory.fold<int>(
        0,
        (sum, workout) => sum + (workout['estimated_duration'] as int? ?? 0),
      );
      final avgDuration =
          completedWorkouts > 0 ? totalDuration / completedWorkouts : 0;

      return {
        'completed_workouts': completedWorkouts,
        'target_workouts': totalTargetWorkouts,
        'consistency_percentage': consistencyPercentage.round(),
        'avg_duration': avgDuration.round(),
        'total_duration': totalDuration,
        'analysis_period_days': days,
        'last_workout_date': workoutHistory.isNotEmpty
            ? workoutHistory.last['generated_at']
            : null,
      };
    } catch (e) {
      log('[FitnessData] Error calculating performance data: $e');
      return {
        'completed_workouts': 0,
        'target_workouts': 0,
        'consistency_percentage': 0,
        'avg_duration': 0,
        'total_duration': 0,
        'analysis_period_days': lastDays ?? 30,
        'last_workout_date': null,
      };
    }
  }

  // ================== DATA FORMATTING ==================

  /// Format fitness profile for AI prompts
  Map<String, dynamic> formatFitnessProfileForAI(FitnessProfile profile) {
    return {
      'fitness_level': profile.fitnessLevel,
      'experience_years': profile.yearsOfExperience,
      'previous_exercise_types': profile.previousExerciseTypes,
      'workout_location': profile.workoutLocation,
      'available_equipment': profile.availableEquipment,
      'has_gym_access': profile.hasGymAccess,
      'workout_space': profile.workoutSpace,
      'workouts_per_week': profile.workoutsPerWeek,
      'max_workout_duration': profile.maxWorkoutDuration,
      'preferred_time_of_day': profile.preferredTimeOfDay,
      'preferred_days': profile.preferredDays,
      'recommended_difficulty': profile.recommendedDifficulty,
      'recommended_workout_types': profile.recommendedWorkoutTypes,
      'optimal_workout_duration': profile.optimalWorkoutDuration,
      'profile_completeness': {
        'basic_complete': profile.isBasicProfileComplete,
        'advanced_complete': profile.isAdvancedProfileComplete,
      },
    };
  }

  /// Check if user has sufficient data for AI recommendations
  Future<bool> isReadyForAIRecommendations() async {
    try {
      final profile = await getCurrentFitnessProfile();
      final macroData = await getMacroData();

      // Also check Supabase for more reliable data checking
      bool hasSupabaseData = false;
      try {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          // Check if user has complete data in Supabase
          final response = await Supabase.instance.client
              .from('user_ai_readiness')
              .select('ai_ready, has_macro_data, has_fitness_data')
              .eq('user_id', currentUser.id)
              .single();

          hasSupabaseData = response['ai_ready'] == true;
          debugPrint(
              '[FitnessData] Supabase AI ready status: ${response['ai_ready']}');
          debugPrint(
              '[FitnessData] Has macro data: ${response['has_macro_data']}');
          debugPrint(
              '[FitnessData] Has fitness data: ${response['has_fitness_data']}');
        }
      } catch (e) {
        debugPrint('[FitnessData] Error checking Supabase AI readiness: $e');
        // Continue with local check if Supabase fails
      }

      // Local check as backup
      final localReady = profile.isBasicProfileComplete &&
          macroData['target_calories'] != null &&
          macroData['goal_type'] != null;

      debugPrint('[FitnessData] Local AI ready: $localReady');
      debugPrint('[FitnessData] Supabase AI ready: $hasSupabaseData');

      // Return true if either source indicates readiness
      return hasSupabaseData || localReady;
    } catch (e) {
      log('[FitnessData] Error checking AI readiness: $e');
      return false;
    }
  }

  /// Get user's fitness goals derived from macro data
  List<String> getFitnessGoalsFromMacroData(Map<String, dynamic> macroData) {
    final goals = <String>[];
    final goalType = macroData['goal_type']?.toString().toLowerCase();

    switch (goalType) {
      case 'lose':
        goals.addAll(['weight_loss', 'fat_loss', 'body_composition']);
        break;
      case 'gain':
        goals.addAll(['muscle_gain', 'strength', 'weight_gain']);
        break;
      case 'maintain':
        goals.addAll(['general_fitness', 'maintenance', 'health']);
        break;
      default:
        goals.add('general_fitness');
    }

    return goals;
  }

  // ================== DATA VALIDATION ==================

  /// Validate fitness profile data quality
  Map<String, dynamic> validateFitnessProfile(FitnessProfile profile) {
    final issues = <String>[];
    final recommendations = <String>[];

    if (profile.fitnessLevel.isEmpty) {
      issues.add('Missing fitness level');
      recommendations.add('Complete fitness level assessment');
    }

    if (profile.workoutLocation.isEmpty) {
      issues.add('Missing workout location preference');
      recommendations.add('Specify preferred workout location');
    }

    if (profile.availableEquipment.isEmpty &&
        profile.workoutLocation != 'outdoor') {
      issues.add('No equipment specified');
      recommendations.add('List available workout equipment');
    }

    if (profile.workoutsPerWeek < 1 || profile.workoutsPerWeek > 7) {
      issues.add('Invalid workout frequency');
      recommendations.add('Set realistic workout frequency (1-7 per week)');
    }

    if (profile.maxWorkoutDuration < 10 || profile.maxWorkoutDuration > 180) {
      issues.add('Invalid workout duration');
      recommendations.add('Set reasonable workout duration (10-180 minutes)');
    }

    return {
      'is_valid': issues.isEmpty,
      'issues': issues,
      'recommendations': recommendations,
      'completeness_score': _calculateCompletenessScore(profile),
    };
  }

  // ================== HELPER METHODS ==================

  Map<String, dynamic> _getDefaultMacroData() {
    return {
      'target_calories': 2000,
      'protein_g': 150,
      'carb_g': 200,
      'fat_g': 60,
      'goal_type': 'maintain',
      'current_weight_kg': 70,
      'goal_weight_kg': 70,
      'bmr': 1650,
      'tdee': 2200,
    };
  }

  double _calculateCompletenessScore(FitnessProfile profile) {
    int score = 0;
    int totalFields = 11;

    if (profile.fitnessLevel.isNotEmpty) score++;
    if (profile.yearsOfExperience > 0) score++;
    if (profile.previousExerciseTypes.isNotEmpty) score++;
    if (profile.workoutLocation.isNotEmpty) score++;
    if (profile.availableEquipment.isNotEmpty) score++;
    if (profile.workoutSpace.isNotEmpty) score++;
    if (profile.workoutsPerWeek > 0) score++;
    if (profile.maxWorkoutDuration > 0) score++;
    if (profile.preferredTimeOfDay.isNotEmpty) score++;
    if (profile.preferredDays.isNotEmpty) score++;
    if (profile.hasGymAccess) score++; // Bonus for gym access info

    return score / totalFields;
  }

  // ================== DATA UPDATES ==================

  /// Update fitness profile
  Future<bool> updateFitnessProfile(FitnessProfile profile) async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    bool success = false;

    if (currentUser != null) {
      try {
        // Save to Supabase first
        await _fitnessAIService.saveFitnessProfile(currentUser.id, profile);
        log('[FitnessData] Fitness profile saved to Supabase for user ${currentUser.id}');
        success = true;
      } catch (e) {
        log('[FitnessData] Error saving fitness profile to Supabase: $e');
        // Continue to save locally even if Supabase fails for now
      }
    } else {
      log('[FitnessData] User not logged in, cannot save profile to Supabase.');
    }

    // Always update local storage
    try {
      await _storage.put('fitness_profile', json.encode(profile.toJson()));
      log('[FitnessData] Fitness profile updated in local storage.');

      // Update in macro results (legacy, consider removing if fitness_profile is primary local source)
      final macroResultsJson = await _storage.get('macro_results');
      if (macroResultsJson != null) {
        final macroResults = json.decode(macroResultsJson);
        macroResults['fitness_profile'] = profile.toJson();
        await _storage.put('macro_results', json.encode(macroResults));
      }
      success = true; // Local save was successful
    } catch (e) {
      log('[FitnessData] Error updating fitness profile in local storage: $e');
      if (currentUser == null)
        return false; // If Supabase also failed (no user)
    }
    return success;
  }

  /// Record workout completion for performance tracking
  Future<void> recordWorkoutCompletion({
    required String workoutType,
    required int actualDuration,
    required DateTime completedAt,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final completion = {
        'workout_type': workoutType,
        'actual_duration': actualDuration,
        'completed_at': completedAt.toIso8601String(),
        'date': completedAt.toIso8601String().split('T')[0], // YYYY-MM-DD
        'id': completedAt.millisecondsSinceEpoch.toString(),
        ...?additionalData,
      };

      final completionsJson = await _storage.get('workout_completions');
      List<Map<String, dynamic>> completions = [];

      if (completionsJson != null) {
        final List<dynamic> existing = json.decode(completionsJson);
        completions = existing.cast<Map<String, dynamic>>();
      }

      completions.add(completion);

      // Keep only last 100 completions
      if (completions.length > 100) {
        completions.removeRange(0, completions.length - 100);
      }

      await _storage.put('workout_completions', json.encode(completions));
      log('[FitnessData] Workout completion recorded');
    } catch (e) {
      log('[FitnessData] Error recording workout completion: $e');
    }
  }
}
