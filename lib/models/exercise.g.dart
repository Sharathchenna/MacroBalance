// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exercise.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExerciseAdapter extends TypeAdapter<Exercise> {
  @override
  final int typeId = 0;

  @override
  Exercise read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Exercise(
      id: fields[0] as String?,
      name: fields[1] as String,
      description: fields[2] as String,
      primaryMuscles: (fields[3] as List).cast<String>(),
      secondaryMuscles: (fields[4] as List).cast<String>(),
      equipment: (fields[5] as List).cast<String>(),
      type: fields[6] as String,
      difficulty: fields[7] as String,
      instructions: (fields[8] as List).cast<String>(),
      videoUrl: fields[9] as String?,
      imageUrl: fields[10] as String?,
      isCompound: fields[11] as bool,
      defaultSets: fields[12] as int?,
      defaultReps: fields[13] as int?,
      defaultDurationSeconds: fields[14] as int?,
      defaultWeight: fields[15] as double?,
      estimatedCaloriesBurnedPerMinute: fields[16] as double?,
      createdAt: fields[17] as DateTime?,
      updatedAt: fields[18] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Exercise obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.primaryMuscles)
      ..writeByte(4)
      ..write(obj.secondaryMuscles)
      ..writeByte(5)
      ..write(obj.equipment)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(7)
      ..write(obj.difficulty)
      ..writeByte(8)
      ..write(obj.instructions)
      ..writeByte(9)
      ..write(obj.videoUrl)
      ..writeByte(10)
      ..write(obj.imageUrl)
      ..writeByte(11)
      ..write(obj.isCompound)
      ..writeByte(12)
      ..write(obj.defaultSets)
      ..writeByte(13)
      ..write(obj.defaultReps)
      ..writeByte(14)
      ..write(obj.defaultDurationSeconds)
      ..writeByte(15)
      ..write(obj.defaultWeight)
      ..writeByte(16)
      ..write(obj.estimatedCaloriesBurnedPerMinute)
      ..writeByte(17)
      ..write(obj.createdAt)
      ..writeByte(18)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExerciseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
