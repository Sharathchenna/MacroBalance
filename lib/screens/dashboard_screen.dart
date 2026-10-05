import 'dart:typed_data';

import 'package:macrotracker/widgets/app_bottom_bar.dart';
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
import 'dashboard/components/components.dart';
import '../widgets/home_tour.dart';

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

  @override
  Widget build(BuildContext context) {
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
                  child: TourTargets.mark(
                      context, TourTarget.dateBar, const DateNavigatorBar()),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        TourTargets.mark(
                            context, TourTarget.summary, const CalorieTracker()),
                        TourTargets.mark(context, TourTarget.meals, const MealSection()),
                        // Room to scroll past the bottom bar.
                        const SizedBox(height: AppBottomBar.scrollClearance),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
