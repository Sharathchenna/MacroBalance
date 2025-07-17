import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:convert';
import '../services/storage_service.dart';
import '../services/workout_sync_service.dart';
import '../models/workout_entry.dart';
import 'package:uuid/uuid.dart';
import '../services/posthog_service.dart';

class WorkoutTrackingScreen extends StatefulWidget {
  final bool hideAppBar;

  const WorkoutTrackingScreen({
    Key? key,
    this.hideAppBar = false,
  }) : super(key: key);

  @override
  State<WorkoutTrackingScreen> createState() => _WorkoutTrackingScreenState();
}

class _WorkoutTrackingScreenState extends State<WorkoutTrackingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  List<WorkoutEntry> _todayWorkouts = [];
  MonthlyWorkoutData? _currentMonthData;
  DateTime _currentMonth = DateTime.now();
  bool _isLoading = true;
  int _totalTodayMinutes = 0;
  final WorkoutSyncService _syncService = WorkoutSyncService();
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    // Track screen view
    PostHogService.trackScreen('workout_tracking_screen');
    
    _loadWorkoutData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkoutData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load today's workouts
      await _loadTodayWorkouts();
      
      // Load current month data
      await _loadMonthData(_currentMonth);
      
      // Perform background sync with Supabase (don't wait for it)
      _backgroundSync();
      
      _animationController.forward();
    } catch (e) {
      print('Error loading workout data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Background sync with Supabase
  Future<void> _backgroundSync() async {
    try {
      // This runs in the background and doesn't block the UI
      if (!_syncService.isUserAuthenticated) {
        print('User not logged in, skipping sync');
        return;
      }

      // Try to fetch recent data from Supabase to sync with local
      final today = DateTime.now();
      final weekAgo = today.subtract(const Duration(days: 7));
      
      final supabaseWorkouts = await _syncService.fetchWorkoutEntries(weekAgo, today);
      final currentMonthSupabaseStats = await _syncService.fetchMonthlyStats(_currentMonth);
      
      // Check if we have newer data locally that needs to be synced up
      // This is a simple approach - in a more complex app you'd want proper conflict resolution
      
      print('Background sync completed - found ${supabaseWorkouts.length} workouts from Supabase');
      
    } catch (e) {
      print('Background sync failed: $e');
      // Fail silently to not disrupt user experience
    }
  }

  Future<void> _loadTodayWorkouts() async {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd').format(today);
    final workoutsData = StorageService().get('workouts_$todayKey');
    
    if (workoutsData != null) {
      // If it's a List directly from Hive
      if (workoutsData is List) {
        _todayWorkouts = workoutsData.map((w) => WorkoutEntry.fromMap(Map<String, dynamic>.from(w))).toList();
      } else {
        // Fallback for JSON string (for backward compatibility)
        final List<dynamic> workoutsList = json.decode(workoutsData);
        _todayWorkouts = workoutsList.map((w) => WorkoutEntry.fromMap(w)).toList();
      }
    } else {
      _todayWorkouts = [];
    }
    
    _totalTodayMinutes = _todayWorkouts.fold(0, (sum, w) => sum + w.durationMinutes);
  }

  Future<void> _loadMonthData(DateTime month) async {
    final monthKey = DateFormat('yyyy-MM').format(month);
    final monthData = StorageService().get('monthly_workouts_$monthKey');
    
    if (monthData != null) {
      // If it's a Map directly from Hive
      if (monthData is Map) {
        _currentMonthData = MonthlyWorkoutData.fromMap(Map<String, dynamic>.from(monthData));
      } else {
        // Fallback for JSON string (for backward compatibility)
        final Map<String, dynamic> monthMap = json.decode(monthData);
        _currentMonthData = MonthlyWorkoutData.fromMap(monthMap);
      }
    } else {
      _currentMonthData = MonthlyWorkoutData(
        year: month.year,
        month: month.month,
        dailyTotalMinutes: {},
      );
    }
  }

  Future<void> _saveWorkoutEntry(WorkoutEntry workout) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(workout.date);
      
      // Add to daily workouts
      final currentWorkoutsData = StorageService().get('workouts_$dateKey');
      List<WorkoutEntry> dayWorkouts = [];
      
      if (currentWorkoutsData != null) {
        if (currentWorkoutsData is List) {
          // Direct List from Hive
          dayWorkouts = currentWorkoutsData.map((w) => WorkoutEntry.fromMap(Map<String, dynamic>.from(w))).toList();
        } else {
          // Fallback for JSON string
          final List<dynamic> workoutsList = json.decode(currentWorkoutsData);
          dayWorkouts = workoutsList.map((w) => WorkoutEntry.fromMap(w)).toList();
        }
      }
      
      dayWorkouts.add(workout);
      
      // Store as native Dart objects (List of Maps) for Hive
      final workoutsData = dayWorkouts.map((w) => w.toMap()).toList();
      StorageService().put('workouts_$dateKey', workoutsData);
      
      // Sync to Supabase
      await _syncService.syncWorkoutEntry(workout);
      
      // Update monthly aggregation
      await _updateMonthlyData(workout.date, workout.durationMinutes);
      
      // Check if the workout date is in a different month than currently displayed
      final workoutMonth = DateTime(workout.date.year, workout.date.month);
      final currentDisplayedMonth = DateTime(_currentMonth.year, _currentMonth.month);
      
      // If the workout is for a different month, switch to that month
      if (workoutMonth != currentDisplayedMonth) {
        setState(() {
          _currentMonth = workoutMonth;
        });
      }
      
      // Refresh today's data if the workout is for today
      if (DateFormat('yyyy-MM-dd').format(workout.date) == 
          DateFormat('yyyy-MM-dd').format(DateTime.now())) {
        await _loadTodayWorkouts();
      }
      
      // Reload month data for the currently displayed month (which might have changed)
      await _loadMonthData(_currentMonth);
      
      setState(() {});
      
    } catch (e) {
      print('Error saving workout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving workout: $e')),
      );
    }
  }

  Future<void> _updateMonthlyData(DateTime date, int additionalMinutes) async {
    final monthKey = DateFormat('yyyy-MM').format(date);
    final day = date.day;
    
    // Load existing monthly data
    final monthData = StorageService().get('monthly_workouts_$monthKey');
    Map<int, int> dailyTotals = {};
    
    if (monthData != null) {
      if (monthData is Map) {
        // Direct Map from Hive
        final monthDataObj = MonthlyWorkoutData.fromMap(Map<String, dynamic>.from(monthData));
        dailyTotals = Map.from(monthDataObj.dailyTotalMinutes);
      } else {
        // Fallback for JSON string
        final monthMap = json.decode(monthData);
        final monthDataObj = MonthlyWorkoutData.fromMap(monthMap);
        dailyTotals = Map.from(monthDataObj.dailyTotalMinutes);
      }
    }
    
    // Add new minutes to the day
    dailyTotals[day] = (dailyTotals[day] ?? 0) + additionalMinutes;
    
    print('Updating monthly data for $monthKey, day $day: ${dailyTotals[day]} minutes (added $additionalMinutes)');
    print('Full daily totals: $dailyTotals');
    
    // Save updated monthly data as native Dart Map for Hive
    final updatedMonthData = MonthlyWorkoutData(
      year: date.year,
      month: date.month,
      dailyTotalMinutes: dailyTotals,
    );
    
    StorageService().put('monthly_workouts_$monthKey', updatedMonthData.toMap());
    
    // Sync monthly stats to Supabase
    await _syncService.syncMonthlyStats(updatedMonthData);
    
    print('Saved monthly data: ${updatedMonthData.toMap()}');
  }

  Future<void> _deleteWorkout(WorkoutEntry workout) async {
    try {
      final dateKey = DateFormat('yyyy-MM-dd').format(workout.date);
      
      // Remove from daily workouts
      final currentWorkoutsData = StorageService().get('workouts_$dateKey');
      if (currentWorkoutsData != null) {
        List<WorkoutEntry> dayWorkouts = [];
        
        if (currentWorkoutsData is List) {
          // Direct List from Hive
          dayWorkouts = currentWorkoutsData.map((w) => WorkoutEntry.fromMap(Map<String, dynamic>.from(w))).toList();
        } else {
          // Fallback for JSON string
          final List<dynamic> workoutsList = json.decode(currentWorkoutsData);
          dayWorkouts = workoutsList.map((w) => WorkoutEntry.fromMap(w)).toList();
        }
        
        dayWorkouts.removeWhere((w) => w.id == workout.id);
        
        if (dayWorkouts.isEmpty) {
          StorageService().delete('workouts_$dateKey');
        } else {
          final workoutsData = dayWorkouts.map((w) => w.toMap()).toList();
          StorageService().put('workouts_$dateKey', workoutsData);
        }
      }
      
      // Delete from Supabase
      await _syncService.deleteWorkoutEntry(workout.id);
      
      // Update monthly aggregation (subtract the deleted workout)
      await _updateMonthlyData(workout.date, -workout.durationMinutes);
      
      // Refresh data
      await _loadTodayWorkouts();
      await _loadMonthData(_currentMonth);
      
      setState(() {});
      
    } catch (e) {
      print('Error deleting workout: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting workout: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customColors = theme.extension<CustomColors>()!;

    Widget body = _isLoading
        ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(customColors.accentPrimary),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading workout data...',
                  style: GoogleFonts.inter(
                    color: customColors.textSecondary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          )
        : SafeArea(
            child: RefreshIndicator(
              onRefresh: _loadWorkoutData,
              color: customColors.accentPrimary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildContributionGraph(customColors),
                          const SizedBox(height: 32),
                          _buildTodaySection(customColors),
                          const SizedBox(height: 50),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

    if (!widget.hideAppBar) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'Workout Tracking',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: customColors.textPrimary,
            ),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: theme.brightness == Brightness.light
              ? SystemUiOverlayStyle.dark
              : SystemUiOverlayStyle.light,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: customColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: body,
      );
    }

    return body;
  }

  Widget _buildTodaySection(CustomColors customColors) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - _animationController.value)),
          child: Opacity(
            opacity: _animationController.value,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: customColors.cardBackground,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today\'s Workouts',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: customColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, MMMM d').format(DateTime.now()),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: customColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildTotalTimeCard(customColors),
                  const SizedBox(height: 16),
                  _buildWorkoutsList(customColors),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuickAddSection(CustomColors customColors) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          _showAddWorkoutDialog();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                customColors.accentPrimary.withOpacity(0.08),
                customColors.accentPrimary.withOpacity(0.03),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: customColors.accentPrimary.withOpacity(0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                color: customColors.accentPrimary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Add Workout',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: customColors.accentPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddWorkoutButton(CustomColors customColors) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          _showAddWorkoutDialog();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: customColors.accentPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline,
                color: customColors.accentPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Add Workout',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: customColors.accentPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalTimeCard(CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            customColors.accentPrimary.withOpacity(0.1),
            customColors.accentPrimary.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: customColors.accentPrimary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: customColors.accentPrimary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.timer_outlined,
              color: customColors.accentPrimary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total Workout Time',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: customColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTotalDuration(_totalTodayMinutes),
                  style: GoogleFonts.inter(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: customColors.accentPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTotalDuration(int minutes) {
    if (minutes == 0) return '0 minutes';
    
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;
    
    if (hours > 0) {
      if (remainingMinutes > 0) {
        return '${hours}h ${remainingMinutes}m';
      } else {
        return '${hours}h';
      }
    } else {
      return '${remainingMinutes}m';
    }
  }

  Widget _buildWorkoutsList(CustomColors customColors) {
    if (_todayWorkouts.isEmpty) {
      return Center(child: Container(
        padding: const EdgeInsets.all(20),
        // decoration: BoxDecoration(
        //   color: customColors.dateNavigatorBackground.withOpacity(0.3),
        //   borderRadius: BorderRadius.circular(12),
        // ),
        child: Column(  
          children: [
            Icon(
              Icons.fitness_center_outlined,
              size: 48,
              color: customColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'No workouts today',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: customColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Tap "Add Workout" to get started!',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: customColors.textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ));
    }

    return Column(
      children: _todayWorkouts.asMap().entries.map((entry) {
        final index = entry.key;
        final workout = entry.value;
        return Padding(
          padding: EdgeInsets.only(bottom: index < _todayWorkouts.length - 1 ? 12 : 0),
          child: _buildWorkoutCard(workout, customColors),
        );
      }).toList(),
    );
  }

  Widget _buildWorkoutCard(WorkoutEntry workout, CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: customColors.dateNavigatorBackground,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: customColors.accentPrimary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.fitness_center,
              color: customColors.accentPrimary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workout.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: customColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.timer,
                      size: 14,
                      color: customColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      workout.formattedDuration,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: customColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: customColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('h:mm a').format(workout.createdAt),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: customColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onOpened: () {
              HapticFeedback.lightImpact();
            },
            onSelected: (value) {
              HapticFeedback.lightImpact();
              switch (value) {
                case 'edit':
                  _showEditWorkoutDialog(workout);
                  break;
                case 'delete':
                  _showDeleteConfirmation(workout);
                  break;
              }
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            color: customColors.cardBackground,
            shadowColor: Colors.black.withOpacity(0.1),
            offset: const Offset(-8, 8),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                height: 48,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: customColors.accentPrimary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: customColors.accentPrimary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Edit',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: customColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                height: 48,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Delete',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: customColors.cardBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: customColors.dateNavigatorBackground,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.more_vert,
                color: customColors.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContributionGraph(CustomColors customColors) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _animationController.value)),
          child: Opacity(
            opacity: _animationController.value,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: customColors.cardBackground,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Monthly Activity',
                            style: GoogleFonts.inter(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: customColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            DateFormat('MMMM yyyy').format(_currentMonth),
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: customColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: _canNavigateToPrevious() ? () {
                              HapticFeedback.lightImpact();
                              _navigateToPreviousMonth();
                            } : null,
                            icon: Icon(
                              Icons.chevron_left,
                              color: _canNavigateToPrevious() 
                                  ? customColors.textPrimary 
                                  : customColors.textSecondary.withOpacity(0.3),
                              size: 28,
                            ),
                          ),
                          IconButton(
                            onPressed: _canNavigateToNext() ? () {
                              HapticFeedback.lightImpact();
                              _navigateToNextMonth();
                            } : null,
                            icon: Icon(
                              Icons.chevron_right,
                              color: _canNavigateToNext() 
                                  ? customColors.textPrimary 
                                  : customColors.textSecondary.withOpacity(0.3),
                              size: 28,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildQuickAddSection(customColors),
                  const SizedBox(height: 28),
                  WorkoutContributionGraph(
                    monthlyData: _currentMonthData,
                    customColors: customColors,
                    currentMonth: _currentMonth,
                  ),
                  const SizedBox(height: 20),
                  // _buildLegend(customColors),
                  // const SizedBox(height: 16),
                  _buildMonthlyStats(customColors),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLegend(CustomColors customColors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Less',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: customColors.textSecondary,
          ),
        ),
        Row(
          children: List.generate(5, (index) {
            final intensity = index / 4;
            return Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(left: 3),
              decoration: BoxDecoration(
                color: _getColorForIntensity(intensity, customColors),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
        Text(
          'More',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: customColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Color _getColorForIntensity(double intensity, CustomColors customColors) {
    if (intensity == 0) {
      return customColors.dateNavigatorBackground;
    }
    return customColors.accentPrimary.withOpacity(0.2 + (intensity * 0.8));
  }

  bool _canNavigateToPrevious() {
    // Allow navigation to previous months without limit for now
    return true;
  }

  bool _canNavigateToNext() {
    final now = DateTime.now();
    final currentYearMonth = DateTime(now.year, now.month);
    final selectedYearMonth = DateTime(_currentMonth.year, _currentMonth.month);
    
    return selectedYearMonth.isBefore(currentYearMonth);
  }

  void _navigateToPreviousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
    _loadMonthData(_currentMonth);
  }

  void _navigateToNextMonth() {
    if (_canNavigateToNext()) {
      setState(() {
        _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      });
      _loadMonthData(_currentMonth);
    }
  }

  void _showAddWorkoutDialog() {
    _showWorkoutDialog();
  }

  void _showEditWorkoutDialog(WorkoutEntry workout) {
    _showWorkoutDialog(editingWorkout: workout);
  }

  void _showWorkoutDialog({WorkoutEntry? editingWorkout}) {
    final isEditing = editingWorkout != null;
    String workoutName = isEditing ? editingWorkout.name : '';
    int hours = 0;
    int minutes = 5; // Default to minimum 5 minutes
    DateTime selectedDate = isEditing ? editingWorkout.date : DateTime.now(); // Initialize with workout date or today
    
    if (isEditing) {
      final components = editingWorkout.durationComponents;
      hours = components['hours']!;
      minutes = components['minutes']!;
    }

    final nameController = TextEditingController(text: workoutName);
    final customColors = Theme.of(context).extension<CustomColors>()!;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final totalMinutes = (hours * 60) + minutes;
            final isValid = workoutName.trim().isNotEmpty && 
                           totalMinutes >= 5 && 
                           totalMinutes <= 355;

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isEditing ? 'Edit Workout' : 'Add Workout',
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: customColors.textPrimary,
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: Icon(Icons.close, color: customColors.textSecondary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Workout name input
                        TextField(
                          controller: nameController,
                          decoration: InputDecoration(
                            labelText: 'Workout Name',
                            hintText: 'e.g., Morning Run, Push Day, Yoga',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: customColors.accentPrimary),
                            ),
                          ),
                          onChanged: (value) {
                            setDialogState(() {
                              workoutName = value;
                            });
                          },
                        ),
                        
                      const SizedBox(height: 12),
                      Container(
                        // padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: customColors.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                          // border: Border.all(
                          //   color: customColors.dateNavigatorBackground,
                          // ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  color: customColors.accentPrimary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  DateFormat('MMM d, yyyy').format(selectedDate),
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: customColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                showCupertinoModalPopup(
                                  context: context,
                                  builder: (_) => Container(
                                    height: 250,
                                    color: customColors.cardBackground,
                                    child: Column(
                                      children: [
                                        // Header with Done button
                                        Container(
                                          color: customColors.cardBackground,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              CupertinoButton(
                                                child: Text(
                                                  'Done',
                                                  style: TextStyle(color: customColors.accentPrimary),
                                                ),
                                                onPressed: () {
                                                  HapticFeedback.lightImpact();
                                                  Navigator.of(context).pop();
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        // The Date Picker
                                        Expanded(
                                          child: CupertinoDatePicker(
                                            mode: CupertinoDatePickerMode.date,
                                            initialDateTime: selectedDate,
                                            maximumDate: DateTime.now(),
                                            minimumDate: DateTime(2020),
                                            onDateTimeChanged: (DateTime newDate) {
                                              HapticFeedback.selectionClick();
                                              setDialogState(() {
                                                selectedDate = newDate;
                                              });
                                            },
                                            backgroundColor: customColors.cardBackground,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                'Change',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: customColors.accentPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 12),
                      
                      // Duration section
                        Text(
                          'Duration',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: customColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Container(
                          height: 120,
                          decoration: BoxDecoration(
                            color: customColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: customColors.dateNavigatorBackground,
                            ),
                          ),
                          child: Row(
                            children: [
                              // Hours picker
                              Expanded(
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        'Hours',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: customColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: CupertinoPicker(
                                        itemExtent: 32,
                                        onSelectedItemChanged: (index) {
                                          HapticFeedback.lightImpact();
                                          setDialogState(() {
                                            hours = index;
                                          });
                                        },
                                        scrollController: FixedExtentScrollController(
                                          initialItem: hours,
                                        ),
                                        children: List.generate(6, (index) {
                                          return Center(
                                            child: Text(
                                              '$index',
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                color: customColors.textPrimary,
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              Container(
                                width: 1,
                                color: customColors.dateNavigatorBackground,
                              ),
                              
                              // Minutes picker
                              Expanded(
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        'Minutes',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: customColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: CupertinoPicker(
                                        itemExtent: 32,
                                        onSelectedItemChanged: (index) {
                                          HapticFeedback.lightImpact();
                                          setDialogState(() {
                                            minutes = index * 5;
                                          });
                                        },
                                        scrollController: FixedExtentScrollController(
                                          initialItem: minutes ~/ 5,
                                        ),
                                        children: List.generate(12, (index) {
                                          final minute = index * 5;
                                          return Center(
                                            child: Text(
                                              '$minute',
                                              style: GoogleFonts.inter(
                                                fontSize: 16,
                                                color: customColors.textPrimary,
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Duration info
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: customColors.accentPrimary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16,
                                color: customColors.accentPrimary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  // isValid
                                       'Total: ${_formatTotalDuration(totalMinutes)}',
                                      // : 'Duration must be between 5 minutes and 5 hours',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: customColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  'Cancel',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: customColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                                              onPressed: isValid ? () async {
                                HapticFeedback.mediumImpact();
                                final workout = WorkoutEntry(
                                  id: isEditing ? editingWorkout.id : _uuid.v4(),
                                  name: workoutName.trim(),
                                  durationMinutes: totalMinutes,
                                  date: selectedDate,
                                  createdAt: DateTime.now(),
                                );
                                  
                                  if (isEditing) {
                                    // Delete old workout first, then add new one
                                    await _deleteWorkout(editingWorkout);
                                  }
                                  
                                  await _saveWorkoutEntry(workout);
                                  Navigator.pop(context);
                                  
                                  HapticFeedback.heavyImpact();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isEditing 
                                            ? 'Workout updated successfully!' 
                                            : 'Workout added successfully!',
                                      ),
                                      backgroundColor: Colors.green,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                } : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: customColors.accentPrimary,
                                  disabledBackgroundColor: customColors.textSecondary.withOpacity(0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: Text(
                                  isEditing ? 'Update' : 'Add',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showDeleteConfirmation(WorkoutEntry workout) {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Workout',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: customColors.textPrimary,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${workout.name}"?',
          style: GoogleFonts.inter(
            color: customColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: customColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              await _deleteWorkout(workout);
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Workout deleted'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStats(CustomColors customColors) {
    final totalMinutes = _currentMonthData?.totalMonthlyMinutes ?? 0;
    final workoutDays = _currentMonthData?.workoutDaysCount ?? 0;
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    
    // Debug print to check the data
    print('Monthly stats - Total minutes: $totalMinutes, Workout days: $workoutDays, Daily totals: ${_currentMonthData?.dailyTotalMinutes}');
    
    return Row(
      children: [
        // Expanded(
        //   child: _buildStatCard(
        //     'Total Time',
        //     _formatTotalDuration(totalMinutes),
        //     Icons.timer_outlined,
        //     customColors,
        //   ),
        // ),
        // const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Active Days',
            '$workoutDays/$daysInMonth',
            Icons.calendar_today_outlined,
            customColors,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, CustomColors customColors) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: customColors.accentPrimary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: customColors.accentPrimary.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: customColors.accentPrimary,
            size: 20,
          ),
          const SizedBox(width: 20),
          Column(
            children: [
              Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: customColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: customColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          ],
          ),
        ],
      ),
    );
  }
}

// GitHub-style contribution graph widget
class WorkoutContributionGraph extends StatelessWidget {
  final MonthlyWorkoutData? monthlyData;
  final CustomColors customColors;
  final DateTime currentMonth;

  const WorkoutContributionGraph({
    Key? key,
    required this.monthlyData,
    required this.customColors,
    required this.currentMonth,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate dynamic height based on available width
        const int cols = 7; // 7 days
        const double spacingRatio = 0.15; // 15% of cell size for spacing
        
        // Calculate rows needed based on days in current month
        final daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
        final rows = (daysInMonth / cols).ceil();
        
        // Calculate cell size based on available width
        final availableWidth = constraints.maxWidth;
        final cellSize = (availableWidth - (cols - 1) * (availableWidth * spacingRatio / cols)) / cols;
        final spacing = cellSize * spacingRatio;
        final totalHeight = (cellSize * rows) + (spacing * (rows - 1));
        
        return CustomPaint(
          size: Size(constraints.maxWidth, totalHeight),
          painter: ContributionGraphPainter(
            monthlyData: monthlyData,
            customColors: customColors,
            currentMonth: currentMonth,
            cellSize: cellSize,
            cellSpacing: spacing,
          ),
        );
      },
    );
  }
}

class ContributionGraphPainter extends CustomPainter {
  final MonthlyWorkoutData? monthlyData;
  final CustomColors customColors;
  final DateTime currentMonth;
  final double cellSize;
  final double cellSpacing;

  ContributionGraphPainter({
    required this.monthlyData,
    required this.customColors,
    required this.currentMonth,
    required this.cellSize,
    required this.cellSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate grid dimensions
    final daysInMonth = DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    const int cols = 7; // 7 columns
    final rows = (daysInMonth / cols).ceil(); // Calculate rows needed based on days in month
    
    // Create grid starting from the beginning of the row
    for (int i = 0; i < daysInMonth; i++) {
      final row = i ~/ cols;
      final col = i % cols;
      final dayNumber = i + 1;
      
      final x = col * (cellSize + cellSpacing);
      final y = row * (cellSize + cellSpacing);
      
      // Get workout minutes for this day
      final minutes = monthlyData?.getTotalMinutesForDay(dayNumber) ?? 0;
      
      // Calculate color intensity (0 to 1, where 1 = 90+ minutes)
      final intensity = math.min(minutes / 120.0, 1.0);
      
      // Get color for this intensity
      final color = _getColorForIntensity(intensity);
      
      // Draw cell
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, cellSize, cellSize),
        const Radius.circular(3),
      );
      
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      
      canvas.drawRRect(rect, paint);
      
      // Add border for today
      final today = DateTime.now();
      if (currentMonth.year == today.year && 
          currentMonth.month == today.month && 
          dayNumber == today.day) {
        final borderPaint = Paint()
          ..color = customColors.accentPrimary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;
        
        canvas.drawRRect(rect, borderPaint);
      }
    }
  }

  Color _getColorForIntensity(double intensity) {
    if (intensity == 0) {
      return customColors.dateNavigatorBackground;
    }
    return customColors.accentPrimary.withOpacity(0.2 + (intensity * 0.8));
  }

  @override
  bool shouldRepaint(ContributionGraphPainter oldDelegate) {
    return oldDelegate.monthlyData != monthlyData ||
           oldDelegate.currentMonth != currentMonth ||
           oldDelegate.cellSize != cellSize ||
           oldDelegate.cellSpacing != cellSpacing;
  }
} 