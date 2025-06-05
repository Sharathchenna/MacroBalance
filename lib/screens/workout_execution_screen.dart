import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/workout_plan.dart';
import '../theme/app_theme.dart';
import '../providers/workout_planning_provider.dart';
import '../services/workout_statistics_service.dart';
import '../services/workout_calories_service.dart';
import '../services/auth_service.dart';
import '../services/fitness_data_service.dart';

class WorkoutExecutionScreen extends StatefulWidget {
  final WorkoutRoutine routine;

  const WorkoutExecutionScreen({
    super.key,
    required this.routine,
  });

  @override
  State<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends State<WorkoutExecutionScreen> {
  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  Timer? _restTimer;
  Timer? _workoutTimer;

  int _restTimeRemaining = 0;
  int _totalWorkoutTime = 0;

  bool _isResting = false;
  bool _isPaused = false;
  bool _isWorkoutCompleted = false;

  // Workout tracking
  WorkoutLog? _currentWorkoutLog;
  final List<WorkoutExercise> _completedExercises = [];
  final Map<int, List<WorkoutSet>> _completedSets = {};
  double _totalVolume = 0.0;
  double _caloriesBurned = 0.0;

  WorkoutExercise get _currentExercise =>
      widget.routine.exercises[_currentExerciseIndex];
  WorkoutSet get _currentSet => _currentExercise.sets[_currentSetIndex];

  @override
  void initState() {
    super.initState();
    _initializeCompletedSets();
    _startWorkout();
  }

  void _initializeCompletedSets() {
    // Initialize completed sets map for tracking
    for (int i = 0; i < widget.routine.exercises.length; i++) {
      _completedSets[i] = [];
    }
  }

  void _startWorkout() async {
    // Start the workout timer
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && !_isWorkoutCompleted) {
        setState(() {
          _totalWorkoutTime++;
          _updateRealTimeCalories();
        });
      }
    });

    // Start workout logging
    await _startWorkoutLogging();
  }

  Future<void> _startWorkoutLogging() async {
    try {
      setState(() {});

      final workoutProvider =
          Provider.of<WorkoutPlanningProvider>(context, listen: false);

      final userId = AuthService().currentUser?.id;
      if (userId == null) {
        throw Exception('No authenticated user found');
      }

      await workoutProvider.startWorkout(
        userId: userId,
        routineId: widget.routine.id,
      );

      _currentWorkoutLog = workoutProvider.currentWorkout;

      setState(() {});
    } catch (e) {
      print('Error starting workout logging: $e');
      setState(() {});
    }
  }

  void _startRestTimer() {
    setState(() {
      _isResting = true;
      _restTimeRemaining = _currentExercise.restSeconds;
    });

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _restTimeRemaining--;
        });

        if (_restTimeRemaining <= 0) {
          _completeRest();
        } else if (_restTimeRemaining <= 3 && _restTimeRemaining > 0) {
          HapticFeedback.lightImpact();
        }
      }
    });
  }

  void _completeRest() {
    _restTimer?.cancel();
    setState(() {
      _isResting = false;
      _restTimeRemaining = 0;
    });
  }

  void _completeSet() {
    HapticFeedback.mediumImpact();

    // Track completed set
    _trackCompletedSet();

    if (_currentSetIndex < _currentExercise.sets.length - 1) {
      setState(() {
        _currentSetIndex++;
      });
      if (_currentExercise.restSeconds > 0) {
        _startRestTimer();
      }
    } else {
      _completeExercise();
    }
  }

  void _trackCompletedSet() {
    final completedSet = _currentSet.copyWith(
      isCompleted: true,
    );

    // Add to completed sets for current exercise
    _completedSets[_currentExerciseIndex]?.add(completedSet);

    // Calculate volume (weight × reps)
    if (completedSet.weight != null) {
      final setVolume = completedSet.weight! * completedSet.reps;
      setState(() {
        _totalVolume += setVolume;
      });
    }

    // Update workout log if available
    _updateWorkoutProgress();
  }

  void _updateRealTimeCalories() async {
    // Calculate calories burned so far
    final completedExercises = <WorkoutExercise>[];

    _completedSets.forEach((exerciseIndex, sets) {
      if (sets.isNotEmpty && exerciseIndex < widget.routine.exercises.length) {
        final originalExercise = widget.routine.exercises[exerciseIndex];
        completedExercises.add(originalExercise.copyWith(sets: sets));
      }
    });

    if (completedExercises.isNotEmpty) {
      try {
        final macroData = await FitnessDataService().getMacroData();
        final userWeightKg =
            (macroData['current_weight_kg'] as num?)?.toDouble() ?? 70.0;

        _caloriesBurned = WorkoutCaloriesService.calculateRealTimeCalories(
          completedExercises,
          _totalWorkoutTime,
          userWeightKg: userWeightKg,
        );
      } catch (e) {
        print('Error getting user weight: $e');
        // Fallback to default weight if there's an error
        _caloriesBurned = WorkoutCaloriesService.calculateRealTimeCalories(
          completedExercises,
          _totalWorkoutTime,
          userWeightKg: 70.0,
        );
      }
    }
  }

  Future<void> _updateWorkoutProgress() async {
    if (_currentWorkoutLog == null) return;

    try {
      final workoutProvider =
          Provider.of<WorkoutPlanningProvider>(context, listen: false);

      // Create updated completed exercises list
      final updatedExercises = <WorkoutExercise>[];

      for (int i = 0; i < widget.routine.exercises.length; i++) {
        final originalExercise = widget.routine.exercises[i];
        final completedSetsForExercise = _completedSets[i] ?? [];

        if (completedSetsForExercise.isNotEmpty) {
          updatedExercises.add(originalExercise.copyWith(
            sets: completedSetsForExercise,
          ));
        }
      }

      final updatedLog = _currentWorkoutLog!.copyWith(
        completedExercises: updatedExercises,
        totalVolume: _totalVolume,
      );

      await workoutProvider.updateCurrentWorkout(updatedLog);
      _currentWorkoutLog = workoutProvider.currentWorkout;
    } catch (e) {
      print('Error updating workout progress: $e');
    }
  }

  void _completeExercise() {
    if (_currentExerciseIndex < widget.routine.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _currentSetIndex = 0;
      });
      if (_currentExercise.restSeconds > 0) {
        _startRestTimer();
      }
    } else {
      _completeWorkout();
    }
  }

  void _completeWorkout() async {
    setState(() {
      _isWorkoutCompleted = true;
    });

    _workoutTimer?.cancel();
    _restTimer?.cancel();

    HapticFeedback.heavyImpact();

    // Complete the workout logging
    await _completeWorkoutLogging();

    _showWorkoutCompletedDialog();
  }

  Future<void> _completeWorkoutLogging() async {
    if (_currentWorkoutLog == null) return;

    try {
      final workoutProvider =
          Provider.of<WorkoutPlanningProvider>(context, listen: false);

      // Final update with all completed exercises
      await _updateWorkoutProgress();

      // Complete the workout
      await workoutProvider.completeWorkout(
        workoutLogId: _currentWorkoutLog!.id,
        completedExercises: _completedExercises,
        notes: 'Completed via mobile app',
      );

      print('Workout completed successfully');
    } catch (e) {
      print('Error completing workout logging: $e');
    }
  }

  void _pauseWorkout() {
    setState(() {
      _isPaused = !_isPaused;
    });
    HapticFeedback.selectionClick();
  }

  void _skipRest() {
    HapticFeedback.lightImpact();
    _completeRest();
  }

  void _previousExercise() {
    if (_currentExerciseIndex > 0) {
      setState(() {
        _currentExerciseIndex--;
        _currentSetIndex = 0;
        _isResting = false;
      });
      _restTimer?.cancel();
      HapticFeedback.lightImpact();
    }
  }

  void _nextExercise() {
    if (_currentExerciseIndex < widget.routine.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _currentSetIndex = 0;
        _isResting = false;
      });
      _restTimer?.cancel();
      HapticFeedback.lightImpact();
    }
  }

  void _showWorkoutCompletedDialog() {
    final completedSetsCount = _getCompletedSetsCount();
    final workoutProvider =
        Provider.of<WorkoutPlanningProvider>(context, listen: false);
    final currentStreak = WorkoutStatisticsService.calculateWorkoutStreak(
        workoutProvider.workoutLogs);
    final wasStreakExtended = currentStreak > 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Success Icon with animation
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),

              // Title
              Text(
                'Workout Complete!',
                style: PremiumTypography.h2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),

              // Subtitle with motivation
              Text(
                'Great job completing "${widget.routine.name}"!',
                textAlign: TextAlign.center,
                style: PremiumTypography.bodyMedium.copyWith(
                  color: PremiumColors.slate600,
                ),
              ),

              // Streak indicator
              if (wasStreakExtended) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        '$currentStreak day streak!',
                        style: PremiumTypography.bodyMedium.copyWith(
                          color: Colors.orange,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Enhanced Stats
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: PremiumColors.slate50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    _buildStatRow('Duration', _formatTime(_totalWorkoutTime)),
                    const SizedBox(height: 12),
                    _buildStatRow(
                        'Exercises', '${widget.routine.exercises.length}'),
                    const SizedBox(height: 12),
                    _buildStatRow('Sets Completed',
                        '$completedSetsCount/${_getTotalSets()}'),
                    if (_totalVolume > 0) ...[
                      const SizedBox(height: 12),
                      _buildStatRow('Total Volume',
                          '${_totalVolume.toStringAsFixed(1)} kg'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context)
                        .pop(true); // Return to details screen with result
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Awesome!',
                    style: PremiumTypography.button.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: PremiumTypography.bodyMedium.copyWith(
            color: PremiumColors.slate600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: PremiumTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: PremiumColors.slate900,
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  int _getTotalSets() {
    return widget.routine.exercises
        .map((e) => e.sets.length)
        .reduce((a, b) => a + b);
  }

  int _getCompletedSetsCount() {
    int totalCompleted = 0;
    _completedSets.forEach((exerciseIndex, sets) {
      totalCompleted += sets.length;
    });
    return totalCompleted;
  }

  String _getMotivationalMessage() {
    final completedSets = _getCompletedSetsCount();
    final totalSets = _getTotalSets();
    final completionPercentage = (completedSets / totalSets) * 100;

    if (completionPercentage >= 75) {
      return 'Almost there! 💪';
    } else if (completionPercentage >= 50) {
      return 'Great progress! 🔥';
    } else if (completionPercentage >= 25) {
      return 'Keep it up! 💯';
    } else {
      return 'Strong start! 🚀';
    }
  }

  @override
  void dispose() {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isWorkoutCompleted) {
      return Scaffold(
        backgroundColor: isDark ? PremiumColors.darkBackground : Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : Colors.black,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 60,
                  color: isDark ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Workout Completed!',
                style: PremiumTypography.h1.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? PremiumColors.darkBackground : Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildProgressSection(),
          Expanded(
            child: _isResting ? _buildRestScreen() : _buildExerciseScreen(),
          ),
          _buildBottomControls(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDark ? PremiumColors.darkBackground : Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.close_rounded,
          color: isDark ? Colors.white : Colors.black,
        ),
        onPressed: () => _showExitDialog(),
      ),
      title: Text(
        widget.routine.name,
        style: PremiumTypography.h3.copyWith(
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          child: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark ? PremiumColors.slate800 : PremiumColors.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: isDark ? Colors.white : Colors.black,
                size: 20,
              ),
            ),
            onPressed: _pauseWorkout,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalExercises = widget.routine.exercises.length;
    final currentProgress = (_currentExerciseIndex + 1) / totalExercises;

    return Container(
      color: isDark ? PremiumColors.darkBackground : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exercise ${_currentExerciseIndex + 1} of $totalExercises',
                      style: PremiumTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Set ${_currentSetIndex + 1} of ${_currentExercise.sets.length}',
                      style: PremiumTypography.bodySmall.copyWith(
                        color: isDark
                            ? PremiumColors.slate300
                            : PremiumColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? PremiumColors.slate800
                          : PremiumColors.slate100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _formatTime(_totalWorkoutTime),
                      style: PremiumTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  if (_totalVolume > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.fitness_center,
                            size: 10,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${_totalVolume.toStringAsFixed(0)}kg',
                            style: PremiumTypography.caption.copyWith(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_caloriesBurned > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : Colors.black.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            size: 10,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${_caloriesBurned.toStringAsFixed(0)}',
                            style: PremiumTypography.caption.copyWith(
                              color: isDark ? Colors.white : Colors.black,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? PremiumColors.slate700 : PremiumColors.slate200,
              borderRadius: BorderRadius.circular(2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: currentProgress,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white : Colors.black,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseScreen() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildExerciseCard(isDark),
          ),
          const SizedBox(height: 12),
          Expanded(
            flex: 2,
            child: _buildSetDetailsCard(),
          ),
          const SizedBox(height: 12),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(bool isDark) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? PremiumColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withAlpha(((0.2) * 255).round())
              : Colors.black.withAlpha(((0.2) * 255).round()),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(((0.3) * 255).round())
                : Colors.black.withAlpha(((0.1) * 255).round()),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Exercise Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: isDark ? Colors.white : Colors.black,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.fitness_center,
              color: isDark ? Colors.black : Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),

          // Exercise Name
          Text(
            _currentExercise.exercise?.name ?? 'Exercise',
            style: PremiumTypography.h3.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),

          // Exercise Instructions (condensed)
          if (_currentExercise.exercise?.description != null) ...[
            Text(
              _currentExercise.exercise!.description,
              style: PremiumTypography.bodySmall.copyWith(
                color: isDark ? PremiumColors.slate300 : PremiumColors.slate600,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
          ],

          // Status indicators
          if (_isPaused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withAlpha(((0.2) * 255).round())
                    : Colors.black.withAlpha(((0.2) * 255).round()),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white : Colors.black,
                  width: 1,
                ),
              ),
              child: Text(
                'PAUSED',
                style: PremiumTypography.bodySmall.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),

          // Motivational progress indicator
          if (!_isPaused && _getCompletedSetsCount() > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _getMotivationalMessage(),
                style: PremiumTypography.bodySmall.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSetDetailsCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final completedSetsForCurrentExercise =
        _completedSets[_currentExerciseIndex] ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? PremiumColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? PremiumColors.slate700 : PremiumColors.slate200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Set ${_currentSetIndex + 1} of ${_currentExercise.sets.length}',
                style: PremiumTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              // Progress indicator
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: completedSetsForCurrentExercise.isNotEmpty
                      ? (isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1))
                      : (isDark
                          ? PremiumColors.slate800
                          : PremiumColors.slate100),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: completedSetsForCurrentExercise.isNotEmpty
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.3))
                        : (isDark
                            ? PremiumColors.slate600
                            : PremiumColors.slate300),
                  ),
                ),
                child: Text(
                  '${completedSetsForCurrentExercise.length} done',
                  style: PremiumTypography.caption.copyWith(
                    color: completedSetsForCurrentExercise.isNotEmpty
                        ? (isDark ? Colors.white : Colors.black)
                        : (isDark
                            ? PremiumColors.slate300
                            : PremiumColors.slate600),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Set progress dots (more compact)
          if (_currentExercise.sets.length > 1) ...[
            Row(
              children: List.generate(_currentExercise.sets.length, (index) {
                final isCompleted =
                    index < completedSetsForCurrentExercise.length;
                final isCurrent = index == _currentSetIndex;

                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? (isDark ? Colors.white : Colors.black)
                        : isCurrent
                            ? (isDark
                                ? PremiumColors.slate400
                                : PremiumColors.slate600)
                            : (isDark
                                ? PremiumColors.slate700
                                : PremiumColors.slate300),
                  ),
                  child: isCompleted
                      ? Icon(
                          Icons.check,
                          size: 6,
                          color: isDark ? Colors.black : Colors.white,
                        )
                      : null,
                );
              }),
            ),
            const SizedBox(height: 12),
          ],

          // Set details in a grid (more compact)
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildSetDetail(
                    'Reps',
                    '${_currentSet.reps}',
                    Icons.repeat_rounded,
                    Colors.transparent,
                  ),
                ),
                const SizedBox(width: 8),
                if (_currentSet.weight != null)
                  Expanded(
                    child: _buildSetDetail(
                      'Weight',
                      '${_currentSet.weight} kg',
                      Icons.fitness_center_rounded,
                      Colors.transparent,
                    ),
                  ),
                if (_currentSet.durationSeconds != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSetDetail(
                      'Duration',
                      _formatTime(_currentSet.durationSeconds!),
                      Icons.timer_rounded,
                      Colors.transparent,
                    ),
                  ),
                ],
                if (_currentExercise.restSeconds > 0) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSetDetail(
                      'Rest',
                      '${_currentExercise.restSeconds}s',
                      Icons.schedule_rounded,
                      Colors.transparent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetDetail(
      String label, String value, IconData icon, Color color) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: cardColor.withAlpha(((0.1) * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor.withAlpha(((0.3) * 255).round())),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: cardColor,
            size: 18,
          ),
          // const SizedBox(height: 2),
          Text(
            value,
            style: PremiumTypography.bodyLarge.copyWith(
              color: cardColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          // const SizedBox(height: 2),
          Text(
            label,
            style: PremiumTypography.caption.copyWith(
              color: cardColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        if (_currentExerciseIndex > 0)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _previousExercise,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Previous'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? PremiumColors.slate700 : PremiumColors.slate200,
                foregroundColor: isDark ? Colors.white : PremiumColors.slate700,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        if (_currentExerciseIndex > 0 &&
            _currentExerciseIndex < widget.routine.exercises.length - 1)
          const SizedBox(width: 12),
        if (_currentExerciseIndex < widget.routine.exercises.length - 1)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _nextExercise,
              icon: const Icon(Icons.arrow_forward, size: 18),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.white : Colors.black,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRestScreen() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final progressValue = _currentExercise.restSeconds > 0
        ? 1.0 - (_restTimeRemaining / _currentExercise.restSeconds)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rest Timer Circle (more compact)
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? PremiumColors.darkCard : Colors.white,
              border: Border.all(
                color: _restTimeRemaining <= 3
                    ? (isDark ? Colors.white : Colors.black)
                    : (isDark ? Colors.white : Colors.black),
                width: 6,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_restTimeRemaining <= 3
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.white : Colors.black))
                      .withAlpha(((0.3) * 255).round()),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 140,
                  height: 140,
                  child: CircularProgressIndicator(
                    value: progressValue,
                    strokeWidth: 5,
                    backgroundColor: isDark
                        ? PremiumColors.slate700
                        : PremiumColors.slate200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _restTimeRemaining <= 3
                          ? (isDark ? Colors.white : Colors.black)
                          : (isDark ? Colors.white : Colors.black),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'REST',
                      style: PremiumTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: isDark
                            ? PremiumColors.slate300
                            : PremiumColors.slate600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(_restTimeRemaining),
                      style: PremiumTypography.h2.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: _restTimeRemaining <= 3
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.white : Colors.black),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          if (_restTimeRemaining <= 3 && _restTimeRemaining > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withAlpha(((0.1) * 255).round()),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withAlpha(((0.3) * 255).round())),
              ),
              child: Text(
                'GET READY!',
                style: PremiumTypography.bodyMedium.copyWith(
                  color: isDark ? Colors.white : Colors.black,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),

          const SizedBox(height: 24),

          // Next exercise preview (more compact)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? PremiumColors.darkCard : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? PremiumColors.slate700 : PremiumColors.slate200,
              ),
            ),
            child: Column(
              children: [
                Text(
                  'Up Next',
                  style: PremiumTypography.bodySmall.copyWith(
                    color: isDark
                        ? PremiumColors.slate300
                        : PremiumColors.slate600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _getNextItemText(),
                  style: PremiumTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getNextItemText() {
    if (_currentSetIndex < _currentExercise.sets.length - 1) {
      return 'Set ${_currentSetIndex + 2} of ${_currentExercise.sets.length}';
    } else if (_currentExerciseIndex < widget.routine.exercises.length - 1) {
      return widget
              .routine.exercises[_currentExerciseIndex + 1].exercise?.name ??
          'Next Exercise';
    } else {
      return 'Workout Complete! 🎉';
    }
  }

  Widget _buildBottomControls() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: isDark ? PremiumColors.darkBackground : Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: SafeArea(
        child: Row(
          children: [
            if (_isResting) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _skipRest,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: Text(
                    'Skip Rest',
                    style: PremiumTypography.button,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _completeSet,
                  icon: Icon(
                    _currentSetIndex < _currentExercise.sets.length - 1
                        ? Icons.check_rounded
                        : _currentExerciseIndex <
                                widget.routine.exercises.length - 1
                            ? Icons.arrow_forward_rounded
                            : Icons.flag_rounded,
                    size: 18,
                  ),
                  label: Text(
                    _getButtonText(),
                    style: PremiumTypography.button,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getButtonText() {
    if (_currentSetIndex < _currentExercise.sets.length - 1) {
      return 'Complete Set';
    } else if (_currentExerciseIndex < widget.routine.exercises.length - 1) {
      return 'Next Exercise';
    } else {
      return 'Finish Workout';
    }
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.exit_to_app_rounded,
                size: 48,
                color: Colors.black,
              ),
              const SizedBox(height: 16),
              Text(
                'Exit Workout?',
                style: PremiumTypography.h3.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your progress will be lost if you exit now.',
                style: PremiumTypography.bodyMedium.copyWith(
                  color: PremiumColors.slate600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: PremiumTypography.bodyMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Exit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
