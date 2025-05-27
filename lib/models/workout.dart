import 'exercise.dart';

class WorkoutSet {
  final String id;
  final String exerciseId;
  final int setNumber;
  final int? reps;
  final double? weight;
  final int? durationSeconds;
  final int? restSeconds;
  final bool isCompleted;
  final String? notes;
  final DateTime createdAt;

  WorkoutSet({
    required this.id,
    required this.exerciseId,
    required this.setNumber,
    this.reps,
    this.weight,
    this.durationSeconds,
    this.restSeconds,
    required this.isCompleted,
    this.notes,
    required this.createdAt,
  });

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      id: json['id'] ?? '',
      exerciseId: json['exercise_id'] ?? '',
      setNumber: json['set_number'] ?? 1,
      reps: json['reps'],
      weight: json['weight']?.toDouble(),
      durationSeconds: json['duration_seconds'],
      restSeconds: json['rest_seconds'],
      isCompleted: json['is_completed'] ?? false,
      notes: json['notes'],
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'set_number': setNumber,
      'reps': reps,
      'weight': weight,
      'duration_seconds': durationSeconds,
      'rest_seconds': restSeconds,
      'is_completed': isCompleted,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
    };
  }

  WorkoutSet copyWith({
    String? id,
    String? exerciseId,
    int? setNumber,
    int? reps,
    double? weight,
    int? durationSeconds,
    int? restSeconds,
    bool? isCompleted,
    String? notes,
    DateTime? createdAt,
  }) {
    return WorkoutSet(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      setNumber: setNumber ?? this.setNumber,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      restSeconds: restSeconds ?? this.restSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class WorkoutExercise {
  final String id;
  final String exerciseId;
  final Exercise? exercise; // Populated when needed
  final int order;
  final List<WorkoutSet> sets;
  final String? notes;

  WorkoutExercise({
    required this.id,
    required this.exerciseId,
    this.exercise,
    required this.order,
    required this.sets,
    this.notes,
  });

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      id: json['id'] ?? '',
      exerciseId: json['exercise_id'] ?? '',
      exercise:
          json['exercise'] != null ? Exercise.fromJson(json['exercise']) : null,
      order: json['order'] ?? 0,
      sets: (json['sets'] as List<dynamic>?)
              ?.map((set) => WorkoutSet.fromJson(set))
              .toList() ??
          [],
      notes: json['notes'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'exercise': exercise?.toJson(),
      'order': order,
      'sets': sets.map((set) => set.toJson()).toList(),
      'notes': notes,
    };
  }

  // Calculate total volume (weight * reps) for this exercise
  double get totalVolume {
    return sets.fold(0.0, (sum, set) {
      if (set.weight != null && set.reps != null) {
        return sum + (set.weight! * set.reps!);
      }
      return sum;
    });
  }

  // Get total reps for this exercise
  int get totalReps {
    return sets.fold(0, (sum, set) => sum + (set.reps ?? 0));
  }

  // Check if all sets are completed
  bool get isCompleted {
    return sets.isNotEmpty && sets.every((set) => set.isCompleted);
  }

  WorkoutExercise copyWith({
    String? id,
    String? exerciseId,
    Exercise? exercise,
    int? order,
    List<WorkoutSet>? sets,
    String? notes,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exercise: exercise ?? this.exercise,
      order: order ?? this.order,
      sets: sets ?? this.sets,
      notes: notes ?? this.notes,
    );
  }
}

class WorkoutRoutine {
  final String id;
  final String name;
  final String description;
  final List<WorkoutExercise> exercises;
  final int estimatedDurationMinutes;
  final String difficulty;
  final List<MuscleGroup> targetMuscles;
  final List<EquipmentType> requiredEquipment;
  final bool isCustom; // true if created by user, false if pre-defined
  final String? createdBy; // user_id if custom
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkoutRoutine({
    required this.id,
    required this.name,
    required this.description,
    required this.exercises,
    required this.estimatedDurationMinutes,
    required this.difficulty,
    required this.targetMuscles,
    required this.requiredEquipment,
    required this.isCustom,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkoutRoutine.fromJson(Map<String, dynamic> json) {
    return WorkoutRoutine(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      exercises: (json['exercises'] as List<dynamic>?)
              ?.map((exercise) => WorkoutExercise.fromJson(exercise))
              .toList() ??
          [],
      estimatedDurationMinutes: json['estimated_duration_minutes'] ?? 30,
      difficulty: json['difficulty'] ?? 'beginner',
      targetMuscles: (json['target_muscles'] as List<dynamic>?)
              ?.map((muscle) => MuscleGroup.values.firstWhere(
                    (e) => e.toString().split('.').last == muscle,
                    orElse: () => MuscleGroup.fullBody,
                  ))
              .toList() ??
          [],
      requiredEquipment: (json['required_equipment'] as List<dynamic>?)
              ?.map((eq) => EquipmentType.values.firstWhere(
                    (e) => e.toString().split('.').last == eq,
                    orElse: () => EquipmentType.bodyweight,
                  ))
              .toList() ??
          [],
      isCustom: json['is_custom'] ?? false,
      createdBy: json['created_by'],
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'exercises': exercises.map((exercise) => exercise.toJson()).toList(),
      'estimated_duration_minutes': estimatedDurationMinutes,
      'difficulty': difficulty,
      'target_muscles':
          targetMuscles.map((m) => m.toString().split('.').last).toList(),
      'required_equipment':
          requiredEquipment.map((e) => e.toString().split('.').last).toList(),
      'is_custom': isCustom,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Check if routine can be performed with available equipment
  bool canPerformWith(List<EquipmentType> availableEquipment) {
    return requiredEquipment.every((req) => availableEquipment.contains(req));
  }

  // Get total estimated volume
  double get totalEstimatedVolume {
    return exercises.fold(0.0, (sum, exercise) => sum + exercise.totalVolume);
  }

  // Check if routine is completed
  bool get isCompleted {
    return exercises.isNotEmpty &&
        exercises.every((exercise) => exercise.isCompleted);
  }

  WorkoutRoutine copyWith({
    String? id,
    String? name,
    String? description,
    List<WorkoutExercise>? exercises,
    int? estimatedDurationMinutes,
    String? difficulty,
    List<MuscleGroup>? targetMuscles,
    List<EquipmentType>? requiredEquipment,
    bool? isCustom,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutRoutine(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      exercises: exercises ?? this.exercises,
      estimatedDurationMinutes:
          estimatedDurationMinutes ?? this.estimatedDurationMinutes,
      difficulty: difficulty ?? this.difficulty,
      targetMuscles: targetMuscles ?? this.targetMuscles,
      requiredEquipment: requiredEquipment ?? this.requiredEquipment,
      isCustom: isCustom ?? this.isCustom,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class WorkoutPlan {
  final String id;
  final String name;
  final String description;
  final List<String> routineIds; // References to WorkoutRoutine IDs
  final int durationWeeks;
  final int workoutsPerWeek;
  final String goal; // 'weight_loss', 'muscle_gain', 'strength', 'endurance'
  final String difficulty;
  final List<EquipmentType> requiredEquipment;
  final bool isCustom;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkoutPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.routineIds,
    required this.durationWeeks,
    required this.workoutsPerWeek,
    required this.goal,
    required this.difficulty,
    required this.requiredEquipment,
    required this.isCustom,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      routineIds: List<String>.from(json['routine_ids'] ?? []),
      durationWeeks: json['duration_weeks'] ?? 4,
      workoutsPerWeek: json['workouts_per_week'] ?? 3,
      goal: json['goal'] ?? 'general_fitness',
      difficulty: json['difficulty'] ?? 'beginner',
      requiredEquipment: (json['required_equipment'] as List<dynamic>?)
              ?.map((eq) => EquipmentType.values.firstWhere(
                    (e) => e.toString().split('.').last == eq,
                    orElse: () => EquipmentType.bodyweight,
                  ))
              .toList() ??
          [],
      isCustom: json['is_custom'] ?? false,
      createdBy: json['created_by'],
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'routine_ids': routineIds,
      'duration_weeks': durationWeeks,
      'workouts_per_week': workoutsPerWeek,
      'goal': goal,
      'difficulty': difficulty,
      'required_equipment':
          requiredEquipment.map((e) => e.toString().split('.').last).toList(),
      'is_custom': isCustom,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Calculate total workouts in the plan
  int get totalWorkouts => durationWeeks * workoutsPerWeek;

  WorkoutPlan copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? routineIds,
    int? durationWeeks,
    int? workoutsPerWeek,
    String? goal,
    String? difficulty,
    List<EquipmentType>? requiredEquipment,
    bool? isCustom,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WorkoutPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      routineIds: routineIds ?? this.routineIds,
      durationWeeks: durationWeeks ?? this.durationWeeks,
      workoutsPerWeek: workoutsPerWeek ?? this.workoutsPerWeek,
      goal: goal ?? this.goal,
      difficulty: difficulty ?? this.difficulty,
      requiredEquipment: requiredEquipment ?? this.requiredEquipment,
      isCustom: isCustom ?? this.isCustom,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class WorkoutLog {
  final String id;
  final String userId;
  final String routineId;
  final WorkoutRoutine? routine; // Populated when needed
  final DateTime startTime;
  final DateTime? endTime;
  final int? actualDurationMinutes;
  final List<WorkoutExercise> completedExercises;
  final double totalVolume;
  final String? notes;
  final bool isCompleted;
  final DateTime createdAt;

  WorkoutLog({
    required this.id,
    required this.userId,
    required this.routineId,
    this.routine,
    required this.startTime,
    this.endTime,
    this.actualDurationMinutes,
    required this.completedExercises,
    required this.totalVolume,
    this.notes,
    required this.isCompleted,
    required this.createdAt,
  });

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      routineId: json['routine_id'] ?? '',
      routine: json['routine'] != null
          ? WorkoutRoutine.fromJson(json['routine'])
          : null,
      startTime: DateTime.parse(
          json['start_time'] ?? DateTime.now().toIso8601String()),
      endTime:
          json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      actualDurationMinutes: json['actual_duration_minutes'],
      completedExercises: (json['completed_exercises'] as List<dynamic>?)
              ?.map((exercise) => WorkoutExercise.fromJson(exercise))
              .toList() ??
          [],
      totalVolume: (json['total_volume'] ?? 0).toDouble(),
      notes: json['notes'],
      isCompleted: json['is_completed'] ?? false,
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'routine_id': routineId,
      'routine': routine?.toJson(),
      'start_time': startTime.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'actual_duration_minutes': actualDurationMinutes,
      'completed_exercises':
          completedExercises.map((exercise) => exercise.toJson()).toList(),
      'total_volume': totalVolume,
      'notes': notes,
      'is_completed': isCompleted,
      'created_at': createdAt.toIso8601String(),
    };
  }

  // Calculate actual duration if end time is available
  int? get calculatedDurationMinutes {
    if (endTime != null) {
      return endTime!.difference(startTime).inMinutes;
    }
    return actualDurationMinutes;
  }

  WorkoutLog copyWith({
    String? id,
    String? userId,
    String? routineId,
    WorkoutRoutine? routine,
    DateTime? startTime,
    DateTime? endTime,
    int? actualDurationMinutes,
    List<WorkoutExercise>? completedExercises,
    double? totalVolume,
    String? notes,
    bool? isCompleted,
    DateTime? createdAt,
  }) {
    return WorkoutLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      routineId: routineId ?? this.routineId,
      routine: routine ?? this.routine,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      actualDurationMinutes:
          actualDurationMinutes ?? this.actualDurationMinutes,
      completedExercises: completedExercises ?? this.completedExercises,
      totalVolume: totalVolume ?? this.totalVolume,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
