import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert'; // Added for JSON parsing
import 'package:lottie/lottie.dart'; // Added for Lottie animations

import '../../services/flutter_camera_service.dart';
import '../../services/barcode_detection_service.dart';
import '../../AI/gemini.dart'; // Added for Gemini service
import '../../models/ai_food_item.dart'; // Added for AIFoodItem model
import '../../camera/ai_food_detail_page.dart'; // Corrected path for AIFoodDetailPage
import '../../utils/json_helper.dart'; // Added for JsonHelper

import 'camera_theme.dart';
import 'camera_controls.dart';
import 'camera_top_bar.dart';
import 'camera_mode_selector.dart';
import 'camera_guide_overlay.dart';
import 'manual_barcode_entry_dialog.dart';

class FlutterCameraScreen extends StatefulWidget {
  final CameraMode initialMode;

  const FlutterCameraScreen({
    super.key,
    this.initialMode = CameraMode.camera,
  });

  @override
  State<FlutterCameraScreen> createState() => _FlutterCameraScreenState();
}

class _FlutterCameraScreenState extends State<FlutterCameraScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // Services
  final FlutterCameraService _cameraService = FlutterCameraService();
  final BarcodeDetectionService _barcodeService = BarcodeDetectionService();
  final ImagePicker _imagePicker = ImagePicker();

  // State
  CameraMode _currentMode = CameraMode.camera;
  bool _isFlashOn = false;
  String? _error;
  bool _isInitialized = false;
  bool _isProcessingImage = false;
  bool _hasDetectedBarcode = false;

  // Animation controllers
  late AnimationController _guideAnimationController;
  late AnimationController _modeTransitionController;

  // Barcode detection
  StreamSubscription<String>? _barcodeSubscription;
  StreamSubscription<CameraImage>? _imageStreamSubscription;
  Timer? _detectionWatchdog;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentMode = widget.initialMode;

    // Reset all detection flags
    _hasDetectedBarcode = false;
    _isProcessingImage = false;

    _setupAnimations();
    _initializeServices();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeAnimations();
    _disposeServices();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isInitialized) return;

    switch (state) {
      case AppLifecycleState.paused:
        _pauseCamera();
        break;
      case AppLifecycleState.resumed:
        _resumeCamera();
        break;
      case AppLifecycleState.detached:
        _disposeServices();
        break;
      default:
        break;
    }
  }

  void _setupAnimations() {
    _guideAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _modeTransitionController = AnimationController(
      duration: CameraTheme.normalAnimation,
      vsync: this,
    );
  }

  void _disposeAnimations() {
    _guideAnimationController.dispose();
    _modeTransitionController.dispose();
  }

  Future<void> _initializeServices() async {
    try {
      print('Flutter Camera Screen: Starting full re-initialization...');

      // Reset all local screen state
      _hasDetectedBarcode = false;
      _isProcessingImage = false;
      _isInitialized =
          false; // Mark screen as not initialized during this process

      // 1. Stop any ongoing activities and clear subscriptions
      await _cleanupServices(); // Stops streams, detection, cancels subscriptions from screen's perspective
      print(
          'Flutter Camera Screen: Local cleanup (_cleanupServices) complete.');

      // 2. Explicitly dispose the singleton services to force a full reset of their internal states.
      //    This is critical for ensuring no lingering state when the camera screen is re-entered.
      print(
          'Flutter Camera Screen: Explicitly disposing singleton services for a full reset...');
      await _cameraService
          .dispose(); // Calls the main dispose method of FlutterCameraService
      _barcodeService
          .dispose(); // Calls the main dispose method of BarcodeDetectionService
      print('Flutter Camera Screen: Singleton services explicitly disposed.');

      // Brief delay to allow native resources to release if needed, especially after forced disposal.
      await Future.delayed(const Duration(milliseconds: 250));

      // 3. Re-initialize the services. Their internal initialize methods
      //    should also handle their own cleanup (as they currently do).
      print('Flutter Camera Screen: Re-initializing barcode service...');
      _barcodeService.initialize();
      print('Flutter Camera Screen: Barcode service re-initialized.');

      // Another small delay before camera init
      await Future.delayed(const Duration(milliseconds: 100));

      print('Flutter Camera Screen: Re-initializing camera service...');
      await _cameraService.initializeCamera();
      print('Flutter Camera Screen: Camera service re-initialized.');

      if (mounted) {
        setState(() {
          _isInitialized = true; // Screen is now initialized
        });
        print('Flutter Camera Screen: Screen marked as initialized.');

        if (_currentMode == CameraMode.barcode) {
          print(
              'Flutter Camera Screen: Current mode is barcode, starting detection...');
          await _startBarcodeDetection(); // This already resets _hasDetectedBarcode internally
        }
      }
    } catch (e) {
      print('Flutter Camera Screen: Error during full re-initialization: $e');
      if (mounted) {
        String errorMessage = e.toString();
        // Provide user-friendly error messages
        if (errorMessage.contains('Camera permission denied') ||
            errorMessage.contains('permission denied') ||
            errorMessage.contains('access denied')) {
          if (errorMessage.contains('restart the app')) {
            errorMessage =
                'Camera permission issue detected. Please restart the app to refresh permission status.';
          } else {
            errorMessage =
                'Camera permission denied. Please grant camera access in Settings and restart the app.';
          }
        } else if (errorMessage.contains('No cameras available')) {
          errorMessage = 'No cameras available on this device.';
        } else if (errorMessage.contains('initialize')) {
          errorMessage = 'Failed to initialize camera. Please try again.';
        } else {
          errorMessage = 'Camera error: $errorMessage';
        }
        setState(() {
          _error = errorMessage;
          _isInitialized = false; // Ensure it's false on error
        });
      }
    }
  }

  Future<void> _cleanupServices() async {
    try {
      print('Flutter Camera Screen: Cleaning up services...');

      // Stop detection watchdog
      _detectionWatchdog?.cancel();
      _detectionWatchdog = null;

      // Cancel existing subscriptions
      if (_barcodeSubscription != null) {
        await _barcodeSubscription!.cancel();
        _barcodeSubscription = null;
      }

      if (_imageStreamSubscription != null) {
        await _imageStreamSubscription!.cancel();
        _imageStreamSubscription = null;
      }

      // Stop any ongoing detection
      await _stopBarcodeDetection();

      print('Flutter Camera Screen: Services cleanup completed');
    } catch (e) {
      print('Flutter Camera Screen: Error during cleanup: $e');
    }
  }

  Future<void> _disposeServices() async {
    try {
      print('Flutter Camera Screen: Disposing services...');

      // Stop barcode detection first
      await _stopBarcodeDetection();

      // Wait for detection to fully stop
      await Future.delayed(const Duration(milliseconds: 100));

      // Dispose camera service
      await _cameraService.dispose();

      // Dispose barcode service
      _barcodeService.dispose();

      print('Flutter Camera Screen: Services disposed successfully');
    } catch (e) {
      print('Flutter Camera Screen: Error disposing services: $e');
    }
  }

  Future<void> _pauseCamera() async {
    await _stopBarcodeDetection();
    await _cameraService.pausePreview();
  }

  Future<void> _resumeCamera() async {
    await _cameraService.resumePreview();
    if (_currentMode == CameraMode.barcode) {
      // Reset detection flag when resuming
      _hasDetectedBarcode = false;
      await _startBarcodeDetection();
    }
  }

  Future<void> _startBarcodeDetection() async {
    if (!_isInitialized) {
      print(
          'FlutterCameraScreen: Cannot start barcode detection - not initialized');
      return;
    }

    try {
      print('FlutterCameraScreen: Starting barcode detection...');

      // CRITICAL RESET: Ensure detection flag is false before any new setup.
      // This addresses issues where the flag might not be reset correctly
      // when the screen is re-entered or detection is restarted.
      _hasDetectedBarcode = false;
      print(
          'FlutterCameraScreen: _hasDetectedBarcode explicitly reset to false in _startBarcodeDetection.');

      // Start camera image stream
      await _cameraService.startImageStream();

      // Set scan area for barcode detection matching the guide overlay
      final screenSize = MediaQuery.of(context).size;
      final guideWidth = screenSize.width * 0.7;
      final guideHeight = screenSize.height * 0.12;

      final scanArea = Rect.fromCenter(
        center: Offset(screenSize.width / 2, screenSize.height / 2),
        width: guideWidth,
        height: guideHeight,
      );

      print('FlutterCameraScreen: Scan area set to: $scanArea');
      _barcodeService.setScanArea(scanArea);
      _barcodeService.startDetection();

      // Listen to image stream with improved error handling
      if (_cameraService.imageStream != null) {
        _imageStreamSubscription = _cameraService.imageStream!.listen(
          (image) {
            // Only process if we haven't detected a barcode and we're in barcode mode
            if (!_hasDetectedBarcode &&
                _currentMode == CameraMode.barcode &&
                _barcodeService.isEnabled) {
              _barcodeService.detectBarcode(image);
            }
          },
          onError: (error) {
            print('FlutterCameraScreen: Error in image stream: $error');
          },
          onDone: () {
            print('FlutterCameraScreen: Image stream completed');
          },
        );
        print('FlutterCameraScreen: Image stream subscription active');
      } else {
        print('FlutterCameraScreen: Warning - image stream is null');
      }

      // Listen to barcode detections with improved error handling
      if (_barcodeService.barcodeStream != null) {
        _barcodeSubscription = _barcodeService.barcodeStream!.listen(
          _handleBarcodeDetected,
          onError: (error) {
            print('FlutterCameraScreen: Error in barcode stream: $error');
          },
          onDone: () {
            print('FlutterCameraScreen: Barcode stream completed');
          },
        );
        print('FlutterCameraScreen: Barcode stream subscription active');
      } else {
        print('FlutterCameraScreen: Warning - barcode stream is null');
      }

      // Debug stream status
      final streamStats = _cameraService.getStreamStats();
      print('FlutterCameraScreen: Stream stats: $streamStats');

      // Debug barcode service state
      _debugBarcodeServiceState();

      // Start detection watchdog to ensure detection stays active
      _startDetectionWatchdog();
    } catch (e) {
      print('FlutterCameraScreen: Error starting barcode detection: $e');
      _showError('Failed to start barcode detection: $e');
    }
  }

  void _startDetectionWatchdog() {
    // Cancel existing watchdog
    _detectionWatchdog?.cancel();

    // Start a periodic check to ensure detection stays active
    _detectionWatchdog = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentMode == CameraMode.barcode &&
          _isInitialized &&
          !_hasDetectedBarcode) {
        // Check if detection is still active
        if (!_barcodeService.isEnabled ||
            _barcodeService.barcodeStream == null ||
            _barcodeSubscription == null ||
            _imageStreamSubscription == null) {
          print(
              'FlutterCameraScreen: Detection watchdog detected inactive detection, restarting...');
          _restartBarcodeDetection();
        }
      } else {
        // Stop watchdog if not in barcode mode or already detected
        timer.cancel();
      }
    });
  }

  Future<void> _stopBarcodeDetection() async {
    try {
      print('FlutterCameraScreen: Stopping barcode detection...');

      // Stop detection watchdog
      _detectionWatchdog?.cancel();
      _detectionWatchdog = null;

      // Stop barcode service detection
      _barcodeService.stopDetection();

      // Cancel subscriptions first
      if (_barcodeSubscription != null) {
        await _barcodeSubscription!.cancel();
        _barcodeSubscription = null;
        print('FlutterCameraScreen: Barcode subscription cancelled');
      }

      if (_imageStreamSubscription != null) {
        await _imageStreamSubscription!.cancel();
        _imageStreamSubscription = null;
        print('FlutterCameraScreen: Image subscription cancelled');
      }

      // Stop camera image stream
      await _cameraService.stopImageStream();

      print('FlutterCameraScreen: Barcode detection stopped successfully');
    } catch (e) {
      print('FlutterCameraScreen: Error stopping barcode detection: $e');
    }
  }

  Future<void> _restartBarcodeDetection() async {
    if (_currentMode != CameraMode.barcode) return;

    try {
      print('FlutterCameraScreen: Restarting barcode detection...');
      await _stopBarcodeDetection();

      // Reset the barcode service state
      _barcodeService.resetDetection();

      // Reset our local state
      _hasDetectedBarcode = false;

      await Future.delayed(const Duration(milliseconds: 200)); // Brief pause
      await _startBarcodeDetection();
      print('FlutterCameraScreen: Barcode detection restarted successfully');
    } catch (e) {
      print('FlutterCameraScreen: Error restarting barcode detection: $e');
    }
  }

  void _debugBarcodeServiceState() {
    print('FlutterCameraScreen: === DEBUG BARCODE SERVICE STATE ===');
    print('FlutterCameraScreen: Service enabled: ${_barcodeService.isEnabled}');
    print(
        'FlutterCameraScreen: Stream available: ${_barcodeService.barcodeStream != null}');
    print('FlutterCameraScreen: Has detected flag: $_hasDetectedBarcode');
    print('FlutterCameraScreen: Current mode: $_currentMode');
    print('FlutterCameraScreen: Is initialized: $_isInitialized');
    print(
        'FlutterCameraScreen: Barcode subscription active: ${_barcodeSubscription != null}');
    print(
        'FlutterCameraScreen: Image subscription active: ${_imageStreamSubscription != null}');
    print('FlutterCameraScreen: ===============================');
  }

  void _handleBarcodeDetected(String barcode) {
    print('FlutterCameraScreen: Barcode detected: $barcode');
    print('FlutterCameraScreen: Has already detected: $_hasDetectedBarcode');
    print('FlutterCameraScreen: Current mode: $_currentMode');

    if (_hasDetectedBarcode || _currentMode != CameraMode.barcode) {
      print(
          'FlutterCameraScreen: Ignoring barcode - already detected or wrong mode');
      return;
    }

    print('FlutterCameraScreen: Processing valid barcode detection');
    _hasDetectedBarcode = true;
    HapticFeedback.heavyImpact();

    // Stop detection to prevent multiple detections
    _stopBarcodeDetection();

    // Return result
    if (mounted) {
      print('FlutterCameraScreen: Returning barcode result to caller');
      Navigator.of(context).pop({
        'type': 'barcode',
        'value': barcode,
        'mode': _currentMode.name,
      });
      print('FlutterCameraScreen: Navigation pop completed');
    } else {
      print('FlutterCameraScreen: Widget not mounted, cannot return result');
    }
  }

  Future<void> _handleModeChange(CameraMode newMode) async {
    if (newMode == _currentMode) return;

    HapticFeedback.mediumImpact();
    print(
        'FlutterCameraScreen: Changing mode from ${_currentMode.name} to ${newMode.name}');

    // Stop current mode activities
    if (_currentMode == CameraMode.barcode) {
      await _stopBarcodeDetection();
    }

    // Always reset the detection flag when changing modes
    _hasDetectedBarcode = false;

    setState(() {
      _currentMode = newMode;
    });

    // Start new mode activities
    if (_currentMode == CameraMode.barcode) {
      print('FlutterCameraScreen: Starting barcode detection for new mode');
      // Reset barcode service before starting fresh
      _barcodeService.resetDetection();
      await _startBarcodeDetection();
    }
  }

  Future<void> _handleShutterTap() async {
    if (!_isInitialized || _isProcessingImage) return;

    HapticFeedback.heavyImpact();

    switch (_currentMode) {
      case CameraMode.camera:
        await _takePicture();
        break;
      case CameraMode.label:
        await _captureAndAnalyzeLabel();
        break;
      case CameraMode.barcode:
        // Manual barcode capture if continuous detection hasn't worked
        await _manualBarcodeCapture();
        break;
    }
  }

  /// Helper function to extract JSON from Gemini response using JsonHelper
  String _extractJSONFromResponse(String geminiResponse, String mode) {
    print('[FlutterCameraScreen] === EXTRACTING JSON ($mode) ===');
    print('[FlutterCameraScreen] Response length: ${geminiResponse.length}');

    String cleaned = geminiResponse.trim();

    // Remove common markdown patterns
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    } else if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    // Find JSON boundaries
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');

    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      final jsonCandidate = cleaned.substring(firstBrace, lastBrace + 1);
      print(
          '[FlutterCameraScreen] Found JSON candidate: ${jsonCandidate.length} chars');

      // Try to parse using JsonHelper
      try {
        final parsed = JsonHelper.safelyParseJson(jsonCandidate);
        if (parsed.isNotEmpty) {
          print('[FlutterCameraScreen] Successfully parsed JSON!');
          return jsonCandidate;
        }
      } catch (e) {
        print('[FlutterCameraScreen] JsonHelper parsing failed: $e');
      }

      // Fallback to standard JSON decode
      try {
        jsonDecode(jsonCandidate);
        print('[FlutterCameraScreen] Standard JSON parsing succeeded!');
        return jsonCandidate;
      } catch (e) {
        print('[FlutterCameraScreen] Standard JSON parsing failed: $e');
      }
    }

    print('[FlutterCameraScreen] All parsing strategies failed');
    print('[FlutterCameraScreen] Original response: $geminiResponse');

    throw FormatException(
        'Unable to extract valid JSON from AI response: $geminiResponse');
  }

  Future<void> _takePicture() async {
    setState(() => _isProcessingImage = true);

    try {
      final imagePath = await _cameraService.takePictureAsFile();
      if (imagePath != null && mounted) {
        _showLoadingDialogWithAnimation('Analyzing your food...');

        try {
          final String geminiResponse = await processImageWithGemini(imagePath);
          print(
              '[FlutterCameraScreen] Raw Gemini Response (Photo): $geminiResponse'); // Log raw response
          if (mounted) Navigator.of(context).pop(); // Dismiss loading dialog

          if (geminiResponse.startsWith('Error')) {
            _showError(geminiResponse);
            return;
          }

          // Extract and parse JSON from the response
          final jsonStringToParse =
              _extractJSONFromResponse(geminiResponse, 'Photo');

          print(
              '[FlutterCameraScreen] About to parse JSON (Photo). Length: ${jsonStringToParse.length}');

          final decodedResponse = JsonHelper.safelyParseJson(jsonStringToParse);
          if (decodedResponse['meal'] != null &&
              (decodedResponse['meal'] as List).isNotEmpty) {
            final foodData = (decodedResponse['meal'] as List).first;
            final aiFoodItem = AIFoodItem.fromJson(foodData);

            if (mounted) {
              // Pop with the AI processed food item
              Navigator.of(context).pop({
                'type': 'ai_processed_photo',
                'value': [
                  aiFoodItem
                ], // Ensure it's a list as expected by caller
                'mode': _currentMode.name,
              });
            }
          } else {
            _showError('Could not parse food data from AI response.');
          }
        } catch (e) {
          if (mounted)
            Navigator.of(context).pop(); // Dismiss loading dialog on error
          _showError('Failed to process image with AI: $e');
        }
      }
    } catch (e) {
      _showError('Failed to take picture: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingImage = false);
      }
    }
  }

  Future<void> _captureAndAnalyzeLabel() async {
    setState(() => _isProcessingImage = true);

    try {
      final imagePath = await _cameraService.takePictureAsFile();
      if (imagePath != null && mounted) {
        _showLoadingDialogWithAnimation('Analyzing nutrition label...');

        try {
          final String geminiResponse = await processImageWithGemini(imagePath);
          print(
              '[FlutterCameraScreen] Raw Gemini Response (Label): $geminiResponse'); // Log raw response
          if (mounted) Navigator.of(context).pop(); // Dismiss loading dialog

          if (geminiResponse.startsWith('Error')) {
            _showError(geminiResponse);
            return;
          }

          // Extract and parse JSON from the response
          final jsonStringToParse =
              _extractJSONFromResponse(geminiResponse, 'Label');

          print(
              '[FlutterCameraScreen] About to parse JSON (Label). Length: ${jsonStringToParse.length}');

          final decodedResponse = JsonHelper.safelyParseJson(jsonStringToParse);
          if (decodedResponse['meal'] != null &&
              (decodedResponse['meal'] as List).isNotEmpty) {
            final foodData = (decodedResponse['meal'] as List).first;
            final aiFoodItem = AIFoodItem.fromJson(foodData);

            if (mounted) {
              // Pop with the AI processed food item from label
              Navigator.of(context).pop({
                'type': 'ai_processed_label',
                'value': [
                  aiFoodItem
                ], // Ensure it's a list as expected by caller
                'mode': _currentMode.name,
              });
            }
          } else {
            _showError('Could not parse label data from AI response.');
          }
        } catch (e) {
          if (mounted)
            Navigator.of(context).pop(); // Dismiss loading dialog on error
          _showError('Failed to process label with AI: $e');
        }
      }
    } catch (e) {
      _showError('Failed to capture image: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingImage = false);
      }
    }
  }

  Future<void> _manualBarcodeCapture() async {
    setState(() => _isProcessingImage = true);

    try {
      print('FlutterCameraScreen: Manual barcode capture initiated...');

      // Reset the detection flag to allow new detections
      _hasDetectedBarcode = false;

      // Try to capture and analyze the current frame using file path
      final String? imagePath = await _cameraService.takePictureAsFile();
      if (imagePath != null) {
        print(
            'FlutterCameraScreen: Image captured for barcode analysis: $imagePath');

        // Show loading dialog
        _showLoadingDialog('Scanning for barcode...');

        try {
          // Process the captured image file directly for barcodes
          final String? detectedBarcode =
              await _barcodeService.detectBarcodeFromFile(imagePath);

          // Dismiss loading dialog
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }

          if (detectedBarcode != null &&
              detectedBarcode.isNotEmpty &&
              mounted) {
            // Barcode found in captured image - return result immediately
            print(
                'FlutterCameraScreen: Barcode detected from captured image: $detectedBarcode');
            _hasDetectedBarcode = true;
            HapticFeedback.heavyImpact();

            Navigator.of(context).pop({
              'type': 'barcode',
              'value': detectedBarcode,
              'mode': _currentMode.name,
            });
            return;
          }

          // If no barcode detected from image, restart continuous detection
          print(
              'FlutterCameraScreen: No barcode in captured image, restarting continuous detection');
          _hasDetectedBarcode = false;
          // Restart barcode detection to ensure it's running
          await _restartBarcodeDetection();
        } catch (e) {
          print(
              'FlutterCameraScreen: Error processing captured image for barcodes: $e');
          // Dismiss loading dialog
          if (mounted && Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
          // Restart detection on error
          _hasDetectedBarcode = false;
          await _restartBarcodeDetection();
        }
      } else {
        print('FlutterCameraScreen: Failed to capture image');
        if (mounted) {
          _showError('Failed to capture image. Please try again.');
        }
      }
    } catch (e) {
      print('FlutterCameraScreen: Error in manual barcode capture: $e');
      // Dismiss loading dialog if showing
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      _showManualBarcodeEntry();
    } finally {
      if (mounted) {
        setState(() => _isProcessingImage = false);
      }
    }
  }

  Future<void> _toggleFlash() async {
    try {
      await _cameraService.toggleFlash();
      setState(() {
        _isFlashOn = _cameraService.currentFlashMode != FlashMode.off;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      _showError('Failed to toggle flash: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null && mounted) {
        final imageBytes = await image.readAsBytes();
        Navigator.of(context).pop({
          'type': 'photo',
          'value': imageBytes,
          'mode': _currentMode.name,
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _showManualBarcodeEntry() async {
    final String? barcode = await showManualBarcodeEntryDialog(context);
    if (barcode != null && mounted) {
      Navigator.of(context).pop({
        'type': 'barcode',
        'value': barcode,
        'mode': CameraMode.barcode.name,
      });
    }
  }

  void _showInfo() {
    String title, message, disclaimer;

    switch (_currentMode) {
      case CameraMode.barcode:
        title = 'Barcode Scanner';
        message =
            'Position the barcode within the highlighted area. Hold the device steady, and the scanner will automatically detect and process valid barcodes.';
        disclaimer =
            'Note: Some barcodes may not be recognized. You can use manual entry if scanning fails.';
        break;
      case CameraMode.camera:
        title = 'Photo Mode';
        message =
            'Take a clear photo of your food or product. Make sure there\'s good lighting for best results.';
        disclaimer =
            'AI results are estimates and should be verified for accuracy.';
        break;
      case CameraMode.label:
        title = 'Nutrition Label Scanner';
        message =
            'Position the entire nutrition label within the highlighted area. Try to capture the full label with good lighting for best results.';
        disclaimer =
            'AI results are estimates and should be verified for accuracy.';
        break;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: 16),
            Text(
              disclaimer,
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  void _showLoadingDialogWithAnimation(String message) {
    // Add premium haptic feedback
    HapticFeedback.selectionClick();

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 600),
        tween: Tween(begin: 0.0, end: 1.0),
        curve: Curves.elasticOut,
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              elevation: 0,
              content: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.95),
                      Colors.grey.shade900.withValues(alpha: 0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: CameraTheme.premiumGold.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: CameraTheme.premiumGold.withValues(alpha: 0.2),
                      blurRadius: 25,
                      spreadRadius: 5,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.8),
                      blurRadius: 40,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Premium animation stack with multiple layers
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Background glow effect
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 2000),
                            tween: Tween(begin: 0.0, end: 1.0),
                            curve: Curves.easeInOut,
                            builder: (context, glow, _) {
                              return AnimatedBuilder(
                                animation: _modeTransitionController,
                                builder: (context, _) {
                                  return Container(
                                    width: 160 + (glow * 20),
                                    height: 160 + (glow * 20),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          CameraTheme.premiumGold
                                              .withValues(alpha: 0.1 * glow),
                                          CameraTheme.premiumGold
                                              .withValues(alpha: 0.05 * glow),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),

                          // Rotating ring animation
                          TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 3000),
                            tween: Tween(
                                begin: 0.0, end: 6.28), // 2π for full rotation
                            builder: (context, rotation, _) {
                              return Transform.rotate(
                                angle: rotation,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: CameraTheme.premiumGold
                                          .withValues(alpha: 0.4),
                                      width: 2,
                                    ),
                                    gradient: SweepGradient(
                                      colors: [
                                        Colors.transparent,
                                        CameraTheme.premiumGold
                                            .withValues(alpha: 0.7),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.0, 0.3, 1.0],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          // Main nutrition animation - enhanced
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: CameraTheme.premiumGold
                                      .withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Lottie.asset(
                              'assets/animations/nutrition.json',
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                              repeat: true,
                              animate: true,
                            ),
                          ),

                          // Pulsing overlay dots
                          ...List.generate(8, (index) {
                            final angle =
                                (index * 0.785398); // π/4 radians = 45 degrees
                            return TweenAnimationBuilder<double>(
                              duration:
                                  Duration(milliseconds: 1500 + (index * 200)),
                              tween: Tween(begin: 0.0, end: 1.0),
                              builder: (context, pulse, _) {
                                return Transform.translate(
                                  offset: Offset(
                                    60 *
                                        (1 + pulse * 0.2) *
                                        (index.isEven ? 1 : -1) *
                                        (index.isOdd ? 0.7 : 1.0),
                                    60 *
                                        (1 + pulse * 0.2) *
                                        (index > 3 ? -1 : 1) *
                                        (index.isEven ? 0.7 : 1.0),
                                  ),
                                  child: AnimatedOpacity(
                                    duration: Duration(
                                        milliseconds: 800 + (index * 100)),
                                    opacity: 0.3 + (pulse * 0.4),
                                    child: Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: CameraTheme.premiumGold,
                                        boxShadow: [
                                          BoxShadow(
                                            color: CameraTheme.premiumGold
                                                .withValues(alpha: 0.5),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Enhanced text with animation
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 800),
                      tween: Tween(begin: 0.0, end: 1.0),
                      curve: Curves.easeOut,
                      builder: (context, textOpacity, _) {
                        return AnimatedOpacity(
                          duration: const Duration(milliseconds: 300),
                          opacity: textOpacity,
                          child: Column(
                            children: [
                              Text(
                                message,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      color: CameraTheme.premiumGold
                                          .withValues(alpha: 0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Animated progress dots
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (index) {
                                  return TweenAnimationBuilder<double>(
                                    duration: Duration(
                                        milliseconds: 600 + (index * 200)),
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    builder: (context, dotScale, _) {
                                      return AnimatedContainer(
                                        duration: Duration(
                                            milliseconds: 400 + (index * 100)),
                                        margin: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        width: 8 * dotScale,
                                        height: 8 * dotScale,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: CameraTheme.premiumGold
                                              .withValues(
                                            alpha: 0.4 + (dotScale * 0.6),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: CameraTheme.premiumGold
                                                  .withValues(alpha: 0.3),
                                              blurRadius: 4,
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                }),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getInstructionText() {
    switch (_currentMode) {
      case CameraMode.barcode:
        return 'Scan a barcode';
      case CameraMode.camera:
        return 'Take a photo';
      case CameraMode.label:
        return 'Scan a nutrition label';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview - fullscreen
          _buildCameraPreview(),

          // Error overlay
          if (_error != null) _buildErrorOverlay(),

          // Camera guide overlay - positioned in center with better spacing
          if (_isInitialized)
            Positioned(
              top: screenHeight * 0.3, // Moved down to avoid top bar
              left: 24,
              right: 24,
              bottom: screenHeight * 0.38, // Adjusted for better spacing
              child: CameraGuideOverlay(
                currentMode: _currentMode,
                isAnimating: _isProcessingImage,
              ),
            ),

          // Top bar - safe area aware
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CameraTopBar(
              onClose: () => Navigator.of(context).pop(),
              onFlash: _toggleFlash,
              onInfo: _showInfo,
              isFlashOn: _isFlashOn,
              instructionText: _getInstructionText(),
            ),
          ),

          // Mode selector - positioned above controls
          if (_isInitialized)
            Positioned(
              bottom: safeAreaBottom + 120,
              left: 20,
              right: 20,
              child: SizedBox(
                height: 60,
                child: CameraModeSelector(
                  currentMode: _currentMode,
                  onModeChanged: _handleModeChange,
                ),
              ),
            ),

          // Camera controls - bottom safe area
          if (_isInitialized)
            Positioned(
              bottom: safeAreaBottom + 20,
              left: 0,
              right: 0,
              child: SizedBox(
                height: 80,
                child: CameraControls(
                  onShutter: _handleShutterTap,
                  onGallery: _pickFromGallery,
                  onManualEntry: _showManualBarcodeEntry,
                  currentMode: _currentMode,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(
          color: CameraTheme.premiumGold,
        ),
      );
    }

    final cameraPreview = _cameraService.getCameraPreview();
    if (cameraPreview == null) {
      return const Center(
        child: Text(
          'Camera not available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraService.controller!.value.previewSize!.height,
          height: _cameraService.controller!.value.previewSize!.width,
          child: cameraPreview,
        ),
      ),
    );
  }

  Widget _buildErrorOverlay() {
    final isPermissionError = _error!.contains('permission denied') ||
        _error!.contains('access denied') ||
        _error!.contains('Camera permission');

    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isPermissionError
                    ? Icons.camera_alt_outlined
                    : Icons.error_outline,
                color: isPermissionError ? CameraTheme.premiumGold : Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (isPermissionError) ...[
                if (_error!.contains('restart the app')) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Try to reinitialize first
                      setState(() {
                        _error = null;
                        _isInitialized = false;
                      });
                      _initializeServices();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CameraTheme.premiumGold,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'If the issue persists, please restart the app to refresh camera permissions.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      final status = await Permission.camera.status;

                      if (status.isPermanentlyDenied) {
                        // Open app settings if permanently denied
                        await openAppSettings();
                      } else {
                        // Request permission again
                        final result = await Permission.camera.request();
                        // Try to reinitialize after permission request
                        if (result.isGranted) {
                          setState(() {
                            _error = null;
                            _isInitialized = false;
                          });
                          _initializeServices();
                        }
                      }
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('Grant Permission'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CameraTheme.premiumGold,
                      foregroundColor: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () async {
                      // Try to reinitialize without requesting permission again
                      setState(() {
                        _error = null;
                        _isInitialized = false;
                      });
                      _initializeServices();
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade700,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade700,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
