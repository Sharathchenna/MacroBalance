import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class FlutterCameraService {
  static final FlutterCameraService _instance =
      FlutterCameraService._internal();
  factory FlutterCameraService() => _instance;
  FlutterCameraService._internal();

  CameraController? _controller;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isStreamingImages = false;
  StreamController<CameraImage>? _imageStreamController;

  // Camera state
  FlashMode _currentFlashMode = FlashMode.off;
  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;

  // Stream management
  StreamSubscription<CameraImage>? _cameraImageSubscription;

  // Getters
  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  FlashMode get currentFlashMode => _currentFlashMode;
  double get currentZoomLevel => _currentZoomLevel;
  double get minZoomLevel => _minZoomLevel;
  double get maxZoomLevel => _maxZoomLevel;

  // Stream for barcode detection - improved management
  Stream<CameraImage>? get imageStream => _imageStreamController?.stream;

  Future<bool> checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      print('FlutterCameraService: Current camera permission status: $status');

      if (status.isGranted) {
        return true;
      } else if (status.isDenied || status.isRestricted) {
        print('FlutterCameraService: Requesting camera permission...');
        final result = await Permission.camera.request();
        print(
            'FlutterCameraService: Camera permission request result: $result');
        return result.isGranted;
      } else if (status.isPermanentlyDenied) {
        print(
            'FlutterCameraService: Camera permission permanently denied - testing direct access...');

        // Sometimes the permission status is stale, especially on iOS
        try {
          final cameras = await availableCameras();
          if (cameras.isNotEmpty) {
            print(
                'FlutterCameraService: Direct camera access successful despite status');
            return true;
          }
        } catch (e) {
          print('FlutterCameraService: Direct camera access failed: $e');
        }

        return false;
      }
      return false;
    } catch (e) {
      print('FlutterCameraService: Error checking camera permission: $e');
      return false;
    }
  }

  Future<void> initializeCamera() async {
    // Always dispose first to ensure clean state
    print('FlutterCameraService: Starting initialization...');
    await dispose();

    // Small delay to ensure complete cleanup
    await Future.delayed(const Duration(milliseconds: 100));

    print('FlutterCameraService: Previous state cleared, initializing...');

    // Check permissions with retry logic
    bool hasPermission = await checkCameraPermission();

    if (!hasPermission) {
      print('FlutterCameraService: Retrying permission check...');
      await Future.delayed(const Duration(milliseconds: 500));
      hasPermission = await checkCameraPermission();
    }

    // Last resort: try direct camera initialization
    if (!hasPermission) {
      print('FlutterCameraService: Attempting direct camera initialization...');
      try {
        _cameras = await availableCameras();
        if (_cameras != null && _cameras!.isNotEmpty) {
          print('FlutterCameraService: Direct access successful');
          hasPermission = true;
        }
      } catch (e) {
        print('FlutterCameraService: Direct initialization failed: $e');
        throw Exception(
            'Camera permission denied. Please restart the app after granting camera access in Settings.');
      }
    }

    if (!hasPermission) {
      throw Exception(
          'Camera permission denied. Please restart the app after granting camera access in Settings.');
    }

    try {
      // Get available cameras if not already retrieved
      _cameras ??= await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      // Use back camera (first camera is usually back camera)
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      print('FlutterCameraService: Using camera: ${backCamera.name}');

      // Initialize camera controller with optimized settings for barcode detection
      _controller = CameraController(
        backCamera,
        ResolutionPreset.high, // High resolution for better barcode detection
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();

      // Get zoom capabilities
      _minZoomLevel = await _controller!.getMinZoomLevel();
      _maxZoomLevel = await _controller!.getMaxZoomLevel();
      _currentZoomLevel = _minZoomLevel;

      // Set optimal focus mode for barcode detection
      try {
        await _controller!.setFocusMode(FocusMode.auto);
      } catch (e) {
        print('FlutterCameraService: Could not set focus mode: $e');
      }

      // Set optimal exposure mode
      try {
        await _controller!.setExposureMode(ExposureMode.auto);
      } catch (e) {
        print('FlutterCameraService: Could not set exposure mode: $e');
      }

      _isInitialized = true;
      print('FlutterCameraService: Initialized successfully');
    } catch (e) {
      print('FlutterCameraService: Error during initialization: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> startImageStream() async {
    if (!_isInitialized || _controller == null || _isStreamingImages) {
      print(
          'FlutterCameraService: Cannot start image stream - not ready or already streaming');
      return;
    }

    try {
      print('FlutterCameraService: Starting image stream...');

      // Close existing stream controller if any
      await _closeImageStreamController();

      // Create new stream controller
      _imageStreamController = StreamController<CameraImage>.broadcast();

      // Start the camera image stream
      await _controller!.startImageStream((CameraImage image) {
        // Only add to stream if controller exists and is not closed
        if (_imageStreamController != null &&
            !_imageStreamController!.isClosed) {
          try {
            _imageStreamController!.add(image);
          } catch (e) {
            print('FlutterCameraService: Error adding image to stream: $e');
          }
        }
      });

      _isStreamingImages = true;
      print('FlutterCameraService: Image stream started successfully');
    } catch (e) {
      print('FlutterCameraService: Error starting image stream: $e');
      _isStreamingImages = false;
      await _closeImageStreamController();
      rethrow;
    }
  }

  Future<void> stopImageStream() async {
    if (!_isStreamingImages || _controller == null) {
      return;
    }

    try {
      print('FlutterCameraService: Stopping image stream...');

      // Stop the camera image stream first
      await _controller!.stopImageStream();
      _isStreamingImages = false;

      // Close stream controller
      await _closeImageStreamController();

      print('FlutterCameraService: Image stream stopped successfully');
    } catch (e) {
      print('FlutterCameraService: Error stopping image stream: $e');
      _isStreamingImages = false;
    }
  }

  Future<void> _closeImageStreamController() async {
    try {
      if (_imageStreamController != null) {
        if (!_imageStreamController!.isClosed) {
          await _imageStreamController!.close();
        }
        _imageStreamController = null;
      }
    } catch (e) {
      print('FlutterCameraService: Error closing stream controller: $e');
    }
  }

  Future<void> setFlashMode(FlashMode mode) async {
    if (!_isInitialized || _controller == null) return;

    try {
      await _controller!.setFlashMode(mode);
      _currentFlashMode = mode;
      print('FlutterCameraService: Flash mode set to: $mode');
    } catch (e) {
      print('FlutterCameraService: Error setting flash mode: $e');
      rethrow;
    }
  }

  Future<void> toggleFlash() async {
    final newMode =
        _currentFlashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await setFlashMode(newMode);
  }

  Future<void> setZoomLevel(double zoom) async {
    if (!_isInitialized || _controller == null) return;

    try {
      final clampedZoom = zoom.clamp(_minZoomLevel, _maxZoomLevel);
      await _controller!.setZoomLevel(clampedZoom);
      _currentZoomLevel = clampedZoom;
      print('FlutterCameraService: Zoom level set to: $clampedZoom');
    } catch (e) {
      print('FlutterCameraService: Error setting zoom level: $e');
      rethrow;
    }
  }

  Future<Uint8List?> takePicture() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('Camera not initialized');
    }

    try {
      // Temporarily stop image stream for better photo quality
      final wasStreaming = _isStreamingImages;
      if (wasStreaming) {
        await stopImageStream();
        // Small delay to ensure stream is fully stopped
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final XFile imageFile = await _controller!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();

      print(
          'FlutterCameraService: Picture taken successfully: ${imageBytes.length} bytes');

      // Restart image stream if it was running
      if (wasStreaming) {
        await Future.delayed(const Duration(milliseconds: 100));
        await startImageStream();
      }

      return imageBytes;
    } catch (e) {
      print('FlutterCameraService: Error taking picture: $e');
      rethrow;
    }
  }

  /// Take picture and return the file path (useful for barcode detection)
  Future<String?> takePictureAsFile() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('Camera not initialized');
    }

    try {
      // Temporarily stop image stream for better photo quality
      final wasStreaming = _isStreamingImages;
      if (wasStreaming) {
        await stopImageStream();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      final XFile imageFile = await _controller!.takePicture();
      print(
          'FlutterCameraService: Picture taken and saved to: ${imageFile.path}');

      // Restart image stream if it was running
      if (wasStreaming) {
        await Future.delayed(const Duration(milliseconds: 100));
        await startImageStream();
      }

      return imageFile.path;
    } catch (e) {
      print('FlutterCameraService: Error taking picture as file: $e');
      rethrow;
    }
  }

  Future<void> pausePreview() async {
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        await stopImageStream(); // Stop streaming when paused
        await _controller!.pausePreview();
        print('FlutterCameraService: Preview paused');
      }
    } catch (e) {
      print('FlutterCameraService: Error pausing preview: $e');
    }
  }

  Future<void> resumePreview() async {
    try {
      if (_controller != null && _controller!.value.isInitialized) {
        await _controller!.resumePreview();
        print('FlutterCameraService: Preview resumed');
      }
    } catch (e) {
      print('FlutterCameraService: Error resuming preview: $e');
    }
  }

  Future<void> dispose() async {
    try {
      print('FlutterCameraService: Disposing...');

      // Stop image stream first
      await stopImageStream();

      // Dispose camera controller with additional safety
      if (_controller != null) {
        try {
          if (_controller!.value.isInitialized) {
            await _controller!.dispose();
          }
        } catch (e) {
          print('FlutterCameraService: Error disposing controller: $e');
        }
        _controller = null;
      }

      // Reset all state
      _isInitialized = false;
      _isStreamingImages = false;
      _cameras = null;
      _currentFlashMode = FlashMode.off;
      _currentZoomLevel = 1.0;
      _minZoomLevel = 1.0;
      _maxZoomLevel = 1.0;

      print('FlutterCameraService: Disposed successfully');
    } catch (e) {
      print('FlutterCameraService: Error during disposal: $e');
      // Force reset state even if disposal fails
      _controller = null;
      _isInitialized = false;
      _isStreamingImages = false;
      _cameras = null;
    }
  }

  // Focus at a specific point (for tap-to-focus)
  Future<void> setFocusPoint(Offset point) async {
    if (!_isInitialized || _controller == null) return;

    try {
      await _controller!.setFocusPoint(point);
      print('FlutterCameraService: Focus point set to: $point');
    } catch (e) {
      print('FlutterCameraService: Error setting focus point: $e');
    }
  }

  // Get current camera description
  CameraDescription? get currentCamera {
    if (_cameras == null || _cameras!.isEmpty) return null;
    return _cameras!.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras!.first,
    );
  }

  // Check if camera has flash
  bool get hasFlash {
    return currentCamera?.name.toLowerCase().contains('flash') ?? false;
  }

  // Get camera preview widget
  Widget? getCameraPreview() {
    if (!_isInitialized || _controller == null) return null;
    return CameraPreview(_controller!);
  }

  // Get image stream statistics for debugging
  Map<String, dynamic> getStreamStats() {
    return {
      'isInitialized': _isInitialized,
      'isStreaming': _isStreamingImages,
      'hasController': _controller != null,
      'controllerInitialized': _controller?.value.isInitialized ?? false,
      'streamControllerActive': _imageStreamController != null &&
          !(_imageStreamController?.isClosed ?? true),
    };
  }

  // Check if service is in a clean state for initialization
  bool isCleanState() {
    return !_isInitialized &&
        !_isStreamingImages &&
        _controller == null &&
        _imageStreamController == null;
  }
}
