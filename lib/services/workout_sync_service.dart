import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/workout_entry.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class WorkoutSyncService {
  static final WorkoutSyncService _instance = WorkoutSyncService._internal();
  factory WorkoutSyncService() => _instance;
  WorkoutSyncService._internal();

  final _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  // Check if user is authenticated
  bool get isUserAuthenticated => _supabase.auth.currentUser != null;

  // Sync a single workout entry to Supabase
  Future<void> syncWorkoutEntry(WorkoutEntry workout) async {
    print('[SYNC] Starting sync for workout: ${workout.name}');
    print('[SYNC] User authenticated: $isUserAuthenticated');
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('[SYNC] ERROR: User not logged in');
        return;
      }

      print('[SYNC] User ID: $userId');
      print('[SYNC] Workout data: ${workout.toMap()}');

      // Generate a proper UUID for the workout if it's not already a UUID
      String workoutId = workout.id;
      if (!_isValidUuid(workout.id)) {
        workoutId = _uuid.v4();
        print('[SYNC] Generated new UUID for workout: $workoutId');
      }

      final dataToSync = {
        'id': workoutId,
        'user_id': userId,
        'name': workout.name,
        'duration_minutes': workout.durationMinutes,
        'workout_date': workout.date.toIso8601String(),
        'created_at': workout.createdAt.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('[SYNC] Data being sent to Supabase: $dataToSync');

      final response = await _supabase.from('workout_entries').upsert(dataToSync);
      
      print('[SYNC] Supabase response: $response');
      print('[SYNC] Successfully synced workout entry: ${workout.name}');
    } catch (e, stackTrace) {
      print('[SYNC] ERROR syncing workout entry: $e');
      print('[SYNC] Stack trace: $stackTrace');
      // Don't throw error to avoid disrupting local functionality
    }
  }

  // Helper method to check if a string is a valid UUID
  bool _isValidUuid(String id) {
    try {
      // Check if it matches UUID format (8-4-4-4-12 hexadecimal digits)
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$', caseSensitive: false);
      return uuidRegex.hasMatch(id);
    } catch (e) {
      return false;
    }
  }

  // Delete a workout entry from Supabase
  Future<void> deleteWorkoutEntry(String workoutId) async {
    print('[SYNC] Starting delete for workout ID: $workoutId');
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('[SYNC] ERROR: Cannot delete workout - User not logged in');
        return;
      }

      print('[SYNC] Deleting workout from Supabase...');
      
      await _supabase
          .from('workout_entries')
          .delete()
          .eq('id', workoutId)
          .eq('user_id', userId);

      print('[SYNC] Successfully deleted workout entry: $workoutId');
    } catch (e, stackTrace) {
      print('[SYNC] ERROR deleting workout entry: $e');
      print('[SYNC] Stack trace: $stackTrace');
      // Don't throw error to avoid disrupting local functionality
    }
  }

  // Sync monthly workout statistics to Supabase
  Future<void> syncMonthlyStats(MonthlyWorkoutData monthlyData) async {
    print('[SYNC] Starting sync for monthly stats: ${monthlyData.year}-${monthlyData.month}');
    
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('[SYNC] ERROR: Cannot sync monthly stats - User not logged in');
        return;
      }

      // Convert Map<int, int> to Map<String, dynamic> for JSON serialization
      final dailyTotalMinutesJson = <String, dynamic>{};
      monthlyData.dailyTotalMinutes.forEach((day, minutes) {
        dailyTotalMinutesJson[day.toString()] = minutes;
      });

      final dataToSync = {
        'user_id': userId,
        'year': monthlyData.year,
        'month': monthlyData.month,
        'daily_total_minutes': dailyTotalMinutesJson,
        'updated_at': DateTime.now().toIso8601String(),
      };

      print('[SYNC] Monthly data being sent to Supabase: $dataToSync');

      await _supabase.from('workout_monthly_stats').upsert(dataToSync);

      print('[SYNC] Successfully synced monthly stats: ${monthlyData.year}-${monthlyData.month}');
    } catch (e, stackTrace) {
      print('[SYNC] ERROR syncing monthly stats: $e');
      print('[SYNC] Stack trace: $stackTrace');
      // Don't throw error to avoid disrupting local functionality
    }
  }

  // Fetch workout entries for a specific date range from Supabase
  Future<List<WorkoutEntry>> fetchWorkoutEntries(DateTime startDate, DateTime endDate) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('Cannot fetch workouts: User not logged in');
        return [];
      }

      final response = await _supabase
          .from('workout_entries')
          .select()
          .eq('user_id', userId)
          .gte('workout_date', startDate.toIso8601String())
          .lte('workout_date', endDate.toIso8601String())
          .order('workout_date', ascending: true);

      return response.map<WorkoutEntry>((data) => WorkoutEntry(
        id: data['id'],
        name: data['name'],
        durationMinutes: data['duration_minutes'],
        date: DateTime.parse(data['workout_date']),
        createdAt: DateTime.parse(data['created_at']),
      )).toList();
    } catch (e) {
      print('Error fetching workout entries: $e');
      return [];
    }
  }

  // Fetch monthly stats from Supabase
  Future<MonthlyWorkoutData?> fetchMonthlyStats(DateTime month) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('Cannot fetch monthly stats: User not logged in');
        return null;
      }

      final response = await _supabase
          .from('workout_monthly_stats')
          .select()
          .eq('user_id', userId)
          .eq('year', month.year)
          .eq('month', month.month)
          .maybeSingle();

      if (response == null) return null;

      // Convert string keys back to int keys when reading from Supabase
      final dailyTotalMinutesData = response['daily_total_minutes'] ?? {};
      final dailyTotalMinutes = <int, int>{};
      if (dailyTotalMinutesData is Map) {
        dailyTotalMinutesData.forEach((key, value) {
          final dayInt = int.tryParse(key.toString()) ?? 0;
          final minutesInt = (value is int) ? value : int.tryParse(value.toString()) ?? 0;
          if (dayInt > 0) {
            dailyTotalMinutes[dayInt] = minutesInt;
          }
        });
      }

      return MonthlyWorkoutData(
        year: response['year'],
        month: response['month'],
        dailyTotalMinutes: dailyTotalMinutes,
      );
    } catch (e) {
      print('Error fetching monthly stats: $e');
      return null;
    }
  }

  // Perform a full sync of all local workout data to Supabase
  Future<void> fullSyncToSupabase(List<WorkoutEntry> localWorkouts, List<MonthlyWorkoutData> localMonthlyData) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('Cannot perform full sync: User not logged in');
        return;
      }

      // Sync all workout entries
      for (final workout in localWorkouts) {
        await syncWorkoutEntry(workout);
      }

      // Sync all monthly data
      for (final monthData in localMonthlyData) {
        await syncMonthlyStats(monthData);
      }

      print('Full sync completed successfully');
    } catch (e) {
      print('Error during full sync: $e');
    }
  }

  // Fetch all workout data from Supabase and return as local-compatible format
  Future<Map<String, dynamic>> fetchAllWorkoutDataFromSupabase() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        print('Cannot fetch data: User not logged in');
        return {'workouts': <WorkoutEntry>[], 'monthlyData': <MonthlyWorkoutData>[]};
      }

      // Fetch all workout entries
      final workoutResponse = await _supabase
          .from('workout_entries')
          .select()
          .eq('user_id', userId)
          .order('workout_date', ascending: true);

      final workouts = workoutResponse.map<WorkoutEntry>((data) => WorkoutEntry(
        id: data['id'],
        name: data['name'],
        durationMinutes: data['duration_minutes'],
        date: DateTime.parse(data['workout_date']),
        createdAt: DateTime.parse(data['created_at']),
      )).toList();

      // Fetch all monthly stats
      final monthlyResponse = await _supabase
          .from('workout_monthly_stats')
          .select()
          .eq('user_id', userId)
          .order('year', ascending: true)
          .order('month', ascending: true);

      final monthlyData = monthlyResponse.map<MonthlyWorkoutData>((data) {
        // Convert string keys back to int keys when reading from Supabase
        final dailyTotalMinutesData = data['daily_total_minutes'] ?? {};
        final dailyTotalMinutes = <int, int>{};
        if (dailyTotalMinutesData is Map) {
          dailyTotalMinutesData.forEach((key, value) {
            final dayInt = int.tryParse(key.toString()) ?? 0;
            final minutesInt = (value is int) ? value : int.tryParse(value.toString()) ?? 0;
            if (dayInt > 0) {
              dailyTotalMinutes[dayInt] = minutesInt;
            }
          });
        }

        return MonthlyWorkoutData(
          year: data['year'],
          month: data['month'],
          dailyTotalMinutes: dailyTotalMinutes,
        );
      }).toList();

      return {'workouts': workouts, 'monthlyData': monthlyData};
    } catch (e) {
      print('Error fetching all workout data: $e');
      return {'workouts': <WorkoutEntry>[], 'monthlyData': <MonthlyWorkoutData>[]};
    }
  }

  // Test method to debug sync issues
  Future<void> testSync() async {
    print('[SYNC] === DEBUGGING SYNC SERVICE ===');
    print('[SYNC] Supabase client available: ${_supabase != null}');
    print('[SYNC] User authenticated: $isUserAuthenticated');
    
    final currentUser = _supabase.auth.currentUser;
    if (currentUser != null) {
      print('[SYNC] Current user ID: ${currentUser.id}');
      print('[SYNC] Current user email: ${currentUser.email}');
    } else {
      print('[SYNC] No current user found');
    }

    // Test database connection
    try {
      print('[SYNC] Testing database connection...');
      final response = await _supabase.from('workout_entries').select('count').limit(1);
      print('[SYNC] Database connection successful: $response');
    } catch (e, stackTrace) {
      print('[SYNC] Database connection failed: $e');
      print('[SYNC] Stack trace: $stackTrace');
    }

    // Test a simple sync
    if (isUserAuthenticated) {
      print('[SYNC] Testing sync with sample data...');
      try {
        final testWorkout = WorkoutEntry(
          id: _uuid.v4(),
          name: 'Test Workout',
          durationMinutes: 30,
          date: DateTime.now(),
          createdAt: DateTime.now(),
        );
        
        await syncWorkoutEntry(testWorkout);
        print('[SYNC] Test sync completed');
      } catch (e, stackTrace) {
        print('[SYNC] Test sync failed: $e');
        print('[SYNC] Stack trace: $stackTrace');
      }
    }
    
    print('[SYNC] === END DEBUGGING ===');
  }
} 