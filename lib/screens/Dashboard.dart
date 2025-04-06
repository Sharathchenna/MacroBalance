import 'dart:convert';
import 'dart:io'; // For Platform check and File operations
import 'dart:typed_data'; // For Uint8List
import 'dart:ui'; // Used for ImageFilter

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart'; // Import Lottie package
import 'package:macrotracker/camera/barcode_results.dart'; // Import for navigation
import 'package:macrotracker/camera/results_page.dart'; // Import for navigation
import 'package:macrotracker/models/ai_food_item.dart'; // Import for type casting
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/expenditure_provider.dart'; // Added for TDEE
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/MacroTrackingScreen.dart'; // Added import
import 'package:macrotracker/screens/NativeStatsScreen.dart';
import 'package:macrotracker/screens/StepsTrackingScreen.dart'; // Added import
import 'package:macrotracker/screens/TrackingPagesScreen.dart';
import 'package:macrotracker/screens/accountdashboard.dart';
import 'package:macrotracker/screens/editGoals.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:macrotracker/screens/tdee_dashboard.dart'; // Added import for TDEE dashboard
import 'package:macrotracker/theme/app_theme.dart';
import 'package:path_provider/path_provider.dart'; // For temp directory
import 'package:permission_handler/permission_handler.dart'; // Import needed for openAppSettings
import 'package:provider/provider.dart';

import '../AI/gemini.dart'; // Import Gemini processing
import '../Health/Health.dart';

