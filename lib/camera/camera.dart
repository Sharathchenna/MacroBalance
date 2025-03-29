// ignore_for_file: library_private_types_in_public_api, avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'dart:io'; // For Platform check and File operations
import 'dart:typed_data'; // For Uint8List

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart'; // Import Lottie package
// Results pages are no longer navigated to from here
// import 'package:macrotracker/camera/barcode_results.dart';
// import 'package:macrotracker/camera/results_page.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:path_provider/path_provider.dart'; // For temp directory
import '../AI/gemini.dart'; // Keep Gemini processing

// Define the expected result structure
typedef CameraResult = Map<String, dynamic>;

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  // New Method Channel for the native view
  static const MethodChannel _nativeCameraViewChannel =
      MethodChannel('com.macrotracker/native_camera_view');

  bool _isLoading = true; // Show loading initially
  String? _error;

  @override
  void initState() {
    super.initState();
    _setupMethodChannelHandler();
    _showNativeCamera();
  }

  void _setupMethodChannelHandler() {
    _nativeCameraViewChannel.setMethodCallHandler((call) async {
      print('[Flutter Camera] Received method call: ${call.method}');
      switch (call.method) {
        case 'cameraResult':
          // Use addPostFrameCallback to ensure state is stable before popping
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              print(
                  '[Flutter Camera] Post-frame callback: Widget is unmounted. Ignoring result.');
              return;
            }

            final Map<dynamic, dynamic> result = call.arguments as Map;
            final String type = result['type'] as String;
            final currentContext = context; // Capture context safely

            if (type == 'barcode') {
              final String barcode = result['value'] as String;
              print('[Flutter Camera] Post-frame: Handling barcode: $barcode');
              _handleBarcodeResult(currentContext, barcode);
            } else if (type == 'photo') {
              final Uint8List photoData = result['value'] as Uint8List;
              print(
                  '[Flutter Camera] Post-frame: Handling photo data: ${photoData.lengthInBytes} bytes');
              // Don't await, let it pop when done
              _handlePhotoResult(currentContext, photoData);
            } else if (type == 'cancel') {
              print('[Flutter Camera] Post-frame: Handling cancel.');
              // Pop with null result to indicate cancellation
              Navigator.pop(currentContext, null);
            } else {
              print(
                  '[Flutter Camera] Post-frame: Unknown camera result type: $type');
              if (mounted) {
                setState(() => _error = 'Received unknown result from camera.');
                // Optionally pop with null on unknown error after showing message?
                // Future.delayed(Duration(seconds: 2), () {
                //   if (mounted) Navigator.pop(currentContext, null);
                // });
              }
            }
          });
          break;
        default:
          print(
              '[Flutter Camera] Unknown method call from native: ${call.method}');
      }
    });
  }

  Future<void> _showNativeCamera() async {
    if (!Platform.isIOS) {
      print('[Flutter Camera] Native camera view only supported on iOS.');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Camera feature is only available on iOS.';
        });
      }
      return;
    }

    try {
      print('[Flutter Camera] Invoking showNativeCamera...');
      // Re-enable native camera implementation
      await _nativeCameraViewChannel.invokeMethod('showNativeCamera');
      if (mounted) {
        // Keep loading true while native view is presented
      }
      print('[Flutter Camera] showNativeCamera invoked successfully.');
    } on PlatformException catch (e) {
      print('[Flutter Camera] Error showing native camera: ${e.message}');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'Failed to open camera: ${e.message}';
        });
        // Pop after showing error
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context, null);
        });
      }
    }
  }

  // --- Result Handling ---

  // Pops with barcode result
  void _handleBarcodeResult(BuildContext safeContext, String barcode) {
    print('[Flutter Camera] Popping CameraScreen with barcode result');
    if (!mounted) return;
    Navigator.pop(safeContext, {'type': 'barcode', 'value': barcode});
  }

  // Processes photo, then pops with photo result (list of foods)
  Future<void> _handlePhotoResult(
      BuildContext safeContext, Uint8List photoData) async {
    if (!mounted) return;

    _showLoadingDialog('Analyzing Image...'); // Show loading for Gemini

    CameraResult? popResult; // Variable to hold the result for popping

    try {
      // --- Gemini Processing ---
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath =
          '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(photoData);
      print('[Flutter Camera] Photo saved to temporary file: $tempPath');
      String jsonResponse = await processImageWithGemini(tempFile.path);
      print('[Flutter Camera] Gemini response received.');
      // try { await tempFile.delete(); } catch (e) { print('[Flutter Camera] Warn: Could not delete temp file: $e'); }
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

      // Check if Gemini identified any food
      if (foods.isEmpty) {
        print('[Flutter Camera] Gemini returned an empty food list.');
        if (mounted) {
          _showErrorSnackbar('Unable to identify food, try again');
        }
        popResult = null; // Treat empty result as an error case for popping
      } else {
        // Prepare result only if foods list is not empty
        popResult = {'type': 'photo', 'value': foods};
      }
    } catch (e) {
      print('[Flutter Camera] Error processing photo result: ${e.toString()}');
      if (mounted) {
        // Show generic error message for other exceptions
        _showErrorSnackbar('Something went wrong, try again');
      }
      // Prepare null result for error case
      popResult = null;
    } finally {
      // Ensure loading dialog is dismissed and screen is popped
      if (mounted) {
        // Dismiss loading dialog safely
        try {
          if (Navigator.of(safeContext, rootNavigator: true).canPop()) {
            Navigator.of(safeContext, rootNavigator: true)
                .pop(); // Dismiss dialog
          }
        } catch (e) {
          print(
              "[Flutter Camera] Error dismissing loading dialog in finally: $e");
        }

        // Pop CameraScreen with the result (or null on error)
        // Check mounted again right before popping
        if (mounted) {
          print(
              '[Flutter Camera] Popping CameraScreen with photo result: $popResult');
          Navigator.pop(safeContext, popResult);
        }
      }
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

  void _showLoadingDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.white,
      builder: (BuildContext dialogContext) {
        // Improved Loading Dialog Layout
        return Dialog(
          backgroundColor:
              Colors.white, // Changed from black.withOpacity(0.8) to white
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                vertical: 30, horizontal: 24), // More padding
            child: Column(
              // Use Column for vertical centering
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center, // Center vertically
              children: [
                // Replace CircularProgressIndicator with Lottie animation
                Lottie.asset(
                  'assets/animations/food_loading.json',
                  width: 200, // Adjust size as needed
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16), // Adjusted spacing
                Text(
                  message,
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 17), // Change text color to black
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
    // Shows Loading or Error states. The actual camera view is native.
    // This screen primarily handles errors during native camera launch
    // or acts as a placeholder. Loading during processing is handled by the dialog.
    Widget bodyContent;
    // if (_isLoading) { // REMOVED: No need for initial loading indicator here
    //    bodyContent = const CircularProgressIndicator(color: Colors.white);
    // } else
    if (_error != null) {
      // Show error if native camera failed to launch
      bodyContent = Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red[300], size: 50),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Colors.red[300], fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            // No back button needed, should pop automatically after error display or timeout
            // ElevatedButton.icon(
            //    icon: const Icon(Icons.arrow_back),
            //    label: const Text('Go Back'),
            //    onPressed: () => Navigator.pop(context, null), // Pop with null on manual back
            //    style: ElevatedButton.styleFrom(
            //      foregroundColor: Colors.black, backgroundColor: Colors.white,
            //    ),
            //  )
          ],
        ),
      );
    } else {
      // If not loading and no error, native view should be showing or transitioning.
      // Show loading as a fallback state.
      // If no error, show a simple container. The native view is expected
      // to be visible, or the loading dialog during processing.
      bodyContent =
          Container(); // Empty container, native view/dialog takes precedence
    }

    return Scaffold(
      // Keep background white for consistency during transitions
      backgroundColor: Colors.white,
      body: Center(child: bodyContent),
      // Prevent accidental back navigation while native view is potentially active
      // WillPopScope might be needed if native view presentation isn't fully modal
      // onWillPop: () async => !_isLoading, // Prevent back if loading/native view active
    );
  }
}
