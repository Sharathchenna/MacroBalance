import 'package:uuid/uuid.dart';
import 'exercise.dart';

class WorkoutSet {
  final String id;
  final int reps;
  final double? weight;
  final int? durationSeconds;
  final bool isCompleted;

  WorkoutSet({
    String? id,
    required this.reps,
    this.weight,
    this.durationSeconds,
    this.isCompleted = false,
  }) : id = id ?? const Uuid().v4();

  WorkoutSet copyWith({
    String? id,
    int? reps,
    double? weight,
    int? durationSeconds,
    bool? isCompleted,
  }) {
    return WorkoutSet(
      id: id ?? this.id,
      reps: reps ?? this.reps,
      weight: weight ?? this.weight,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  factory WorkoutSet.fromJson(Map<String, dynamic> json) {
    return WorkoutSet(
      id: json['id'],
      reps: json['reps'] ?? 0,
      weight:
          json['weight'] != null ? (json['weight'] as num).toDouble() : null,
      durationSeconds: json['duration_seconds'],
      isCompleted: json['is_completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reps': reps,
      'weight': weight,
      'duration_seconds': durationSeconds,
      'is_completed': isCompleted,
    };
  }
}

class WorkoutExercise {
  final String id;
  final String exerciseId;
  final Exercise? exercise;
  final List<WorkoutSet> sets;
  final int restSeconds;
  final String? notes;
  final bool isCompleted;

  WorkoutExercise({
    String? id,
    required this.exerciseId,
    this.exercise,
    List<WorkoutSet>? sets,
    this.restSeconds = 60,
    this.notes,
    this.isCompleted = false,
  })  : id = id ?? const Uuid().v4(),
        sets = sets ?? [];

  int get completedSets => sets.where((set) => set.isCompleted).length;
  bool get isPartiallyCompleted =>
      completedSets > 0 && completedSets < sets.length;
  double get completionPercentage =>
      sets.isEmpty ? 0 : (completedSets / sets.length) * 100;

  WorkoutExercise copyWith({
    String? id,
    String? exerciseId,
    Exercise? exercise,
    List<WorkoutSet>? sets,
    int? restSeconds,
    String? notes,
    bool? isCompleted,
  }) {
    return WorkoutExercise(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      exercise: exercise ?? this.exercise,
      sets: sets ?? this.sets,
      restSeconds: restSeconds ?? this.restSeconds,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  factory WorkoutExercise.fromJson(Map<String, dynamic> json) {
    return WorkoutExercise(
      id: json['id'],
      exerciseId: json['exercise_id'] ?? '',
      exercise:
          json['exercise'] != null ? Exercise.fromJson(json['exercise']) : null,
      sets: ((json['sets'] ?? []) as List)
          .map((set) => WorkoutSet.fromJson(set))
          .toList(),
      restSeconds: json['rest_seconds'] ?? 60,
      notes: json['notes'],
      isCompleted: json['is_completed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exercise_id': exerciseId,
      'exercise': exercise?.toJson(),
      'sets': sets.map((set) => set.toJson()).toList(),
      'rest_seconds': restSeconds,
      'notes': notes,
      'is_completed': isCompleted,
    };
  }
}

class WorkoutRoutine {
  final String id;
  final String name;
  final String description;
  final List<WorkoutExercise> exercises;
  final int estimatedDurationMinutes;
  final String difficulty;
  final List<String> targetMuscles;
  final List<String> requiredEquipment;
  final bool isCustom;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkoutRoutine({
    String? id,
    required this.name,
    required this.description,
    List<WorkoutExercise>? exercises,
    required this.estimatedDurationMinutes,
    required this.difficulty,
    List<String>? targetMuscles,
    List<String>? requiredEquipment,
    this.isCustom = false,
    this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        exercises = exercises ?? [],
        targetMuscles = targetMuscles ?? [],
        requiredEquipment = requiredEquipment ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get totalExercises => exercises.length;
  int get totalSets =>
      exercises.fold(0, (sum, exercise) => sum + exercise.sets.length);
  int get completedExercises =>
      exercises.where((exercise) => exercise.isCompleted).length;
  double get completionPercentage =>
      exercises.isEmpty ? 0 : (completedExercises / totalExercises) * 100;

  WorkoutRoutine copyWith({
    String? id,
    String? name,
    String? description,
    List<WorkoutExercise>? exercises,
    int? estimatedDurationMinutes,
    String? difficulty,
    List<String>? targetMuscles,
    List<String>? requiredEquipment,
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

  factory WorkoutRoutine.fromJson(Map<String, dynamic> json) {
    return WorkoutRoutine(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      exercises: ((json['exercises'] ?? []) as List)
          .map((exercise) => WorkoutExercise.fromJson(exercise))
          .toList(),
      estimatedDurationMinutes: json['estimated_duration_minutes'] ?? 30,
      difficulty: json['difficulty'] ?? 'beginner',
      targetMuscles: List<String>.from(json['target_muscles'] ?? []),
      requiredEquipment: List<String>.from(json['required_equipment'] ?? []),
      isCustom: json['is_custom'] ?? false,
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
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
      'target_muscles': targetMuscles,
      'required_equipment': requiredEquipment,
      'is_custom': isCustom,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class WorkoutPlan {
  final String id;
  final String name;
  final String description;
  final List<String> routineIds;
  final int durationWeeks;
  final int workoutsPerWeek;
  final String goal;
  final String difficulty;
  final List<String> requiredEquipment;
  final bool isCustom;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  WorkoutPlan({
    String? id,
    required this.name,
    required this.description,
    List<String>? routineIds,
    required this.durationWeeks,
    required this.workoutsPerWeek,
    required this.goal,
    required this.difficulty,
    List<String>? requiredEquipment,
    this.isCustom = false,
    this.createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        routineIds = routineIds ?? [],
        requiredEquipment = requiredEquipment ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

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
    List<String>? requiredEquipment,
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

  factory WorkoutPlan.fromJson(Map<String, dynamic> json) {
    return WorkoutPlan(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      routineIds: List<String>.from(json['routine_ids'] ?? []),
      durationWeeks: json['duration_weeks'] ?? 4,
      workoutsPerWeek: json['workouts_per_week'] ?? 3,
      goal: json['goal'] ?? 'general_fitness',
      difficulty: json['difficulty'] ?? 'beginner',
      requiredEquipment: List<String>.from(json['required_equipment'] ?? []),
      isCustom: json['is_custom'] ?? false,
      createdBy: json['created_by'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
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
      'required_equipment': requiredEquipment,
      'is_custom': isCustom,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class WorkoutLog {
  final String id;
  final String userId;
  final String? routineId;
  final WorkoutRoutine? routine;
  final DateTime startTime;
  final DateTime? endTime;
  final int? actualDurationMinutes;
  final List<WorkoutExercise> completedExercises;
  final double totalVolume;
  final String? notes;
  final bool isCompleted;
  final DateTime createdAt;

  WorkoutLog({
    String? id,
    required this.userId,
    this.routineId,
    this.routine,
    DateTime? startTime,
    this.endTime,
    this.actualDurationMinutes,
    List<WorkoutExercise>? completedExercises,
    this.totalVolume = 0,
    this.notes,
    this.isCompleted = false,
    DateTime? createdAt,
  })  : id = id ?? const Uuid().v4(),
        startTime = startTime ?? DateTime.now(),
        completedExercises = completedExercises ?? [],
        createdAt = createdAt ?? DateTime.now();

  int get totalExercises => completedExercises.length;
  int get totalSets =>
      completedExercises.fold(0, (sum, exercise) => sum + exercise.sets.length);
  int get completedSets => completedExercises.fold(
      0, (sum, exercise) => sum + exercise.completedSets);

  bool get isInProgress => !isCompleted && endTime == null;

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

  factory WorkoutLog.fromJson(Map<String, dynamic> json) {
    return WorkoutLog(
      id: json['id'],
      userId: json['user_id'] ?? '',
      routineId: json['routine_id'],
      routine: json['routine'] != null
          ? WorkoutRoutine.fromJson(json['routine'])
          : null,
      startTime: json['start_time'] != null
          ? DateTime.parse(json['start_time'])
          : DateTime.now(),
      endTime:
          json['end_time'] != null ? DateTime.parse(json['end_time']) : null,
      actualDurationMinutes: json['actual_duration_minutes'],
      completedExercises: ((json['completed_exercises'] ?? []) as List)
          .map((exercise) => WorkoutExercise.fromJson(exercise))
          .toList(),
      totalVolume: (json['total_volume'] ?? 0).toDouble(),
      notes: json['notes'],
      isCompleted: json['is_completed'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
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
}
