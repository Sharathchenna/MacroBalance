// ignore_for_file: library_private_types_in_public_api, avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'dart:io'; // For Platform check and File operations
import 'dart:typed_data'; // For Uint8List

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
              print('[Flutter Camera] Post-frame callback: Widget is unmounted. Ignoring result.');
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
              print('[Flutter Camera] Post-frame: Handling photo data: ${photoData.lengthInBytes} bytes');
              // Don't await, let it pop when done
              _handlePhotoResult(currentContext, photoData);
            } else if (type == 'cancel') {
               print('[Flutter Camera] Post-frame: Handling cancel.');
               // Pop with null result to indicate cancellation
               Navigator.pop(currentContext, null);
            } else {
               print('[Flutter Camera] Post-frame: Unknown camera result type: $type');
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
           print('[Flutter Camera] Unknown method call from native: ${call.method}');
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
        // Pop immediately if not iOS? Or let error screen show?
        // Consider popping after a delay:
        // Future.delayed(Duration(seconds: 2), () {
        //   if (mounted) Navigator.pop(context, null);
        // });
      }
      return;
    }

    try {
      print('[Flutter Camera] Invoking showNativeCamera...');
      // This method now just presents the native view.
      // The result comes back via the method channel handler.
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
         // Pop after showing error?
        // Future.delayed(Duration(seconds: 2), () {
        //   if (mounted) Navigator.pop(context, null);
        // });
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
   Future<void> _handlePhotoResult(BuildContext safeContext, Uint8List photoData) async {
     if (!mounted) return;

     _showLoadingDialog('Analyzing Image...'); // Show loading for Gemini

    CameraResult? popResult; // Variable to hold the result for popping

    try {
      // --- Gemini Processing ---
      final Directory tempDir = await getTemporaryDirectory();
      final String tempPath = '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final File tempFile = File(tempPath);
      await tempFile.writeAsBytes(photoData);
      print('[Flutter Camera] Photo saved to temporary file: $tempPath');
      String jsonResponse = await processImageWithGemini(tempFile.path);
      print('[Flutter Camera] Gemini response received.');
      // try { await tempFile.delete(); } catch (e) { print('[Flutter Camera] Warn: Could not delete temp file: $e'); }
      jsonResponse = jsonResponse.trim().replaceAll('```json', '').replaceAll('```', '');
      dynamic decodedJson = json.decode(jsonResponse);
      List<dynamic> mealData;
       if (decodedJson is Map<String, dynamic> && decodedJson.containsKey('meal') && decodedJson['meal'] is List) {
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

      // Prepare result (even if foods list is empty)
      popResult = {'type': 'photo', 'value': foods};

    } catch (e) {
      print('[Flutter Camera] Error processing photo result: ${e.toString()}');
      if (mounted) {
          _showErrorSnackbar('Error processing image: ${e.toString()}');
      }
      // Prepare null result for error case
      popResult = null;
    } finally {
       // Ensure loading dialog is dismissed and screen is popped
       if (mounted) {
         // Dismiss loading dialog safely
         try {
           if (Navigator.of(safeContext, rootNavigator: true).canPop()) {
              Navigator.of(safeContext, rootNavigator: true).pop(); // Dismiss dialog
           }
         } catch (e) { print("[Flutter Camera] Error dismissing loading dialog in finally: $e"); }

         // Pop CameraScreen with the result (or null on error)
         // Check mounted again right before popping
         if (mounted) {
            print('[Flutter Camera] Popping CameraScreen with photo result: $popResult');
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
       builder: (BuildContext dialogContext) {
         return Dialog(
           backgroundColor: Colors.black.withOpacity(0.7),
           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
           child: Padding(
             padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
             child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 const CircularProgressIndicator(
                   valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                   strokeWidth: 3,
                 ),
                 const SizedBox(width: 24),
                 Text(message, style: const TextStyle(color: Colors.white, fontSize: 16)),
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
    // This screen will be popped automatically when a result/cancel/error occurs.
    Widget bodyContent;
    if (_isLoading) {
       bodyContent = const CircularProgressIndicator(color: Colors.white);
    } else if (_error != null) {
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
       bodyContent = const CircularProgressIndicator(color: Colors.white);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(child: bodyContent),
      // Prevent accidental back navigation while native view is potentially active
      // WillPopScope might be needed if native view presentation isn't fully modal
      // onWillPop: () async => !_isLoading, // Prevent back if loading/native view active
    );
  }
}
