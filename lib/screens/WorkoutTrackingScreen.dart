import 'package:flutter/cupertino.dart';
import 'package:macrotracker/widgets/app_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'dart:math' as math;
import 'dart:convert';
import '../services/storage_service.dart';
import '../services/workout_sync_service.dart';
import '../models/workout_entry.dart';
import 'package:uuid/uuid.dart';
import '../services/posthog_service.dart';
import '../widgets/progress_card.dart';

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
      if (mounted) setState(() {
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
        if (mounted) setState(() {
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
      
      if (mounted) setState(() {});
      
    } catch (e) {
      print('Error saving workout: $e');
      if (!mounted) return;
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
      
      if (mounted) setState(() {});
      
    } catch (e) {
      print('Error deleting workout: $e');
      if (!mounted) return;
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
        : RefreshIndicator(
            onRefresh: _loadWorkoutData,
            color: customColors.accentPrimary,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(
                  16, 16, 16, AppBottomBar.scrollClearance),
              children: [
                _buildTodaySection(customColors),
                const SizedBox(height: 16),
                _buildContributionGraph(customColors),
              ],
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
          offset: Offset(0, 20 * (1 - _animationController.value)),
          child: Opacity(opacity: _animationController.value, child: child),
        );
      },
      child: ProgressCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressCardTitle(
              'Today',
              trailing: ProgressAddButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showAddWorkoutDialog();
                },
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat.MMMMEEEEd().format(DateTime.now()),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: customColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            if (_todayWorkouts.isNotEmpty) ...[
              _buildTotalTimeCard(customColors),
              const SizedBox(height: 14),
            ],
            _buildWorkoutsList(customColors),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalTimeCard(CustomColors customColors) {
    return Row(
      children: [
        Expanded(
          child: ProgressStat(
            label: 'Time',
            value: _formatTotalDuration(_totalTodayMinutes),
          ),
        ),
        Expanded(
          child: ProgressStat(
            label: 'Workouts',
            value: '${_todayWorkouts.length}',
          ),
        ),
      ],
    );
  }

  String _formatTotalDuration(int minutes) {
    if (minutes == 0) return '0m';
    
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
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: customColors.textSecondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.fitness_center,
                size: 18, color: customColors.textSecondary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No workouts yet today.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: customColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      );
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
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: customColors.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
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
          const SizedBox(width: 12),
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
                      TimeOfDay.fromDateTime(workout.createdAt).format(context),
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
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                Icons.more_horiz_rounded,
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
    final totalMinutes = _currentMonthData?.totalMonthlyMinutes ?? 0;
    final workoutDays = _currentMonthData?.workoutDaysCount ?? 0;
    Widget navButton(IconData icon, bool enabled, VoidCallback onTap) =>
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  onTap();
                }
              : null,
          icon: Icon(
            icon,
            size: 22,
            color: enabled
                ? customColors.textPrimary
                : customColors.textSecondary.withValues(alpha: 0.3),
          ),
        );
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - _animationController.value)),
          child: Opacity(opacity: _animationController.value, child: child),
        );
      },
      child: ProgressCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ProgressCardTitle(
              DateFormat.yMMMM().format(_currentMonth),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  navButton(Icons.chevron_left_rounded,
                      _canNavigateToPrevious(), _navigateToPreviousMonth),
                  navButton(Icons.chevron_right_rounded,
                      _canNavigateToNext(), _navigateToNextMonth),
                ],
              ),
            ),
            const SizedBox(height: 12),
            WorkoutContributionGraph(
              monthlyData: _currentMonthData,
              customColors: customColors,
              currentMonth: _currentMonth,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ProgressStat(
                    label: 'Active days',
                    value: '$workoutDays',
                  ),
                ),
                Expanded(
                  child: ProgressStat(
                    label: 'Total time',
                    value: _formatTotalDuration(totalMinutes),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
                                  DateFormat.yMMMd().format(selectedDate),
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
                                  
                                  // The sheet's context is gone once it closes;
                                  // use the screen's messenger instead.
                                  final messenger = ScaffoldMessenger.of(this.context);
                                  if (isEditing) {
                                    // Delete old workout first, then add new one
                                    await _deleteWorkout(editingWorkout);
                                  }
                                  
                                  await _saveWorkoutEntry(workout);
                                  if (!context.mounted) return;
                                  Navigator.pop(context);
                                  
                                  HapticFeedback.heavyImpact();
                                  messenger.showSnackBar(
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
              // Capture before closing: the dialog's context is unusable after.
              final messenger = ScaffoldMessenger.of(this.context);
              Navigator.pop(context);
              await _deleteWorkout(workout);
              
              messenger.showSnackBar(
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
}

/// The month as a calendar: weekday columns, day numbers, and a green fill
/// that deepens with the minutes worked out that day.
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
    final l10n = MaterialLocalizations.of(context);
    final firstWeekday = l10n.firstDayOfWeekIndex; // 0 = Sunday
    final first = DateTime(currentMonth.year, currentMonth.month, 1);
    final daysInMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0).day;
    // DateTime.weekday is 1 (Mon) to 7 (Sun); make Sunday 0.
    final lead = (first.weekday % 7 - firstWeekday) % 7;
    final weeks = ((lead + daysInMonth) / 7).ceil();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    Widget cell(int day) {
      final date = DateTime(currentMonth.year, currentMonth.month, day);
      final minutes = monthlyData?.getTotalMinutesForDay(day) ?? 0;
      final intensity = math.min(minutes / 120.0, 1.0);
      final isToday = date == today;
      final future = date.isAfter(today);
      final fill = intensity == 0
          ? future
              ? Colors.transparent
              : customColors.textSecondary.withValues(alpha: 0.08)
          : customColors.accentPrimary.withValues(alpha: 0.3 + intensity * 0.7);
      return AspectRatio(
        aspectRatio: 1,
        child: Container(
          margin: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(8),
            border: isToday
                ? Border.all(color: customColors.accentPrimary, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight:
                  isToday || intensity > 0 ? FontWeight.w600 : FontWeight.w400,
              color: intensity > 0.4
                  ? customColors.onAccent
                  : future
                      ? customColors.textSecondary.withValues(alpha: 0.45)
                      : isToday || intensity > 0
                          ? customColors.textPrimary
                          : customColors.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Center(
                  child: Text(
                    l10n.narrowWeekdays[(firstWeekday + i) % 7],
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: customColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var w = 0; w < weeks; w++)
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: Builder(builder: (context) {
                    final day = w * 7 + d - lead + 1;
                    return day < 1 || day > daysInMonth
                        ? const AspectRatio(aspectRatio: 1)
                        : cell(day);
                  }),
                ),
            ],
          ),
      ],
    );
  }
}
