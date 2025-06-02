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

  // Getters
  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  FlashMode get currentFlashMode => _currentFlashMode;
  double get currentZoomLevel => _currentZoomLevel;
  double get minZoomLevel => _minZoomLevel;
  double get maxZoomLevel => _maxZoomLevel;

  // Stream for barcode detection
  Stream<CameraImage>? get imageStream => _imageStreamController?.stream;

  Future<bool> checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      print('Current camera permission status: $status');

      if (status.isGranted) {
        return true;
      } else if (status.isDenied || status.isRestricted) {
        print('Requesting camera permission...');
        final result = await Permission.camera.request();
        print('Camera permission request result: $result');
        return result.isGranted;
      } else if (status.isPermanentlyDenied) {
        print(
            'Camera permission permanently denied - but attempting direct camera access to verify...');

        // Sometimes the permission status is stale, especially on iOS
        // Try to access the camera directly to see if it actually works
        try {
          final cameras = await availableCameras();
          if (cameras.isNotEmpty) {
            print(
                'Camera access successful despite permanentlyDenied status - permission likely granted');
            return true;
          }
        } catch (e) {
          print('Direct camera access failed: $e');
        }

        return false;
      }
      return false;
    } catch (e) {
      print('Error checking camera permission: $e');
      return false;
    }
  }

  Future<void> initializeCamera() async {
    if (_isInitialized) return;

    print('Initializing camera...');

    // Check permissions first with retry logic
    bool hasPermission = await checkCameraPermission();

    // If permission denied, try once more after a short delay
    if (!hasPermission) {
      print('First permission check failed, retrying...');
      await Future.delayed(const Duration(milliseconds: 500));
      hasPermission = await checkCameraPermission();
    }

    // If still no permission, try direct camera initialization as a last resort
    if (!hasPermission) {
      print(
          'Permission checks failed, attempting direct camera initialization...');
      try {
        // Try to initialize camera directly - sometimes permission status is stale
        _cameras = await availableCameras();
        if (_cameras != null && _cameras!.isNotEmpty) {
          print(
              'Direct camera access successful - proceeding with initialization');
          hasPermission = true;
        }
      } catch (e) {
        print('Direct camera initialization failed: $e');
        throw Exception(
            'Camera permission denied. Please restart the app after granting camera access in Settings.');
      }
    }

    if (!hasPermission) {
      throw Exception(
          'Camera permission denied. Please restart the app after granting camera access in Settings.');
    }

    try {
      // Get available cameras (if not already retrieved during permission check)
      if (_cameras == null) {
        _cameras = await availableCameras();
      }
      if (_cameras == null || _cameras!.isEmpty) {
        throw Exception('No cameras available');
      }

      // Use back camera (first camera is usually back camera)
      final backCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras!.first,
      );

      // Initialize camera controller
      _controller = CameraController(
        backCamera,
        ResolutionPreset.high,
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

      _isInitialized = true;
      print('Flutter Camera Service initialized successfully');
    } catch (e) {
      print('Error initializing camera: $e');
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> startImageStream() async {
    if (!_isInitialized || _controller == null || _isStreamingImages) return;

    try {
      _imageStreamController = StreamController<CameraImage>.broadcast();

      await _controller!.startImageStream((CameraImage image) {
        if (_imageStreamController != null &&
            !_imageStreamController!.isClosed) {
          _imageStreamController!.add(image);
        }
      });

      _isStreamingImages = true;
      print('Image stream started');
    } catch (e) {
      print('Error starting image stream: $e');
      rethrow;
    }
  }

  Future<void> stopImageStream() async {
    if (!_isStreamingImages || _controller == null) return;

    try {
      await _controller!.stopImageStream();
      _isStreamingImages = false;

      if (_imageStreamController != null && !_imageStreamController!.isClosed) {
        await _imageStreamController!.close();
        _imageStreamController = null;
      }

      print('Image stream stopped');
    } catch (e) {
      print('Error stopping image stream: $e');
    }
  }

  Future<void> setFlashMode(FlashMode mode) async {
    if (!_isInitialized || _controller == null) return;

    try {
      await _controller!.setFlashMode(mode);
      _currentFlashMode = mode;
      print('Flash mode set to: $mode');
    } catch (e) {
      print('Error setting flash mode: $e');
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
      print('Zoom level set to: $clampedZoom');
    } catch (e) {
      print('Error setting zoom level: $e');
      rethrow;
    }
  }

  Future<Uint8List?> takePicture() async {
    if (!_isInitialized || _controller == null) {
      throw Exception('Camera not initialized');
    }

    try {
      final XFile imageFile = await _controller!.takePicture();
      final Uint8List imageBytes = await imageFile.readAsBytes();
      print('Picture taken successfully: ${imageBytes.length} bytes');
      return imageBytes;
    } catch (e) {
      print('Error taking picture: $e');
      rethrow;
    }
  }

  Future<void> pausePreview() async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.pausePreview();
    }
  }

  Future<void> resumePreview() async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _controller!.resumePreview();
    }
  }

  Future<void> dispose() async {
    try {
      await stopImageStream();

      if (_controller != null) {
        await _controller!.dispose();
        _controller = null;
      }

      _isInitialized = false;
      _isStreamingImages = false;

      print('Flutter Camera Service disposed');
    } catch (e) {
      print('Error disposing camera service: $e');
    }
  }

  // Focus at a specific point (for tap-to-focus)
  Future<void> setFocusPoint(Offset point) async {
    if (!_isInitialized || _controller == null) return;

    try {
      await _controller!.setFocusPoint(point);
      print('Focus point set to: $point');
    } catch (e) {
      print('Error setting focus point: $e');
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
}
