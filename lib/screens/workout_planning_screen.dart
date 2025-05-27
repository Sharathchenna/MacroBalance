import 'package:flutter/material.dart';
import '../models/workout_plan.dart';
import '../models/exercise.dart';
import '../services/workout_planning_service.dart';
import '../models/user_preferences.dart';
import 'package:flutter/cupertino.dart';

class WorkoutPlanningScreen extends StatefulWidget {
  const WorkoutPlanningScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutPlanningScreen> createState() => _WorkoutPlanningScreenState();
}

class _WorkoutPlanningScreenState extends State<WorkoutPlanningScreen> {
  final WorkoutPlanningService _workoutService = WorkoutPlanningService();
  List<WorkoutRoutine> _routines = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorkoutRoutines();
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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _CreateWorkoutDialog(),
    );

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
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create workout: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _generateWorkoutRoutine() async {
    setState(() => _isLoading = true);
    try {
      // Create a basic user preferences object
      // In a real app, you would get this from your user preferences service
      final userPrefs = UserPreferences(
        userId: 'default',
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
        name: 'Generated Workout ${DateTime.now().toString().substring(0, 10)}',
        description: 'AI-generated workout routine',
        targetMuscles: ['chest', 'back', 'legs'],
        durationMinutes: 45,
      );

      if (routine != null) {
        setState(() {
          _routines = [..._routines, routine];
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate workout: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _startWorkout(WorkoutRoutine routine) async {
    // Start workout tracking
    try {
      final workoutLog = await _workoutService.startWorkout(
        'default_user', // In a real app, get the actual user ID
        routine.id,
      );

      if (workoutLog != null) {
        // Navigate to workout tracking screen
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Workout started!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start workout: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Planning'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createNewWorkoutRoutine,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _routines.isEmpty
                  ? const Center(
                      child: Text('No workout routines found. Create one!'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _routines.length,
                      itemBuilder: (context, index) {
                        final routine = _routines[index];
                        return _buildWorkoutCard(routine);
                      },
                    ),
      floatingActionButton: FloatingActionButton(
        onPressed: _generateWorkoutRoutine,
        child: const Icon(Icons.fitness_center),
      ),
    );
  }

  Widget _buildWorkoutCard(WorkoutRoutine routine) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            title: Text(
              routine.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Text(
              '${routine.difficulty} • ${routine.estimatedDurationMinutes} min',
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () => _startWorkout(routine),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(routine.description),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: routine.targetMuscles
                      .map((muscle) => Chip(label: Text(muscle)))
                      .toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Exercises',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ...routine.exercises
                    .map((exercise) => _buildExerciseItem(exercise)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseItem(WorkoutExercise exercise) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(exercise.exercise?.name ?? 'Unknown Exercise'),
      subtitle: Text(
        '${exercise.sets.length} sets • ${exercise.restSeconds}s rest',
      ),
      trailing: exercise.isCompleted
          ? const Icon(Icons.check_circle, color: Colors.green)
          : null,
    );
  }
}

class _CreateWorkoutDialog extends StatefulWidget {
  @override
  _CreateWorkoutDialogState createState() => _CreateWorkoutDialogState();
}

class _CreateWorkoutDialogState extends State<_CreateWorkoutDialog> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create New Workout'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Workout Name',
              hintText: 'Enter workout name',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(
              labelText: 'Description',
              hintText: 'Enter workout description',
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              Navigator.pop(context, {
                'name': _nameController.text,
                'description': _descriptionController.text,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
