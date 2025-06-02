import 'package:flutter/material.dart';
import '../models/workout_plan.dart';
import '../theme/workout_colors.dart';
import '../screens/workout_execution_screen.dart';
import '../services/exercise_image_service.dart';

class WorkoutDetailsScreen extends StatefulWidget {
  final WorkoutRoutine routine;

  const WorkoutDetailsScreen({super.key, required this.routine});

  @override
  State<WorkoutDetailsScreen> createState() => _WorkoutDetailsScreenState();
}

class _WorkoutDetailsScreenState extends State<WorkoutDetailsScreen> {
  final Set<String> _preloadedImages = {};
  bool _hasPreloadedImages = false;
  late final ExerciseImageService _imageService;
  bool _showEnhancedData = false;
  final Map<String, Map<String, dynamic>?> _exerciseDataCache = {};

  @override
  void initState() {
    super.initState();
    _imageService = ExerciseImageService();
    _loadExerciseData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasPreloadedImages) {
      _preloadExerciseImages();
      _hasPreloadedImages = true;
    }
  }

  Future<void> _loadExerciseData() async {
    // Load enhanced exercise data from ExerciseDB
    for (final exercise in widget.routine.exercises) {
      final exerciseName = exercise.exercise?.name ?? '';
      if (exerciseName.isNotEmpty) {
        final data = await _imageService.getExerciseData(exerciseName);
        setState(() {
          _exerciseDataCache[exerciseName] = data;
        });
      }
    }
  }

  void _preloadExerciseImages() async {
    // Preload images for better performance
    for (final exercise in widget.routine.exercises) {
      final exerciseName = exercise.exercise?.name ?? '';
      try {
        final imageUrl = exercise.exercise?.imageUrl ??
            await _imageService.getExerciseImageUrl(exerciseName);

        if (imageUrl.isNotEmpty && !_preloadedImages.contains(imageUrl)) {
          _preloadedImages.add(imageUrl);
          if (!mounted) return;
          precacheImage(NetworkImage(imageUrl), context).catchError((error) {
            // Silently handle preload failures
            print('Failed to preload image for $exerciseName: $imageUrl');
          });
        }
      } catch (e) {
        print('Error getting image URL for $exerciseName: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final workoutColor = WorkoutColors.getWorkoutCategoryColor(
        widget.routine.name, widget.routine.targetMuscles);
    final isAIGenerated =
        !widget.routine.isCustom && widget.routine.name.contains('AI');

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildModernAppBar(context, workoutColor, isAIGenerated),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildQuickStats(workoutColor),
                const SizedBox(height: 24),
                _buildSimplifiedDescription(),
                const SizedBox(height: 24),
                _buildExercisePreview(),
              ]),
            ),
          ),
        ],
      ),
      floatingActionButton:
          _buildFloatingActionButton(context, workoutColor, isAIGenerated),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildModernAppBar(
      BuildContext context, Color workoutColor, bool isAIGenerated) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      elevation: 0,
      backgroundColor: workoutColor,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(((0.2) * 255).round()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      actions: [
        // ExerciseDB Integration Status
        if (ExerciseImageService.isExerciseDbConfigured)
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(((0.2) * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: Icon(
                _showEnhancedData ? Icons.science : Icons.fitness_center,
                color: Colors.white,
              ),
              onPressed: () {
                setState(() {
                  _showEnhancedData = !_showEnhancedData;
                });
              },
              tooltip: _showEnhancedData
                  ? 'Hide ExerciseDB Data'
                  : 'Show ExerciseDB Data',
            ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                workoutColor,
                workoutColor.withAlpha(((0.9) * 255).round()),
              ],
            ),
          ),
          child: Stack(
            children: [
              // Subtle background pattern
              Positioned.fill(
                child: Opacity(
                  opacity: 0.08,
                  child: CustomPaint(
                    painter: _ModernPatternPainter(),
                  ),
                ),
              ),
              // Main content
              Positioned(
                bottom: 32,
                left: 20,
                right: 20,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badges Row
                    Row(
                      children: [
                        // AI Generated Badge
                        if (isAIGenerated)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                Color(0xFFFF6B35),
                                Color(0xFF4F46E5)
                              ]),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'AI Generated',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white
                                  .withAlpha(((0.25) * 255).round()),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.routine.isCustom ? 'Custom' : 'Template',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),

                        const SizedBox(width: 8),

                        // ExerciseDB Integration Badge
                        if (ExerciseImageService.isExerciseDbConfigured)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withAlpha(((0.9) * 255).round()),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.science,
                                    size: 14, color: Colors.white),
                                SizedBox(width: 6),
                                Text(
                                  'ExerciseDB',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Title
                    Text(
                      widget.routine.name,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Subtitle with enhanced data
                    Text(
                      '${widget.routine.exercises.length} exercises • ${widget.routine.estimatedDurationMinutes} min',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withAlpha(((0.9) * 255).round()),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (ExerciseImageService.isExerciseDbConfigured) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Powered by professional exercise database',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withAlpha(((0.7) * 255).round()),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickStats(Color workoutColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem(
              Icons.schedule_outlined,
              '${widget.routine.estimatedDurationMinutes}',
              'Minutes',
              workoutColor,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          Expanded(
            child: _buildStatItem(
              Icons.fitness_center_outlined,
              '${widget.routine.exercises.length}',
              'Exercises',
              workoutColor,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey[300],
          ),
          Expanded(
            child: _buildStatItem(
              Icons.trending_up_outlined,
              widget.routine.difficulty.substring(0, 1).toUpperCase() +
                  widget.routine.difficulty.substring(1).toLowerCase(),
              'Level',
              workoutColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSimplifiedDescription() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(((0.05) * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'About This Workout',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1a1a1a),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.routine.description,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
              height: 1.5,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.routine.targetMuscles.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.routine.targetMuscles
                  .take(4)
                  .map(
                    (muscle) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        muscle,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExercisePreview() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(((0.05) * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Exercise Preview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1a1a1a),
                      ),
                    ),
                    if (ExerciseImageService.isExerciseDbConfigured &&
                        _showEnhancedData)
                      Text(
                        'Enhanced with ExerciseDB',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${widget.routine.exercises.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[700],
                        ),
                      ),
                    ),
                    if (ExerciseImageService.isExerciseDbConfigured) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _showEnhancedData = !_showEnhancedData;
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _showEnhancedData
                                ? Colors.green[100]
                                : Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.science,
                            size: 16,
                            color: _showEnhancedData
                                ? Colors.green[600]
                                : Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          SizedBox(
            height: _showEnhancedData ? 200 : 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(left: 20, bottom: 20),
              itemCount: widget.routine.exercises.length,
              itemBuilder: (context, index) {
                final exercise = widget.routine.exercises[index];
                return _buildEnhancedExercisePreviewCard(exercise, index + 1);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedExercisePreviewCard(
      WorkoutExercise exercise, int index) {
    final exerciseName = exercise.exercise?.name ?? 'Exercise $index';
    final category = _imageService.getExerciseCategory(exerciseName);
    final exerciseData = _exerciseDataCache[exerciseName];

    return Container(
      width: _showEnhancedData ? 180 : 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(((0.08) * 255).round()),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background image or gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _getCategoryColor(category)
                        .withAlpha(((0.8) * 255).round()),
                    _getCategoryColor(category),
                  ],
                ),
              ),
              child: _buildExerciseImageAsync(exerciseName, category),
            ),
            // Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withAlpha(((0.7) * 255).round()),
                  ],
                ),
              ),
            ),
            // Exercise number
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(((0.9) * 255).round()),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1a1a1a),
                    ),
                  ),
                ),
              ),
            ),
            // Enhanced data badge
            if (_showEnhancedData && exerciseData != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(((0.9) * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.science,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              )
            else
              // Category badge
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(((0.9) * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: _getCategoryColor(category),
                    ),
                  ),
                ),
              ),

            // Exercise information
            Positioned(
              bottom: 8,
              left: 8,
              right: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Exercise name
                  Text(
                    exerciseName,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    maxLines: _showEnhancedData ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // Enhanced data when available
                  if (_showEnhancedData && exerciseData != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(((0.6) * 255).round()),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Equipment: ${exerciseData['equipment'] ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Target: ${exerciseData['target'] ?? 'N/A'}',
                            style: const TextStyle(
                              fontSize: 8,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (exerciseData['difficulty'] != null)
                            Text(
                              'Level: ${exerciseData['difficulty']}',
                              style: TextStyle(
                                fontSize: 8,
                                color: _getDifficultyColor(
                                    exerciseData['difficulty']),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Tap overlay for exercise details
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showExerciseDetails(exerciseName, exerciseData),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseImageAsync(String exerciseName, String category) {
    return FutureBuilder<String>(
      future: _imageService.getExerciseImageUrl(exerciseName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildImageLoadingState();
        }

        if (snapshot.hasData && snapshot.data != null) {
          final imageUrl = snapshot.data!;

          // Check if it's a placeholder URL (indicates fallback to category image)
          if (imageUrl.contains('placehold.co')) {
            return _buildCategoryFallback(exerciseName, category);
          }

          return Image.network(
            imageUrl,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return _buildImageLoadingState();
            },
            errorBuilder: (context, error, stackTrace) {
              print('Image failed to load for $exerciseName: $imageUrl');
              return _buildCategoryFallback(exerciseName, category);
            },
          );
        }

        // Fallback to category image
        return _buildCategoryFallback(exerciseName, category);
      },
    );
  }

  Widget _buildImageLoadingState() {
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
              Colors.white.withAlpha(((0.8) * 255).round())),
        ),
      ),
    );
  }

  Widget _buildCategoryFallback(String exerciseName, String category) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _getCategoryColor(category).withAlpha(((0.8) * 255).round()),
            _getCategoryColor(category),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(((0.2) * 255).round()),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getCategoryIcon(category),
              size: 28,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              _getShortExerciseName(exerciseName),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _getShortExerciseName(String exerciseName) {
    // Extract key words for display
    final words = exerciseName.split(' ');
    if (words.length <= 2) return exerciseName;

    // Return first two meaningful words
    final meaningfulWords = words
        .where((word) =>
            word.length > 2 &&
            !['the', 'and', 'for', 'with'].contains(word.toLowerCase()))
        .take(2)
        .join(' ');

    return meaningfulWords.isNotEmpty ? meaningfulWords : exerciseName;
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Chest':
        return const Color(0xFF3B82F6);
      case 'Back':
        return const Color(0xFF10B981);
      case 'Shoulders':
        return const Color(0xFFF59E0B);
      case 'Arms':
        return const Color(0xFF06B6D4);
      case 'Legs':
        return const Color(0xFF8B5CF6);
      case 'Core':
        return const Color(0xFFF59E0B);
      case 'Cardio':
        return const Color(0xFFEF4444);
      case 'Full Body':
        return const Color(0xFF059669);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Chest':
      case 'Arms':
      case 'Shoulders':
        return Icons.fitness_center;
      case 'Back':
        return Icons.arrow_downward;
      case 'Legs':
        return Icons.airline_seat_legroom_extra;
      case 'Core':
        return Icons.self_improvement;
      case 'Cardio':
        return Icons.directions_run;
      case 'Full Body':
        return Icons.sports_gymnastics;
      default:
        return Icons.fitness_center;
    }
  }

  Widget _buildFloatingActionButton(
      BuildContext context, Color workoutColor, bool isAIGenerated) {
    return Container(
      width: MediaQuery.of(context).size.width - 40,
      height: 56,
      decoration: BoxDecoration(
        gradient: isAIGenerated
            ? const LinearGradient(
                colors: [Color(0xFFFF6B35), Color(0xFF4F46E5)])
            : LinearGradient(colors: [
                workoutColor,
                workoutColor.withAlpha(((0.8) * 255).round())
              ]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: workoutColor.withAlpha(((0.3) * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _startWorkout(context),
          borderRadius: BorderRadius.circular(28),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow, color: Colors.white, size: 24),
              SizedBox(width: 12),
              Text(
                'Start Workout',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startWorkout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => WorkoutExecutionScreen(routine: widget.routine),
      ),
    );
  }

  void _showExerciseDetails(
      String exerciseName, Map<String, dynamic>? exerciseData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _buildExerciseDetailsModal(exerciseName, exerciseData),
    );
  }

  Widget _buildExerciseDetailsModal(
      String exerciseName, Map<String, dynamic>? exerciseData) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Exercise name and category
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            exerciseName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1a1a1a),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getCategoryColor(_imageService
                                    .getExerciseCategory(exerciseName))
                                .withAlpha(((0.1) * 255).round()),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            _imageService.getExerciseCategory(exerciseName),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getCategoryColor(_imageService
                                  .getExerciseCategory(exerciseName)),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // Exercise GIF/Image
                    FutureBuilder<String>(
                      future: _imageService.getExerciseImageUrl(exerciseName),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Container(
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black
                                      .withAlpha(((0.1) * 255).round()),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildCategoryFallback(
                                      exerciseName,
                                      _imageService
                                          .getExerciseCategory(exerciseName));
                                },
                              ),
                            ),
                          );
                        }
                        return Container(
                          height: 200,
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child:
                              const Center(child: CircularProgressIndicator()),
                        );
                      },
                    ),

                    if (exerciseData != null) ...[
                      const SizedBox(height: 24),

                      // Enhanced ExerciseDB Data Section
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.science,
                                    color: Colors.green[600], size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'ExerciseDB Professional Data',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.green[800],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Equipment
                            _buildDetailRow('Equipment',
                                exerciseData['equipment'] ?? 'N/A'),

                            // Target muscle
                            _buildDetailRow('Primary Target',
                                exerciseData['target'] ?? 'N/A'),

                            // Body part
                            _buildDetailRow(
                                'Body Part', exerciseData['bodyPart'] ?? 'N/A'),

                            // Difficulty
                            if (exerciseData['difficulty'] != null)
                              _buildDetailRow(
                                  'Difficulty', exerciseData['difficulty'],
                                  color: _getDifficultyColor(
                                      exerciseData['difficulty'])),

                            // Secondary muscles
                            if (exerciseData['secondaryMuscles'] != null &&
                                (exerciseData['secondaryMuscles'] as List)
                                    .isNotEmpty)
                              _buildDetailRow(
                                  'Secondary Muscles',
                                  (exerciseData['secondaryMuscles'] as List)
                                      .join(', ')),
                          ],
                        ),
                      ),

                      // Instructions
                      if (exerciseData['instructions'] != null &&
                          (exerciseData['instructions'] as List)
                              .isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text(
                          'Exercise Instructions',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1a1a1a),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: (exerciseData['instructions'] as List)
                                .asMap()
                                .entries
                                .map((entry) => Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 24,
                                            height: 24,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3B82F6),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Center(
                                              child: Text(
                                                '${entry.key + 1}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              entry.value,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                height: 1.5,
                                                color: Color(0xFF374151),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ] else ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange[600]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Enhanced exercise data not available. Using local exercise database.',
                                style: TextStyle(
                                  color: Colors.orange[800],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    // Close button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Close',
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
            ],
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color ?? const Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return const Color(0xFF10B981); // Green
      case 'intermediate':
        return const Color(0xFFF59E0B); // Orange
      case 'advanced':
        return const Color(0xFFEF4444); // Red
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }
}

class _ModernPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw a modern hexagonal pattern
    final spacing = 60.0;
    for (double x = 0; x < size.width + spacing; x += spacing) {
      for (double y = 0; y < size.height + spacing; y += spacing * 0.866) {
        final offset = (y / (spacing * 0.866)) % 2 == 1 ? spacing / 2 : 0;
        _drawHexagon(canvas, Offset(x + offset, y), 15, paint);
      }
    }
  }

  void _drawHexagon(Canvas canvas, Offset center, double radius, Paint paint) {
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final x = center.dx +
          radius * (i == 0 ? 1 : (i < 3 ? 0.5 : (i == 3 ? -1 : -0.5)));
      final y = center.dy +
          radius *
              (i < 2
                  ? (i == 0 ? 0 : 0.866)
                  : (i < 4
                      ? (i == 2 ? 0.866 : 0)
                      : (i == 4 ? -0.866 : -0.866)));

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
