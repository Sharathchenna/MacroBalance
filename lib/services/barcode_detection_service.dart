import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Simplified barcode detection service with focus on reliability
/// Uses Google ML Kit for both Android and iOS (unified approach)
class BarcodeDetectionService {
  static final BarcodeDetectionService _instance =
      BarcodeDetectionService._internal();
  factory BarcodeDetectionService() => _instance;
  BarcodeDetectionService._internal();

  // ML Kit scanner for all platforms
  BarcodeScanner? _barcodeScanner;
  bool _isProcessing = false;
  StreamController<String>? _barcodeStreamController;

  // Configuration
  bool _isEnabled = false;
  Rect? _scanArea;
  double _overlapThreshold = 0.3; // Lowered threshold for better detection

  // Getters
  bool get isEnabled => _isEnabled;
  Stream<String>? get barcodeStream => _barcodeStreamController?.stream;

  void initialize() {
    try {
      print('BarcodeDetectionService: Starting initialization...');

      // Force dispose first to ensure clean state
      _forceDispose();

      // Reset all state
      _isEnabled = false;
      _isProcessing = false;
      _scanArea = null;

      // Initialize fresh broadcast stream controller
      _barcodeStreamController = StreamController<String>.broadcast();

      // Initialize ML Kit scanner with all supported formats
      final List<BarcodeFormat> formats = [
        BarcodeFormat.all, // Support all barcode formats
      ];

      _barcodeScanner = BarcodeScanner(formats: formats);
      print('BarcodeDetectionService: Initialized successfully');
    } catch (e) {
      print('BarcodeDetectionService: Initialization error: $e');
    }
  }

  /// Force dispose without try-catch to ensure cleanup
  void _forceDispose() {
    _isEnabled = false;
    _isProcessing = false;

    // Close ML Kit scanner
    if (_barcodeScanner != null) {
      try {
        _barcodeScanner!.close();
      } catch (e) {
        print(
            'BarcodeDetectionService: Error closing scanner during force dispose: $e');
      }
      _barcodeScanner = null;
    }

    // Close stream controller
    if (_barcodeStreamController != null) {
      try {
        if (!_barcodeStreamController!.isClosed) {
          _barcodeStreamController!.close();
        }
      } catch (e) {
        print(
            'BarcodeDetectionService: Error closing stream during force dispose: $e');
      }
      _barcodeStreamController = null;
    }
  }

  void setScanArea(Rect scanArea) {
    _scanArea = scanArea;
    print('BarcodeDetectionService: Scan area set to: $scanArea');
  }

  void setOverlapThreshold(double threshold) {
    _overlapThreshold = threshold.clamp(0.0, 1.0);
    print(
        'BarcodeDetectionService: Overlap threshold set to: $_overlapThreshold');
  }

  void startDetection() {
    _isEnabled = true;
    _isProcessing = false; // Reset processing flag

    // Ensure stream controller is available
    if (_barcodeStreamController == null ||
        _barcodeStreamController!.isClosed) {
      _barcodeStreamController = StreamController<String>.broadcast();
      print('BarcodeDetectionService: Created new stream controller');
    }

    print('BarcodeDetectionService: Detection started');
  }

  void stopDetection() {
    _isEnabled = false;
    _isProcessing = false;
    print('BarcodeDetectionService: Detection stopped');
  }

  /// Reset the detection state for a clean restart
  void resetDetection() {
    print('BarcodeDetectionService: Resetting detection state...');
    _isEnabled = false;
    _isProcessing = false;

    // Close and recreate stream controller
    try {
      if (_barcodeStreamController != null &&
          !_barcodeStreamController!.isClosed) {
        _barcodeStreamController!.close();
      }
    } catch (e) {
      print(
          'BarcodeDetectionService: Error closing stream controller during reset: $e');
    }

    _barcodeStreamController = StreamController<String>.broadcast();
    print('BarcodeDetectionService: Detection state reset complete');
  }

