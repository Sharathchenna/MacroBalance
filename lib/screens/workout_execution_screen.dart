import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/workout_plan.dart';
import '../theme/app_theme.dart';
import '../theme/workout_colors.dart';

class WorkoutExecutionScreen extends StatefulWidget {
  final WorkoutRoutine routine;

  const WorkoutExecutionScreen({
    Key? key,
    required this.routine,
  }) : super(key: key);

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

  WorkoutExercise get _currentExercise =>
      widget.routine.exercises[_currentExerciseIndex];
  WorkoutSet get _currentSet => _currentExercise.sets[_currentSetIndex];

  @override
  void initState() {
    super.initState();
    _startWorkout();
  }

  void _startWorkout() {
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && !_isWorkoutCompleted) {
        setState(() {
          _totalWorkoutTime++;
        });
      }
    });
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

  void _completeWorkout() {
    setState(() {
      _isWorkoutCompleted = true;
    });

    _workoutTimer?.cancel();
    _restTimer?.cancel();

    HapticFeedback.heavyImpact();
    _showWorkoutCompletedDialog();
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
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: PremiumColors.successGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Workout Complete!',
                style: PremiumTypography.h2.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Great job completing "${widget.routine.name}"!',
                textAlign: TextAlign.center,
                style: PremiumTypography.bodyMedium.copyWith(
                  color: PremiumColors.slate600,
                ),
              ),
              const SizedBox(height: 24),
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
                    _buildStatRow('Total Sets', '${_getTotalSets()}'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumColors.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Done',
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

  @override
  void dispose() {
    _workoutTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isWorkoutCompleted) {
      return Scaffold(
        backgroundColor: PremiumColors.slate50,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: PremiumColors.successGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Workout Completed!',
                style: PremiumTypography.h1.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: PremiumColors.slate50,
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
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.close_rounded, color: PremiumColors.slate900),
        onPressed: () => _showExitDialog(),
      ),
      title: Text(
        widget.routine.name,
        style: PremiumTypography.h3.copyWith(
          fontWeight: FontWeight.w600,
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
                color: PremiumColors.slate100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: PremiumColors.slate900,
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
    final totalExercises = widget.routine.exercises.length;
    final currentProgress = (_currentExerciseIndex + 1) / totalExercises;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exercise ${_currentExerciseIndex + 1} of $totalExercises',
                    style: PremiumTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set ${_currentSetIndex + 1} of ${_currentExercise.sets.length}',
                    style: PremiumTypography.bodyMedium.copyWith(
                      color: PremiumColors.slate600,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: PremiumColors.slate100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _formatTime(_totalWorkoutTime),
                  style: PremiumTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: PremiumColors.slate200,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: currentProgress,
              child: Container(
                decoration: BoxDecoration(
                  color: PremiumColors.vibrantOrange,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseScreen() {
    final workoutColor = WorkoutColors.getWorkoutCategoryColor(
        _currentExercise.exercise?.name ?? '',
        _currentExercise.exercise?.primaryMuscles ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildExerciseCard(workoutColor),
          const SizedBox(height: 24),
          _buildSetDetailsCard(),
          const SizedBox(height: 24),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildExerciseCard(Color workoutColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: workoutColor.withOpacity(0.2),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: workoutColor.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Exercise Icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: workoutColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.fitness_center,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),

          // Exercise Name
          Text(
            _currentExercise.exercise?.name ?? 'Exercise',
            style: PremiumTypography.h2.copyWith(
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Exercise Instructions
          if (_currentExercise.exercise?.description != null) ...[
            Text(
              _currentExercise.exercise!.description,
              style: PremiumTypography.bodyMedium.copyWith(
                color: PremiumColors.slate600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],

          // Pause Indicator
          if (_isPaused)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: PremiumColors.pastelYellow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: PremiumColors.pastelYellow,
                  width: 1,
                ),
              ),
              child: Text(
                'PAUSED',
                style: PremiumTypography.bodyMedium.copyWith(
                  color: PremiumColors.pastelYellow,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSetDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: PremiumColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set ${_currentSetIndex + 1} of ${_currentExercise.sets.length}',
            style: PremiumTypography.h3.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          // Set details in a grid
          Row(
            children: [
              Expanded(
                child: _buildSetDetail(
                  'Reps',
                  '${_currentSet.reps}',
                  Icons.repeat_rounded,
                  PremiumColors.energeticBlue,
                ),
              ),
              const SizedBox(width: 12),
              if (_currentSet.weight != null)
                Expanded(
                  child: _buildSetDetail(
                    'Weight',
                    '${_currentSet.weight} kg',
                    Icons.fitness_center_rounded,
                    PremiumColors.vibrantOrange,
                  ),
                ),
            ],
          ),

          if (_currentSet.durationSeconds != null ||
              _currentExercise.restSeconds > 0) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (_currentSet.durationSeconds != null)
                  Expanded(
                    child: _buildSetDetail(
                      'Duration',
                      _formatTime(_currentSet.durationSeconds!),
                      Icons.timer_rounded,
                      PremiumColors.desaturatedMagenta,
                    ),
                  ),
                if (_currentSet.durationSeconds != null &&
                    _currentExercise.restSeconds > 0)
                  const SizedBox(width: 12),
                if (_currentExercise.restSeconds > 0)
                  Expanded(
                    child: _buildSetDetail(
                      'Rest',
                      '${_currentExercise.restSeconds}s',
                      Icons.schedule_rounded,
                      PremiumColors.successGreen,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSetDetail(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: PremiumTypography.h3.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: PremiumTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentExerciseIndex > 0)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _previousExercise,
              icon: const Icon(Icons.arrow_back, size: 18),
              label: const Text('Previous'),
              style: ElevatedButton.styleFrom(
                backgroundColor: PremiumColors.slate200,
                foregroundColor: PremiumColors.slate700,
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
                backgroundColor: PremiumColors.energeticBlue,
                foregroundColor: Colors.white,
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
    final progressValue = _currentExercise.restSeconds > 0
        ? 1.0 - (_restTimeRemaining / _currentExercise.restSeconds)
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 40),

          // Rest Timer Circle
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: _restTimeRemaining <= 3
                    ? PremiumColors.softRed
                    : PremiumColors.vibrantOrange,
                width: 8,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_restTimeRemaining <= 3
                          ? PremiumColors.softRed
                          : PremiumColors.vibrantOrange)
                      .withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: progressValue,
                    strokeWidth: 6,
                    backgroundColor: PremiumColors.slate200,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _restTimeRemaining <= 3
                          ? PremiumColors.softRed
                          : PremiumColors.vibrantOrange,
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'REST',
                      style: PremiumTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                        color: PremiumColors.slate600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _formatTime(_restTimeRemaining),
                      style: PremiumTypography.h1.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: _restTimeRemaining <= 3
                            ? PremiumColors.softRed
                            : PremiumColors.vibrantOrange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          if (_restTimeRemaining <= 3 && _restTimeRemaining > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: PremiumColors.softRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border:
                    Border.all(color: PremiumColors.softRed.withOpacity(0.3)),
              ),
              child: Text(
                'GET READY!',
                style: PremiumTypography.bodyLarge.copyWith(
                  color: PremiumColors.softRed,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),

          const SizedBox(height: 32),

          // Next exercise preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: PremiumColors.slate200),
            ),
            child: Column(
              children: [
                Text(
                  'Up Next',
                  style: PremiumTypography.bodyMedium.copyWith(
                    color: PremiumColors.slate600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getNextItemText(),
                  style: PremiumTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
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
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        child: Row(
          children: [
            if (_isResting) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _skipRest,
                  icon: const Icon(Icons.skip_next_rounded, size: 20),
                  label: Text(
                    'Skip Rest',
                    style: PremiumTypography.button,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumColors.vibrantOrange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                    size: 20,
                  ),
                  label: Text(
                    _getButtonText(),
                    style: PremiumTypography.button,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumColors.successGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
              Icon(
                Icons.exit_to_app_rounded,
                size: 48,
                color: PremiumColors.softRed,
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
                        backgroundColor: PremiumColors.softRed,
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
