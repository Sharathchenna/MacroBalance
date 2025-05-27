import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:uuid/uuid.dart';
import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../models/user_preferences.dart';
import 'supabase_service.dart';
import 'storage_service.dart';

class WorkoutPlanningService {
  static final WorkoutPlanningService _instance =
      WorkoutPlanningService._internal();

  factory WorkoutPlanningService() => _instance;

  WorkoutPlanningService._internal()
      : _supabaseService = SupabaseService(),
        _storageService = StorageService(),
        _uuid = const Uuid(),
        _apiKey = null,
        _model = null;

  final SupabaseService _supabaseService;
  final StorageService _storageService;
  final Uuid _uuid;
  String? _apiKey;
  GenerativeModel? _model;

  // Cache for exercises and workout plans
  final Map<String, Exercise> _exerciseCache = {};
  final Map<String, WorkoutRoutine> _routineCache = {};
  final Map<String, WorkoutPlan> _planCache = {};

  // Exercise Management
  Future<List<Exercise>> getExercises({
    String? searchQuery,
    List<String>? muscleGroups,
    List<String>? equipment,
    String? difficulty,
    String? type,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      var query = _supabaseService.supabaseClient.from('exercises').select();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$searchQuery%');
      }

      if (muscleGroups != null && muscleGroups.isNotEmpty) {
        query = query.overlaps('primary_muscles', muscleGroups);
      }

      if (equipment != null && equipment.isNotEmpty) {
        query = query.overlaps('equipment', equipment);
      }

      if (difficulty != null) {
        query = query.eq('difficulty', difficulty);
      }

      if (type != null) {
        query = query.eq('type', type);
      }

      final response = await query
          .order('name')
          .limit(limit)
          .range(offset, offset + limit - 1);

      final exercises =
          (response as List).map((data) => Exercise.fromJson(data)).toList();

      // Update cache
      for (var exercise in exercises) {
        _exerciseCache[exercise.id] = exercise;
      }

      return exercises;
    } catch (e) {
      debugPrint('Error fetching exercises: $e');
      return [];
    }
  }

  Future<Exercise?> getExerciseById(String id) async {
    // Check cache first
    if (_exerciseCache.containsKey(id)) {
      return _exerciseCache[id];
    }

    try {
      final response = await _supabaseService.supabaseClient
          .from('exercises')
          .select()
          .eq('id', id)
          .single();

      if (response != null) {
        final exercise = Exercise.fromJson(response);
        _exerciseCache[id] = exercise;
        return exercise;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching exercise $id: $e');
      return null;
    }
  }

  Future<Exercise?> createExercise(Exercise exercise) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('exercises')
          .insert(exercise.toJson())
          .select()
          .single();

      if (response != null) {
        final createdExercise = Exercise.fromJson(response);
        _exerciseCache[createdExercise.id] = createdExercise;
        return createdExercise;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating exercise: $e');
      return null;
    }
  }

  Future<Exercise?> updateExercise(Exercise exercise) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('exercises')
          .update(exercise.toJson())
          .eq('id', exercise.id)
          .select()
          .single();

      if (response != null) {
        final updatedExercise = Exercise.fromJson(response);
        _exerciseCache[exercise.id] = updatedExercise;
        return updatedExercise;
      }
      return null;
    } catch (e) {
      debugPrint('Error updating exercise: $e');
      return null;
    }
  }

  Future<bool> deleteExercise(String id) async {
    try {
      await _supabaseService.supabaseClient
          .from('exercises')
          .delete()
          .eq('id', id);

      _exerciseCache.remove(id);
      return true;
    } catch (e) {
      debugPrint('Error deleting exercise: $e');
      return false;
    }
  }

  // Workout Routine Management
  Future<List<WorkoutRoutine>> getWorkoutRoutines({
    String? searchQuery,
    String? difficulty,
    List<String>? targetMuscles,
    List<String>? equipment,
    bool? isCustom,
    String? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var query =
          _supabaseService.supabaseClient.from('workout_routines').select('*');

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$searchQuery%');
      }

      if (difficulty != null) {
        query = query.eq('difficulty', difficulty);
      }

      if (targetMuscles != null && targetMuscles.isNotEmpty) {
        query = query.overlaps('target_muscles', targetMuscles);
      }

      if (equipment != null && equipment.isNotEmpty) {
        query = query.overlaps('required_equipment', equipment);
      }

      if (isCustom != null) {
        query = query.eq('is_custom', isCustom);
      }

      if (userId != null) {
        query = query.eq('created_by', userId);
      }

      final response = await query
          .order('name')
          .limit(limit)
          .range(offset, offset + limit - 1);

      if (response == null) return [];

      final List<WorkoutRoutine> routines = [];
      for (final data in response) {
        try {
          final routine = WorkoutRoutine.fromJson(data);
          routines.add(routine);
          _routineCache[routine.id] = routine;
        } catch (e) {
          debugPrint('Error parsing workout routine: $e');
          continue;
        }
      }

      return routines;
    } catch (e) {
      debugPrint('Error fetching workout routines: $e');
      return [];
    }
  }

  Future<WorkoutRoutine?> getWorkoutRoutineById(String id) async {
    // Check cache first
    if (_routineCache.containsKey(id)) {
      return _routineCache[id];
    }

    try {
      final response = await _supabaseService.supabaseClient
          .from('workout_routines')
          .select()
          .eq('id', id)
          .single();

      if (response != null) {
        final routine = WorkoutRoutine.fromJson(response);

        // Load exercise details for each exercise in the routine
        final updatedExercises = <WorkoutExercise>[];
        for (final workoutExercise in routine.exercises) {
          final exercise = await getExerciseById(workoutExercise.exerciseId);
          if (exercise != null) {
            updatedExercises.add(workoutExercise.copyWith(exercise: exercise));
          } else {
            updatedExercises.add(workoutExercise);
          }
        }

        final updatedRoutine = routine.copyWith(exercises: updatedExercises);
        _routineCache[id] = updatedRoutine;
        return updatedRoutine;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching workout routine $id: $e');
      return null;
    }
  }

  Future<WorkoutRoutine?> createWorkoutRoutine(WorkoutRoutine routine) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('workout_routines')
          .insert(routine.toJson())
          .select()
          .single();

      if (response != null) {
        final createdRoutine = WorkoutRoutine.fromJson(response);
        _routineCache[createdRoutine.id] = createdRoutine;
        return createdRoutine;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating workout routine: $e');
      return null;
    }
  }

  Future<WorkoutRoutine?> updateWorkoutRoutine(WorkoutRoutine routine) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('workout_routines')
          .update(routine.toJson())
          .eq('id', routine.id)
          .select()
          .single();

      if (response != null) {
        final updatedRoutine = WorkoutRoutine.fromJson(response);
        _routineCache[routine.id] = updatedRoutine;
        return updatedRoutine;
      }
      return null;
    } catch (e) {
      debugPrint('Error updating workout routine: $e');
      return null;
    }
  }

  Future<bool> deleteWorkoutRoutine(String id) async {
    try {
      await _supabaseService.supabaseClient
          .from('workout_routines')
          .delete()
          .eq('id', id);

      _routineCache.remove(id);
      return true;
    } catch (e) {
      debugPrint('Error deleting workout routine: $e');
      return false;
    }
  }

  // Workout Plan Management
  Future<List<WorkoutPlan>> getWorkoutPlans({
    String? searchQuery,
    String? difficulty,
    String? goal,
    List<String>? equipment,
    bool? isCustom,
    String? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var query =
          _supabaseService.supabaseClient.from('workout_plans').select();

      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.ilike('name', '%$searchQuery%');
      }

      if (difficulty != null) {
        query = query.eq('difficulty', difficulty);
      }

      if (goal != null) {
        query = query.eq('goal', goal);
      }

      if (equipment != null && equipment.isNotEmpty) {
        query = query.overlaps('required_equipment', equipment);
      }

      if (isCustom != null) {
        query = query.eq('is_custom', isCustom);
      }

      if (userId != null) {
        query = query.eq('created_by', userId);
      }

      final response = await query
          .order('name')
          .limit(limit)
          .range(offset, offset + limit - 1);

      final plans =
          (response as List).map((data) => WorkoutPlan.fromJson(data)).toList();

      // Update cache
      for (var plan in plans) {
        _planCache[plan.id] = plan;
      }

      return plans;
    } catch (e) {
      debugPrint('Error fetching workout plans: $e');
      return [];
    }
  }

  Future<WorkoutPlan?> getWorkoutPlanById(String id) async {
    // Check cache first
    if (_planCache.containsKey(id)) {
      return _planCache[id];
    }

    try {
      final response = await _supabaseService.supabaseClient
          .from('workout_plans')
          .select()
          .eq('id', id)
          .single();

      if (response != null) {
        final plan = WorkoutPlan.fromJson(response);
        _planCache[id] = plan;
        return plan;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching workout plan $id: $e');
      return null;
    }
  }

  Future<WorkoutPlan?> createWorkoutPlan(WorkoutPlan plan) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('workout_plans')
          .insert(plan.toJson())
          .select()
          .single();

      if (response != null) {
        final createdPlan = WorkoutPlan.fromJson(response);
        _planCache[createdPlan.id] = createdPlan;
        return createdPlan;
      }
      return null;
    } catch (e) {
      debugPrint('Error creating workout plan: $e');
      return null;
    }
  }

  Future<WorkoutPlan?> updateWorkoutPlan(WorkoutPlan plan) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('workout_plans')
          .update(plan.toJson())
          .eq('id', plan.id)
          .select()
          .single();

      if (response != null) {
        final updatedPlan = WorkoutPlan.fromJson(response);
        _planCache[plan.id] = updatedPlan;
        return updatedPlan;
      }
      return null;
    } catch (e) {
      debugPrint('Error updating workout plan: $e');
      return null;
    }
  }

  Future<bool> deleteWorkoutPlan(String id) async {
    try {
      await _supabaseService.supabaseClient
          .from('workout_plans')
          .delete()
          .eq('id', id);

      _planCache.remove(id);
      return true;
    } catch (e) {
      debugPrint('Error deleting workout plan: $e');
      return false;
    }
  }

  // Workout Logging
  Future<WorkoutLog?> startWorkout(String userId, String? routineId) async {
    try {
      WorkoutRoutine? routine;
      if (routineId != null) {
        routine = await getWorkoutRoutineById(routineId);
      }

      final workoutLog = WorkoutLog(
        userId: userId,
        routineId: routineId,
        routine: routine,
        startTime: DateTime.now(),
        completedExercises: routine?.exercises ?? [],
      );

      final response = await _supabaseService.supabaseClient
          .from('workout_logs')
          .insert(workoutLog.toJson())
          .select()
          .single();

      if (response != null) {
        return WorkoutLog.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error starting workout: $e');
      return null;
    }
  }

  Future<WorkoutLog?> updateWorkoutLog(WorkoutLog log) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('workout_logs')
          .update(log.toJson())
          .eq('id', log.id)
          .select()
          .single();

      if (response != null) {
        return WorkoutLog.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error updating workout log: $e');
      return null;
    }
  }

  Future<WorkoutLog?> completeWorkout(String logId) async {
    try {
      final now = DateTime.now();
      final response = await _supabaseService.supabaseClient
          .from('workout_logs')
          .update({
            'end_time': now.toIso8601String(),
            'is_completed': true,
            'actual_duration_minutes': await _calculateDuration(logId, now),
          })
          .eq('id', logId)
          .select()
          .single();

      if (response != null) {
        return WorkoutLog.fromJson(response);
      }
      return null;
    } catch (e) {
      debugPrint('Error completing workout: $e');
      return null;
    }
  }

  Future<int> _calculateDuration(String logId, DateTime endTime) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('workout_logs')
          .select('start_time')
          .eq('id', logId)
          .single();

      if (response != null) {
        final startTime = DateTime.parse(response['start_time']);
        return endTime.difference(startTime).inMinutes;
      }
      return 0;
    } catch (e) {
      debugPrint('Error calculating workout duration: $e');
      return 0;
    }
  }

  Future<List<WorkoutLog>> getUserWorkoutHistory(String userId,
      {int limit = 20, int offset = 0}) async {
    try {
      final response = await _supabaseService.supabaseClient
          .from('workout_logs')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: false)
          .limit(limit)
          .range(offset, offset + limit - 1);

      return (response as List)
          .map((data) => WorkoutLog.fromJson(data))
          .toList();
    } catch (e) {
      debugPrint('Error fetching workout history: $e');
      return [];
    }
  }

  // Workout Suggestions
  Future<List<WorkoutRoutine>> suggestWorkoutRoutines(
      UserPreferences userPreferences) async {
    try {
      final equipment = userPreferences.equipment.available;
      final fitnessGoals = userPreferences.fitnessGoals;

      String difficulty = 'beginner';
      if (fitnessGoals.primary == 'muscle_gain' ||
          fitnessGoals.secondary.contains('strength')) {
        difficulty = 'intermediate';
      }

      return getWorkoutRoutines(
        equipment: equipment,
        difficulty: difficulty,
        isCustom: false,
        limit: 5,
      );
    } catch (e) {
      debugPrint('Error suggesting workout routines: $e');
      return [];
    }
  }

  Future<WorkoutPlan?> suggestWorkoutPlan(
      UserPreferences userPreferences) async {
    try {
      final equipment = userPreferences.equipment.available;
      final fitnessGoals = userPreferences.fitnessGoals;

      String goal = 'general_fitness';
      if (fitnessGoals.primary == 'weight_loss') {
        goal = 'weight_loss';
      } else if (fitnessGoals.primary == 'muscle_gain') {
        goal = 'muscle_gain';
      }

      String difficulty = 'beginner';
      if (fitnessGoals.workoutsPerWeek >= 4) {
        difficulty = 'intermediate';
      }

      final plans = await getWorkoutPlans(
        goal: goal,
        difficulty: difficulty,
        equipment: equipment,
        isCustom: false,
        limit: 1,
      );

      return plans.isNotEmpty ? plans.first : null;
    } catch (e) {
      debugPrint('Error suggesting workout plan: $e');
      return null;
    }
  }

  // AI-powered workout generation
  Future<WorkoutRoutine?> generateWorkoutRoutine({
    required UserPreferences userPreferences,
    required String name,
    required String description,
    required List<String> targetMuscles,
    required int durationMinutes,
  }) async {
    if (_model == null) {
      throw Exception('API key not provided for workout generation');
    }

    try {
      final equipment = userPreferences.equipment.available;
      final difficulty = userPreferences.fitnessGoals.primary == 'muscle_gain'
          ? 'intermediate'
          : 'beginner';

      final prompt = '''
Generate a workout routine with the following specifications:
- Name: $name
- Description: $description
- Target muscles: ${targetMuscles.join(', ')}
- Duration: $durationMinutes minutes
- Difficulty: $difficulty
- Available equipment: ${equipment.join(', ')}

For each exercise, provide:
1. Exercise name
2. Number of sets
3. Number of reps or duration
4. Rest period between sets

Format the response as a JSON object with an array of exercises.
''';

      final content = [Content.text(prompt)];
      final response = await _model!.generateContent(content);

      final jsonStr = response.text?.trim() ?? '';

      // Extract JSON from the response if needed
      final jsonMatch = RegExp(r'\{.*\}', dotAll: true).firstMatch(jsonStr);
      final jsonData = jsonMatch != null ? jsonMatch.group(0) : jsonStr;

      if (jsonData == null) {
        throw Exception('Failed to parse generated workout');
      }

      final routineData = json.decode(jsonData);
      final exercises = routineData['exercises'] as List<dynamic>;

      // Find or create exercises
      final workoutExercises = <WorkoutExercise>[];

      for (final exerciseData in exercises) {
        final exerciseName = exerciseData['name'] as String;

        // Search for existing exercise
        final existingExercises = await getExercises(
          searchQuery: exerciseName,
          limit: 1,
        );

        String exerciseId;
        Exercise? exercise;

        if (existingExercises.isNotEmpty) {
          exercise = existingExercises.first;
          exerciseId = exercise.id;
        } else {
          // Create a new exercise if not found
          final newExercise = Exercise(
            name: exerciseName,
            description:
                exerciseData['description'] ?? 'No description available',
            primaryMuscles: targetMuscles,
            equipment: equipment,
            type: 'strength',
            difficulty: difficulty,
            instructions: List<String>.from(exerciseData['instructions'] ?? []),
            isCompound: targetMuscles.length > 1,
            defaultSets: exerciseData['sets'] ?? 3,
            defaultReps: exerciseData['reps'],
            defaultDurationSeconds: exerciseData['duration_seconds'],
          );

          final createdExercise = await createExercise(newExercise);
          if (createdExercise != null) {
            exercise = createdExercise;
            exerciseId = createdExercise.id;
          } else {
            continue; // Skip if exercise creation failed
          }
        }

        // Create workout sets
        final sets = <WorkoutSet>[];
        final numSets = exerciseData['sets'] ?? 3;
        final reps = exerciseData['reps'] ?? 10;
        final durationSeconds = exerciseData['duration_seconds'];

        for (int i = 0; i < numSets; i++) {
          sets.add(WorkoutSet(
            reps: reps,
            durationSeconds: durationSeconds,
          ));
        }

        // Add exercise to workout
        workoutExercises.add(WorkoutExercise(
          exerciseId: exerciseId,
          exercise: exercise,
          sets: sets,
          restSeconds: exerciseData['rest_seconds'] ?? 60,
        ));
      }

      // Create the workout routine
      final workoutRoutine = WorkoutRoutine(
        name: name,
        description: description,
        exercises: workoutExercises,
        estimatedDurationMinutes: durationMinutes,
        difficulty: difficulty,
        targetMuscles: targetMuscles,
        requiredEquipment: equipment,
        isCustom: true,
        createdBy: userPreferences.userId,
      );

      return await createWorkoutRoutine(workoutRoutine);
    } catch (e) {
      debugPrint('Error generating workout routine: $e');
      return null;
    }
  }

  // Clear cache
  void clearCache() {
    _exerciseCache.clear();
    _routineCache.clear();
    _planCache.clear();
  }
}
