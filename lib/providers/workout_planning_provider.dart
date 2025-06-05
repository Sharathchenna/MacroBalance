import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import '../models/exercise.dart';
import '../models/workout_plan.dart';
import '../models/user_preferences.dart';
import '../services/workout_planning_service.dart';

class WorkoutPlanningProvider with ChangeNotifier {
  final WorkoutPlanningService _workoutPlanningService;

  // State variables
  List<Exercise> _exercises = [];
  List<WorkoutRoutine> _workoutRoutines = [];
  List<WorkoutPlan> _workoutPlans = [];
  List<WorkoutLog> _workoutLogs = [];
  WorkoutLog? _currentWorkout;
  Map<String, dynamic> _workoutProgress = {};
  bool _isLoading = false;
  String? _error;

  // Getters
  List<Exercise> get exercises => _exercises;
  List<WorkoutRoutine> get workoutRoutines => _workoutRoutines;
  List<WorkoutPlan> get workoutPlans => _workoutPlans;
  List<WorkoutLog> get workoutLogs => _workoutLogs;
  WorkoutLog? get currentWorkout => _currentWorkout;
  Map<String, dynamic> get workoutProgress => _workoutProgress;
  bool get isLoading => _isLoading;
  String? get error => _error;

  WorkoutPlanningProvider({WorkoutPlanningService? workoutPlanningService})
      : _workoutPlanningService =
            workoutPlanningService ?? WorkoutPlanningService();

