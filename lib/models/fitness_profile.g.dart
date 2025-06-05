// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fitness_profile.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FitnessProfileAdapter extends TypeAdapter<FitnessProfile> {
  @override
  final int typeId = 4;

  @override
  FitnessProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FitnessProfile(
      fitnessLevel: fields[0] as String,
      yearsOfExperience: fields[1] as int,
      previousExerciseTypes: (fields[2] as List).cast<String>(),
      workoutLocation: fields[3] as String,
      availableEquipment: (fields[4] as List).cast<String>(),
      hasGymAccess: fields[5] as bool,
      workoutSpace: fields[6] as String,
      workoutsPerWeek: fields[7] as int,
      maxWorkoutDuration: fields[8] as int,
      preferredTimeOfDay: fields[9] as String,
      preferredDays: (fields[10] as List).cast<String>(),
      injuries: (fields[11] as List?)?.cast<String>(),
      limitations: (fields[12] as List?)?.cast<String>(),
      primaryGoal: fields[13] as String?,
      secondaryGoals: (fields[14] as List?)?.cast<String>(),
      aiPreferences: (fields[15] as Map?)?.cast<String, dynamic>(),
      lastUpdated: fields[16] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, FitnessProfile obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.fitnessLevel)
      ..writeByte(1)
      ..write(obj.yearsOfExperience)
      ..writeByte(2)
      ..write(obj.previousExerciseTypes)
      ..writeByte(3)
      ..write(obj.workoutLocation)
      ..writeByte(4)
      ..write(obj.availableEquipment)
      ..writeByte(5)
      ..write(obj.hasGymAccess)
      ..writeByte(6)
      ..write(obj.workoutSpace)
      ..writeByte(7)
      ..write(obj.workoutsPerWeek)
      ..writeByte(8)
      ..write(obj.maxWorkoutDuration)
      ..writeByte(9)
      ..write(obj.preferredTimeOfDay)
      ..writeByte(10)
      ..write(obj.preferredDays)
      ..writeByte(11)
      ..write(obj.injuries)
      ..writeByte(12)
      ..write(obj.limitations)
      ..writeByte(13)
      ..write(obj.primaryGoal)
      ..writeByte(14)
      ..write(obj.secondaryGoals)
      ..writeByte(15)
      ..write(obj.aiPreferences)
      ..writeByte(16)
      ..write(obj.lastUpdated);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitnessProfileAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
