import '../models/workout_plan.dart';
import '../models/exercise.dart';
import '../data/exercise_database.dart';

class WorkoutCaloriesService {
  /// Calculate calories burned for a specific workout log
  static double calculateWorkoutCalories(WorkoutLog workoutLog,
      {double? userWeightKg}) {
    if (!workoutLog.isCompleted) return 0.0;

    double totalCaloriesBurned = 0.0;

    for (final workoutExercise in workoutLog.completedExercises) {
      final exercise = workoutExercise.exercise;
      if (exercise?.estimatedCaloriesBurnedPerMinute != null) {
        // Calculate duration for this exercise based on sets and rest time
        final exerciseDurationMinutes =
            _calculateExerciseDuration(workoutExercise);

        // Apply weight factor if user weight is provided
        double caloriesPerMinute = exercise!.estimatedCaloriesBurnedPerMinute!;
        if (userWeightKg != null) {
          // Adjust calories based on user weight (base calculation assumes 70kg person)
          caloriesPerMinute = caloriesPerMinute * (userWeightKg / 70.0);
        }

        totalCaloriesBurned += caloriesPerMinute * exerciseDurationMinutes;
      }
    }

    return totalCaloriesBurned;
  }

  /// Calculate calories burned for a single exercise during execution
  static double calculateExerciseCalories(
      WorkoutExercise workoutExercise, int durationMinutes,
      {double? userWeightKg}) {
    final exercise = workoutExercise.exercise;
    if (exercise?.estimatedCaloriesBurnedPerMinute == null) return 0.0;

    double caloriesPerMinute = exercise!.estimatedCaloriesBurnedPerMinute!;

    // Apply weight factor if user weight is provided
    if (userWeightKg != null) {
      caloriesPerMinute = caloriesPerMinute * (userWeightKg / 70.0);
    }

    return caloriesPerMinute * durationMinutes;
  }

  /// Calculate estimated calories for a workout routine (before execution)
  static double estimateRoutineCalories(WorkoutRoutine routine,
      {double? userWeightKg}) {
    double totalEstimatedCalories = 0.0;

    for (final workoutExercise in routine.exercises) {
      final exercise = workoutExercise.exercise ??
          _findExerciseById(workoutExercise.exerciseId);
      if (exercise?.estimatedCaloriesBurnedPerMinute != null) {
        // Estimate duration based on sets, reps, and rest time
        final estimatedDurationMinutes =
            _estimateExerciseDuration(workoutExercise);

        double caloriesPerMinute = exercise!.estimatedCaloriesBurnedPerMinute!;
        if (userWeightKg != null) {
          caloriesPerMinute = caloriesPerMinute * (userWeightKg / 70.0);
        }

        totalEstimatedCalories += caloriesPerMinute * estimatedDurationMinutes;
      }
    }

    return totalEstimatedCalories;
  }

  /// Calculate calories burned for today's workouts
  static double calculateTodaysWorkoutCalories(List<WorkoutLog> workoutLogs,
      {double? userWeightKg}) {
    final today = DateTime.now();
    final todaysWorkouts = workoutLogs.where((log) {
      return log.isCompleted &&
          log.startTime.year == today.year &&
          log.startTime.month == today.month &&
          log.startTime.day == today.day;
    }).toList();

    double totalCalories = 0.0;
    for (final workout in todaysWorkouts) {
      totalCalories +=
          calculateWorkoutCalories(workout, userWeightKg: userWeightKg);
    }

    return totalCalories;
  }

  /// Calculate calories burned for a specific date
  static double calculateWorkoutCaloriesForDate(
      List<WorkoutLog> workoutLogs, DateTime date,
      {double? userWeightKg}) {
    final dateWorkouts = workoutLogs.where((log) {
      return log.isCompleted &&
          log.startTime.year == date.year &&
          log.startTime.month == date.month &&
          log.startTime.day == date.day;
    }).toList();

    double totalCalories = 0.0;
    for (final workout in dateWorkouts) {
      totalCalories +=
          calculateWorkoutCalories(workout, userWeightKg: userWeightKg);
    }

    return totalCalories;
  }

  /// Get workout calories statistics for a date range
  static Map<String, dynamic> getWorkoutCaloriesStats(
      List<WorkoutLog> workoutLogs,
      {double? userWeightKg}) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    double totalCalories = 0.0;
    double weekCalories = 0.0;
    double monthCalories = 0.0;
    int workoutDays = 0;