  // Safe notification method that avoids calling during build
  void _safeNotifyListeners() {
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // We're in the build phase, defer the notification
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } else {
      // Safe to notify immediately
      notifyListeners();
    }
  }

  // Set loading state
  void _setLoading(bool loading) {
    _isLoading = loading;
    _safeNotifyListeners();
  }

  // Set error state
  void _setError(String? error) {
    _error = error;
    _safeNotifyListeners();
  }

  // Clear error
  void clearError() {
    _error = null;
    _safeNotifyListeners();
  }

  // Exercise Management
  Future<void> loadExercises({
    List<String>? targetMuscles,
    List<String>? equipment,
    String? type,
    String? difficulty,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      _exercises = await _workoutPlanningService.getExercises(
        muscleGroups: targetMuscles,
        equipment: equipment,
        type: type,
        difficulty: difficulty,
      );

      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to load exercises: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<Exercise?> getExerciseById(String exerciseId) async {
    try {
      return await _workoutPlanningService.getExerciseById(exerciseId);
    } catch (e) {
      _setError('Failed to load exercise: $e');
      return null;
    }
  }

  Future<void> saveExercise(Exercise exercise) async {
    try {
      _setLoading(true);
      _setError(null);

      final savedExercise =
          await _workoutPlanningService.createExercise(exercise);

      // Update local exercises list
      if (savedExercise != null) {
        final index = _exercises.indexWhere((e) => e.id == savedExercise.id);
        if (index != -1) {
          _exercises[index] = savedExercise;
        } else {
          _exercises.add(savedExercise);
        }
      }

      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to save exercise: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> searchExercises(String query) async {
    try {
      _setLoading(true);
      _setError(null);

      _exercises = await _workoutPlanningService.getExercises(
        searchQuery: query,
      );
      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to search exercises: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Workout Routine Management
  Future<void> loadWorkoutRoutines({
    String? difficulty,
    List<String>? targetMuscles,
    List<String>? equipment,
    bool? isCustom,
    String? userId,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      _workoutRoutines = await _workoutPlanningService.getWorkoutRoutines(
        difficulty: difficulty,
        targetMuscles: targetMuscles,
        equipment: equipment,
        isCustom: isCustom,
        userId: userId,
      );

      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to load workout routines: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<WorkoutRoutine?> getWorkoutRoutineById(String routineId) async {
    try {
      final routine =
          await _workoutPlanningService.getWorkoutRoutineById(routineId);
      return routine;
    } catch (e) {
      _setError('Failed to load workout routine: $e');
      return null;
    }
  }

  Future<bool> saveWorkoutRoutine(WorkoutRoutine routine) async {
    try {
      _setLoading(true);
      _setError(null);

      final savedRoutine =
          await _workoutPlanningService.createWorkoutRoutine(routine);

      if (savedRoutine != null) {
        // Update local routines list
        final index =
            _workoutRoutines.indexWhere((r) => r.id == savedRoutine.id);
        if (index != -1) {
          _workoutRoutines[index] = savedRoutine;
        } else {
          _workoutRoutines.add(savedRoutine);
        }
        _safeNotifyListeners();
        return true; // Indicate success
      } else {
        _setError('Failed to save workout routine. Please try again.');
        _safeNotifyListeners();
        return false; // Indicate failure
      }
    } catch (e) {
      _setError('Failed to save workout routine: $e');
      _safeNotifyListeners();
      return false; // Indicate failure
    } finally {
      _setLoading(false);
    }
  }

  Future<void> deleteWorkoutRoutine(String routineId) async {
    try {
      _setLoading(true);
      _setError(null);

      await _workoutPlanningService.deleteWorkoutRoutine(routineId);

      // Remove from local list
      _workoutRoutines.removeWhere((r) => r.id == routineId);

      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to delete workout routine: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createCustomWorkoutRoutine({
    required String userId,
    required String name,
    required String description,
    required List<String> exerciseIds,
    required Map<String, List<Map<String, dynamic>>> exerciseSets,
    required List<String> targetMuscles,
    required List<String> equipment,
    int estimatedDurationMinutes = 45,
    String difficulty = 'intermediate',
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      final exercises = await _buildWorkoutExercises(exerciseIds, exerciseSets);

      final routine = WorkoutRoutine(
        name: name,
        description: description,
        exercises: exercises,
        estimatedDurationMinutes: estimatedDurationMinutes,
        difficulty: difficulty,
        targetMuscles: targetMuscles,
        requiredEquipment: equipment,
        isCustom: true,
        createdBy: userId,
      );

      final createdRoutine =
          await _workoutPlanningService.createWorkoutRoutine(routine);
      if (createdRoutine != null) {
        _workoutRoutines.add(createdRoutine);
      }

      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to create custom workout routine: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<List<WorkoutExercise>> _buildWorkoutExercises(
    List<String> exerciseIds,
    Map<String, List<Map<String, dynamic>>> exerciseSets,
  ) async {
    final exercises = <WorkoutExercise>[];

    for (final exerciseId in exerciseIds) {
      final exercise = await getExerciseById(exerciseId);
      if (exercise != null) {
        final sets = exerciseSets[exerciseId]
                ?.map((setData) => WorkoutSet(
                      reps: setData['reps'] as int,
                      weight: setData['weight'] as double?,
                      durationSeconds: setData['duration_seconds'] as int?,
                    ))
                .toList() ??
            [];

        exercises.add(WorkoutExercise(
          exerciseId: exerciseId,
          exercise: exercise,
          sets: sets,
        ));
      }
    }

    return exercises;
  }

  // Workout Plan Management
  Future<void> loadWorkoutPlans({
    String? goal,
    String? difficulty,
    List<String>? equipment,
    bool? isCustom,
    String? userId,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      _workoutPlans = await _workoutPlanningService.getWorkoutPlans(
        goal: goal,
        difficulty: difficulty,
        equipment: equipment,
        isCustom: isCustom,
        userId: userId,
      );

      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to load workout plans: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<WorkoutPlan?> getWorkoutPlanById(String planId) async {
    try {
      final plan = await _workoutPlanningService.getWorkoutPlanById(planId);
      return plan;
    } catch (e) {
      _setError('Failed to load workout plan: $e');
      return null;
    }
  }

  Future<void> saveWorkoutPlan(WorkoutPlan plan) async {
    try {
      _setLoading(true);
      _setError(null);

      final savedPlan = await _workoutPlanningService.createWorkoutPlan(plan);

      // Update local plans list
      if (savedPlan != null) {
        final index = _workoutPlans.indexWhere((p) => p.id == savedPlan.id);
        if (index != -1) {
          _workoutPlans[index] = savedPlan;
        } else {
          _workoutPlans.add(savedPlan);
        }
      }

      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to save workout plan: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Workout Suggestions
  Future<void> loadWorkoutSuggestions(UserPreferences userPreferences) async {
    try {
      _setLoading(true);
      _setError(null);

      // Load routines based on user preferences
      String difficulty = userPreferences.fitnessGoals.workoutsPerWeek >= 4
          ? 'intermediate'
          : 'beginner';

      await loadWorkoutRoutines(
        difficulty: difficulty,
        equipment: userPreferences.equipment.available,
      );

      // Load plans based on user preferences
      await loadWorkoutPlans(
        difficulty: difficulty,
        equipment: userPreferences.equipment.available,
        goal: userPreferences.fitnessGoals.primary,
      );

      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to load workout suggestions: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Workout Logging
  Future<void> loadWorkoutLogs({
    required String userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      _workoutLogs = await _workoutPlanningService.getUserWorkoutHistory(
        userId,
      );

      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to load workout logs: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> startWorkout({
    required String userId,
    required String routineId,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      _currentWorkout =
          await _workoutPlanningService.startWorkout(userId, routineId);

      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to start workout: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> updateCurrentWorkout(WorkoutLog workoutLog) async {
    try {
      _setLoading(true);
      _setError(null);

      _currentWorkout =
          await _workoutPlanningService.updateWorkoutLog(workoutLog);

      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to update workout: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> completeWorkout({
    required String workoutLogId,
    required List<WorkoutExercise> completedExercises,
    String? notes,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      _currentWorkout =
          await _workoutPlanningService.completeWorkout(workoutLogId);

      // Add to workout logs
      if (_currentWorkout != null) {
        _workoutLogs.insert(0, _currentWorkout!);
      }

      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to complete workout: $e');
    } finally {
      _setLoading(false);
    }
  }

  void cancelCurrentWorkout() {
    _currentWorkout = null;
    _safeNotifyListeners();
  }

  // Progress Tracking
  Future<void> loadWorkoutProgress({
    required String userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      _setLoading(true);
      _setError(null);

      // Calculate progress from workout logs instead of using a service method
      final logs = await _workoutPlanningService.getUserWorkoutHistory(userId);
      final filteredLogs = logs.where((log) =>
          log.startTime.isAfter(startDate) && log.startTime.isBefore(endDate));

      _workoutProgress = {
        'total_workouts': filteredLogs.length,
        'completed_workouts':
            filteredLogs.where((log) => log.isCompleted).length,
        'total_volume':
            filteredLogs.fold(0.0, (sum, log) => sum + log.totalVolume),
        'total_duration': filteredLogs.fold(
            0, (sum, log) => sum + (log.actualDurationMinutes ?? 0)),
      };

      _safeNotifyListeners();
    } catch (e) {
      _setError('Failed to load workout progress: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Local operations
  void updateCurrentWorkoutExercise(WorkoutExercise exercise) {
    if (_currentWorkout != null) {
      final exercises =
          List<WorkoutExercise>.from(_currentWorkout!.completedExercises);
      final index = exercises.indexWhere((e) => e.id == exercise.id);

      if (index != -1) {
        exercises[index] = exercise;
      } else {
        exercises.add(exercise);
      }

      _currentWorkout = _currentWorkout!.copyWith(
        completedExercises: exercises,
      );

      _safeNotifyListeners();
    }
  }

  void addSetToCurrentExercise(String exerciseId, WorkoutSet set) {
    if (_currentWorkout != null) {
      final exercises =
          List<WorkoutExercise>.from(_currentWorkout!.completedExercises);
      final exerciseIndex =
          exercises.indexWhere((e) => e.exerciseId == exerciseId);

      if (exerciseIndex != -1) {
        final exercise = exercises[exerciseIndex];
        final updatedSets = List<WorkoutSet>.from(exercise.sets)..add(set);
        exercises[exerciseIndex] = exercise.copyWith(sets: updatedSets);

        _currentWorkout = _currentWorkout!.copyWith(
          completedExercises: exercises,
        );

        _safeNotifyListeners();
      }
    }
  }

  void updateSetInCurrentExercise(String exerciseId, WorkoutSet set) {
    if (_currentWorkout != null) {
      final exercises =
          List<WorkoutExercise>.from(_currentWorkout!.completedExercises);
      final exerciseIndex =
          exercises.indexWhere((e) => e.exerciseId == exerciseId);

      if (exerciseIndex != -1) {
        final exercise = exercises[exerciseIndex];
        final sets = List<WorkoutSet>.from(exercise.sets);
        final setIndex = sets.indexWhere((s) => s.id == set.id);

        if (setIndex != -1) {
          sets[setIndex] = set;
          exercises[exerciseIndex] = exercise.copyWith(sets: sets);

          _currentWorkout = _currentWorkout!.copyWith(
            completedExercises: exercises,
          );

          _safeNotifyListeners();
        }
      }
    }
  }

  // Filter exercises by equipment
  List<Exercise> getExercisesByEquipment(List<String> availableEquipment) {
    return _exercises
        .where((exercise) =>
            exercise.equipment.any((eq) => availableEquipment.contains(eq)))
        .toList();
  }

  // Filter exercises by muscle group
  List<Exercise> getExercisesByMuscleGroup(String muscleGroup) {
    return _exercises
        .where((exercise) =>
            exercise.primaryMuscles.contains(muscleGroup) ||
            exercise.secondaryMuscles.contains(muscleGroup))
        .toList();
  }

  // Get workout statistics
  Map<String, dynamic> get workoutStatistics {
    if (_workoutLogs.isEmpty) {
      return {
        'total_workouts': 0,
        'total_volume': 0.0,
        'average_duration': 0.0,
        'this_week_workouts': 0,
        'this_month_workouts': 0,
      };
    }

    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    final completedWorkouts =
        _workoutLogs.where((log) => log.isCompleted).toList();
    final thisWeekWorkouts = completedWorkouts
        .where((log) => log.startTime.isAfter(weekStart))
        .length;
    final thisMonthWorkouts = completedWorkouts
        .where((log) => log.startTime.isAfter(monthStart))
        .length;

    final totalVolume =
        completedWorkouts.fold(0.0, (sum, log) => sum + log.totalVolume);
    final totalDuration = completedWorkouts.fold(
        0, (sum, log) => sum + (log.actualDurationMinutes ?? 0));
    final averageDuration = completedWorkouts.isNotEmpty
        ? totalDuration / completedWorkouts.length
        : 0.0;

    return {
      'total_workouts': completedWorkouts.length,
      'total_volume': totalVolume,
      'average_duration': averageDuration,
      'this_week_workouts': thisWeekWorkouts,
      'this_month_workouts': thisMonthWorkouts,
    };
  }

  // Check if currently in a workout
  bool get isWorkoutInProgress =>
      _currentWorkout != null && !_currentWorkout!.isCompleted;

  // Get current workout duration
  Duration? get currentWorkoutDuration {
    if (_currentWorkout != null) {
      return DateTime.now().difference(_currentWorkout!.startTime);
    }
    return null;
  }

  // Clear all data
  void clearData() {
    _exercises.clear();
    _workoutRoutines.clear();
    _workoutPlans.clear();
    _workoutLogs.clear();
    _currentWorkout = null;
    _workoutProgress.clear();
    _error = null;
    _isLoading = false;
    _safeNotifyListeners();
  }
}