  /// Main method for detecting barcodes from camera images
  Future<String?> detectBarcode(CameraImage image) async {
    if (!_isEnabled || _isProcessing || _barcodeScanner == null) {
      return null;
    }

    _isProcessing = true;

    try {
      // Convert CameraImage to InputImage
      final InputImage inputImage = _convertCameraImageToInputImage(image);

      // Process with ML Kit
      final List<Barcode> barcodes =
          await _barcodeScanner!.processImage(inputImage);

      // Find first valid barcode in scan area
      for (final Barcode barcode in barcodes) {
        if (barcode.displayValue != null && barcode.displayValue!.isNotEmpty) {
          // Check if barcode is in scan area (if specified)
          if (_scanArea != null &&
              !_isBarcodeInScanArea(barcode.boundingBox, _scanArea!)) {
            continue;
          }

          final String barcodeValue = barcode.displayValue!;
          print('BarcodeDetectionService: Barcode detected: $barcodeValue');

          // Add to stream
          _addToStream(barcodeValue);
          return barcodeValue;
        }
      }

      return null;
    } catch (e) {
      print('BarcodeDetectionService: Error detecting barcode: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Detect barcode from file path (for manual capture)
  Future<String?> detectBarcodeFromFile(String imagePath) async {
    if (_isProcessing || _barcodeScanner == null) {
      return null;
    }

    _isProcessing = true;

    try {
      // Create InputImage from file path
      final InputImage inputImage = InputImage.fromFilePath(imagePath);
      final List<Barcode> barcodes =
          await _barcodeScanner!.processImage(inputImage);

      // Return first valid barcode found
      for (final Barcode barcode in barcodes) {
        if (barcode.displayValue != null && barcode.displayValue!.isNotEmpty) {
          final String barcodeValue = barcode.displayValue!;
          print(
              'BarcodeDetectionService: Barcode detected from file: $barcodeValue');

          // Add to stream
          _addToStream(barcodeValue);
          return barcodeValue;
        }
      }

      print('BarcodeDetectionService: No barcode found in image file');
      return null;
    } catch (e) {
      print('BarcodeDetectionService: Error detecting barcode from file: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  /// Add barcode to stream safely
  void _addToStream(String barcode) {
    try {
      if (_barcodeStreamController != null &&
          !_barcodeStreamController!.isClosed) {
        _barcodeStreamController!.add(barcode);
      }
    } catch (e) {
      print('BarcodeDetectionService: Error adding to stream: $e');
    }
  }

  /// Convert CameraImage to InputImage for ML Kit
  InputImage _convertCameraImageToInputImage(CameraImage image) {
    // Handle different platforms
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    // Determine format and rotation based on platform
    InputImageFormat format;
    InputImageRotation rotation;

    if (Platform.isAndroid) {
      format = InputImageFormat.yuv420;
      rotation = InputImageRotation.rotation90deg;
    } else {
      format = InputImageFormat.bgra8888;
      rotation = InputImageRotation.rotation90deg;
    }

    final Size imageSize =
        Size(image.width.toDouble(), image.height.toDouble());
    final int bytesPerRow =
        image.planes.isNotEmpty ? image.planes[0].bytesPerRow : image.width;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imageSize,
        rotation: rotation,
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );
  }

  /// Check if barcode bounding box overlaps with scan area
  bool _isBarcodeInScanArea(Rect? boundingBox, Rect scanArea) {
    if (boundingBox == null) return true; // Allow if no bounding box

    try {
      final intersection = boundingBox.intersect(scanArea);
      if (intersection.isEmpty) return false;

      final overlapArea = intersection.width * intersection.height;
      final barcodeArea = boundingBox.width * boundingBox.height;

      if (barcodeArea <= 0) return true; // Allow if area calculation fails

      final overlapPercentage = overlapArea / barcodeArea;
      final meetsThreshold = overlapPercentage >= _overlapThreshold;

      print(
          'BarcodeDetectionService: Overlap ${(overlapPercentage * 100).toStringAsFixed(1)}% (threshold: ${(_overlapThreshold * 100).toStringAsFixed(1)}%)');

      return meetsThreshold;
    } catch (e) {
      print('BarcodeDetectionService: Error checking overlap: $e');
      return true; // Allow detection if overlap check fails
    }
  }

  /// Get list of supported barcode formats
  List<String> getSupportedFormats() {
    return [
      'aztec',
      'codabar',
      'code39',
      'code93',
      'code128',
      'dataMatrix',
      'ean8',
      'ean13',
      'itf',
      'pdf417',
      'qrCode',
      'upca',
      'upce'
    ];
  }

  /// Validate barcode format
  bool isValidBarcodeFormat(String barcode) {
    if (barcode.isEmpty || barcode.length < 4) {
      return false;
    }

    // Additional format-specific validation can be added here
    return true;
  }

  /// Clean disposal of resources
  void dispose() {
    print('BarcodeDetectionService: Disposing...');

    _isEnabled = false;
    _isProcessing = false;

    // Close ML Kit scanner
    try {
      _barcodeScanner?.close();
      _barcodeScanner = null;
    } catch (e) {
      print('BarcodeDetectionService: Error closing scanner: $e');
    }

    // Close stream controller
    try {
      if (_barcodeStreamController != null &&
          !_barcodeStreamController!.isClosed) {
        _barcodeStreamController!.close();
      }
      _barcodeStreamController = null;
    } catch (e) {
      print('BarcodeDetectionService: Error closing stream: $e');
    }

    print('BarcodeDetectionService: Disposed successfully');
  }
}
