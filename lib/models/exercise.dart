import 'package:uuid/uuid.dart';

enum MuscleGroup {
  chest,
  back,
  shoulders,
  biceps,
  triceps,
  forearms,
  abs,
  obliques,
  quadriceps,
  hamstrings,
  glutes,
  calves,
  cardio,
  fullBody
}

enum EquipmentType {
  bodyweight,
  dumbbells,
  barbell,
  kettlebell,
  resistanceBands,
  pullUpBar,
  bench,
  machine,
  cable,
  medicineBall,
  foamRoller,
  yogaMat
}

enum ExerciseType {
  strength,
  cardio,
  flexibility,
  balance,
  plyometric,
  isometric
}

class Exercise {
  final String id;
  final String name;
  final String description;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> equipment;
  final String type;
  final String difficulty;
  final List<String> instructions;
  final String? videoUrl;
  final String? imageUrl;
  final bool isCompound;
  final int? defaultSets;
  final int? defaultReps;
  final int? defaultDurationSeconds;
  final double? defaultWeight;
  final DateTime createdAt;
  final DateTime updatedAt;

  Exercise({
    String? id,
    required this.name,
    required this.description,
    required this.primaryMuscles,
    this.secondaryMuscles = const [],
    required this.equipment,
    required this.type,
    required this.difficulty,
    required this.instructions,
    this.videoUrl,
    this.imageUrl,
    required this.isCompound,
    this.defaultSets,
    this.defaultReps,
    this.defaultDurationSeconds,
    this.defaultWeight,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isTimeBased => defaultDurationSeconds != null;
  bool get isRepBased => defaultReps != null;

  bool requiresEquipment(String equipmentItem) {
    return equipment.contains(equipmentItem);
  }

  bool hasAllRequiredEquipment(List<String> availableEquipment) {
    return equipment.every(
        (item) => availableEquipment.contains(item) || item == 'bodyweight');
  }

  Exercise copyWith({
    String? id,
    String? name,
    String? description,
    List<String>? primaryMuscles,
    List<String>? secondaryMuscles,
    List<String>? equipment,
    String? type,
    String? difficulty,
    List<String>? instructions,
    String? videoUrl,
    String? imageUrl,
    bool? isCompound,
    int? defaultSets,
    int? defaultReps,
    int? defaultDurationSeconds,
    double? defaultWeight,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      primaryMuscles: primaryMuscles ?? this.primaryMuscles,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      equipment: equipment ?? this.equipment,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      instructions: instructions ?? this.instructions,
      videoUrl: videoUrl ?? this.videoUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      isCompound: isCompound ?? this.isCompound,
      defaultSets: defaultSets ?? this.defaultSets,
      defaultReps: defaultReps ?? this.defaultReps,
      defaultDurationSeconds:
          defaultDurationSeconds ?? this.defaultDurationSeconds,
      defaultWeight: defaultWeight ?? this.defaultWeight,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'],
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      primaryMuscles: List<String>.from(json['primary_muscles'] ?? []),
      secondaryMuscles: List<String>.from(json['secondary_muscles'] ?? []),
      equipment: List<String>.from(json['equipment'] ?? []),
      type: json['type'] ?? 'strength',
      difficulty: json['difficulty'] ?? 'beginner',
      instructions: List<String>.from(json['instructions'] ?? []),
      videoUrl: json['video_url'],
      imageUrl: json['image_url'],
      isCompound: json['is_compound'] ?? false,
      defaultSets: json['default_sets'],
      defaultReps: json['default_reps'],
      defaultDurationSeconds: json['default_duration_seconds'],
      defaultWeight: json['default_weight'] != null
          ? (json['default_weight'] as num).toDouble()
          : null,
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
      'primary_muscles': primaryMuscles,
      'secondary_muscles': secondaryMuscles,
      'equipment': equipment,
      'type': type,
      'difficulty': difficulty,
      'instructions': instructions,
      'video_url': videoUrl,
      'image_url': imageUrl,
      'is_compound': isCompound,
      'default_sets': defaultSets,
      'default_reps': defaultReps,
      'default_duration_seconds': defaultDurationSeconds,
      'default_weight': defaultWeight,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Check if exercise can be performed with available equipment
  bool canPerformWith(List<EquipmentType> availableEquipment) {
    if (equipment.isEmpty || equipment.contains(EquipmentType.bodyweight.name)) {
      return true;
    }
    return equipment.every((req) => availableEquipment.any((availEq) => availEq.name == req));
  }

  // Check if exercise targets specific muscle groups
  bool targetsMuscleGroup(MuscleGroup muscle) {
    return primaryMuscles.contains(muscle.toString().split('.').last) ||
        secondaryMuscles.contains(muscle.toString().split('.').last);
  }

  // Get all targeted muscle groups
  List<MuscleGroup> get allTargetedMuscles =>
      [...primaryMuscles, ...secondaryMuscles]
          .map((muscle) => MuscleGroup.values.firstWhere(
                (e) => e.toString().split('.').last == muscle,
                orElse: () => MuscleGroup.fullBody,
              ))
          .toList();
}
