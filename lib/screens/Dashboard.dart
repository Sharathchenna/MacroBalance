import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/camera/barcode_results.dart' hide Serving;
import 'package:macrotracker/camera/ai_food_detail_page.dart'; // Added for AI processed results
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/providers/date_provider.dart';
import 'package:macrotracker/providers/food_entry_provider.dart';
import 'package:macrotracker/screens/macro_tracking_screen.dart';
import 'package:macrotracker/screens/steps_tracking_screen.dart';
import 'package:macrotracker/screens/tracking_pages_screen.dart';
import 'package:macrotracker/screens/accountdashboard.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:macrotracker/screens/workout_planning_screen.dart'; // Added for WorkoutPlanningScreen
import 'package:macrotracker/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Import Hive

import '../Health/Health.dart';
import '../services/camera_service.dart'; // Import CameraService
import '../services/storage_service.dart'; // Import StorageService
import '../services/nutrition_calculator_service.dart'; // Import NutritionCalculatorService
import '../utils/performance_monitor.dart';
import '../widgets/camera/camera_controls.dart'; // Import CameraMode

// Define the expected result structure at the top level
typedef CameraResult = Map<String, dynamic>;

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with PerformanceTrackingMixin {
  // Use CameraService instance
  final CameraService _cameraService = CameraService();

  @override
  void initState() {
    super.initState();

    trackOperation('dashboard_setup');

    // Provider initialization is now handled by ProxyProvider in main.dart
    // Just track that Dashboard is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        trackOperation('food_provider_refresh');
        final foodEntryProvider =
            Provider.of<FoodEntryProvider>(context, listen: false);

        endTracking('food_provider_refresh');
        print(
            'Dashboard: FoodEntryProvider state, calories_goal=${foodEntryProvider.caloriesGoal}, isInitialized=${foodEntryProvider.isInitialized}');
      }
    });

    endTracking('dashboard_setup');
  }

  // --- Flutter Camera Handling ---

  Future<void> _showFlutterCamera() async {
    try {
      print('[Flutter Dashboard] Showing camera with camera mode');
      // Use CameraService to show the Flutter camera
      final result = await _cameraService.showCamera(
        context: context,
        initialMode: CameraMode.camera,
      );

      print('[Flutter Dashboard] Camera result received: $result');
      print('[Flutter Dashboard] Widget mounted after camera: $mounted');

      if (result != null && mounted) {
        final String type = result['type'] as String;
        print('[Flutter Dashboard] Result type: $type');

        final dynamic value = result['value']; // Get value dynamically first

        if (type == 'barcode') {
          final String barcode = value as String;
          print('[Flutter Dashboard] Barcode value received: $barcode');
          _handleBarcodeResult(context, barcode);
        } else if (type == 'ai_processed_photo' ||
            type == 'ai_processed_label') {
          final List<AIFoodItem> foods = value as List<AIFoodItem>;
          print(
              '[Flutter Dashboard] AI Processed data with ${foods.length} foods received');
          if (foods.isNotEmpty) {
            Navigator.push(
              context,
              CupertinoPageRoute(
                  builder: (ctx) => AIFoodDetailPage(food: foods.first)),
            );
          } else {
            _showErrorSnackbar('AI processing returned no food items.');
          }
        } else if (type == 'photo') {
          // This is from gallery, value is Uint8List
          final Uint8List imageBytes =
              value as Uint8List; // Correctly cast to Uint8List
          print(
              '[Flutter Dashboard] Raw photo (gallery) Uint8List received: ${imageBytes.length} bytes.');
          // TODO: Implement AI processing for gallery images.
          // This could be done here by calling Gemini, or _pickFromGallery in FlutterCameraScreen
          // could be modified to do the processing before popping, similar to _takePicture.
          _showErrorSnackbar(
              'Gallery image selected. Displaying/processing this image type is not yet fully implemented here.');
        }
      } else {
        print('[Flutter Dashboard] No result or widget not mounted');
        if (result == null) {
          print('[Flutter Dashboard] Result was null - camera was cancelled');
        }
      }
    } catch (e) {
      print('[Flutter Dashboard] Error showing camera: ${e.toString()}');
      if (mounted) {
        _showErrorSnackbar('Failed to open camera');
      }
    }
  }

  // --- Helper Methods for Navigation ---

  void _handleBarcodeResult(BuildContext safeContext, String barcode) {
    print(
        '[Flutter Dashboard] Navigating to BarcodeResults with barcode: $barcode');
    print('[Flutter Dashboard] Widget mounted: $mounted');
    print('[Flutter Dashboard] Context valid: ${safeContext.mounted}');

    if (!mounted) {
      print('[Flutter Dashboard] Widget not mounted, aborting navigation');
      return;
    }

    try {
      print('[Flutter Dashboard] Attempting navigation to BarcodeResults...');
      Navigator.push(
        safeContext,
        MaterialPageRoute(builder: (context) {
          print('[Flutter Dashboard] Building BarcodeResults widget');
          return BarcodeResults(barcode: barcode);
        }),
      ).then((value) {
        print('[Flutter Dashboard] Navigation to BarcodeResults completed');
      }).catchError((error) {
        print('[Flutter Dashboard] Navigation error: $error');
      });
      print('[Flutter Dashboard] Navigation call made successfully');
    } catch (e) {
      print('[Flutter Dashboard] Error during navigation: $e');
      _showErrorSnackbar('Failed to open product details: $e');
    }
  }

  // --- UI Helper Methods ---

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    // Calculate dynamic sizes based on screen dimensions.
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody:
          true, // Allows body to go behind bottom nav bar if transparent
      floatingActionButtonLocation: FloatingActionButtonLocation.miniStartTop,
      body: Stack(
        children: [
          // Main Content Area
          Positioned.fill(
            child: Column(
              children: [
                // Date Navigator Bar (respecting safe area)
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: EdgeInsets.only(top: topPadding),
                  child: const DateNavigatorbar(),
                ),
                // Scrollable Content
                const Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // <-- Added const back here
                        SizedBox(height: 8), // Add some space after date bar
                        CalorieTracker(),
                        MealSection(),
                        // Add padding at the bottom to ensure content isn't hidden
                        // behind the floating navigation bar. Adjust height as needed.
                        SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Navigation Bar
          Positioned(
            bottom: screenHeight * 0.04, // Adjust as needed
            left: screenWidth * 0.18, // Adjust as needed
            right: screenWidth * 0.18, // Adjust as needed
            child: _buildFloatingNavBar(context),
          ),
        ],
      ),
    );
  }

  // Extracted Floating Navigation Bar build method
  Widget _buildFloatingNavBar(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          height: 45,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.0),
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.shade50.withAlpha(((0.4) * 255).round())
                : Colors.black.withAlpha(((0.4) * 255).round()),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.grey.withAlpha(((0.2) * 255).round())
                  : Colors.white.withAlpha(((0.1) * 255).round()),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black.withAlpha(((0.05) * 255).round())
                    : Colors.black.withAlpha(((0.2) * 255).round()),
                blurRadius: 10,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItemCompact(
                context: context,
                icon: CupertinoIcons.add,
                onTap: () => _showAddFoodMenu(context),
              ),
              _buildNavItemCompact(
                context: context,
                icon: CupertinoIcons.graph_circle,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (context) => const TrackingPagesScreen()),
                  );
                },
              ),
              _buildNavItemCompact(
                context: context,
                icon: CupertinoIcons.flame_fill,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (context) => const WorkoutPlanningScreen()),
                  );
                },
              ),
              _buildNavItemCompact(
                context: context,
                icon: CupertinoIcons.person,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (context) => const AccountDashboard()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Add method to show the add food menu
  void _showAddFoodMenu(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: Theme.of(context).extension<CustomColors>()?.cardBackground,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              _buildAddFoodOption(
                context: context,
                icon: CupertinoIcons.camera,
                title: 'AI Camera',
                subtitle: 'Take a photo of your food',
                onTap: () {
                  Navigator.pop(context);
                  _showFlutterCamera();
                },
              ),
              const SizedBox(height: 12),
              _buildAddFoodOption(
                context: context,
                icon: CupertinoIcons.bookmark,
                title: 'Saved Foods',
                subtitle: 'Quick access to your favorites',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/savedFoods');
                },
              ),
              const SizedBox(height: 12),
              _buildAddFoodOption(
                context: context,
                icon: CupertinoIcons.search,
                title: 'Search Foods',
                subtitle: 'Browse our food database',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                      builder: (context) => const FoodSearchPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // Helper method to build add food options
  Widget _buildAddFoodOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .extension<CustomColors>()
                            ?.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                CupertinoIcons.chevron_right,
                size: 20,
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey.shade600
                    : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Smaller compact navigation item with updated styling for frosted glass effect
Widget _buildNavItemCompact({
  required BuildContext context,
  required IconData icon,
  required VoidCallback onTap,
  bool isActive = false,
}) {
  return Expanded(
      child: InkWell(
    onTap: onTap,
    customBorder: const CircleBorder(),
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFFFFC107).withAlpha(((0.2) * 255).round())
            : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: const Color(0xFFFFC107),
        size: 24,
      ),
    ),
  ));
}

