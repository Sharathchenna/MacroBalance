import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/workout_plan.dart';
import '../screens/workout_execution_screen.dart';
import '../services/exercise_image_service.dart';
import '../services/workout_statistics_service.dart';
import '../providers/workout_planning_provider.dart';

class WorkoutDetailsScreen extends StatefulWidget {
  final WorkoutRoutine routine;

  const WorkoutDetailsScreen({super.key, required this.routine});

  @override
  State<WorkoutDetailsScreen> createState() => _WorkoutDetailsScreenState();
}

class _WorkoutDetailsScreenState extends State<WorkoutDetailsScreen>
    with TickerProviderStateMixin {
  final Set<String> _preloadedImages = {};
  bool _hasPreloadedImages = false;
  late final ExerciseImageService _imageService;
  bool _showEnhancedData = false;
  final Map<String, Map<String, dynamic>?> _exerciseDataCache = {};

  // Workout tracking variables
  int _customRoutinesThisWeek = 0;
  int _totalWorkoutsThisWeek = 0;
  int _streakDays = 0;
  bool _isLoadingStats = false;

  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _imageService = ExerciseImageService();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _loadExerciseData();
    _loadWorkoutStats();
    _fadeController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasPreloadedImages) {
      _preloadExerciseImages();
      _hasPreloadedImages = true;
    }

    // Refresh stats when returning to this screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshWorkoutStats();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    // Clear any cached data to prevent memory leaks
    _exerciseDataCache.clear();
    _preloadedImages.clear();
    super.dispose();
  }

  Future<void> _loadExerciseData() async {
    for (final exercise in widget.routine.exercises) {
      final exerciseName = exercise.exercise?.name ?? '';
      if (exerciseName.isNotEmpty) {
        final data = await _imageService.getExerciseData(exerciseName);
        if (mounted) {
          setState(() {
            _exerciseDataCache[exerciseName] = data;
          });
        }
      }
    }
  }

  void _preloadExerciseImages() async {
    for (final exercise in widget.routine.exercises) {
      final exerciseName = exercise.exercise?.name ?? '';
      try {
        final imageUrl = exercise.exercise?.imageUrl ??
            await _imageService.getExerciseImageUrl(exerciseName);

        if (!mounted) return; // Check mounted before proceeding

        if (imageUrl.isNotEmpty && !_preloadedImages.contains(imageUrl)) {
          _preloadedImages.add(imageUrl);
          precacheImage(NetworkImage(imageUrl), context).catchError((error) {
            print('Failed to preload image for $exerciseName: $imageUrl');
          });
        }
      } catch (e) {
        print('Error getting image URL for $exerciseName: $e');
      }
    }
  }

  Future<void> _loadWorkoutStats() async {
    if (!mounted) return;

    setState(() {
      _isLoadingStats = true;
    });

    try {
      final workoutProvider =
          Provider.of<WorkoutPlanningProvider>(context, listen: false);
      final stats = _calculateWorkoutStats(workoutProvider.workoutLogs);

      if (mounted) {
        setState(() {
          _customRoutinesThisWeek = stats['customRoutinesThisWeek'] ?? 0;
          _totalWorkoutsThisWeek = stats['totalWorkoutsThisWeek'] ?? 0;
          _streakDays = stats['streakDays'] ?? 0;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      print('Error loading workout stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Map<String, int> _calculateWorkoutStats(List<WorkoutLog> workoutLogs) {
    final customRoutinesThisWeek =
        WorkoutStatisticsService.getCustomRoutinesThisWeek(workoutLogs);
    final totalWorkoutsThisWeek =
        WorkoutStatisticsService.getTotalWorkoutsThisWeek(workoutLogs);
    final streakDays =
        WorkoutStatisticsService.calculateWorkoutStreak(workoutLogs);

    return {
      'customRoutinesThisWeek': customRoutinesThisWeek,
      'totalWorkoutsThisWeek': totalWorkoutsThisWeek,
      'streakDays': streakDays,
    };
  }

  Future<void> _refreshWorkoutStats() async {
    if (!mounted) return;

    try {
      final workoutProvider =
          Provider.of<WorkoutPlanningProvider>(context, listen: false);
      // Only refresh if we have data and it's not already loading
      if (!_isLoadingStats && workoutProvider.workoutLogs.isNotEmpty) {
        final stats = _calculateWorkoutStats(workoutProvider.workoutLogs);

        if (mounted) {
          setState(() {
            _customRoutinesThisWeek = stats['customRoutinesThisWeek'] ?? 0;
            _totalWorkoutsThisWeek = stats['totalWorkoutsThisWeek'] ?? 0;
            _streakDays = stats['streakDays'] ?? 0;
          });
        }
      }
    } catch (e) {
      print('Error refreshing workout stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAIGenerated =
        !widget.routine.isCustom && widget.routine.name.contains('AI');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F0F) : Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(isAIGenerated),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildWorkoutOverview(),
                      const SizedBox(height: 24),
                      _buildDescription(),
                      const SizedBox(height: 24),
                      _buildExercisesList(),
                      const SizedBox(height: 100), // Space for FAB
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildStartButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildAppBar(bool isAIGenerated) {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: Colors.black,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF000000),
                Color(0xFF1A1A1A),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Elegant pattern overlay
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: CustomPaint(
                    painter: _ElegantPatternPainter(),
                  ),
                ),
              ),
              // Content
              Positioned(
                bottom: 40,
                left: 24,
                right: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges
                    Row(
                      children: [
                        if (isAIGenerated)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome_rounded,
                                    size: 12, color: Colors.black),
                                SizedBox(width: 6),
                                Text(
                                  'AI Generated',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            widget.routine.isCustom ? 'CUSTOM' : 'TEMPLATE',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Text(
                      widget.routine.name,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Stats
                    Row(
                      children: [
                        _buildStatChip(
                          Icons.fitness_center_outlined,
                          '${widget.routine.exercises.length} exercises',
                        ),
                        const SizedBox(width: 12),
                        _buildStatChip(
                          Icons.schedule_outlined,
                          '${widget.routine.estimatedDurationMinutes} min',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        if (ExerciseImageService.isExerciseDbConfigured)
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                _showEnhancedData
                    ? Icons.science_rounded
                    : Icons.science_outlined,
                color: Colors.white,
              ),
              onPressed: () {
                if (mounted) {
                  setState(() {
                    _showEnhancedData = !_showEnhancedData;
                  });
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildStatChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.9)),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutOverview() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(color: const Color(0xFF3A3A43), width: 1)
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Workout Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildOverviewStat(
                  Icons.schedule_outlined,
                  '${widget.routine.estimatedDurationMinutes}',
                  'Minutes',
                  Colors.black,
                ),
              ),
              Expanded(
                child: _buildOverviewStat(
                  Icons.fitness_center_outlined,
                  '${widget.routine.exercises.length}',
                  'Exercises',
                  Colors.black,
                ),
              ),
              Expanded(
                child: _buildOverviewStat(
                  Icons.trending_up_outlined,
                  widget.routine.difficulty.toUpperCase(),
                  'Level',
                  Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildProgressStats(isDark),
        ],
      ),
    );
  }

  Widget _buildProgressStats(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: isDark
            ? Border.all(color: const Color(0xFF3A3A43), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 16,
                color: isDark ? Colors.white : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 8),
              Text(
                'Your Progress',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildProgressItem(
                  widget.routine.isCustom
                      ? 'Custom Workouts This Week'
                      : 'Total Workouts This Week',
                  _isLoadingStats
                      ? '...'
                      : widget.routine.isCustom
                          ? (_customRoutinesThisWeek > 0
                              ? '$_customRoutinesThisWeek 💪'
                              : 'None yet')
                          : (_totalWorkoutsThisWeek > 0
                              ? '$_totalWorkoutsThisWeek 💪'
                              : 'None yet'),
                  Icons.playlist_add_check_outlined,
                  (widget.routine.isCustom
                              ? _customRoutinesThisWeek
                              : _totalWorkoutsThisWeek) >
                          0
                      ? Colors.blue
                      : Colors.grey,
                  isDark,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildProgressItem(
                  'Current Streak',
                  _isLoadingStats
                      ? '...'
                      : _streakDays > 0
                          ? '$_streakDays ${_streakDays == 1 ? 'day' : 'days'} 🔥'
                          : 'Start today!',
                  Icons.local_fire_department_outlined,
                  _streakDays > 0 ? Colors.orange : Colors.grey,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(
      String label, String value, IconData icon, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFE5E7EB)
                      : const Color(0xFF6B7280),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF1F2937),
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewStat(
      IconData icon, String value, String label, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              Icon(icon, color: isDark ? Colors.white : Colors.black, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildDescription() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(color: const Color(0xFF3A3A43), width: 1)
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Description',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.routine.description.isNotEmpty
                ? widget.routine.description
                : 'A comprehensive workout routine designed to help you achieve your fitness goals. Each exercise has been carefully selected for maximum effectiveness.',
            style: const TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Color(0xFF6B7280),
            ),
          ),
          if (widget.routine.targetMuscles.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Target Muscles',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.routine.targetMuscles.map((muscle) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    muscle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExercisesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isDark
            ? Border.all(color: const Color(0xFF3A3A43), width: 1)
            : null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Exercises',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                if (ExerciseImageService.isExerciseDbConfigured)
                  GestureDetector(
                    onTap: () {
                      if (mounted) {
                        setState(() {
                          _showEnhancedData = !_showEnhancedData;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _showEnhancedData
                            ? Colors.black.withValues(alpha: 0.1)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 14,
                            color:
                                _showEnhancedData ? Colors.black : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Enhanced Data',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: _showEnhancedData
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.routine.exercises.length,
            separatorBuilder: (context, index) => const Divider(
              height: 1,
              color: Color(0xFFF3F4F6),
            ),
            itemBuilder: (context, index) {
              return _buildExerciseItem(
                  widget.routine.exercises[index], index + 1);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseItem(WorkoutExercise exercise, int index) {
    final exerciseName = exercise.exercise?.name ?? 'Exercise $index';
    final enhancedData = _exerciseDataCache[exerciseName];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Exercise number
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Exercise details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exerciseName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${exercise.sets.length} sets • ${_getSetsDescription(exercise)}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
                if (_showEnhancedData && enhancedData != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (enhancedData['target'] != null)
                          _buildDataPoint('Target', enhancedData['target']),
                        if (enhancedData['equipment'] != null)
                          _buildDataPoint(
                              'Equipment', enhancedData['equipment']),
                        if (enhancedData['bodyPart'] != null)
                          _buildDataPoint(
                              'Body Part', enhancedData['bodyPart']),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Sets preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${exercise.sets.length} sets',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataPoint(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: () => _startWorkout(),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.black.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_arrow_rounded, size: 24),
            SizedBox(width: 8),
            Text(
              'Start Workout',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getSetsDescription(WorkoutExercise exercise) {
    if (exercise.sets.isEmpty) return 'No sets defined';

    final firstSet = exercise.sets.first;
    if (firstSet.durationSeconds != null) {
      return '${firstSet.durationSeconds}s each';
    } else {
      return '${firstSet.reps} reps each';
    }
  }

  void _startWorkout() async {
    try {
      final workoutProvider =
          Provider.of<WorkoutPlanningProvider>(context, listen: false);

      // If we don't have workout logs loaded yet, try to load them
      if (workoutProvider.workoutLogs.isEmpty) {
        // You might want to get the actual user ID from your auth system
        // For now, we'll proceed without loading logs
        print('No workout logs available - continuing to workout execution');
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => WorkoutExecutionScreen(routine: widget.routine),
        ),
      );

      // When returning from workout execution, refresh the stats
      if (mounted) {
        _refreshWorkoutStats();
      }
    } catch (e) {
      print('Error starting workout: $e');
      // Still allow the user to start the workout even if stats loading fails
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                WorkoutExecutionScreen(routine: widget.routine),
          ),
        );
      }
    }
  }
}

class _ElegantPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Draw elegant diagonal lines
    for (int i = 0; i < 10; i++) {
      final startX = (size.width / 10) * i;
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + size.height * 0.2, size.height),
        paint,
      );
    }

    // Draw horizontal accent lines
    for (int i = 0; i < 6; i++) {
      final y = (size.height / 6) * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width * 0.3, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
