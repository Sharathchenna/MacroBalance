import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/workout_plan.dart';
import '../services/workout_planning_service.dart';
import '../models/user_preferences.dart';
import 'package:uuid/uuid.dart';
import 'workout_execution_screen.dart';

class WorkoutPlanningScreen extends StatefulWidget {
  const WorkoutPlanningScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutPlanningScreen> createState() => _WorkoutPlanningScreenState();
}

class _WorkoutPlanningScreenState extends State<WorkoutPlanningScreen>
    with SingleTickerProviderStateMixin {
  final WorkoutPlanningService _workoutService = WorkoutPlanningService();
  final Uuid _uuid = const Uuid();
  List<WorkoutRoutine> _routines = [];
  bool _isLoading = false;
  String? _error;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Enhanced Premium Color Palette
  static const Color primaryBlack = Color(0xFF000000);
  static const Color slate900 = Color(0xFF0F172A);
  static const Color slate800 = Color(0xFF1E293B);
  static const Color slate700 = Color(0xFF334155);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate50 = Color(0xFFF8FAFC);
  static const Color zinc50 = Color(0xFFFAFAFA);
  static const Color white = Color(0xFFFFFFFF);

  // Accent Colors
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald50 = Color(0xFFECFDF5);
  static const Color red500 = Color(0xFFEF4444);
  static const Color red50 = Color(0xFFFEF2F2);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue50 = Color(0xFFEFF6FF);

  // Premium Typography System
  static TextStyle get h1 => GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        color: slate900,
      );

  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        color: slate900,
      );

  static TextStyle get h3 => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        color: slate800,
      );

  static TextStyle get h4 => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: slate800,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
        color: slate700,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
        color: slate600,
      );

  static TextStyle get button => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        color: slate500,
      );

  static TextStyle get subtitle => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.3,
        color: slate500,
      );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadWorkoutRoutines();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load workout routines: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _createNewWorkoutRoutine() async {
    final result = await _showCreateWorkoutDialog();

    if (result != null) {
      setState(() => _isLoading = true);
      try {
        final routine = WorkoutRoutine(
          name: result['name'],
          description: result['description'],
          exercises: [],
          estimatedDurationMinutes: 45,
          difficulty: 'beginner',
          targetMuscles: [],
          requiredEquipment: [],
          isCustom: true,
        );

        final createdRoutine =
            await _workoutService.createWorkoutRoutine(routine);
        if (createdRoutine != null) {
          setState(() {
            _routines = [..._routines, createdRoutine];
          });
          _showPremiumSnackBar('Workout created successfully', true);
        }
      } catch (e) {
        _showPremiumSnackBar('Failed to create workout', false);
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateWorkoutRoutine() async {
    setState(() => _isLoading = true);
    try {
      final userPrefs = UserPreferences(
        userId: _uuid.v4(),
        targetCalories: 2000,
        targetProtein: 150,
        targetCarbohydrates: 200,
        targetFat: 65,
        equipment: EquipmentAvailability(
          available: ['Dumbbells', 'Bodyweight'],
          hasHomeEquipment: true,
        ),
        fitnessGoals: FitnessGoals(
          primary: 'general_fitness',
          secondary: ['strength', 'endurance'],
          workoutsPerWeek: 3,
        ),
        dietaryPreferences: DietaryPreferences(
          preferences: [],
          allergies: [],
          dislikedFoods: [],
          mealsPerDay: 3,
        ),
      );

      final routine = await _workoutService.generateWorkoutRoutine(
        userPreferences: userPrefs,
        name: 'AI Workout ${DateTime.now().toString().substring(0, 10)}',
        description: 'Intelligently designed workout routine',
        targetMuscles: ['chest', 'back', 'legs'],
        durationMinutes: 45,
      );

      if (routine != null) {
        setState(() {
          _routines = [..._routines, routine];
        });
        _showPremiumSnackBar('AI workout generated successfully', true);
      }
    } catch (e) {
      _showPremiumSnackBar('Failed to generate workout', false);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startWorkout(WorkoutRoutine routine) async {
    try {
      final result = await Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) =>
              WorkoutExecutionScreen(routine: routine),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeInOutCubic,
              )),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );

      if (result == true && mounted) {
        _showPremiumSnackBar('Workout completed successfully', true);
      }
    } catch (e) {
      if (mounted) {
        _showPremiumSnackBar('Failed to start workout', false);
      }
    }
  }

  void _showPremiumSnackBar(String message, bool isSuccess) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isSuccess ? primaryBlack : slate500,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSuccess ? Icons.check : Icons.close,
                  color: white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  message,
                  style: bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: white,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(
            color: slate300,
            width: 1,
          ),
        ),
        margin: const EdgeInsets.all(20),
        elevation: 12,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<Map<String, dynamic>?> _showCreateWorkoutDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: true,
      barrierColor: primaryBlack.withOpacity(0.7),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 20,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: white,
            boxShadow: [
              BoxShadow(
                color: primaryBlack.withOpacity(0.1),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: primaryBlack,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      'Create Workout',
                      style: h2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    _buildPremiumTextField(
                      controller: nameController,
                      label: 'Workout Name',
                      hint: 'Upper Body Strength',
                      icon: Icons.title_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a workout name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildPremiumTextField(
                      controller: descriptionController,
                      label: 'Description',
                      hint: 'Describe your workout goals',
                      icon: Icons.description_outlined,
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a description';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      onPressed: () => Navigator.pop(context),
                      text: 'Cancel',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPrimaryButton(
                      onPressed: () {
                        if (formKey.currentState!.validate()) {
                          Navigator.pop(context, {
                            'name': nameController.text,
                            'description': descriptionController.text,
                          });
                        }
                      },
                      text: 'Create',
                      icon: Icons.add,
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

  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: bodyLarge.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator: validator,
          style: bodyLarge.copyWith(
            color: slate700,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: slate500, size: 22),
            filled: true,
            fillColor: slate100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: slate300, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: primaryBlack, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: slate500, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: slate500, width: 2),
            ),
            hintStyle: bodyMedium.copyWith(
              color: slate400,
              fontWeight: FontWeight.w400,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback onPressed,
    required String text,
    IconData? icon,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: primaryBlack,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryBlack.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: button.copyWith(
                    color: white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryButton({
    required VoidCallback onPressed,
    required String text,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: slate300, width: 1.5),
        borderRadius: BorderRadius.circular(16),
        color: white,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: Text(
                text,
                style: bodyMedium.copyWith(
                  color: slate500,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: slate100,
      body: CustomScrollView(
        slivers: [
          _buildPremiumAppBar(),
          SliverToBoxAdapter(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildBody(),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget _buildPremiumAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: primaryBlack,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            color: primaryBlack,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Workouts',
                    style: h1.copyWith(color: white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Excellence through consistency',
                    style: subtitle.copyWith(
                      color: white.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: IconButton(
            icon: const Icon(Icons.refresh, color: white, size: 24),
            onPressed: _loadWorkoutRoutines,
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: FloatingActionButton.extended(
        onPressed: _generateWorkoutRoutine,
        backgroundColor: primaryBlack,
        elevation: 16,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        label: Text(
          'Generate AI Workout',
          style: button.copyWith(
            color: white,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        icon: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.auto_awesome,
            color: white,
            size: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: primaryBlack,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(
                      color: white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Loading workouts...',
                style: bodyLarge.copyWith(
                  color: slate500,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: slate400.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.error_outline,
                  size: 40,
                  color: slate500,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Something went wrong',
                style: h3,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: bodyMedium.copyWith(
                  color: slate500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              _buildPrimaryButton(
                onPressed: _loadWorkoutRoutines,
                text: 'Try Again',
                icon: Icons.refresh,
              ),
            ],
          ),
        ),
      );
    }

    if (_routines.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: slate400.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  size: 60,
                  color: slate500,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                'Ready to begin?',
                style: h2,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Create your first workout or let AI design the perfect routine for you',
                style: bodyMedium.copyWith(
                  color: slate500,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              Row(
                children: [
                  Expanded(
                    child: _buildPrimaryButton(
                      onPressed: _createNewWorkoutRoutine,
                      text: 'Create Workout',
                      icon: Icons.add,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      onPressed: _generateWorkoutRoutine,
                      text: 'Generate AI Workout',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Your Routines',
                style: h3.copyWith(
                  color: primaryBlack,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: primaryBlack,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_routines.length}',
                  style: bodyMedium.copyWith(
                    color: white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _routines.length,
            itemBuilder: (context, index) =>
                _buildWorkoutCard(_routines[index], index),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkoutCard(WorkoutRoutine routine, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _showWorkoutDetails(routine),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: slate300, width: 1),
              boxShadow: [
                BoxShadow(
                  color: primaryBlack.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: routine.isCustom ? primaryBlack : slate600,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        routine.isCustom
                            ? Icons.fitness_center
                            : Icons.auto_awesome,
                        color: white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.name,
                            style: h3.copyWith(
                              color: primaryBlack,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              _buildInfoChip(
                                routine.difficulty.toUpperCase(),
                                _getDifficultyShade(routine.difficulty),
                              ),
                              const SizedBox(width: 8),
                              _buildInfoChip(
                                '${routine.estimatedDurationMinutes}MIN',
                                slate500,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: slate100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: slate300, width: 1),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.play_arrow,
                          color: primaryBlack,
                          size: 24,
                        ),
                        onPressed: () => _startWorkout(routine),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  routine.description,
                  style: bodyMedium.copyWith(
                    color: slate500,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (routine.exercises.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: slate100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: slate300, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.list_alt_outlined,
                          size: 18,
                          color: slate500,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${routine.exercises.length} exercises',
                          style: bodyMedium.copyWith(
                            color: slate500,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (routine.targetMuscles.isNotEmpty) ...[
                          Icon(
                            Icons.track_changes_outlined,
                            size: 18,
                            color: slate500,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            routine.targetMuscles.take(2).join(', '),
                            style: bodyMedium.copyWith(
                              color: slate500,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Text(
        text,
        style: bodyMedium.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Color _getDifficultyShade(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return slate400;
      case 'intermediate':
        return slate500;
      case 'advanced':
        return slate600;
      default:
        return slate500;
    }
  }

  void _showWorkoutDetails(WorkoutRoutine routine) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: primaryBlack.withOpacity(0.7),
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        elevation: 24,
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            color: white,
            boxShadow: [
              BoxShadow(
                color: primaryBlack.withOpacity(0.15),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: routine.isCustom ? primaryBlack : slate600,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Icon(
                      routine.isCustom
                          ? Icons.fitness_center
                          : Icons.auto_awesome,
                      color: white,
                      size: 36,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routine.name,
                          style: h3.copyWith(
                            color: primaryBlack,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoChip(
                          routine.isCustom ? 'CUSTOM' : 'AI GENERATED',
                          routine.isCustom ? primaryBlack : slate600,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Text(
                routine.description,
                style: bodyMedium.copyWith(
                  color: slate500,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              _buildDetailRow(Icons.signal_cellular_alt, 'Difficulty',
                  routine.difficulty.toUpperCase()),
              _buildDetailRow(Icons.schedule_outlined, 'Duration',
                  '${routine.estimatedDurationMinutes} minutes'),
              _buildDetailRow(Icons.list_alt_outlined, 'Exercises',
                  '${routine.exercises.length} total'),
              if (routine.targetMuscles.isNotEmpty)
                _buildDetailRow(Icons.track_changes_outlined, 'Target Areas',
                    routine.targetMuscles.join(', ')),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: _buildSecondaryButton(
                      onPressed: () => Navigator.pop(context),
                      text: 'Close',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPrimaryButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _startWorkout(routine);
                      },
                      text: 'Start',
                      icon: Icons.play_arrow,
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

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: slate500),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: bodyMedium.copyWith(
              color: primaryBlack,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: bodyMedium.copyWith(
                color: slate500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
