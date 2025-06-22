import 'dart:convert';

class WorkoutEntry {
  final String id;
  final String name;
  final int durationMinutes; // Total minutes for easier calculations
  final DateTime date;
  final DateTime createdAt;

  WorkoutEntry({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.date,
    required this.createdAt,
  });

  // Convert WorkoutEntry to Map for Hive storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'durationMinutes': durationMinutes,
      'date': date.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  // Create WorkoutEntry from Map (from Hive storage)
  factory WorkoutEntry.fromMap(Map<String, dynamic> map) {
    return WorkoutEntry(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      durationMinutes: map['durationMinutes'] ?? 0,
      date: DateTime.parse(map['date']),
      createdAt: DateTime.parse(map['createdAt']),
    );
  }

  // Convert to JSON string
  String toJson() => json.encode(toMap());

  // Create from JSON string
  factory WorkoutEntry.fromJson(String source) => WorkoutEntry.fromMap(json.decode(source));

  // Create a copy with modified values
  WorkoutEntry copyWith({
    String? id,
    String? name,
    int? durationMinutes,
    DateTime? date,
    DateTime? createdAt,
  }) {
    return WorkoutEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'WorkoutEntry(id: $id, name: $name, durationMinutes: $durationMinutes, date: $date, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is WorkoutEntry &&
        other.id == id &&
        other.name == name &&
        other.durationMinutes == durationMinutes &&
        other.date == date &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        durationMinutes.hashCode ^
        date.hashCode ^
        createdAt.hashCode;
  }

  // Helper method to format duration
  String get formattedDuration {
    final hours = durationMinutes ~/ 60;
    final minutes = durationMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  // Helper to get hours and minutes separately
  Map<String, int> get durationComponents {
    return {
      'hours': durationMinutes ~/ 60,
      'minutes': durationMinutes % 60,
    };
  }
}

// Helper class for monthly workout data aggregation
class MonthlyWorkoutData {
  final int year;
  final int month;
  final Map<int, int> dailyTotalMinutes; // day of month -> total minutes

  MonthlyWorkoutData({
    required this.year,
    required this.month,
    required this.dailyTotalMinutes,
  });

  // Get total minutes for a specific day
  int getTotalMinutesForDay(int day) {
    return dailyTotalMinutes[day] ?? 0;
  }

  // Get the maximum minutes in any day this month
  int get maxDailyMinutes {
    if (dailyTotalMinutes.isEmpty) return 0;
    return dailyTotalMinutes.values.reduce((a, b) => a > b ? a : b);
  }

  // Get total workout minutes for the month
  int get totalMonthlyMinutes {
    return dailyTotalMinutes.values.fold(0, (sum, minutes) => sum + minutes);
  }

  // Get number of workout days in the month
  int get workoutDaysCount {
    return dailyTotalMinutes.values.where((minutes) => minutes > 0).length;
  }

  Map<String, dynamic> toMap() {
    return {
      'year': year,
      'month': month,
      'dailyTotalMinutes': dailyTotalMinutes,
    };
  }

  factory MonthlyWorkoutData.fromMap(Map<String, dynamic> map) {
    return MonthlyWorkoutData(
      year: map['year'] ?? 0,
      month: map['month'] ?? 0,
      dailyTotalMinutes: Map<int, int>.from(map['dailyTotalMinutes'] ?? {}),
    );
  }
} 