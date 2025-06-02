import 'package:flutter/material.dart';
import '../models/workout_plan.dart';
import '../models/exercise.dart';
import '../services/workout_planning_service.dart';
import '../services/fitness_ai_service.dart';
import '../services/fitness_data_service.dart';
import '../theme/workout_colors.dart';
import 'package:uuid/uuid.dart';
import 'workout_execution_screen.dart';
import 'workout_details_screen.dart';
import 'onboarding/onboarding_screen.dart';

class WorkoutPlanningScreen extends StatefulWidget {
  const WorkoutPlanningScreen({super.key});

  @override
  State<WorkoutPlanningScreen> createState() => _WorkoutPlanningScreenState();
}

class _WorkoutPlanningScreenState extends State<WorkoutPlanningScreen>
    with WidgetsBindingObserver {
  final WorkoutPlanningService _workoutService = WorkoutPlanningService();
  final FitnessAIService _aiService = FitnessAIService();
  final FitnessDataService _dataService = FitnessDataService();
  final Uuid _uuid = const Uuid();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<WorkoutRoutine> _routines = [];
  List<WorkoutRoutine> _filteredRoutines = [];
  bool _isLoading = false;
  bool _aiAvailable = false;
  String? _error;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeData() async {
    _aiService.initialize();
    await _checkAIAvailability();
    await _loadWorkoutRoutines();
    _searchController.addListener(_filterRoutines);
  }

  Future<void> _checkAIAvailability() async {
    try {
      final isReady = await _dataService.isReadyForAIRecommendations();
      if (mounted) {
        setState(() => _aiAvailable = isReady);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiAvailable = false);
      }
    }
  }

  Future<void> _loadWorkoutRoutines() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final routines = await _workoutService.getWorkoutRoutines();
      setState(() {
        _routines = routines;
        _filteredRoutines = routines;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load workout routines: $e';
        _isLoading = false;
      });
    }
  }

  void _filterRoutines() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty && _selectedFilter == 'All') {
        _filteredRoutines = _routines;
      } else {
        _filteredRoutines = _routines.where((routine) {
          final matchesSearch = query.isEmpty ||
              routine.name.toLowerCase().contains(query) ||
              routine.description.toLowerCase().contains(query);
          final matchesFilter = _selectedFilter == 'All' ||
              _getWorkoutCategory(routine) == _selectedFilter;
          return matchesSearch && matchesFilter;
        }).toList();
      }
    });
  }

  String _getWorkoutCategory(WorkoutRoutine routine) {
    final name = routine.name.toLowerCase();
    if (name.contains('cardio')) return 'Cardio';
    if (name.contains('strength')) return 'Strength';
    if (name.contains('yoga')) return 'Flexibility';
    if (name.contains('hiit')) return 'HIIT';
    return 'Strength';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _buildBody(),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E293B), Color(0xFF334155)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Workouts',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Transform your body, elevate your mind',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withAlpha(((0.8) * 255).round()),
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _loadWorkoutRoutines,
                icon: const Icon(Icons.refresh, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withAlpha(((0.15) * 255).round()),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildStatsRow(),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('${_routines.length}', 'Workouts', Icons.fitness_center),
        const SizedBox(width: 16),
        _buildStatCard('3', 'This Week', Icons.calendar_today_outlined),
        const SizedBox(width: 16),
        _buildStatCard('7', 'Day Streak', Icons.local_fire_department_outlined),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(((0.12) * 255).round()),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withAlpha(((0.1) * 255).round()),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: Colors.white.withAlpha(((0.8) * 255).round()),
              size: 20,
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.white.withAlpha(((0.7) * 255).round()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();

    return RefreshIndicator(
      onRefresh: _loadWorkoutRoutines,
      color: const Color(0xFFFF6B35),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (!_aiAvailable) _buildAIBanner(),
                const SizedBox(height: 24),
                _buildSearchBar(),
                const SizedBox(height: 20),
                _buildFilterChips(),
                const SizedBox(height: 24),
                _buildWorkoutSection(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7).withAlpha(((0.5) * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF59E0B).withAlpha(((0.3) * 255).round())),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline,
                  color: Color(0xFFF59E0B), size: 24),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete Fitness Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Complete onboarding to unlock AI-powered workouts',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildButton(
                  text: 'Complete Profile',
                  onPressed: () => _navigateToOnboarding(),
                  isPrimary: true,
                  color: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withAlpha(((0.04) * 255).round()),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search workouts...',
          prefixIcon:
              const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear,
                      color: Color(0xFF9CA3AF), size: 20),
                  onPressed: () => _searchController.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = ['All', 'Strength', 'Cardio', 'Flexibility', 'HIIT'];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter;
          return GestureDetector(
            onTap: () {
              setState(() => _selectedFilter = filter);
              _filterRoutines();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkoutSection() {
    if (_routines.isEmpty) return _buildEmptyState();
    if (_filteredRoutines.isEmpty) return _buildEmptySearchResults();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Your Routines',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_filteredRoutines.length}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...List.generate(
          _filteredRoutines.length,
          (index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildWorkoutCard(_filteredRoutines[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutCard(WorkoutRoutine routine) {
    final workoutColor = WorkoutColors.getWorkoutCategoryColor(
        routine.name, routine.targetMuscles);
    final isAIGenerated = !routine.isCustom && routine.name.contains('AI');

    return GestureDetector(
      onTap: () => _showWorkoutDetails(routine),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: workoutColor.withAlpha(((0.2) * 255).round())),
          boxShadow: [
            BoxShadow(
              color: workoutColor.withAlpha(((0.08) * 255).round()),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 48,
                  decoration: BoxDecoration(
                    color: workoutColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final availableWidth = constraints.maxWidth;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  routine.name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                    height: 1.2,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: availableWidth * 0.3,
                                ),
                                child: isAIGenerated
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFFF6B35),
                                              Color(0xFF4F46E5)
                                            ],
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.auto_awesome,
                                                size: 12, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text(
                                              'AI',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: workoutColor.withAlpha(((0.1) * 255).round()),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          routine.isCustom
                                              ? 'CUSTOM'
                                              : 'TEMPLATE',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: workoutColor,
                                          ),
                                        ),
                                      ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 28,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          clipBehavior: Clip.none,
                          child: Row(
                            children: [
                              _buildInfoChip(routine.difficulty.toUpperCase(),
                                  workoutColor),
                              const SizedBox(width: 8),
                              _buildInfoChip(
                                  '${routine.estimatedDurationMinutes}MIN',
                                  const Color(0xFF64748B)),
                              const SizedBox(width: 8),
                              _buildInfoChip('${routine.exercises.length} EX',
                                  workoutColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 110,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => _deleteWorkout(routine),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withAlpha(((0.1) * 255).round()),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withAlpha(((0.2) * 255).round()),
                            ),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => _startWorkout(routine),
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: isAIGenerated
                                ? const LinearGradient(colors: [
                                    Color(0xFFFF6B35),
                                    Color(0xFF4F46E5)
                                  ])
                                : LinearGradient(colors: [
                                    workoutColor,
                                    workoutColor.withAlpha(((0.8) * 255).round())
                                  ]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.play_arrow,
                              color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              routine.description,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(((0.1) * 255).round()),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(((0.3) * 255).round())),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF1E293B)),
          SizedBox(height: 16),
          Text(
            'Loading workouts...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFF64748B)),
            const SizedBox(height: 16),
            const Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildButton(
              text: 'Try Again',
              onPressed: _loadWorkoutRoutines,
              isPrimary: true,
              color: const Color(0xFF1E293B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fitness_center,
                size: 64, color: Color(0xFF64748B)),
            const SizedBox(height: 24),
            const Text(
              'Ready to begin?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first workout or let AI design the perfect routine for you',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _buildButton(
              text: 'Create Workout',
              onPressed: _createNewWorkoutRoutine,
              isPrimary: true,
              color: const Color(0xFF1E293B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchResults() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          children: [
            const Icon(Icons.search_off, size: 48, color: Color(0xFF64748B)),
            const SizedBox(height: 16),
            const Text(
              'No workouts found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try adjusting your search terms',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 24),
            _buildButton(
              text: 'Clear Search',
              onPressed: () => _searchController.clear(),
              isPrimary: false,
              color: const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _showActionBottomSheet,
      backgroundColor: const Color(0xFFFF6B35),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text(
        'New Workout',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildButton({
    required String text,
    required VoidCallback onPressed,
    required bool isPrimary,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isPrimary ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }

  void _showActionBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Create New Workout',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 24),
            _ActionTile(
              icon: Icons.add,
              title: 'Custom Workout',
              subtitle: 'Create your own workout routine',
              onTap: () {
                Navigator.pop(context);
                _createNewWorkoutRoutine();
              },
            ),
            const SizedBox(height: 12),
            _ActionTile(
              icon: Icons.auto_awesome,
              title: _aiAvailable ? 'AI Generated' : 'Basic Workout',
              subtitle: _aiAvailable
                  ? 'Let AI create a personalized workout'
                  : 'Generate a template-based workout',
              gradient: _aiAvailable
                  ? const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFF4F46E5)])
                  : null,
              onTap: () {
                Navigator.pop(context);
                _generateWorkoutRoutine();
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showWorkoutDetails(WorkoutRoutine routine) {
    WorkoutColors.getWorkoutCategoryColor(
        routine.name, routine.targetMuscles);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkoutDetailsScreen(routine: routine),
      ),
    );
  }

  Future<void> _createNewWorkoutRoutine() async {
    // Implementation for creating new workout
    _showSnackBar('Feature coming soon!', false);
  }

  Future<void> _generateWorkoutRoutine() async {
    if (!_aiAvailable) {
      _showSnackBar(
          'Complete your fitness profile first to use AI workouts', false);
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'AI Creating Your Workout',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Our AI is analyzing your fitness profile and creating a personalized workout just for you...',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: Color(0xFF4F46E5),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // Get user's fitness profile and macro data
      final fitnessProfile = await _dataService.getCurrentFitnessProfile();
      final macroData = await _dataService.getMacroData();

      // Generate AI workout
      final aiWorkoutData = await _aiService.generateWorkoutPlan(
        fitnessProfile: fitnessProfile,
        macroData: macroData,
      );

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (aiWorkoutData.isNotEmpty) {
        debugPrint('AI Workout Data: $aiWorkoutData');

        // Convert AI workout data to WorkoutRoutine
        final aiWorkoutRoutine = _convertAIWorkoutToRoutine(aiWorkoutData);

        debugPrint(
            'Converted Workout Routine - Name: ${aiWorkoutRoutine.name}');
        debugPrint(
            'Converted Workout Routine - Difficulty: ${aiWorkoutRoutine.difficulty}');
        debugPrint(
            'Converted Workout Routine - Equipment: ${aiWorkoutRoutine.requiredEquipment}');
        debugPrint(
            'Converted Workout Routine - Exercises: ${aiWorkoutRoutine.exercises.length}');

        // Save the AI-generated workout
        final savedRoutine =
            await _workoutService.createWorkoutRoutine(aiWorkoutRoutine);

        if (savedRoutine != null) {
          // Refresh the workout list
          await _loadWorkoutRoutines();

          _showSnackBar('AI workout created successfully!', true);

          // Show the new workout details
          _showWorkoutDetails(savedRoutine);
        } else {
          _showSnackBar('Failed to save AI workout. Please try again.', false);
        }
      } else {
        _showSnackBar(
            'Failed to generate AI workout. Please try again.', false);
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.pop(context);

      debugPrint('Error generating AI workout: $e');
      _showSnackBar('Failed to generate AI workout: $e', false);
    }
  }

  WorkoutRoutine _convertAIWorkoutToRoutine(
      Map<String, dynamic> aiWorkoutData) {
    // Convert AI-generated data to WorkoutRoutine format
    final exercises = <WorkoutExercise>[];

    // Only add main exercises - warm-up and cool-down will be in description
    if (aiWorkoutData['main_exercises'] != null) {
      for (final exerciseData in aiWorkoutData['main_exercises']) {
        final numSets = exerciseData['sets'] ?? 3;
        final repsStr = exerciseData['reps']?.toString() ?? '10-12';
        final reps = _parseReps(repsStr);

        final sets = List.generate(numSets, (index) => WorkoutSet(reps: reps));

        exercises.add(WorkoutExercise(
          id: _uuid.v4(),
          exerciseId: _uuid.v4(),
          sets: sets,
          restSeconds: _parseRestSeconds(exerciseData['rest']),
          notes: exerciseData['instructions'] ?? '',
          isCompleted: false,
          exercise: Exercise(
            id: _uuid.v4(),
            name: exerciseData['exercise'] ?? 'Exercise',
            description: exerciseData['instructions'] ?? '',
            instructions: [exerciseData['instructions'] ?? ''],
            primaryMuscles:
                List<String>.from(exerciseData['muscle_groups'] ?? ['general']),
            secondaryMuscles: [],
            equipment: List<String>.from(
                exerciseData['equipment_needed'] ?? ['bodyweight']),
            difficulty: _normalizeDifficulty(aiWorkoutData['difficulty_level']),
            type: 'strength',
            isCompound:
                (exerciseData['muscle_groups'] as List?)?.length != null &&
                    (exerciseData['muscle_groups'] as List).length > 1,
            imageUrl: null,
            videoUrl: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ));
      }
    }

    // Build comprehensive description including warm-up and cool-down
    final description = _buildWorkoutDescription(aiWorkoutData);

    return WorkoutRoutine(
      id: _uuid.v4(),
      name: aiWorkoutData['workout_name'] ?? 'AI Generated Workout',
      description: description,
      difficulty: _normalizeDifficulty(aiWorkoutData['difficulty_level']),
      estimatedDurationMinutes: aiWorkoutData['estimated_duration'] ?? 45,
      targetMuscles: List<String>.from(
          aiWorkoutData['muscle_groups_targeted'] ?? ['full body']),
      requiredEquipment: _normalizeEquipment(aiWorkoutData),
      exercises: exercises,
      isCustom: false, // AI-generated workouts are not custom
      createdBy: '', // Will be set by the service
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  String _buildWorkoutDescription(Map<String, dynamic> aiWorkoutData) {
    final buffer = StringBuffer();

    // Add main description
    if (aiWorkoutData['notes'] != null) {
      buffer.writeln(aiWorkoutData['notes']);
      buffer.writeln();
    } else {
      buffer.writeln(
          'Personalized workout created by AI based on your fitness profile.');
      buffer.writeln();
    }

    // Add warm-up instructions
    if (aiWorkoutData['warm_up'] != null &&
        aiWorkoutData['warm_up'].isNotEmpty) {
      buffer.writeln('🔥 WARM-UP:');
      for (final warmUp in aiWorkoutData['warm_up']) {
        buffer.writeln('• ${warmUp['exercise']}: ${warmUp['duration']}');
        if (warmUp['instructions'] != null) {
          buffer.writeln('  ${warmUp['instructions']}');
        }
      }
      buffer.writeln();
    }

    // Add cool-down instructions
    if (aiWorkoutData['cool_down'] != null &&
        aiWorkoutData['cool_down'].isNotEmpty) {
      buffer.writeln('❄️ COOL-DOWN:');
      for (final coolDown in aiWorkoutData['cool_down']) {
        buffer.writeln('• ${coolDown['exercise']}: ${coolDown['duration']}');
        if (coolDown['instructions'] != null) {
          buffer.writeln('  ${coolDown['instructions']}');
        }
      }
      buffer.writeln();
    }

    // Add progression tips
    if (aiWorkoutData['progression_tips'] != null) {
      buffer.writeln('📈 PROGRESSION TIPS:');
      buffer.writeln(aiWorkoutData['progression_tips']);
    }

    return buffer.toString().trim();
  }

  String _normalizeDifficulty(dynamic difficulty) {
    if (difficulty == null) return 'intermediate';

    final difficultyStr = difficulty.toString().toLowerCase().trim();

    // Map various AI difficulty outputs to database constraints
    switch (difficultyStr) {
      case 'beginner':
      case 'easy':
      case 'novice':
      case 'starter':
        return 'beginner';
      case 'intermediate':
      case 'medium':
      case 'moderate':
      case 'regular':
        return 'intermediate';
      case 'advanced':
      case 'hard':
      case 'expert':
      case 'difficult':
      case 'challenging':
        return 'advanced';
      default:
        debugPrint(
            'Unknown difficulty level: $difficultyStr, defaulting to intermediate');
        return 'intermediate';
    }
  }

  int _parseReps(String repsStr) {
    // Parse reps from strings like "8-12", "10", "15-20"
    final match = RegExp(r'(\d+)(?:-\d+)?').firstMatch(repsStr);
    return int.tryParse(match?.group(1) ?? '10') ?? 10;
  }

  int _parseRestSeconds(dynamic rest) {
    if (rest == null) return 60;

    final restStr = rest.toString().toLowerCase();
    if (restStr.contains('minute')) {
      final minutes = RegExp(r'(\d+)').firstMatch(restStr)?.group(1);
      return (int.tryParse(minutes ?? '1') ?? 1) * 60;
    } else if (restStr.contains('second')) {
      final seconds = RegExp(r'(\d+)').firstMatch(restStr)?.group(1);
      return int.tryParse(seconds ?? '60') ?? 60;
    }

    // Try to parse as just a number (assume seconds)
    return int.tryParse(restStr) ?? 60;
  }

  List<String> _normalizeEquipment(Map<String, dynamic> aiWorkoutData) {
    final Set<String> equipment = {};

    // Get equipment from main exercises
    if (aiWorkoutData['main_exercises'] != null) {
      for (final exerciseData in aiWorkoutData['main_exercises']) {
        if (exerciseData['equipment_needed'] != null) {
          for (final item in exerciseData['equipment_needed']) {
            equipment.add(_normalizeEquipmentItem(item.toString()));
          }
        }
      }
    }

    // If no equipment found, default to bodyweight
    if (equipment.isEmpty) {
      equipment.add('bodyweight');
    }

    return equipment.toList();
  }

  String _normalizeEquipmentItem(String equipment) {
    final equipmentStr = equipment.toLowerCase().trim();

    // Map various AI equipment outputs to standardized values
    switch (equipmentStr) {
      case 'none':
      case 'bodyweight':
      case 'body weight':
      case 'no equipment':
        return 'bodyweight';
      case 'dumbbells':
      case 'dumbbell':
      case 'weights':
      case 'free weights':
        return 'dumbbells';
      case 'barbell':
      case 'barbells':
        return 'barbell';
      case 'resistance bands':
      case 'resistance band':
      case 'bands':
      case 'band':
        return 'resistance_bands';
      case 'pull-up bar':
      case 'pullup bar':
      case 'pull up bar':
        return 'pull_up_bar';
      case 'yoga mat':
      case 'mat':
      case 'exercise mat':
        return 'yoga_mat';
      case 'kettlebell':
      case 'kettlebells':
        return 'kettlebell';
      default:
        debugPrint(
            'Unknown equipment: $equipmentStr, defaulting to bodyweight');
        return 'bodyweight';
    }
  }

  Future<void> _startWorkout(WorkoutRoutine routine) async {
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => WorkoutExecutionScreen(routine: routine),
        ),
      );
    } catch (e) {
      _showSnackBar('Failed to start workout', false);
    }
  }

  void _navigateToOnboarding() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const OnboardingScreen()),
    );
    await _checkAIAvailability();
  }

  void _showSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle : Icons.error,
              color:
                  isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 8,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _deleteWorkout(WorkoutRoutine routine) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withAlpha(((0.1) * 255).round()),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFEF4444),
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Delete Workout?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Are you sure you want to delete "${routine.name}"? This action cannot be undone.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _buildButton(
                      text: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                      isPrimary: false,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildButton(
                      text: 'Delete',
                      onPressed: () => _confirmDeleteWorkout(routine),
                      isPrimary: true,
                      color: const Color(0xFFEF4444),
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

  Future<void> _confirmDeleteWorkout(WorkoutRoutine routine) async {
    Navigator.pop(context); // Close dialog

    try {
      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E293B)),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Deleting workout...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.white,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );

      debugPrint(
          'Attempting to delete workout: ${routine.name} (ID: ${routine.id})');
      debugPrint(
          'Workout created_by: ${routine.createdBy}, is_custom: ${routine.isCustom}');

      // Delete the workout using the service
      final success = await _workoutService.deleteWorkoutRoutine(routine.id);

      if (success) {
        // Remove from local lists immediately for better UX
        setState(() {
          _routines.removeWhere((r) => r.id == routine.id);
          _filteredRoutines.removeWhere((r) => r.id == routine.id);
        });

        _showSnackBar('Workout deleted successfully', true);

        // Refresh the list to ensure consistency
        await _loadWorkoutRoutines();
      } else {
        debugPrint('Delete operation returned false');

        // Reload to check if it was actually deleted
        await _loadWorkoutRoutines();

        // Check if the workout still exists
        final stillExists = _routines.any((r) => r.id == routine.id);
        if (stillExists) {
          _showSnackBar(
            'Unable to delete this workout. You may not have permission to delete it.',
            false,
          );
        } else {
          // It was actually deleted, update UI
          setState(() {
            _routines.removeWhere((r) => r.id == routine.id);
            _filteredRoutines.removeWhere((r) => r.id == routine.id);
          });
          _showSnackBar('Workout deleted successfully', true);
        }
      }
    } catch (e) {
      debugPrint('Error deleting workout: $e');

      // Refresh to see current state
      await _loadWorkoutRoutines();

      if (e.toString().contains('RLS') || e.toString().contains('policy')) {
        _showSnackBar(
          'Permission denied: You can only delete workouts you created.',
          false,
        );
      } else {
        _showSnackBar('Failed to delete workout: ${e.toString()}', false);
      }
    }
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Gradient? gradient;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: gradient == null ? const Color(0xFFF8FAFC) : null,
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                gradient != null ? Colors.transparent : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: gradient != null
                    ? Colors.white.withAlpha(((0.2) * 255).round())
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: gradient != null
                          ? Colors.white
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: gradient != null
                          ? Colors.white.withAlpha(((0.8) * 255).round())
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: gradient != null
                  ? Colors.white.withAlpha(((0.7) * 255).round())
                  : const Color(0xFF64748B),
            ),
          ],
        ),
      ),
    );
  }
}
