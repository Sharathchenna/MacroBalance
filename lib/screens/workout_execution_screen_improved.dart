import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../models/workout_plan.dart';
import '../widgets/exercise_animation_widget.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;

class WorkoutExecutionScreen extends StatefulWidget {
  final WorkoutRoutine routine;

  const WorkoutExecutionScreen({
    super.key,
    required this.routine,
  });

  @override
  State<WorkoutExecutionScreen> createState() => _WorkoutExecutionScreenState();
}

class _WorkoutExecutionScreenState extends State<WorkoutExecutionScreen>
    with TickerProviderStateMixin {
  late AnimationController _progressController;
  late AnimationController _restCircleController;
  late AnimationController _cardController;
  late AnimationController _fadeController;
  late AnimationController _setProgressController;
  late AnimationController _swipeController;

  late Animation<double> _progressAnimation;
  late Animation<double> _restCircleAnimation;
  late Animation<double> _cardSlideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _setProgressAnimation;
  late Animation<Offset> _swipeAnimation;

  int _currentExerciseIndex = 0;
  int _currentSetIndex = 0;
  Timer? _restTimer;
  Timer? _exerciseTimer;
  Timer? _workoutTimer;

  int _restTimeRemaining = 0;
  int _exerciseTimeElapsed = 0;
  int _totalWorkoutTime = 0;
  int _originalRestTime = 0;

  bool _isResting = false;
  bool _isPaused = false;
  bool _isWorkoutCompleted = false;
  bool _showInstructions = false;

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
      duration: PremiumAnimations.medium,
      vsync: this,
    );

    _restCircleController = AnimationController(
      duration: PremiumAnimations.slow,
      vsync: this,
    );

    _cardController = AnimationController(
      duration: PremiumAnimations.medium,
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: PremiumAnimations.fast,
      vsync: this,
    );

    _setProgressController = AnimationController(
      duration: PremiumAnimations.medium,
      vsync: this,
    );

    _swipeController = AnimationController(
      duration: PremiumAnimations.fast,
      vsync: this,
    );

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: PremiumAnimations.smooth,
    ));

    _restCircleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _restCircleController,
      curve: PremiumAnimations.bounce,
    ));

    _cardSlideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _cardController,
      curve: PremiumAnimations.gentle,
    ));

    _fadeAnimation = Tween<double>(
      begin: 1.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: PremiumAnimations.smooth,
    ));

    _setProgressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _setProgressController,
      curve: PremiumAnimations.smooth,
    ));

    _swipeAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _swipeController,
      curve: PremiumAnimations.smooth,
    ));

    _progressController.forward();
    _fadeController.forward();
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
      _originalRestTime = _currentExercise.restSeconds;
      _exerciseTimeElapsed = 0;
    });

    _restCircleController.forward();
    HapticFeedback.lightImpact();

    _restTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _restTimeRemaining--;
        });

        if (_restTimeRemaining <= 0) {
          _completeRest();
        } else if (_restTimeRemaining <= 3) {
          HapticFeedback.selectionClick();
        } else if (_restTimeRemaining == 10) {
          HapticFeedback.lightImpact();
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
    HapticFeedback.mediumImpact();
  }

  void _completeSet() {
    HapticFeedback.mediumImpact();

    // Update set progress animation
    final setProgress = (_currentSetIndex + 1) / _currentExercise.sets.length;
    _setProgressController.animateTo(setProgress);

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
    HapticFeedback.heavyImpact();
    if (_currentExerciseIndex < widget.routine.exercises.length - 1) {
      setState(() {
        _currentExerciseIndex++;
        _currentSetIndex = 0;
        _exerciseTimeElapsed = 0;
      });
      _progressController.reset();
      _setProgressController.reset();
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

    // Double haptic for celebration
    Future.delayed(const Duration(milliseconds: 200), () {
      HapticFeedback.heavyImpact();
    });

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

  void _adjustRestTime(int seconds) {
    if (_isResting) {
      setState(() {
        _restTimeRemaining = math.max(0, _restTimeRemaining + seconds);
      });
      HapticFeedback.selectionClick();
    }
  }

  void _toggleInstructions() {
    setState(() {
      _showInstructions = !_showInstructions;
    });
    HapticFeedback.lightImpact();
  }

  void _showWorkoutCompletedDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: PremiumColors.slate900.withOpacity(0.8),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 24,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: Colors.white,
            boxShadow: AppTheme.elevatedShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PremiumColors.emerald500,
                      PremiumColors.emerald500.withOpacity(0.8)
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PremiumColors.emerald500.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
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
                  color: PremiumColors.slate900,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Great job completing "${widget.routine.name}"!',
                textAlign: TextAlign.center,
                style: PremiumTypography.bodyMedium.copyWith(
                  color: PremiumColors.slate500,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: PremiumColors.slate100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: PremiumColors.slate300, width: 1),
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
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: PremiumColors.emerald500,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: PremiumColors.emerald500.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).pop(true);
                      },
                      child: Center(
                        child: Text(
                          'Done',
                          style: PremiumTypography.button.copyWith(
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
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
            color: PremiumColors.slate500,
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

  @override
  void dispose() {
    _progressController.dispose();
    _restCircleController.dispose();
    _cardController.dispose();
    _fadeController.dispose();
    _setProgressController.dispose();
    _swipeController.dispose();
    _workoutTimer?.cancel();
    _exerciseTimer?.cancel();
    _restTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isWorkoutCompleted) {
      return Scaffold(
        backgroundColor: PremiumColors.slate100,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      PremiumColors.emerald500,
                      PremiumColors.emerald500.withOpacity(0.8)
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: PremiumColors.emerald500.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
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
                  color: PremiumColors.slate900,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: PremiumColors.slate900,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(Icons.close_rounded, color: Colors.white, size: 20),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.routine.name,
          style: PremiumTypography.h4.copyWith(
            color: Colors.white,
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
          if (!_isResting) ...[
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _showInstructions ? Icons.info : Icons.info_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              onPressed: _toggleInstructions,
            ),
          ],
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: FadeTransition(
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
                    style: PremiumTypography.bodyLarge.copyWith(
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set ${_currentSetIndex + 1}/${_currentExercise.sets.length}',
                    style: PremiumTypography.bodyMedium.copyWith(
                      color: Colors.white54,
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
                  style: PremiumTypography.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Overall progress
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
                        colors: [PremiumColors.blue400, PremiumColors.blue500],
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          // Set progress
          AnimatedBuilder(
            animation: _setProgressAnimation,
            builder: (context, child) {
              return Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _setProgressAnimation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      color: PremiumColors.emerald400,
                      borderRadius: BorderRadius.circular(2),
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
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
          _completeSet();
        }
      },
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PremiumColors.slate800,
              PremiumColors.slate700,
              PremiumColors.slate600,
            ],
          ),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: PremiumColors.slate900.withOpacity(0.3),
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
                    style: PremiumTypography.h1.copyWith(
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  if (_showInstructions) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        _currentExercise.exercise?.instructions?.join(' ') ??
                            'Focus on proper form and controlled movements.',
                        style: PremiumTypography.bodyMedium.copyWith(
                          color: Colors.white70,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Exercise Animation
                  SizedBox(
                    height: 160,
                    child: ExerciseAnimationWidget(
                      exerciseName:
                          _currentExercise.exercise?.name ?? 'Exercise',
                      isPlaying: !_isPaused,
                      primaryColor: Colors.white,
                      secondaryColor: Colors.white70,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Timer
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(0.2)),
                    ),
                    child: Text(
                      _formatTime(_exerciseTimeElapsed),
                      style: PremiumTypography.numeric.copyWith(
                        color: Colors.white,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),

                  if (_isPaused) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: PremiumColors.amber500.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: PremiumColors.amber500.withOpacity(0.3)),
                      ),
                      child: Text(
                        'PAUSED',
                        style: PremiumTypography.label.copyWith(
                          color: PremiumColors.amber500,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],

                  // Swipe hint
                  const SizedBox(height: 24),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swipe_right_alt_rounded,
                          color: Colors.white54,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Swipe right to complete set',
                          style: PremiumTypography.caption.copyWith(
                            color: Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
            style: PremiumTypography.h3.copyWith(
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 16,
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
          style: PremiumTypography.bodyLarge.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: PremiumTypography.caption.copyWith(
            color: Colors.white60,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildRestScreen() {
    final progressValue = _originalRestTime > 0
        ? 1.0 - (_restTimeRemaining / _originalRestTime)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rest Circle Timer
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
                                    ? PremiumColors.red400
                                    : PremiumColors.amber400)
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
                              ? [PremiumColors.red400, PremiumColors.red500]
                              : [
                                  PremiumColors.amber400,
                                  PremiumColors.amber500
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
                        Text(
                          'REST',
                          style: PremiumTypography.h3.copyWith(
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _formatTime(_restTimeRemaining),
                          style: PremiumTypography.display1.copyWith(
                            color: Colors.white,
                            fontSize: 48,
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
                            child: Text(
                              'GET READY!',
                              style: PremiumTypography.label.copyWith(
                                color: Colors.white,
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

          const SizedBox(height: 32),

          // Rest time adjustment
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildRestAdjustButton(
                  Icons.remove, () => _adjustRestTime(-15), '-15s'),
              const SizedBox(width: 24),
              _buildRestAdjustButton(
                  Icons.add, () => _adjustRestTime(15), '+15s'),
            ],
          ),

          const SizedBox(height: 32),

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
                  style: PremiumTypography.bodyMedium.copyWith(
                    color: Colors.white60,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getNextItemText(),
                  style: PremiumTypography.h4.copyWith(
                    color: Colors.white,
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

  Widget _buildRestAdjustButton(
      IconData icon, VoidCallback onPressed, String label) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onPressed,
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: PremiumTypography.caption.copyWith(
            color: Colors.white60,
          ),
        ),
      ],
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
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: PremiumColors.amber500,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: PremiumColors.amber500.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _skipRest,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.skip_next_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Skip Rest',
                            style: PremiumTypography.button.copyWith(
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Expanded(
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: PremiumColors.emerald500,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: PremiumColors.emerald500.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _completeSet,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _currentSetIndex < _currentExercise.sets.length - 1
                                ? Icons.check_rounded
                                : _currentExerciseIndex <
                                        widget.routine.exercises.length - 1
                                    ? Icons.arrow_forward_rounded
                                    : Icons.flag_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _getButtonText(),
                            style: PremiumTypography.button.copyWith(
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
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
