import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

/// Platform-specific barcode detection service
///
/// - Android: Uses Google ML Kit for barcode detection
/// - iOS: Uses native iOS Vision framework through method channels
///
/// This provides optimal performance and native integration on each platform.

class BarcodeDetectionService {
  static final BarcodeDetectionService _instance =
      BarcodeDetectionService._internal();
  factory BarcodeDetectionService() => _instance;
  BarcodeDetectionService._internal();

  // Google ML Kit scanner (for Android)
  late BarcodeScanner _barcodeScanner;

  // iOS Native method channel
  static const MethodChannel _nativeBarcodeChannel =
      MethodChannel('com.macrotracker/native_barcode_scanner');

  bool _isProcessing = false;
  StreamController<String>? _barcodeStreamController;

  // Configuration
  bool _isEnabled = false;
  Rect? _scanArea;
  double _overlapThreshold = 0.5; // Minimum overlap percentage required

  // Getters
  bool get isEnabled => _isEnabled;
  Stream<String>? get barcodeStream => _barcodeStreamController?.stream;

  void initialize() {
    _barcodeStreamController = StreamController<String>.broadcast();

    if (Platform.isAndroid) {
      _initializeAndroidMLKit();
    } else if (Platform.isIOS) {
      _initializeiOSNative();
    }

    print(
        'Barcode Detection Service initialized for ${Platform.operatingSystem}');
  }

  void _initializeAndroidMLKit() {
    // Initialize Google ML Kit barcode scanner for Android
    final List<BarcodeFormat> formats = [
      BarcodeFormat.all, // This includes all supported formats
    ];

    _barcodeScanner = BarcodeScanner(formats: formats);
    print('Google ML Kit barcode scanner initialized for Android');
  }

  void _initializeiOSNative() {
    // Set up method channel for iOS native barcode detection
    _nativeBarcodeChannel.setMethodCallHandler(_handleiOSNativeCall);
    print('iOS native barcode scanner initialized');
  }

  Future<dynamic> _handleiOSNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'onBarcodeDetected':
        final String barcode = call.arguments['barcode'] as String;
        final Map<String, dynamic> boundingBox =
            call.arguments['boundingBox'] as Map<String, dynamic>;

        print('iOS Native barcode detected: $barcode');

        // Check if barcode is in scan area (if specified)
        if (_scanArea != null &&
            !_isiOSBarcodeInScanArea(boundingBox, _scanArea!)) {
          return;
        }

        // Add to stream
        if (_barcodeStreamController != null &&
            !_barcodeStreamController!.isClosed) {
          _barcodeStreamController!.add(barcode);
        }
        break;

      case 'onBarcodeError':
        final String error = call.arguments['error'] as String;
        print('iOS Native barcode error: $error');
        break;

