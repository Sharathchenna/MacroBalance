import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/flutter_camera_service.dart';
import '../../services/barcode_detection_service.dart';

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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentMode = widget.initialMode;
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
      print('Flutter Camera Screen: Starting initialization...');

      // Initialize barcode service
      _barcodeService.initialize();
      print('Flutter Camera Screen: Barcode service initialized');

      // Initialize camera with better error handling
      await _cameraService.initializeCamera();
      print('Flutter Camera Screen: Camera service initialized');

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        print('Flutter Camera Screen: Set as initialized');

        // Start barcode detection if in barcode mode
        if (_currentMode == CameraMode.barcode) {
          _startBarcodeDetection();
        }
      }
    } catch (e) {
      print('Flutter Camera Screen: Error during initialization: $e');
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
        });
      }
    }
  }

  Future<void> _disposeServices() async {
    await _stopBarcodeDetection();
    await _cameraService.dispose();
    _barcodeService.dispose();
  }

  Future<void> _pauseCamera() async {
    await _stopBarcodeDetection();
    await _cameraService.pausePreview();
  }

  Future<void> _resumeCamera() async {
    await _cameraService.resumePreview();
    if (_currentMode == CameraMode.barcode) {
      _startBarcodeDetection();
    }
  }

  Future<void> _startBarcodeDetection() async {
    if (!_isInitialized || _hasDetectedBarcode) return;

    try {
      await _cameraService.startImageStream();

      // Set scan area for barcode detection
      final screenSize = MediaQuery.of(context).size;
      final guideWidth = screenSize.width * 0.7;
      final guideHeight = screenSize.height * 0.15;
      final scanArea = Rect.fromCenter(
        center: Offset(screenSize.width / 2, screenSize.height / 2),
        width: guideWidth,
        height: guideHeight,
      );

      _barcodeService.setScanArea(scanArea);
      _barcodeService.startDetection();

      // Listen to image stream
      if (_cameraService.imageStream != null) {
        _imageStreamSubscription = _cameraService.imageStream!.listen((image) {
          if (!_hasDetectedBarcode) {
            _barcodeService.detectBarcode(image);
          }
        });
      }

      // Listen to barcode detections
      if (_barcodeService.barcodeStream != null) {
        _barcodeSubscription =
            _barcodeService.barcodeStream!.listen(_handleBarcodeDetected);
      }
    } catch (e) {
      print('Error starting barcode detection: $e');
    }
  }

  Future<void> _stopBarcodeDetection() async {
    _barcodeService.stopDetection();
    await _cameraService.stopImageStream();
    await _barcodeSubscription?.cancel();
    await _imageStreamSubscription?.cancel();
    _barcodeSubscription = null;
    _imageStreamSubscription = null;
  }

  void _handleBarcodeDetected(String barcode) {
    if (_hasDetectedBarcode || _currentMode != CameraMode.barcode) return;

    _hasDetectedBarcode = true;
    HapticFeedback.heavyImpact();

    // Stop detection to prevent multiple detections
    _stopBarcodeDetection();

    // Return result
    Navigator.of(context).pop({
      'type': 'barcode',
      'value': barcode,
      'mode': _currentMode.name,
    });
  }

  Future<void> _handleModeChange(CameraMode newMode) async {
    if (newMode == _currentMode) return;

    HapticFeedback.mediumImpact();

    // Stop current mode activities
    if (_currentMode == CameraMode.barcode) {
      await _stopBarcodeDetection();
      _hasDetectedBarcode = false;
    }

    setState(() {
      _currentMode = newMode;
    });

    // Start new mode activities
    if (_currentMode == CameraMode.barcode) {
      _startBarcodeDetection();
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

  Future<void> _takePicture() async {
    setState(() => _isProcessingImage = true);

    try {
      final imageBytes = await _cameraService.takePicture();
      if (imageBytes != null && mounted) {
        Navigator.of(context).pop({
          'type': 'photo',
          'value': imageBytes,
          'mode': _currentMode.name,
        });
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
      final imageBytes = await _cameraService.takePicture();
      if (imageBytes != null && mounted) {
        // Show loading dialog
        _showLoadingDialog('Analyzing nutrition label...');

        try {
          // For now, we'll return the raw image bytes for label analysis
          // In the future, this could be integrated with a proper label analysis service

          // Dismiss loading dialog
          if (mounted) Navigator.of(context).pop();

          // Return result
          if (mounted) {
            Navigator.of(context).pop({
              'type': 'photo',
              'value': imageBytes,
              'mode': _currentMode.name,
            });
          }
        } catch (e) {
          // Dismiss loading dialog
          if (mounted) Navigator.of(context).pop();
          _showError('Failed to analyze label: $e');
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
    // Try to capture current frame for barcode detection
    try {
      final imageBytes = await _cameraService.takePicture();
      if (imageBytes != null) {
        // This could be enhanced to analyze the captured image for barcodes
        // For now, just provide manual entry option
        _showManualBarcodeEntry();
      }
    } catch (e) {
      _showManualBarcodeEntry();
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
              left: 20,
              right: 20,
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
