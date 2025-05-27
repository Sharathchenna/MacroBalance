import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meal_planning_provider.dart';
import '../providers/workout_planning_provider.dart';

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
