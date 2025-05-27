import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/workout_plan.dart';
import '../models/exercise.dart';
import '../widgets/exercise_animation_widget.dart';
import 'dart:math' as math;

class WorkoutExecutionScreen extends StatefulWidget {
  final WorkoutRoutine routine;

  const WorkoutExecutionScreen({
    Key? key,
    required this.routine,
  }) : super(key: key);

  @override
  State<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends State<WorkoutExecutionScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _restCircleController;
  late AnimationController _cardController;
  late AnimationController _fadeController;

  late Animation<double> _progressAnimation;
  late Animation<double> _restCircleAnimation;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _fadeAnimation;

  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  Timer? _restTimer;
  Timer? _exerciseTimer;
  Timer? _workoutTimer;

  int _restTimeRemaining = 0;
  int _exerciseTimeElapsed = 0;
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
    _initializeAnimations();
    _startWorkout();
  }

  void _initializeAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _restCircleController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _cardController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeOutCubic,
    ));

    _restCircleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _restCircleController,
      curve: Curves.elasticOut,
    ));

    _cardSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _progressController.forward();
  }

  void _startWorkout() {
    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _totalWorkoutTime++;
        });
      }
    });

    _exerciseTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused && !_isResting) {
        setState(() {
          _exerciseTimeElapsed++;
        });
      }
    });
  }

  void _startRestTimer() {
    setState(() {
      _isResting = true;
      _restTimeRemaining = _currentExercise.restSeconds;
      _exerciseTimeElapsed = 0;
    });

    _restCircleController.forward();

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _restTimeRemaining--;
        });

        if (_restTimeRemaining <= 0) {
          _completeRest();
        } else if (_restTimeRemaining <= 3) {
          _vibrate();
        }
      }
    });
  }

  void _completeRest() {
    _restTimer?.cancel();
    _restCircleController.reset();
    setState(() {
      _isResting = false;
      _restTimeRemaining = 0;
    });
  }

  void _completeSet() {
    HapticFeedback.mediumImpact();

    _cardController.forward().then((_) {
      if (_currentSetIndex < _currentExercise.sets.length - 1) {
        setState(() {
          _currentSetIndex++;
        });
        _startRestTimer();
      } else {
        _completeExercise();
      }
      _cardController.reset();
    });
  }

  void _completeExercise() {
    if (_currentExerciseIndex < widget.routine.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _currentSetIndex = 0;
        _exerciseTimeElapsed = 0;
      });
      _progressController.reset();
      _progressController.forward();
      _startRestTimer();
    } else {
      _completeWorkout();
    }
  }

  void _completeWorkout() {
    setState(() {
      _isWorkoutCompleted = true;
    });

    _workoutTimer?.cancel();
    _exerciseTimer?.cancel();
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

  void _vibrate() {
    HapticFeedback.selectionClick();
  }

  void _showWorkoutCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(32),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Workout Complete!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Great job completing "${widget.routine.name}"!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _buildStatRow('Duration', _formatTime(_totalWorkoutTime)),
                  const SizedBox(height: 12),
                  _buildStatRow(
                      'Exercises', '${widget.routine.exercises.length}'),
                  const SizedBox(height: 12),
                  _buildStatRow('Total Sets', '${widget.routine.totalSets}'),
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
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
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
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
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

  @override
  void dispose() {
    _progressController.dispose();
    _restCircleController.dispose();
    _cardController.dispose();
    _fadeController.dispose();
    _workoutTimer?.cancel();
    _exerciseTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isWorkoutCompleted) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 60,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Workout Completed!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.routine.name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            onPressed: _pauseWorkout,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildProgressSection(),
            Expanded(
              child: _isResting ? _buildRestScreen() : _buildExerciseScreen(),
            ),
            _buildBottomControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    final totalExercises = widget.routine.exercises.length;
    final currentProgress = (_currentExerciseIndex + 1) / totalExercises;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exercise ${_currentExerciseIndex + 1}/$totalExercises',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set ${_currentSetIndex + 1}/${_currentExercise.sets.length}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Text(
                  _formatTime(_totalWorkoutTime),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Container(
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: currentProgress * _progressAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.cyan.shade400, Colors.blue.shade500],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseScreen() {
    return AnimatedBuilder(
      animation: _cardSlideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_cardSlideAnimation.value * 50, 0),
          child: Opacity(
            opacity: (1 - _cardSlideAnimation.value).clamp(0.0, 1.0),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Expanded(
                    flex: 3,
                    child: _buildExerciseCard(),
                  ),
                  const SizedBox(height: 24),
                  _buildSetDetailsCard(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildExerciseCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E3A8A),
            const Color(0xFF1E40AF),
            const Color(0xFF2563EB),
          ],
        ),
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Background pattern
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: CustomPaint(
                painter: _BackgroundPatternPainter(),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Exercise Name
                Text(
                  _currentExercise.exercise?.name ?? 'Exercise',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 32),

                // Exercise Animation
                SizedBox(
                  height: 160,
                  child: ExerciseAnimationWidget(
                    exerciseName: _currentExercise.exercise?.name ?? 'Exercise',
                    isPlaying: !_isPaused,
                    primaryColor: Colors.white,
                    secondaryColor: Colors.white70,
                  ),
                ),

                const SizedBox(height: 32),

                // Timer
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Text(
                    _formatTime(_exerciseTimeElapsed),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),

                if (_isPaused) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: const Text(
                      'PAUSED',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
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

  Widget _buildSetDetailsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            'Set ${_currentSetIndex + 1} of ${_currentExercise.sets.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (_currentSet.reps != null)
                _buildSetDetail(
                    'Reps', '${_currentSet.reps}', Icons.repeat_rounded),
              if (_currentSet.weight != null)
                _buildSetDetail('Weight', '${_currentSet.weight} kg',
                    Icons.fitness_center_rounded),
              if (_currentSet.durationSeconds != null)
                _buildSetDetail(
                    'Duration',
                    _formatTime(_currentSet.durationSeconds!),
                    Icons.timer_rounded),
              if (_currentExercise.restSeconds > 0)
                _buildSetDetail('Rest', '${_currentExercise.restSeconds}s',
                    Icons.schedule_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSetDetail(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white70,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white60,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRestScreen() {
    final progressValue = _currentExercise.restSeconds > 0
        ? 1.0 - (_restTimeRemaining / _currentExercise.restSeconds)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _restCircleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _restCircleAnimation.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow
                    Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_restTimeRemaining <= 3
                                    ? Colors.red
                                    : Colors.orange)
                                .withOpacity(0.3),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),

                    // Main circle
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _restTimeRemaining <= 3
                              ? [Colors.red.shade400, Colors.red.shade600]
                              : [
                                  Colors.orange.shade400,
                                  Colors.orange.shade600
                                ],
                        ),
                      ),
                    ),

                    // Progress ring
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: CircularProgressIndicator(
                        value: progressValue,
                        strokeWidth: 8,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),

                    // Content
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'REST',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatTime(_restTimeRemaining),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        if (_restTimeRemaining <= 3 &&
                            _restTimeRemaining > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'GET READY!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 48),

          // Next preview
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                Text(
                  'Up Next',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getNextItemText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (_isResting) ...[
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _skipRest,
                  icon: const Icon(Icons.skip_next_rounded, size: 20),
                  label: const Text(
                    'Skip Rest',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
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
}

class _BackgroundPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // Draw concentric circles
    for (int i = 1; i <= 5; i++) {
      final radius = (size.width / 10) * i;
      canvas.drawCircle(Offset(centerX, centerY), radius, paint);
    }

    // Draw radiating lines
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * (3.14159 / 180);
      final startX = centerX + (size.width / 6) * math.cos(angle);
      final startY = centerY + (size.width / 6) * math.sin(angle);
      final endX = centerX + (size.width / 3) * math.cos(angle);
      final endY = centerY + (size.width / 3) * math.sin(angle);

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