      default:
        print('Unknown method call from iOS: ${call.method}');
    }
  }

  bool _isiOSBarcodeInScanArea(
      Map<String, dynamic> boundingBox, Rect scanArea) {
    try {
      final double x = (boundingBox['x'] as num).toDouble();
      final double y = (boundingBox['y'] as num).toDouble();
      final double width = (boundingBox['width'] as num).toDouble();
      final double height = (boundingBox['height'] as num).toDouble();

      final Rect barcodeRect = Rect.fromLTWH(x, y, width, height);
      final intersection = barcodeRect.intersect(scanArea);

      if (intersection.isEmpty) return false;

      final overlapArea = intersection.width * intersection.height;
      final barcodeArea = barcodeRect.width * barcodeRect.height;

      if (barcodeArea == 0) return false;

      final overlapPercentage = overlapArea / barcodeArea;

      print(
          'iOS Barcode overlap: ${(overlapPercentage * 100).toStringAsFixed(1)}%');

      return overlapPercentage >= _overlapThreshold;
    } catch (e) {
      print('Error checking iOS barcode overlap: $e');
      return true; // Allow detection if we can't determine overlap
    }
  }

  void setScanArea(Rect scanArea) {
    _scanArea = scanArea;
    print('Scan area set to: $scanArea');

    // Send scan area to iOS native if needed
    if (Platform.isIOS) {
      _nativeBarcodeChannel.invokeMethod('setScanArea', {
        'x': scanArea.left,
        'y': scanArea.top,
        'width': scanArea.width,
        'height': scanArea.height,
      });
    }
  }

  void setOverlapThreshold(double threshold) {
    _overlapThreshold = threshold.clamp(0.0, 1.0);
    print('Overlap threshold set to: $_overlapThreshold');

    // Send threshold to iOS native if needed
    if (Platform.isIOS) {
      _nativeBarcodeChannel.invokeMethod('setOverlapThreshold', threshold);
    }
  }

  void startDetection() {
    _isEnabled = true;
    print('Barcode detection started');

    // Start iOS native detection if needed
    if (Platform.isIOS) {
      _nativeBarcodeChannel.invokeMethod('startDetection');
    }
  }

  void stopDetection() {
    _isEnabled = false;
    print('Barcode detection stopped');

    // Stop iOS native detection if needed
    if (Platform.isIOS) {
      _nativeBarcodeChannel.invokeMethod('stopDetection');
    }
  }

  Future<String?> detectBarcode(CameraImage image) async {
    if (!_isEnabled || _isProcessing) {
      return null;
    }

    if (Platform.isAndroid) {
      return await _detectBarcodeAndroid(image);
    } else if (Platform.isIOS) {
      // For iOS, we send the image to native code for processing
      return await _detectBarcodeiOS(image);
    }

    return null;
  }

  Future<String?> _detectBarcodeAndroid(CameraImage image) async {
    _isProcessing = true;

    try {
      final InputImage inputImage = _convertCameraImageToInputImage(image);
      final List<Barcode> barcodes =
          await _barcodeScanner.processImage(inputImage);

      for (final Barcode barcode in barcodes) {
        if (barcode.displayValue != null && barcode.displayValue!.isNotEmpty) {
          // Check if barcode is in scan area (if specified)
          if (_scanArea != null &&
              !_isBarcodeInScanArea(barcode.boundingBox, _scanArea!)) {
            continue;
          }

          final String barcodeValue = barcode.displayValue!;
          print('Android ML Kit barcode detected: $barcodeValue');

          // Add to stream
          if (_barcodeStreamController != null &&
              !_barcodeStreamController!.isClosed) {
            _barcodeStreamController!.add(barcodeValue);
          }

          return barcodeValue;
        }
      }

      return null;
    } catch (e) {
      print('Error detecting barcode with ML Kit: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  Future<String?> _detectBarcodeiOS(CameraImage image) async {
    _isProcessing = true;

    try {
      // Convert CameraImage to a format iOS can understand
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      // Send image data to iOS for native processing
      final result = await _nativeBarcodeChannel.invokeMethod('processImage', {
        'imageData': bytes,
        'width': image.width,
        'height': image.height,
        'format': 'bgra8888', // iOS typically uses BGRA format
      });

      if (result != null && result is String && result.isNotEmpty) {
        print('iOS Native barcode detected: $result');

        // Add to stream
        if (_barcodeStreamController != null &&
            !_barcodeStreamController!.isClosed) {
          _barcodeStreamController!.add(result);
        }

        return result;
      }

      return null;
    } catch (e) {
      print('Error detecting barcode with iOS native: $e');
      return null;
    } finally {
      _isProcessing = false;
    }
  }

  // Process stream of camera images
  void processImageStream(Stream<CameraImage> imageStream) {
    if (_barcodeStreamController == null ||
        _barcodeStreamController!.isClosed) {
      _barcodeStreamController = StreamController<String>.broadcast();
    }

    imageStream.listen((CameraImage image) async {
      if (_isEnabled && !_isProcessing) {
        await detectBarcode(image);
      }
    });
  }

  // Android ML Kit specific methods
  InputImage _convertCameraImageToInputImage(CameraImage image) {
    // Convert CameraImage to InputImage for ML Kit (Android only)
    final WriteBuffer allBytes = WriteBuffer();
    for (final Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    // For Android, typically YUV420 format
    const inputImageFormat = InputImageFormat.yuv420;
    const inputImageRotation = InputImageRotation.rotation90deg;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: inputImageRotation,
        format: inputImageFormat,
        bytesPerRow:
            image.planes.isNotEmpty ? image.planes[0].bytesPerRow : image.width,
      ),
    );
  }

  bool _isBarcodeInScanArea(Rect? boundingBox, Rect scanArea) {
    if (boundingBox == null) return false;

    final intersection = boundingBox.intersect(scanArea);
    if (intersection.isEmpty) return false;

    final overlapArea = intersection.width * intersection.height;
    final barcodeArea = boundingBox.width * boundingBox.height;

    if (barcodeArea == 0) return false;

    final overlapPercentage = overlapArea / barcodeArea;

    print(
        'Android Barcode overlap: ${(overlapPercentage * 100).toStringAsFixed(1)}%');

    return overlapPercentage >= _overlapThreshold;
  }

  // Convert screen coordinates to camera coordinates
  Rect convertScreenToImageCoordinates(
      Rect screenRect, Size screenSize, Size imageSize) {
    final double scaleX = imageSize.width / screenSize.width;
    final double scaleY = imageSize.height / screenSize.height;

    return Rect.fromLTWH(
      screenRect.left * scaleX,
      screenRect.top * scaleY,
      screenRect.width * scaleX,
      screenRect.height * scaleY,
    );
  }

  // Get supported barcode formats (cross-platform)
  List<String> getSupportedFormats() {
    if (Platform.isAndroid) {
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
    } else if (Platform.isIOS) {
      return [
        'aztec',
        'code39',
        'code93',
        'code128',
        'dataMatrix',
        'ean8',
        'ean13',
        'face',
        'itf14',
        'pdf417',
        'qr',
        'upce'
      ];
    }
    return [];
  }

  // Validate barcode format
  bool isValidBarcodeFormat(String barcode) {
    // Basic validation - check if it's not empty and has reasonable length
    if (barcode.isEmpty || barcode.length < 4) {
      return false;
    }

    // Additional validation can be added here based on expected formats
    // For example, UPC codes should be 12 digits, EAN13 should be 13 digits, etc.

    return true;
  }

  void dispose() {
    _isEnabled = false;

    if (Platform.isAndroid) {
      _barcodeScanner.close();
    } else if (Platform.isIOS) {
      _nativeBarcodeChannel.invokeMethod('dispose');
    }

    if (_barcodeStreamController != null &&
        !_barcodeStreamController!.isClosed) {
      _barcodeStreamController!.close();
      _barcodeStreamController = null;
    }

    print('Barcode Detection Service disposed');
  }
}