// Define the expected result structure at the top level
typedef CameraResult = Map<String, dynamic>;

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  // Method Channel for the native camera view (moved from CameraScreen)
  static const MethodChannel _nativeCameraViewChannel =
      MethodChannel('com.macrotracker/native_camera_view');

  @override
  void initState() {
    super.initState();
    _setupNativeCameraHandler(); // Set up the handler when the dashboard initializes

    // Ensure TDEE calculation is triggered on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final expenditureProvider =
          Provider.of<ExpenditureProvider>(context, listen: false);
      // Only update if not already loading and if no current value
      if (!expenditureProvider.isLoading &&
          expenditureProvider.currentExpenditure == null) {
        expenditureProvider.updateExpenditure();
      }
    });
  }

  // --- Native Camera Handling (Moved from CameraScreen) ---

  void _setupNativeCameraHandler() {
    _nativeCameraViewChannel.setMethodCallHandler((call) async {
      print('[Flutter Dashboard] Received method call: ${call.method}');
      switch (call.method) {
        case 'cameraResult':
          // Use addPostFrameCallback to ensure state is stable before navigating or showing dialogs
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              print(
                  '[Flutter Dashboard] Post-frame callback: Widget is unmounted. Ignoring result.');
              return;
            }

            final Map<dynamic, dynamic> result = call.arguments as Map;
            final String type = result['type'] as String;
            final currentContext = context; // Capture context safely

            if (type == 'barcode') {
              final String barcode = result['value'] as String;
              print(
                  '[Flutter Dashboard] Post-frame: Handling barcode: $barcode');
              _handleBarcodeResult(currentContext, barcode);
            } else if (type == 'photo') {
              final Uint8List photoData = result['value'] as Uint8List;
              print(
                  '[Flutter Dashboard] Post-frame: Handling photo data: ${photoData.lengthInBytes} bytes');
              // Don't await, let it process in the background
              _handlePhotoResult(currentContext, photoData);
            } else if (type == 'cancel') {
              print('[Flutter Dashboard] Post-frame: Handling cancel.');
              // No action needed on cancel in Dashboard, just log.
            } else {
              print(
                  '[Flutter Dashboard] Post-frame: Unknown camera result type: $type');
              if (mounted) {
                _showErrorSnackbar('Received unknown result from camera.');
              }
            }
          });
          break;
        default:
          print(
              '[Flutter Dashboard] Unknown method call from native: ${call.method}');
      }
    });
  }

  Future<void> _showNativeCamera() async {
    if (!Platform.isIOS) {
      print('[Flutter Dashboard] Native camera view only supported on iOS.');
      if (mounted) {
        _showErrorSnackbar('Camera feature is only available on iOS.');
      }
      return;
    }

    try {
      print('[Flutter Dashboard] Invoking showNativeCamera...');
      await _nativeCameraViewChannel.invokeMethod('showNativeCamera');
      print('[Flutter Dashboard] showNativeCamera invoked successfully.');
      // No navigation or state change needed here, handler will receive result
    } on PlatformException catch (e) {
      print('[Flutter Dashboard] Error showing native camera: ${e.message}');
      if (mounted) {
        _showErrorSnackbar('Failed to open camera: ${e.message}');
      }
    }
  }

  // --- Result Handling (Adapted from CameraScreen) ---

  void _handleBarcodeResult(BuildContext safeContext, String barcode) {
    print('[Flutter Dashboard] Navigating to BarcodeResults');
    if (!mounted) return;
    Navigator.push(
      safeContext,
      MaterialPageRoute(builder: (context) => BarcodeResults(barcode: barcode)),
    );
  }

  Future<void> _handlePhotoResult(
      BuildContext safeContext, Uint8List photoData) async {
    if (!mounted) return;

    _showLoadingDialog('Analyzing Image...'); // Show loading for Gemini

    try {
      // --- Gemini Processing ---
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(photoData);
      print('[Flutter Dashboard] Photo saved to temporary file: $tempPath');
      String jsonResponse = await processImageWithGemini(tempFile.path);
      print('[Flutter Dashboard] Gemini response received.');
      // try { await tempFile.delete(); } catch (e) { print('[Flutter Dashboard] Warn: Could not delete temp file: $e'); }
      jsonResponse =
          jsonResponse.trim().replaceAll('```json', '').replaceAll('```', '');
      dynamic decodedJson = json.decode(jsonResponse);
      List<dynamic> mealData;
      if (decodedJson is Map<String, dynamic> &&
          decodedJson.containsKey('meal') &&
          decodedJson['meal'] is List) {
        mealData = decodedJson['meal'] as List;
      } else if (decodedJson is List) {
        mealData = decodedJson;
      } else if (decodedJson is Map<String, dynamic>) {
        mealData = [decodedJson];
      } else {
        throw Exception('Unexpected JSON structure from Gemini');
      }
      final List<AIFoodItem> foods = mealData
          .map((food) => AIFoodItem.fromJson(food as Map<String, dynamic>))
          .toList();
      // --- End Gemini Processing ---

      // Dismiss loading dialog *before* navigating or showing snackbar
      if (mounted) {
        try {
          if (Navigator.of(safeContext, rootNavigator: true).canPop()) {
            Navigator.of(safeContext, rootNavigator: true)
                .pop(); // Dismiss dialog
          }
        } catch (e) {
          print("[Flutter Dashboard] Error dismissing loading dialog: $e");
        }
      }
      if (!mounted) return; // Check again after async gap

      // Check if Gemini identified any food
      if (foods.isEmpty) {
        print('[Flutter Dashboard] Gemini returned an empty food list.');
        _showErrorSnackbar('Unable to identify food, try again');
      } else {
        // Navigate to results page
        print('[Flutter Dashboard] Navigating to ResultsPage');
        Navigator.push(
          safeContext,
          CupertinoPageRoute(builder: (context) => ResultsPage(foods: foods)),
        );
      }
    } catch (e) {
      print(
          '[Flutter Dashboard] Error processing photo result: ${e.toString()}');
      if (mounted) {
        // Dismiss loading dialog in case of error
        try {
          if (Navigator.of(safeContext, rootNavigator: true).canPop()) {
            Navigator.of(safeContext, rootNavigator: true)
                .pop(); // Dismiss dialog
          }
        } catch (e) {
          print(
              "[Flutter Dashboard] Error dismissing loading dialog in catch: $e");
        }

        // Show generic error message
        _showErrorSnackbar('Something went wrong, try again');
      }
    }
    // No finally block needed here as dialog dismissal is handled within try/catch
  }

  // --- UI Helper Methods (Moved from CameraScreen) ---

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

  void _showLoadingDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      // Use a slightly transparent barrier
      barrierColor: Colors.black.withOpacity(0.3),
      builder: (BuildContext dialogContext) {
        // Improved Loading Dialog Layout
        return Dialog(
          backgroundColor: Theme.of(context).brightness == Brightness.light
              ? Colors.white
              : Colors.grey[850], // Dark mode background
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 30, horizontal: 24), // More padding
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center, // Center vertically
              children: [
                // Lottie animation
                Lottie.asset(
                  'assets/animations/food_loading.json', // Ensure this path is correct
                  width: 150, // Adjusted size
                  height: 150,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20), // Adjusted spacing
                Text(
                  message,
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black87
                          : Colors.white, // Adjust text color for theme
                      fontSize: 17),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
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
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: const [
                        // <-- Added const back here
                        SizedBox(height: 8), // Add some space after date bar
                        CalorieTracker(),
                        TdeeWidget(), // Added TDEE widget
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
                ? Colors.grey.shade50.withOpacity(0.4) // Use withOpacity
                : Colors.black.withOpacity(0.4), // Use withOpacity
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.grey.withOpacity(0.2)
                  : Colors.white.withOpacity(0.1),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).brightness == Brightness.light
                    ? Colors.black.withOpacity(0.05)
                    : Colors.black.withOpacity(0.2),
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
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const FoodSearchPage(),
                      ),
                    );
                  }),
              _buildNavItemCompact(
                context: context,
                icon: CupertinoIcons.camera,
                onTap: () {
                  HapticFeedback.lightImpact();
                  // Directly invoke the native camera view
                  _showNativeCamera();
                  // Result handling is now done in _setupNativeCameraHandler
                },
              ),
              _buildNavItemCompact(
                context: context,
                icon: CupertinoIcons.graph_circle,
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(
                        builder: (context) => TrackingPagesScreen()),
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
                        builder: (context) => AccountDashboard()),
                  );
                },
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
              ? const Color(0xFFFFC107).withOpacity(0.2) // Use withOpacity
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: const Color(0xFFFFC107),
          size: 24,
        ),
      ),
    ),
  );
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
  bool _hasHealthPermissions = false;
  bool _isLoadingHealthData = true;
  int _steps = 0;
  int _stepsGoal = 10000; // Default goal
  double _caloriesBurned = 0;
  DateTime? _lastFetchedDate;
  late DateProvider _dateProvider;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initialize and fetch health data
      if (mounted) {
        _dateProvider = Provider.of<DateProvider>(context, listen: false);
        _dateProvider.addListener(_onDateChanged);
        _initializeHealthData();
      }

      // Trigger TDEE calculation if needed
      final expenditureProvider =
          Provider.of<ExpenditureProvider>(context, listen: false);
      if (!expenditureProvider.isLoading &&
          expenditureProvider.currentExpenditure == null) {
        expenditureProvider.updateExpenditure();
      }
    });
  }

  @override
  void dispose() {
    // Remove listener when widget is disposed
    _dateProvider.removeListener(_onDateChanged);
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
    await _checkAndRequestPermissions();
    // Initial fetch if permissions are granted
    if (_hasHealthPermissions) {
      await _fetchHealthData();
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    // Don't check if already checked and granted
    if (_hasHealthPermissions) return;

    try {
      final granted = await _healthService.requestPermissions();
      if (!mounted) return;
      setState(() {
        _hasHealthPermissions = granted;
      });

      if (!_hasHealthPermissions) {
        _showPermissionDialog();
      }
    } catch (e) {
      print('Error checking permissions: $e');
      if (mounted) {
        // Optionally show an error message to the user
      }
    }
  }

  void _showPermissionDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Health Data Access Required'),
        content: const Text(
            'This app needs access to your health data to track calories and steps.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            child: const Text('Open Settings'),
            onPressed: () {
              Navigator.pop(context);
              // Open app settings using permission_handler
              openAppSettings(); // Call the imported function
            },
          ),
        ],
      ),
    );
  }

  Future<void> _fetchHealthData() async {
    if (!_hasHealthPermissions || _isLoadingHealthData) return;

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
    final percentage = (progress * 100).toInt();
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
        // Changed Container to SizedBox
        // Adjusted height to accommodate text below
        height: 125, // Slightly increased height for better spacing
        width: 75, // Slightly increased width for better spacing
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.start, // Align to start for better layout
          children: [
            // Original Stack with Progress Circle and Icon
            Stack(
              alignment: Alignment.center,
              children: [
                // Progress circle
                SizedBox(
                  height: 60, // Slightly smaller circle
                  width: 60,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 7, // Slightly thicker stroke
                    strokeCap: StrokeCap.round,
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.light
                            ? color.withOpacity(0.15) // Use withOpacity
                            : color.withOpacity(0.2), // Use withOpacity
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                ),
                // Macro icon
                Icon(
                  _getMacroIcon(label), // Use the helper method
                  color: color,
                  size: 22, // Slightly larger icon
                ),
              ],
            ),
            const SizedBox(height: 8), // Increased space
            // Label Text (e.g., Carbs)
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 12, // Kept size
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2), // Space between label and value
            // Value + Unit Text (e.g., 88g)
            Text(
              '$value$unit',
              style: GoogleFonts.poppins(
                fontSize: 12, // Increased size slightly
                fontWeight: FontWeight.w600, // Bolder weight
                color: textColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2), // Space between value and percentage
            // Percentage Text (e.g., 30%)
            Text(
              '$percentage%',
              style: GoogleFonts.poppins(
                fontSize: 11, // Slightly larger size
                fontWeight: FontWeight.w600, // Keep bold
                color: percentageColor, // Use the vibrant color
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
      height: 60, // Fixed height for each card
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).extension<CustomColors>()?.cardBackground,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            spreadRadius: 0,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey.shade700
                        : Colors.grey.shade300,
                  ),
                ),
                Text(
                  '$value',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
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

  // TDEE information card
  Widget _buildTdeeCard(BuildContext context) {
    return Consumer<ExpenditureProvider>(
      builder: (context, expenditureProvider, child) {
        // Show loading if TDEE is calculating
        if (expenditureProvider.isLoading) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).extension<CustomColors>()?.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoActivityIndicator(),
                SizedBox(width: 12),
                Text('Calculating your TDEE...'),
              ],
            ),
          );
        }

        // If TDEE is available, show the card with the value
        if (expenditureProvider.currentExpenditure != null) {
          final tdee = expenditureProvider.currentExpenditure!.toInt();
          return GestureDetector(
            onTap: () {
              // Navigate to detailed TDEE dashboard
              Navigator.push(
                context,
                CupertinoPageRoute(
                    builder: (context) => const TdeeDashboardScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).extension<CustomColors>()?.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 0,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bolt,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your TDEE',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .extension<CustomColors>()
                                ?.textPrimary,
                          ),
                        ),
                        Text(
                          'Total Daily Energy Expenditure',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$tdee',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    ' kcal',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          );
        }

        // If TDEE could not be calculated, show a card with an explanation
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).extension<CustomColors>()?.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 0,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bolt,
                  color: Colors.grey,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TDEE Unavailable',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .extension<CustomColors>()
                            ?.textPrimary,
                      ),
                    ),
                    Text(
                      'Log daily weight and food to calculate your TDEE',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use FutureBuilder to ensure provider is initialized before building UI
    return FutureBuilder(
      future: Provider.of<FoodEntryProvider>(context, listen: false)
          .ensureInitialized(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading indicator while the provider initializes
          // Make the loading indicator fill the space
          return const SizedBox(
            // Changed Container to SizedBox
            height: 300, // Give it a reasonable height
            child: Center(child: CupertinoActivityIndicator()),
          );
        } else if (snapshot.hasError) {
          // Handle initialization error
          return SizedBox(
              // Changed Container to SizedBox
              height: 300,
              child: Center(
                  child: Text('Error initializing data: ${snapshot.error}')));
        } else {
          // Provider is initialized, build the main UI
          return Consumer2<FoodEntryProvider, DateProvider>(
            builder: (context, foodEntryProvider, dateProvider, child) {
              // Get nutrition goals directly from the provider
              final caloriesGoal = foodEntryProvider.caloriesGoal.toInt();
              debugPrint(
                  "Dashboard Calorie Goal: $caloriesGoal"); // Add debug print
              final proteinGoal = foodEntryProvider.proteinGoal.toInt();
              final carbGoal = foodEntryProvider.carbsGoal.toInt();
              final fatGoal = foodEntryProvider.fatGoal.toInt();

              // Calculate total macros from all food entries for the selected date
              final entries = foodEntryProvider
                  .getAllEntriesForDate(dateProvider.selectedDate);

              double totalCarbs = 0;
              double totalFat = 0;
              double totalProtein = 0;

              for (var entry in entries) {
                final carbs =
                    entry.food.nutrients["Carbohydrate, by difference"] ?? 0;
                final fat = entry.food.nutrients["Total lipid (fat)"] ?? 0;
                final protein = entry.food.nutrients["Protein"] ?? 0;

                // Convert quantity to grams
                double quantityInGrams = entry.quantity;
                switch (entry.unit) {
                  case "oz":
                    quantityInGrams *= 28.35;
                    break;
                  case "kg":
                    quantityInGrams *= 1000;
                    break;
                  case "lbs":
                    quantityInGrams *= 453.59;
                    break;
                }

                // Since nutrients are per 100g, divide by 100 to get per gram
                final multiplier = quantityInGrams / 100;
                totalCarbs += carbs * multiplier;
                totalFat += fat * multiplier;
                totalProtein += protein * multiplier;
              }

              // Calculate calories from food entries
              final caloriesFromFood = foodEntryProvider
                  .getTotalCaloriesForDate(dateProvider.selectedDate);

              // Calculate remaining calories (updated logic)
              // Handle potential division by zero if caloriesGoal is 0
              final int caloriesRemaining = caloriesGoal > 0
                  ? caloriesGoal - caloriesFromFood.toInt()
                  : 0;
              double progress =
                  caloriesGoal > 0 ? caloriesFromFood / caloriesGoal : 0.0;
              progress = progress.clamp(0.0, 1.0);

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16), // Reduced from 20
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .extension<CustomColors>()
                      ?.cardBackground,
                  borderRadius: BorderRadius.circular(20.0),
                  boxShadow: [
                    BoxShadow(
                      // Softer shadow, more spread out
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.shade300
                              .withOpacity(0.5) // Lighter shadow for light mode
                          : Colors.black.withOpacity(
                              0.2), // Slightly darker shadow for dark mode
                      blurRadius: 20, // Increased blur
                      spreadRadius: 0, // No spread, just blur
                      offset: const Offset(0, 5), // Slightly increased offset
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start, // Align to start
                  children: [
                    // Add a header
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(children: [
                        Icon(
                          Icons.pie_chart_outline,
                          size: 20,
                          color:
                              Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey.shade700
                                  : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Today's Nutrition and Activity",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color:
                                Theme.of(context).brightness == Brightness.light
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
                                    builder: (context) =>
                                        const MacroTrackingScreen(),
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
                                      : Colors.grey.shade900
                                          .withOpacity(0.3), // Use withOpacity
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.grey.withOpacity(
                                              0.1) // Use withOpacity
                                          : Colors.black.withOpacity(
                                              0.2), // Use withOpacity
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
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
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
                                            color:
                                                Theme.of(context).brightness ==
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
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
                                _stepsGoal, // Use state variable _stepsGoal
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
          _buildMealCard('Breakfast'),
          _buildMealCard('Lunch'),
          _buildMealCard('Snacks'),
          _buildMealCard('Dinner'),
          // Removed SizedBox here since we added it to the main column
        ],
      ),
    );
  }

  Widget _buildMealCard(String mealType) {
    return Consumer2<FoodEntryProvider, DateProvider>(
      builder: (context, foodEntryProvider, dateProvider, child) {
        final entries = foodEntryProvider.getEntriesForMeal(
            mealType, dateProvider.selectedDate);
        // Calculate calories with proper unit conversion
        double totalCalories = entries.fold(0, (sum, entry) {
          double multiplier = entry.quantity;
          // Convert to grams if needed
          switch (entry.unit) {
            case "oz":
              multiplier *= 28.35;
              break;
            case "kg":
              multiplier *= 1000;
              break;
            case "lbs":
              multiplier *= 453.59;
              break;
          }
          multiplier /= 100; // Since calories are per 100g
          return sum + (entry.food.calories * multiplier);
        });

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
                        .withOpacity(0.4) // Lighter shadow for light mode
                    : Colors.black.withOpacity(
                        0.15), // Slightly darker shadow for dark mode
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
                            color: _getMealColor(mealType)
                                .withOpacity(0.1), // Use withOpacity
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
                                      _buildFoodItem(context, entries[i],
                                          foodEntryProvider),
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
                                              .withOpacity(0.1),
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
Widget _buildFoodItem(
    BuildContext context, dynamic entry, FoodEntryProvider provider) {
  // Calculate calories with proper unit conversion
  double quantityInGrams = entry.quantity;
  switch (entry.unit) {
    case "oz":
      quantityInGrams *= 28.35;
      break;
    case "kg":
      quantityInGrams *= 1000;
      break;
    case "lbs":
      quantityInGrams *= 453.59;
      break;
  }
  final caloriesForQuantity = entry.food.calories * (quantityInGrams / 100);

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
      provider.removeEntry(entry.id);
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 10), // Reduced padding
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
                Text(
                  '${entry.quantity}${entry.unit}',
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
            '${caloriesForQuantity.toStringAsFixed(0)} kcal',
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
              provider.removeEntry(entry.id);
            },
            padding: const EdgeInsets.all(8), // Smaller padding for icon button
            constraints: const BoxConstraints(), // Remove constraints
          ),
        ],
      ),
    ),
  );
}

// --- TdeeWidget ---
class TdeeWidget extends StatelessWidget {
  const TdeeWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ExpenditureProvider>(
      builder: (context, expenditureProvider, child) {
        // Show loading if TDEE is calculating
        if (expenditureProvider.isLoading) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  Theme.of(context).extension<CustomColors>()?.cardBackground,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  spreadRadius: 0,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CupertinoActivityIndicator(),
                SizedBox(width: 12),
                Text('Calculating your TDEE...'),
              ],
            ),
          );
        }

        // If TDEE is available, show the card with the value
        if (expenditureProvider.currentExpenditure != null) {
          final tdee = expenditureProvider.currentExpenditure!.toInt();
          return GestureDetector(
            onTap: () {
              // Navigate to detailed TDEE dashboard
              Navigator.push(
                context,
                CupertinoPageRoute(
                    builder: (context) => const TdeeDashboardScreen()),
              );
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).extension<CustomColors>()?.cardBackground,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 0,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.bolt,
                      color: Theme.of(context).colorScheme.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your TDEE',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context)
                                .extension<CustomColors>()
                                ?.textPrimary,
                          ),
                        ),
                        Text(
                          'Total Daily Energy Expenditure',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.grey.shade600
                                    : Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$tdee',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    ' kcal',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey.shade600
                        : Colors.grey.shade400,
                  ),
                ],
              ),
            ),
          );
        }

        // If TDEE could not be calculated, show a card with an explanation
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).extension<CustomColors>()?.cardBackground,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                spreadRadius: 0,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bolt,
                  color: Colors.grey,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TDEE Unavailable',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .extension<CustomColors>()
                            ?.textPrimary,
                      ),
                    ),
                    Text(
                      'Log daily weight and food to calculate your TDEE',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.grey.shade600
                            : Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
