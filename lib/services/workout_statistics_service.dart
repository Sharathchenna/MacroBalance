import '../models/workout_plan.dart';

class WorkoutStatisticsService {
  /// Calculate custom routines completed this week
  static int getCustomRoutinesThisWeek(List<WorkoutLog> workoutLogs) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    return workoutLogs.where((log) {
      return log.isCompleted &&
          log.routine?.isCustom == true &&
          log.startTime.isAfter(weekStart);
    }).length;
  }

  /// Calculate total workouts this week
  static int getTotalWorkoutsThisWeek(List<WorkoutLog> workoutLogs) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    return workoutLogs.where((log) {
      return log.isCompleted && log.startTime.isAfter(weekStart);
    }).length;
  }

  /// Calculate workout streak in days
  static int calculateWorkoutStreak(List<WorkoutLog> workoutLogs) {
    final completedWorkouts = workoutLogs
        .where((log) => log.isCompleted)
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));

    if (completedWorkouts.isEmpty) return 0;

    final now = DateTime.now();
    int streakDays = 0;
    DateTime? lastWorkoutDate;
    Set<String> workoutDates = {};

    for (final workout in completedWorkouts) {
      final workoutDate = DateTime(
        workout.startTime.year,
        workout.startTime.month,
        workout.startTime.day,
      );
      final dateString =
          '${workoutDate.year}-${workoutDate.month}-${workoutDate.day}';

      // Skip if we already counted this date (multiple workouts in one day)
      if (workoutDates.contains(dateString)) {
        continue;
      }

      workoutDates.add(dateString);

      if (lastWorkoutDate == null) {
        // First workout in the sorted list
        lastWorkoutDate = workoutDate;
        final today = DateTime(now.year, now.month, now.day);
        final yesterday = today.subtract(const Duration(days: 1));

        // Check if the last workout was today or yesterday to start streak
        if (workoutDate.isAtSameMomentAs(today) ||
            workoutDate.isAtSameMomentAs(yesterday)) {
          streakDays = 1;
        } else {
          break; // No recent workout, no streak
        }
      } else {
        // Check if this workout is consecutive (1 day before the last workout)
        final expectedDate = lastWorkoutDate.subtract(const Duration(days: 1));
        if (workoutDate.isAtSameMomentAs(expectedDate)) {
          streakDays++;
          lastWorkoutDate = workoutDate;
        } else {
          // Gap in workouts, streak ends
          break;
        }
      }
    }

    return streakDays;
  }

  /// Get comprehensive workout statistics
  static Map<String, dynamic> getWorkoutStatistics(
      List<WorkoutLog> workoutLogs) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    final completedWorkouts =
        workoutLogs.where((log) => log.isCompleted).toList();
    final customRoutinesThisWeek = getCustomRoutinesThisWeek(workoutLogs);
    final totalWorkoutsThisWeek = getTotalWorkoutsThisWeek(workoutLogs);
    final streakDays = calculateWorkoutStreak(workoutLogs);

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

    // Calculate average workouts per week
    final firstWorkout = completedWorkouts.isNotEmpty
        ? completedWorkouts
            .reduce((a, b) => a.startTime.isBefore(b.startTime) ? a : b)
        : null;

    double averageWorkoutsPerWeek = 0.0;
    if (firstWorkout != null) {
      final weeksSinceFirstWorkout =
          now.difference(firstWorkout.startTime).inDays / 7;
      if (weeksSinceFirstWorkout > 0) {
        averageWorkoutsPerWeek =
            completedWorkouts.length / weeksSinceFirstWorkout;
      }
    }

    return {
      'total_workouts': completedWorkouts.length,
      'custom_routines_this_week': customRoutinesThisWeek,
      'total_workouts_this_week': totalWorkoutsThisWeek,
      'this_month_workouts': thisMonthWorkouts,
      'streak_days': streakDays,
      'total_volume': totalVolume,
      'average_duration': averageDuration,
      'average_workouts_per_week': averageWorkoutsPerWeek,
    };
  }

  /// Check if user worked out today
  static bool hasWorkedOutToday(List<WorkoutLog> workoutLogs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return workoutLogs.any((log) {
      final workoutDate = DateTime(
        log.startTime.year,
        log.startTime.month,
        log.startTime.day,
      );
      return log.isCompleted && workoutDate.isAtSameMomentAs(today);
    });
  }

  /// Get workout frequency for the last N days
  static Map<DateTime, int> getWorkoutFrequency(
      List<WorkoutLog> workoutLogs, int days) {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final frequency = <DateTime, int>{};

    // Initialize all dates with 0
    for (int i = 0; i < days; i++) {
      final date = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      ).add(Duration(days: i));
      frequency[date] = 0;
    }

    // Count workouts for each date
    for (final log in workoutLogs) {
      if (log.isCompleted && log.startTime.isAfter(startDate)) {
        final workoutDate = DateTime(
          log.startTime.year,
          log.startTime.month,
          log.startTime.day,
        );
        if (frequency.containsKey(workoutDate)) {
          frequency[workoutDate] = frequency[workoutDate]! + 1;
        }
      }
    }

    return frequency;
  }

  /// Get longest workout streak ever
  static int getLongestStreak(List<WorkoutLog> workoutLogs) {
    final completedWorkouts = workoutLogs
        .where((log) => log.isCompleted)
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    if (completedWorkouts.isEmpty) return 0;

    int longestStreak = 0;
    int currentStreak = 0;
    DateTime? lastWorkoutDate;

    for (final workout in completedWorkouts) {
      final workoutDate = DateTime(
        workout.startTime.year,
        workout.startTime.month,
        workout.startTime.day,
      );

      if (lastWorkoutDate == null) {
        currentStreak = 1;
        lastWorkoutDate = workoutDate;
      } else {
        final daysDifference = workoutDate.difference(lastWorkoutDate).inDays;

        if (daysDifference == 1) {
          // Consecutive day
          currentStreak++;
        } else if (daysDifference == 0) {
          // Same day, don't increment streak
          continue;
        } else {
          // Gap in workouts, reset streak
          longestStreak =
              longestStreak > currentStreak ? longestStreak : currentStreak;
          currentStreak = 1;
        }

        lastWorkoutDate = workoutDate;
      }
    }

    return longestStreak > currentStreak ? longestStreak : currentStreak;
  }
}