// --- DateNavigatorbar Widget ---
class DateNavigatorbar extends StatefulWidget {
  const DateNavigatorbar({super.key});

  @override
  State<DateNavigatorbar> createState() => _DateNavigatorbarState();
}

class _DateNavigatorbarState extends State<DateNavigatorbar> {
  DateTime selectedDate = DateTime.now();

  void _navigateDate(int days) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final newDate = dateProvider.selectedDate.add(Duration(days: days));
    dateProvider.setDate(newDate);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    final tomorrow = now.add(const Duration(days: 1));

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Today';
    }
    if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'Tomorrow';
    }
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Yesterday';
    }
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year.toString().substring(2)}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Add horizontal swipe gesture detection
      onHorizontalDragEnd: (details) {
        // Calculate swipe direction based on velocity
        if (details.primaryVelocity! > 0) {
          // Swipe right to left - go to previous day
          HapticFeedback.lightImpact();
          _navigateDate(-1);
        } else if (details.primaryVelocity! < 0) {
          // Swipe left to right - go to next day
          HapticFeedback.lightImpact();
          _navigateDate(1);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _buildNavigationButton(
                icon: Icons.chevron_left,
                onTap: () => _navigateDate(-1),
              ),
            ),
            Expanded(
              child: _buildDateButton(),
            ),
            Expanded(
              child: _buildNavigationButton(
                icon: Icons.chevron_right,
                onTap: () => _navigateDate(1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color:
          Theme.of(context).extension<CustomColors>()?.dateNavigatorBackground,
      shape: const CircleBorder(),
      elevation: 0.6, // Add subtle elevation
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.all(7.0), // Reduced from 8
          child: Icon(
            icon,
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.black
                : Colors.white,
            size: 18, // Add specific size
          ),
        ),
      ),
    );
  }

  Widget _buildDateButton() {
    return Consumer<DateProvider>(
      builder: (context, dateProvider, child) {
        return Center(
          child: InkWell(
            borderRadius: BorderRadius.circular(18.0),
            onTap: () {
              _showCalendarPopup(context, dateProvider);
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .extension<CustomColors>()
                    ?.dateNavigatorBackground,
                borderRadius: BorderRadius.circular(18.0),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    CupertinoIcons.calendar_today,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.black
                        : Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 6.0),
                  Text(
                    _formatDate(dateProvider.selectedDate),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Add this method to show the calendar popup
  void _showCalendarPopup(BuildContext context, DateProvider dateProvider) {
    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.4,
          padding: const EdgeInsets.only(top: 6.0),
          margin: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          color: Theme.of(context).brightness == Brightness.light
              ? CupertinoColors.systemBackground.resolveFrom(context)
              : CupertinoColors.darkBackgroundGray,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CupertinoButton(
                      child: const Text('Cancel'),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    CupertinoButton(
                      child: const Text(
                        'Done',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    mode: CupertinoDatePickerMode.date,
                    initialDateTime: dateProvider.selectedDate,
                    maximumDate: DateTime.now().add(const Duration(days: 365)),
                    minimumDate:
                        DateTime.now().subtract(const Duration(days: 365)),
                    onDateTimeChanged: (DateTime newDate) {
                      dateProvider.setDate(newDate);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --- CalorieTracker Widget ---
class CalorieTracker extends StatefulWidget {
  const CalorieTracker({super.key});

  @override
  State<CalorieTracker> createState() => _CalorieTrackerState();
}

class _CalorieTrackerState extends State<CalorieTracker> {
  final HealthService _healthService = HealthService();
  int _steps = 0;
  double _caloriesBurned = 0;
  bool _hasHealthPermissions = false;
  bool _isLoadingHealthData = false;
  DateTime? _lastFetchedDate;
  late DateProvider _dateProvider;
  final StorageService _storageService =
      StorageService(); // Instance of StorageService

  // Default goal, consider making this configurable or fetched
  // final int _stepsGoal = 9000;

  VoidCallback? _storageListener; // To hold the listener reference

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to ensure context is available for Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dateProvider = Provider.of<DateProvider>(context, listen: false);
      _initializeHealthData(); // Reads initial status and fetches if needed
      _dateProvider.addListener(_onDateChanged);

      // Set up listener for StorageService changes
      _storageListener = () {
        final currentStatus =
            _storageService.get('healthConnected', defaultValue: false);
        // Check if the status has changed and is now true
        if (currentStatus && !_hasHealthPermissions) {
          if (mounted) {
            setState(() {
              _hasHealthPermissions = true;
            });
            print('Health connection status changed to true, fetching data...');
            _fetchHealthData(); // Fetch data immediately on status change
          }
        } else if (!currentStatus && _hasHealthPermissions) {
          // Optional: Handle disconnection if needed
          if (mounted) {
            setState(() {
              _hasHealthPermissions = false;
              _steps = 0; // Reset data on disconnect
              _caloriesBurned = 0;
            });
            print('Health connection status changed to false.');
          }
        }
      };
      final box = Hive.box('user_preferences');
      box.listenable().addListener(_storageListener!);
    });
  }

  @override
  void dispose() {
    _dateProvider.removeListener(_onDateChanged);
    // Remove the listener when the widget is disposed
    if (_storageListener != null) {
      // Access the Hive box directly to remove the listener
      try {
        final box = Hive.box('user_preferences');
        box.listenable().removeListener(_storageListener!);
        print('Storage listener removed.');
      } catch (e) {
        print('Error removing storage listener: $e');
      }
    }
    super.dispose();
  }

  // Called when the DateProvider notifies listeners
  void _onDateChanged() {
    // Fetch data only if the date has actually changed since the last fetch
    final selectedDate = _dateProvider.selectedDate;
    if (_lastFetchedDate == null ||
        !_isSameDay(_lastFetchedDate!, selectedDate)) {
      _fetchHealthData();
    }
  }

  // Helper to check if two DateTime objects represent the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _initializeHealthData() async {
    // Read initial status from storage
    final initialStatus =
        _storageService.get('healthConnected', defaultValue: false);
    if (mounted) {
      setState(() {
        _hasHealthPermissions = initialStatus;
      });
    }

    // Initial fetch if permissions are already granted according to storage
    if (_hasHealthPermissions) {
      print('Initial health status is connected, fetching data...');
      await _fetchHealthData();
    } else {
      print('Initial health status is not connected.');
    }
  }

  // Future<void> _checkAndRequestPermissions() async {
  //   // Don't check if already checked and granted
  //   if (_hasHealthPermissions) return;

  //   try {
  //     final granted = await _healthService.requestPermissions();
  //     if (!mounted) return;
  //     setState(() {
  //       _hasHealthPermissions = granted;
  //     });

  //     if (!_hasHealthPermissions) {
  //       _showPermissionDialog();
  //     }
  //   } catch (e) {
  //     print('Error checking permissions: $e');
  //     if (mounted) {
  //       // Optionally show an error message to the user
  //     }
  //   }
  // }

  // void _showPermissionDialog() {
  //   showCupertinoDialog(
  //     context: context,
  //     builder: (context) => CupertinoAlertDialog(
  //       title: const Text('Health Data Access Required'),
  //       content: const Text(
  //           'This app needs access to your health data to track calories and steps.'),
  //       actions: [
  //         CupertinoDialogAction(
  //           child: const Text('Cancel'),
  //           onPressed: () => Navigator.pop(context),
  //         ),
  //         CupertinoDialogAction(
  //           child: const Text('Open Settings'),
  //           onPressed: () {
  //             Navigator.pop(context);
  //             // Open app settings using permission_handler
  //             openAppSettings(); // Call the imported function
  //           },
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Future<void> _fetchHealthData() async {
    // Ensure permissions are granted before fetching
    if (!_hasHealthPermissions) {
      print('Skipping health data fetch: Permissions not granted.');
      return;
    }
    if (_isLoadingHealthData) return; // Avoid concurrent fetches

    if (mounted) {
      setState(() {
        _isLoadingHealthData = true;
      });
    }

    // Get the selected date from the DateProvider
    // Ensure context is valid before accessing Provider
    if (!mounted) return;
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final selectedDate = dateProvider.selectedDate;

    // Avoid fetching if data for this date is already loaded, UNLESS it's today
    final bool isToday = _isSameDay(selectedDate, DateTime.now());
    if (!isToday &&
        _lastFetchedDate != null &&
        _isSameDay(_lastFetchedDate!, selectedDate)) {
      if (mounted) {
        setState(() {
          _isLoadingHealthData = false;
        });
      }
      return;
    }

    try {
      // Fetch steps specifically for the selected date
      final fetchedSteps = await _healthService.getStepsForDate(selectedDate);
      final fetchedCalories =
          await _healthService.getCaloriesForDate(selectedDate);

      if (mounted) {
        setState(() {
          _steps = fetchedSteps;
          _caloriesBurned = fetchedCalories;
          _lastFetchedDate = selectedDate; // Update the last fetched date
        });
      }
    } catch (e) {
      print('Error fetching health data: $e');
      if (mounted) {
        // Optionally show an error message
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingHealthData = false;
        });
      }
    }
  }

  // Helper method to get appropriate icons for macros
  IconData _getMacroIcon(String label) {
    switch (label) {
      case 'Carbs':
        return Icons.grain;
      case 'Protein':
        return Icons.fitness_center;
      case 'Fat':
        return Icons.opacity;
      case 'Steps':
        return Icons.directions_walk;
      default:
        return Icons.circle;
    }
  }

  // Helper method to build macro progress indicators
  Widget _buildMacroProgressEnhanced(BuildContext context, String label,
      int value, int goal, Color color, String unit) {
    final progress = goal > 0 ? (value / goal).clamp(0.0, 1.0) : 0.0;
    final textColor = Theme.of(context).brightness == Brightness.light
        ? Colors.grey.shade700 // Adjusted for better contrast in light mode
        : Colors.grey.shade300; // Adjusted for better contrast in dark mode

    // Use the original color for the percentage text in both themes for vibrancy
    final percentageColor = color;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        // Navigate to different sections based on the macro type
        if (label == 'Steps') {
          // Navigate to StepTrackingScreen
          Navigator.push(
            context,
            CupertinoPageRoute(
                builder: (context) => const StepTrackingScreen()),
          );
        } else if (label == 'Carbs' || label == 'Protein' || label == 'Fat') {
          // Navigate to MacroTrackingScreen
          Navigator.push(
            context,
            CupertinoPageRoute(
                builder: (context) => const MacroTrackingScreen()),
          );
        }
      },
      child: SizedBox(
        height: 116,
        width: 75,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 60,
                  width: 60,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 7,
                    strokeCap: StrokeCap.round,
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.light
                            ? color.withAlpha(((0.15) * 255).round())
                            : color.withAlpha(((0.2) * 255).round()),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                Icon(
                  _getMacroIcon(label),
                  color: color,
                  size: 22,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: value.toString(),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: percentageColor,
                    ),
                  ),
                  TextSpan(
                    text: '/$goal${unit.isNotEmpty ? unit : ''}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to build calorie info cards
  Widget _buildCalorieInfoCard(BuildContext context, String label, int value,
      Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 8), // Slightly increased padding
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? color.withAlpha(((0.1) * 255).round()) // Slightly more opacity
            : color.withAlpha(((0.2) * 255).round()), // Slightly more opacity
        borderRadius: BorderRadius.circular(12), // More rounded corners
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                  ),
                ),
                Text(
                  '$value',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context)
                        .extension<CustomColors>()
                        ?.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Don't use FutureBuilder here as it blocks UI - rely on provider state instead
    return Consumer2<FoodEntryProvider, DateProvider>(
      builder: (context, foodEntryProvider, dateProvider, child) {
        // Show loading only if provider is not initialized and is actively loading
        if (!foodEntryProvider.isInitialized && foodEntryProvider.isLoading) {
          return const SizedBox(
            height: 300,
            child: Center(child: CupertinoActivityIndicator()),
          );
        }

        // Show UI even if not fully loaded - it will update automatically when data arrives
        // Get nutrition goals directly from the provider
        final caloriesGoal = foodEntryProvider.caloriesGoal.toInt();
        debugPrint(
            '[Dashboard] Calorie Goal from provider: $caloriesGoal (isInitialized: ${foodEntryProvider.isInitialized})');
        final proteinGoal = foodEntryProvider.proteinGoal.toInt();
        final carbGoal = foodEntryProvider.carbsGoal.toInt();
        final fatGoal = foodEntryProvider.fatGoal.toInt();
        final stepsGoal = foodEntryProvider.stepsGoal.toInt();

        // Get nutrient totals using the new centralized method
        final nutrientTotals = foodEntryProvider
            .getNutritionTotalsForDate(dateProvider.selectedDate);
        final caloriesFromFood = nutrientTotals['calories'] ?? 0.0;
        // --- Dashboard Debug Log ---
        print(
            '[CalorieTracker Build] Received caloriesFromFood: $caloriesFromFood for date: ${dateProvider.selectedDate}');
        // --- End Debug Log ---
        final totalProtein = nutrientTotals['protein'] ?? 0.0;
        final totalCarbs = nutrientTotals['carbs'] ?? 0.0;
        final totalFat = nutrientTotals['fat'] ?? 0.0;

        // Calculate remaining calories (updated logic)
        // Handle potential division by zero if caloriesGoal is 0
        final num caloriesRemaining =
            caloriesGoal > 0 ? caloriesGoal - caloriesFromFood.toInt() : 0;
        double progress =
            caloriesGoal > 0 ? caloriesFromFood / caloriesGoal : 0.0;
        progress = progress.clamp(0.0, 1.0);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16), // Reduced from 20
          decoration: BoxDecoration(
            color: Theme.of(context).extension<CustomColors>()?.cardBackground,
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                // Softer shadow, more spread out
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey.shade300
                        .withValues(alpha: 0.5) // Lighter shadow for light mode
                    : Colors.black.withValues(
                        alpha: 0.2), // Slightly darker shadow for dark mode
                blurRadius: 20, // Increased blur
                spreadRadius: 0, // No spread, just blur
                offset: const Offset(0, 5), // Slightly increased offset
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align to start
            children: [
              // Add a header
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(children: [
                  Icon(
                    Icons.pie_chart_outline,
                    size: 20,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey.shade700
                        : Colors.grey.shade400,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "Today's Nutrition and Activity",
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.shade700
                          : Colors.grey.shade400,
                    ),
                  ),
                ]),
              ),

              // Main content column
              Column(
                children: [
                  // Calories Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Calorie Circle
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          Navigator.push(
                            context,
                            CupertinoPageRoute(
                              builder: (context) => const MacroTrackingScreen(),
                            ),
                          );
                        },
                        child: Container(
                          height: 130,
                          width: 130,
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness ==
                                    Brightness.light
                                ? Colors.white
                                : Colors.grey.shade900.withAlpha(
                                    ((0.3) * 255).round()), // Use withOpacity
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.grey.withAlpha(((0.1) * 255)
                                        .round()) // Use withOpacity
                                    : Colors.black.withAlpha(((0.2) * 255)
                                        .round()), // Use withOpacity
                                blurRadius: 10,
                                spreadRadius: 1,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Progress circle
                              SizedBox(
                                width: 110,
                                height: 110,
                                child: CircularProgressIndicator(
                                  value: progress,
                                  strokeWidth: 10,
                                  strokeCap: StrokeCap
                                      .round, // Added circular stroke cap
                                  backgroundColor:
                                      Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.grey.shade200
                                          : Colors.grey.shade800,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    progress > 1.0
                                        ? Colors.red
                                        : const Color(0xFF34C85A),
                                  ),
                                ),
                              ),
                              // Calorie text
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    caloriesRemaining.toString(),
                                    style: GoogleFonts.poppins(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .extension<CustomColors>()
                                          ?.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    'cal left',
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Calories Info - Vertical layout with colored cards
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment
                                .center, // Center items vertically
                            children: [
                              _buildCalorieInfoCard(
                                context,
                                'Goal',
                                caloriesGoal,
                                const Color(0xFF34C85A),
                                Icons.flag_outlined, // Use outlined icon
                              ),
                              const SizedBox(height: 8),
                              _buildCalorieInfoCard(
                                context,
                                'Food',
                                caloriesFromFood.toInt(),
                                const Color(0xFFFFA726),
                                Icons
                                    .restaurant_menu_outlined, // Use outlined icon
                              ),
                              const SizedBox(height: 8),
                              _buildCalorieInfoCard(
                                context,
                                'Burned',
                                _caloriesBurned
                                    .toInt(), // Use state variable _caloriesBurned
                                const Color(0xFF42A5F5),
                                Icons
                                    .local_fire_department_outlined, // Use outlined icon
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                      height: 30), // Increased space before macro rings

                  // Macro circles - Enhanced with circular progress
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildMacroProgressEnhanced(
                          context,
                          'Carbs',
                          totalCarbs.round(),
                          carbGoal,
                          const Color(0xFF42A5F5),
                          'g',
                        ),
                        _buildMacroProgressEnhanced(
                          context,
                          'Protein',
                          totalProtein.round(),
                          proteinGoal,
                          const Color(0xFFEF5350),
                          'g',
                        ),
                        _buildMacroProgressEnhanced(
                          context,
                          'Fat',
                          totalFat.round(),
                          fatGoal,
                          const Color(0xFFFFA726),
                          'g',
                        ),
                        _buildMacroProgressEnhanced(
                          context,
                          'Steps',
                          _steps, // Use state variable _steps
                          stepsGoal, // Use state variable stepsGoal
                          const Color(0xFF66BB6A),
                          '',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// --- MealSection Widget ---
class MealSection extends StatefulWidget {
  const MealSection({super.key});

  @override
  State<MealSection> createState() => _MealSectionState();
}

class _MealSectionState extends State<MealSection> {
  Map<String, bool> expandedState = {
    'Breakfast': false,
    'Lunch': false,
    'Snacks': false,
    'Dinner': false,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Use unique keys for meal cards to ensure proper rebuilding
          Consumer<DateProvider>(
            builder: (context, dateProvider, _) => Column(
              children: [
                _buildMealCard('Breakfast',
                    key: ValueKey('Breakfast-${dateProvider.selectedDate}')),
                _buildMealCard('Lunch',
                    key: ValueKey('Lunch-${dateProvider.selectedDate}')),
                _buildMealCard('Snacks',
                    key: ValueKey('Snacks-${dateProvider.selectedDate}')),
                _buildMealCard('Dinner',
                    key: ValueKey('Dinner-${dateProvider.selectedDate}')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealCard(String mealType, {Key? key}) {
    return Consumer2<FoodEntryProvider, DateProvider>(
      key: key,
      builder: (context, foodEntryProvider, dateProvider, child) {
        final entries = foodEntryProvider.getEntriesForMeal(
            dateProvider.selectedDate, mealType);

        // *** FIX: Use the nutrition calculator service method ***
        double totalCalories = entries.fold(
            0.0,
            (sum, entry) =>
                sum +
                NutritionCalculatorService.calculateNutrientForEntry(
                    entry, 'calories'));

        // --- Dashboard Debug Log ---
        print(
            '[MealCard Build - $mealType] Calculated totalCalories: $totalCalories for date: ${dateProvider.selectedDate}');
        // --- End Debug Log ---

        // Meal type icon mapping
        IconData getMealIcon() {
          switch (mealType) {
            case 'Breakfast':
              return Icons.breakfast_dining;
            case 'Lunch':
              return Icons.lunch_dining;
            case 'Dinner':
              return Icons.dinner_dining;
            case 'Snacks':
              return Icons.cookie;
            default:
              return Icons.restaurant;
          }
        }

        // Build the entire card including header and expandable content
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Theme.of(context).extension<CustomColors>()?.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                // Apply similar softer shadow as CalorieTracker card
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey.shade300
                        .withValues(alpha: 0.4) // Lighter shadow for light mode
                    : Colors.black.withValues(
                        alpha: 0.15), // Slightly darker shadow for dark mode
                blurRadius: 15, // Adjusted blur
                spreadRadius: 0,
                offset: const Offset(0, 4), // Adjusted offset
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            clipBehavior:
                Clip.antiAlias, // Important: clip to the border radius
            child: Column(
              children: [
                // Header section
                InkWell(
                  splashColor: Colors.transparent, // Remove splash effect
                  highlightColor: Colors.transparent, // Remove highlight effect
                  onTap: () {
                    setState(() {
                      expandedState[mealType] = !expandedState[mealType]!;
                    });
                    // Add haptic feedback for better interaction
                    HapticFeedback.lightImpact();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _getMealColor(mealType).withAlpha(
                                ((0.1) * 255).round()), // Use withOpacity
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            getMealIcon(),
                            color: _getMealColor(mealType),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mealType,
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .extension<CustomColors>()
                                      ?.textPrimary,
                                ),
                              ),
                              Text(
                                '${entries.length} item${entries.length != 1 ? 's' : ''}',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${totalCalories.toStringAsFixed(0)} kcal',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .extension<CustomColors>()
                                    ?.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(
                                begin: 0,
                                end: expandedState[mealType]! ? 1.0 : 0,
                              ),
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOutCubic,
                              builder: (context, value, child) {
                                return Transform.rotate(
                                  angle: value * 3.14159,
                                  child: Icon(
                                    Icons.expand_more,
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.grey.shade700
                                        : Colors.grey.shade400,
                                    size: 18,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Expandable content with improved animation
                AnimatedSize(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  child: expandedState[mealType]!
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Custom animated container for the divider
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 250),
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: const Divider(
                                    height: 1,
                                    thickness: 0.5,
                                  ),
                                );
                              },
                            ),
                            // Staggered animation for list items
                            for (int i = 0; i < entries.length; i++)
                              AnimatedOpacity(
                                opacity: 1.0,
                                duration: Duration(
                                    milliseconds: 200 + (i * 50).clamp(0, 300)),
                                curve: Curves.easeOutCubic,
                                child: AnimatedPadding(
                                  padding: const EdgeInsets.all(0),
                                  duration: Duration(
                                      milliseconds:
                                          200 + (i * 50).clamp(0, 300)),
                                  curve: Curves.easeOutCubic,
                                  child: Column(
                                    children: [
                                      _buildFoodItem(context, entries[i]),
                                      if (i < entries.length - 1)
                                        const Padding(
                                          // Added const
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 16.0),
                                          child: Divider(
                                              height: 1, thickness: 0.5),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            // Animated Add Food button
                            TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: 0.8 + (0.2 * value),
                                  child: Opacity(
                                    opacity: value,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8.0, horizontal: 16.0),
                                      child: TextButton.icon(
                                        icon: Icon(
                                          Icons.add_circle_outline,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                        label: Text(
                                          'Add Food to $mealType',
                                          style: GoogleFonts.poppins(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ),
                                        style: TextButton.styleFrom(
                                          backgroundColor: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withAlpha(((0.1) * 255).round()),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10, horizontal: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          minimumSize: const Size(
                                              double.infinity,
                                              40), // Added const
                                        ),
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          Navigator.push(
                                            context,
                                            CupertinoPageRoute(
                                              builder: (context) =>
                                                  FoodSearchPage(
                                                      selectedMeal: mealType),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Helper method for meal color
Color _getMealColor(String mealType) {
  switch (mealType) {
    case 'Breakfast':
      return Colors.orange;
    case 'Lunch':
      return Colors.green;
    case 'Dinner':
      return Colors.indigo;
    case 'Snacks':
      return Colors.purple;
    default:
      return Colors.blue;
  }
}

// Helper method for food items
Widget _buildFoodItem(BuildContext context, dynamic entry) {
  // Use the centralized calculation method from FoodEntryProvider
  // *** ADDED LOGGING ***
  debugPrint(
      '[Dashboard BuildFoodItem] Processing entry: ID=${entry.id}, Name=${entry.food.name}, Quantity=${entry.quantity}, Unit=${entry.unit}, ServingDesc=${entry.servingDescription}, Brand=${entry.food.brandName}');
  // *** END LOGGING ***

  final double calories =
      NutritionCalculatorService.calculateNutrientForEntry(entry, 'calories');

  // Determine the display unit based on the entry type
  String displayUnit;
  if (entry.food.brandName == 'AI Detected' &&
      entry.servingDescription != null) {
    // For AI entries with a serving description, use the description (excluding leading numbers)
    displayUnit = entry.servingDescription
        .replaceAll(RegExp(r'^\d+(\.\d+)?\s*x?\s*'), '')
        .trim(); // Refined Regex
  } else {
    // For other entries, use the stored unit
    displayUnit = entry.unit;
  }

  return Dismissible(
      key: Key(entry.id),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        // Remove the entry from the provider
        final foodEntryProvider =
            Provider.of<FoodEntryProvider>(context, listen: false);
        foodEntryProvider.removeEntry(entry.id);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36, // Reduced from 40
              height: 36, // Reduced from 40
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey.shade100
                    : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.restaurant,
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.grey.shade600
                    : Colors.grey.shade400,
                size: 18, // Reduced size
              ),
            ),
            const SizedBox(width: 12), // Reduced from 16
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.food.name,
                    style: GoogleFonts.poppins(
                      fontSize: 14, // Reduced from 16
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context)
                          .extension<CustomColors>()
                          ?.textPrimary,
                    ),
                  ),
                  // *** ADDED DISPLAY LOGGING ***
                  () {
                    debugPrint(
                        '[DISPLAY VALUE CHECK] Qty=${entry.quantity}, Unit=$displayUnit for ${entry.id}');
                    return const SizedBox.shrink();
                  }(),
                  // *** END DISPLAY LOGGING ***

                  Text(
                    '${entry.quantity.toStringAsFixed(entry.quantity.toInt() == entry.quantity ? 0 : 1)} $displayUnit', // Format quantity to show decimal only if needed
                    style: GoogleFonts.poppins(
                      fontSize: 11, // Reduced from 13
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${calories.toStringAsFixed(0)} kcal',
              style: GoogleFonts.poppins(
                fontSize: 13, // Reduced from 15
                fontWeight: FontWeight.w600,
                color: Theme.of(context).extension<CustomColors>()?.textPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                size: 20, // Reduced size
              ),
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.red.shade400
                  : Colors.red.shade300,
              onPressed: () {
                // Remove the entry from the provider
                final foodEntryProvider =
                    Provider.of<FoodEntryProvider>(context, listen: false);
                foodEntryProvider.removeEntry(entry.id);
              },
              padding: const EdgeInsets.all(8),
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ));
}