    for (final workout in workoutLogs.where((log) => log.isCompleted)) {
      final calories =
          calculateWorkoutCalories(workout, userWeightKg: userWeightKg);
      totalCalories += calories;

      if (workout.startTime.isAfter(weekStart)) {
        weekCalories += calories;
      }

      if (workout.startTime.isAfter(monthStart)) {
        monthCalories += calories;
      }

      workoutDays++;
    }

    return {
      'total_calories': totalCalories,
      'week_calories': weekCalories,
      'month_calories': monthCalories,
      'average_calories_per_workout':
          workoutDays > 0 ? totalCalories / workoutDays : 0.0,
    };
  }

  /// Calculate real-time calories during workout execution
  static double calculateRealTimeCalories(
      List<WorkoutExercise> completedExercises, int totalWorkoutTimeSeconds,
      {double? userWeightKg}) {
    if (completedExercises.isEmpty || totalWorkoutTimeSeconds <= 0) return 0.0;

    double totalCalories = 0.0;
    final totalMinutes = totalWorkoutTimeSeconds / 60.0;

    // Calculate weighted average calories per minute across all exercises
    double totalCaloriesPerMinute = 0.0;
    int exerciseCount = 0;

    for (final workoutExercise in completedExercises) {
      final exercise = workoutExercise.exercise;
      if (exercise?.estimatedCaloriesBurnedPerMinute != null) {
        double caloriesPerMinute = exercise!.estimatedCaloriesBurnedPerMinute!;
        if (userWeightKg != null) {
          caloriesPerMinute = caloriesPerMinute * (userWeightKg / 70.0);
        }
        totalCaloriesPerMinute += caloriesPerMinute;
        exerciseCount++;
      }
    }

    if (exerciseCount > 0) {
      final averageCaloriesPerMinute = totalCaloriesPerMinute / exerciseCount;
      totalCalories = averageCaloriesPerMinute * totalMinutes;
    }

    return totalCalories;
  }

  /// Private helper methods
  static double _calculateExerciseDuration(WorkoutExercise workoutExercise) {
    double totalMinutes = 0.0;

    for (int i = 0; i < workoutExercise.sets.length; i++) {
      final set = workoutExercise.sets[i];

      if (set.durationSeconds != null) {
        // Time-based exercise
        totalMinutes += set.durationSeconds! / 60.0;
      } else {
        // Rep-based exercise - estimate time per rep
        final timePerRep = _estimateTimePerRep(workoutExercise.exercise);
        totalMinutes += (set.reps * timePerRep) / 60.0;
      }

      // Add rest time between sets (not after the last set)
      if (i < workoutExercise.sets.length - 1 &&
          workoutExercise.restSeconds > 0) {
        totalMinutes += workoutExercise.restSeconds / 60.0;
      }
    }

    return totalMinutes;
  }

  static double _estimateExerciseDuration(WorkoutExercise workoutExercise) {
    double totalMinutes = 0.0;

    for (int i = 0; i < workoutExercise.sets.length; i++) {
      final set = workoutExercise.sets[i];

      if (set.durationSeconds != null) {
        totalMinutes += set.durationSeconds! / 60.0;
      } else {
        final timePerRep = _estimateTimePerRep(workoutExercise.exercise);
        totalMinutes += (set.reps * timePerRep) / 60.0;
      }

      // Add rest time between sets (not after the last set)
      if (i < workoutExercise.sets.length - 1) {
        totalMinutes += workoutExercise.restSeconds / 60.0;
      }
    }

    return totalMinutes;
  }

  static double _estimateTimePerRep(Exercise? exercise) {
    if (exercise == null) return 3.0; // Default 3 seconds per rep

    switch (exercise.type) {
      case 'cardio':
        return 1.0; // Faster movements
      case 'strength':
        return 3.0; // Standard tempo
      case 'flexibility':
        return 5.0; // Slower, controlled movements
      case 'isometric':
        return 5.0; // Longer holds
      default:
        return 3.0;
    }
  }

  static Exercise? _findExerciseById(String exerciseId) {
    try {
      return ExerciseDatabase.getAllExercises()
          .firstWhere((ex) => ex.id == exerciseId);
    } catch (e) {
      return null;
    }
  }
}
