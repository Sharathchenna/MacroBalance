import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/workout_colors.dart';
import '../screens/manual_workout_creator_screen.dart';
import '../models/fitness_profile.dart';
import '../models/workout_plan.dart';
import '../models/exercise.dart';
import '../services/fitness_ai_service.dart';
import 'dart:developer';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/workout_planning_provider.dart'; // Adjusted path

class WorkoutCreationModal extends StatelessWidget {
  final FitnessProfile? fitnessProfile;

  const WorkoutCreationModal({
    super.key,
    this.fitnessProfile,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? PremiumColors.darkCard : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: isDark
                  ? PremiumColors.darkTextSecondary
                  : PremiumColors.slate300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New Workout',
                  style: PremiumTypography.h2.copyWith(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Choose how you\'d like to create your workout',
                  style: PremiumTypography.bodyMedium.copyWith(
                    color: isDark
                        ? PremiumColors.darkTextSecondary
                        : PremiumColors.slate500,
                  ),
                ),
                const SizedBox(height: 24),

                // Manual workout option
                _buildWorkoutOption(
                  context,
                  isDark,
                  icon: CupertinoIcons.add_circled,
                  title: 'Add Workout Manually',
                  subtitle:
                      'Browse our exercise database and build your own custom workout',
                  gradient: LinearGradient(
                    colors: [
                      isDark
                          ? const Color(0xFF3B82F6)
                          : const Color(0xFF1E40AF),
                      isDark
                          ? const Color(0xFF1D4ED8)
                          : const Color(0xFF3B82F6),
                    ],
                  ),
                  onTap: () => _openManualWorkoutCreator(context),
                ),

                const SizedBox(height: 16),

                // Quick AI workout option
                _buildWorkoutOption(
                  context,
                  isDark,
                  icon: CupertinoIcons.sparkles,
                  title: 'Generate AI Workout',
                  subtitle:
                      'Instantly create a personalized workout based on your fitness profile',
                  gradient: LinearGradient(
                    colors: [
                      isDark
                          ? const Color(0xFF8B5CF6)
                          : const Color(0xFF7C3AED),
                      isDark
                          ? const Color(0xFF7C3AED)
                          : const Color(0xFF8B5CF6),
                    ],
                  ),
                  onTap: () => _generateAIWorkout(context),
                ),

                const SizedBox(height: 16),

                // Cancel button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: Text(
                      'Cancel',
                      style: PremiumTypography.button.copyWith(
                        color: isDark
                            ? PremiumColors.darkTextSecondary
                            : PremiumColors.slate500,
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
  }

  Widget _buildWorkoutOption(
    BuildContext context,
    bool isDark, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.last.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: PremiumTypography.subtitle.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: PremiumTypography.caption.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              CupertinoIcons.chevron_right,
              color: Colors.white.withValues(alpha: 0.8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _openManualWorkoutCreator(BuildContext context) async {
    // We get the result from the creator screen first
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManualWorkoutCreatorScreen(),
      ),
    );

    // Then, if we have a result, we pop the modal and pass the result back
    // to the workout planning screen.
    if (result != null && context.mounted) {
      Navigator.pop(context, result);
    }
  }

  Future<void> _generateAIWorkout(BuildContext context) async {
    log('[WorkoutCreation] Starting AI workout generation...');

    if (fitnessProfile == null) {
      log('[WorkoutCreation] Error: No fitness profile available');
      Navigator.pop(context); // Close modal first

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please complete your fitness profile to create AI workouts.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    log('[WorkoutCreation] Using fitness profile: level=${fitnessProfile!.fitnessLevel}, '
        'workouts/week=${fitnessProfile!.workoutsPerWeek}');

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      log('[WorkoutCreation] Creating FitnessAIService instance...');
      final aiService = FitnessAIService();

      log('[WorkoutCreation] Calling generateWorkout...');
      final workoutRoutine = await aiService.generateWorkout(
        fitnessProfile!,
        {}, // Empty macro data for now
      );

      log('[WorkoutCreation] Workout routine generated successfully: ${workoutRoutine.name}');

      // Get services and user
      final workoutPlanningProvider =
          Provider.of<WorkoutPlanningProvider>(context, listen: false);
      final supabase = Supabase
          .instance.client; // Keep for direct exercise insert if preferred
      final user = supabase.auth.currentUser;

      if (user == null) {
        log('[WorkoutCreation] User not found, cannot save workout.');
        if (context.mounted) Navigator.pop(context); // Close loading
        // Optionally show an error message
        return;
      }

      log('[WorkoutCreation] Processing ${workoutRoutine.exercises.length} exercises for routine: ${workoutRoutine.name}');
      List<WorkoutExercise> processedWorkoutExercises = [];

      for (final originalWorkoutExercise in workoutRoutine.exercises) {
        final exerciseDetails = originalWorkoutExercise.exercise;
        if (exerciseDetails == null) {
          log('[WorkoutCreation] Skipping an exercise in the routine due to missing details.');
          continue;
        }

        // 1. Prepare Exercise data for saving, removing temporary ID to let DB generate UUID
        Map<String, dynamic> exerciseDataToInsert =
            exerciseDetails.toDatabaseJson();
        exerciseDataToInsert
            .remove('id'); // Remove temporary 'ai_exercise_X' ID
        exerciseDataToInsert['user_id'] = user.id;

        log('[WorkoutCreation] Saving exercise to DB: ${exerciseDetails.name}, Data: $exerciseDataToInsert');

        final savedExerciseResponse = await supabase
            .from('exercises')
            .insert(exerciseDataToInsert)
            .select('id, name') // Select only needed fields
            .single();

        final String dbExerciseId = savedExerciseResponse['id'];
        log('[WorkoutCreation] Saved exercise "${savedExerciseResponse['name']}" with DB ID: $dbExerciseId');

        // Create an updated Exercise object with the real database ID
        Exercise savedExercise = exerciseDetails.copyWith(id: dbExerciseId);

        // 2. Create a new WorkoutExercise with the real DB ID and saved Exercise object
        processedWorkoutExercises.add(
          WorkoutExercise(
            // id: originalWorkoutExercise.id, // ID for WorkoutExercise itself, if needed by its model
            exerciseId: savedExercise.id,
            exercise: savedExercise,
            sets: originalWorkoutExercise.sets,
            restSeconds: originalWorkoutExercise.restSeconds,
            notes: originalWorkoutExercise.notes,
          ),
        );
      }

      // 3. Create the final WorkoutRoutine with processed exercises
      final finalWorkoutRoutine = WorkoutRoutine(
        id: workoutRoutine.id, // Use the ID from the AI-generated routine
        name: workoutRoutine.name,
        description: workoutRoutine.description,
        exercises:
            processedWorkoutExercises, // Use the list with real exercise IDs
        estimatedDurationMinutes: workoutRoutine.estimatedDurationMinutes,
        difficulty: workoutRoutine.difficulty, // Already mapped by AI service
        targetMuscles: workoutRoutine.targetMuscles,
        requiredEquipment: workoutRoutine.requiredEquipment,
        isCustom: true,
        createdBy: user.id,
        // createdAt and updatedAt should be handled by the model or DB defaults
      );

      // 4. Save the WorkoutRoutine using WorkoutPlanningProvider/Service
      log('[WorkoutCreation] Saving final workout routine to "workout_routines" table: ${finalWorkoutRoutine.name}');
      final bool saveSuccess =
          await workoutPlanningProvider.saveWorkoutRoutine(finalWorkoutRoutine);

      // Close loading indicator
      if (context.mounted) {
        Navigator.pop(context); // Close loading indicator
      }

      if (saveSuccess) {
        log('[WorkoutCreation] Workout routine saved successfully via provider.');
        // Return the generated workout by popping the modal with the workout as result
        if (context.mounted) {
          log('[WorkoutCreation] Returning workout to planning screen');
          Navigator.pop(
              context, finalWorkoutRoutine); // Close modal and return workout
        }
      } else {
        log('[WorkoutCreation] Failed to save workout routine via provider.');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(workoutPlanningProvider.error ??
                  'Failed to save workout. Please try again.'),
              backgroundColor: Colors.redAccent,
            ),
          );
          // Optionally, pop the modal without a result or stay on the modal
          // For now, just showing error, user can cancel modal manually or try again if UI allows
        }
      }
    } catch (e, stackTrace) {
      if (e is PostgrestException) {
        log('[WorkoutCreation] PostgrestException encountered:');
        log('  Message: ${e.message}');
        log('  Code: ${e.code}');
        log('  Details: ${e.details}');
        log('  Hint: ${e.hint}');
      } else {
        log('[WorkoutCreation] Error generating workout: $e');
      }
      log('[WorkoutCreation] Stack trace: $stackTrace');

      // Close loading indicator if still showing
      if (context.mounted) {
        final ModalRoute<dynamic>? currentRoute = ModalRoute.of(context);
        if (currentRoute is DialogRoute) {
          Navigator.pop(context); // Pop loading dialog
        }
      }

      // Show error message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to generate workout. Details: ${e is PostgrestException ? e.message : e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}

// Helper function to show the modal
Future<dynamic> showWorkoutCreationModal(
  BuildContext context, {
  FitnessProfile? fitnessProfile,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => WorkoutCreationModal(
      fitnessProfile: fitnessProfile,
    ),
  );
}
