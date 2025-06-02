import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meal_planning_provider.dart';
import '../providers/workout_planning_provider.dart';
import 'debug_performance_screen.dart';

class MealPlanningDebugScreen extends StatelessWidget {
  const MealPlanningDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mealProvider = Provider.of<MealPlanningProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Meal Planning Debug')),
      body: ListView(
        children: [
          ListTile(
              title: const Text('Recipes'),
              subtitle: Text(mealProvider.recipes.length.toString())),
          ListTile(
              title: const Text('Current Meal Plan'),
              subtitle:
                  Text(mealProvider.currentMealPlan?.toString() ?? 'None')),
          ListTile(
              title: const Text('Weekly Meal Plans'),
              subtitle: Text(mealProvider.weeklyMealPlans.length.toString())),
        ],
      ),
    );
  }
}

class WorkoutPlanningDebugScreen extends StatelessWidget {
  const WorkoutPlanningDebugScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workoutProvider = Provider.of<WorkoutPlanningProvider>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Workout Planning Debug')),
      body: ListView(
        children: [
          ListTile(
              title: const Text('Exercises'),
              subtitle: Text(workoutProvider.exercises.length.toString())),
          ListTile(
              title: const Text('Workout Routines'),
              subtitle:
                  Text(workoutProvider.workoutRoutines.length.toString())),
          ListTile(
              title: const Text('Workout Plans'),
              subtitle: Text(workoutProvider.workoutPlans.length.toString())),
        ],
      ),
    );
  }
}

class DebugMenuScreen extends StatelessWidget {
  const DebugMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🐛 Debug Menu'),
        backgroundColor: Colors.orange[900],
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDebugCard(
            context,
            '⚡ Performance Monitor',
            'Track app performance, memory usage, and bottlenecks',
            Icons.speed,
            Colors.red,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const DebugPerformanceScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDebugCard(
            context,
            '🍽️ Meal Planning Debug',
            'Debug meal planning provider and data',
            Icons.restaurant_menu,
            Colors.green,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MealPlanningDebugScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildDebugCard(
            context,
            '💪 Workout Planning Debug',
            'Debug workout planning provider and data',
            Icons.fitness_center,
            Colors.blue,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const WorkoutPlanningDebugScreen(),
              ),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Debug Mode Active',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'These tools are for development only. Use Performance Monitor to identify and fix bottlenecks in your app.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
