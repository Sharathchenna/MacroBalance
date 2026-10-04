import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/camera/barcode_results.dart' hide Serving;
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:provider/provider.dart';

import '../services/camera_service.dart';
import '../services/posthog_service.dart';
import '../services/photo_analysis_service.dart';
import '../providers/dateProvider.dart';
import '../utils/meal_time.dart';
import 'accountdashboard.dart';
import 'dashboard/components/components.dart';
import 'TrackingPagesScreen.dart';

// Define the expected result structure at the top level
typedef CameraResult = Map<String, dynamic>;

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  final CameraService _cameraService = CameraService();

  @override
  void initState() {
    super.initState();
    _setupNativeCameraHandler();
    PostHogService.trackScreen('dashboard');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final foodEntryProvider = Provider.of<FoodEntryProvider>(context, listen: false);
        final shouldForceSync = foodEntryProvider.entries.isEmpty ||
            (foodEntryProvider.caloriesGoal == 2000.0 &&
                foodEntryProvider.proteinGoal == 150.0);

        if (shouldForceSync) {
          foodEntryProvider.forceSyncAndDiagnose().then((_) {
            print('Dashboard: FoodEntryProvider refreshed on first launch');
            if (mounted) setState(() {});
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _cameraService.removeResultListener(_onCameraCall);
    super.dispose();
  }

  void _setupNativeCameraHandler() {
    _cameraService.addResultListener(_onCameraCall);
  }

  Future<dynamic> _onCameraCall(MethodCall call) async {
    print('[Flutter Dashboard] Received method call: ${call.method}');
    switch (call.method) {
      case 'cameraResult':
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final Map<dynamic, dynamic> result = call.arguments as Map;
          final String type = result['type'] as String;
          final currentContext = context;

          if (type == 'barcode') {
            final String barcode = result['value'] as String;
            print('[Flutter Dashboard] Post-frame: Handling barcode: $barcode');
            _handleBarcodeResult(currentContext, barcode);
          } else if (type == 'photo') {
            final Uint8List photoData = result['value'] as Uint8List;
            print('[Flutter Dashboard] Post-frame: Handling photo data: ${photoData.lengthInBytes} bytes');
            _handlePhotoResult(currentContext, photoData);
          } else if (type == 'cancel') {
            print('[Flutter Dashboard] Post-frame: Handling cancel.');
          } else {
            print('[Flutter Dashboard] Post-frame: Unknown camera result type: $type');
            if (mounted) _showErrorSnackbar('Received unknown result from camera.');
          }
        });
        break;
      default:
        print('[Flutter Dashboard] Unknown method call from native: ${call.method}');
    }
  }

  Future<void> _showNativeCamera() async {
    try {
      await _cameraService.showNativeCamera();
    } on PlatformException catch (e) {
      print('[Flutter Dashboard] Error showing native camera: ${e.message}');
      if (mounted) _showErrorSnackbar('Failed to open camera: ${e.message}');
    }
  }

  void _handleBarcodeResult(BuildContext safeContext, String barcode) {
    print('[Flutter Dashboard] Navigating to BarcodeResults');
    if (!mounted) return;
    Navigator.push(
      safeContext,
      MaterialPageRoute(builder: (context) => BarcodeResults(barcode: barcode)),
    );
  }

  /// Analysis runs in the background; a card in the meal shows progress and
  /// a banner says when it's ready to review.
  void _handlePhotoResult(BuildContext safeContext, Uint8List photoData) {
    if (!mounted) return;
    final date = Provider.of<DateProvider>(safeContext, listen: false).selectedDate;
    Provider.of<PhotoAnalysisService>(safeContext, listen: false)
        .start(photoData, meal: MealTime.suggested(), date: date);
  }

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

  void _showAddFoodMenu(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation1, animation2) => Container(),
      transitionBuilder: (context, animation1, animation2, child) {
        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(color: Colors.black.withOpacity(0.3)),
            ),
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation1,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(
                opacity: animation1,
                child: const AddFoodMenu(),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBody: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                Container(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  padding: EdgeInsets.only(top: topPadding),
                  child: const DateNavigatorBar(),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: const [
                        SizedBox(height: 8),
                        CalorieTracker(),
                        MealSection(),
                        SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: screenHeight * 0.04,
            left: screenWidth * 0.18,
            right: screenWidth * 0.18,
            child: _buildFloatingNavBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingNavBar(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14.0),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.0),
            color: Theme.of(context).brightness == Brightness.light
                ? Colors.grey.shade50.withOpacity(0.4)
                : Colors.black.withOpacity(0.4),
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
              _buildNavItem(
                context: context,
                icon: CupertinoIcons.add,
                label: 'Add',
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showAddFoodMenu(context);
                },
              ),
              _buildNavItem(
                context: context,
                icon: CupertinoIcons.camera,
                label: 'Scan',
                onTap: () {
                  HapticFeedback.lightImpact();
                  _showNativeCamera();
                },
              ),
              _buildNavItem(
                context: context,
                icon: CupertinoIcons.graph_circle,
                label: 'Progress',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => TrackingPagesScreen()),
                  );
                },
              ),
              _buildNavItem(
                context: context,
                icon: CupertinoIcons.person,
                label: 'Profile',
                onTap: () {
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    CupertinoPageRoute(builder: (context) => AccountDashboard()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFFFFC107), size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.black87
                      : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
