// ignore_for_file: library_private_types_in_public_api, avoid_print, use_build_context_synchronously

import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:macrotracker/camera/barcode_results.dart';
import '../AI/gemini.dart';
import 'results_page.dart';
import '../services/camera_service.dart';
// Add import for AIFoodItem model
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:image_picker/image_picker.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  final CameraService _cameraService = CameraService();
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  bool _isScanning = false;
  bool _flashOn = false;
  bool _isBarcodeMode = true;
  bool _isDisposed = false;

  // Add these new variables
  final bool _isAutoFocusEnabled = true;
  // final ExposureMode _exposureMode = ExposureMode.auto;
  // final FocusMode _focusMode = FocusMode.auto;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoom = 1.0;

  // Add this flag to control continuous scanning
  bool _isContinuousScanning = false;

  // Add this variable to track if we've found a barcode
  bool _barcodeFound = false;

  // Add these new state fields
  double _baseScale = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      _controller = await _cameraService.controller;
      if (_controller != null) {
        // Get zoom levels
        _minAvailableZoom = await _controller!.getMinZoomLevel();
        _maxAvailableZoom = await _controller!.getMaxZoomLevel();

        if (mounted) {
          setState(() {
            _initializeControllerFuture = Future.value();
          });
        }

        // Remove automatic start of barcode scanning
        // if (_isBarcodeMode) {
        //   await _startBarcodeScanning();
        // }
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> _captureAndScanBarcode() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print('Camera not initialized');
      return;
    }

    try {
      setState(() {
        _barcodeFound = false; // Reset the barcode found flag
        _isContinuousScanning = true;
      });

      await _startBarcodeScanning();

      // Set a timeout to stop scanning after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isContinuousScanning = false;
          });
          if (!_barcodeFound) {
            _stopBarcodeScanning();
          }
        }
      });
    } catch (e) {
      print('Error capturing and scanning barcode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to scan barcode. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Update _startBarcodeScanning method
  Future<void> _startBarcodeScanning() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print('Camera not initialized');
      return;
    }

    try {
      await _cameraService.startImageStream((image) async {
        // Only process if we're scanning and haven't found a barcode yet
        if (!_isScanning && !_barcodeFound) {
          _isScanning = true;
          try {
            final List<Barcode> barcodes = await _processImage(image);
            if (barcodes.isNotEmpty && mounted) {
              _barcodeFound = true; // Mark that we found a barcode
              await _stopBarcodeScanning();
              await _handleBarcodeResult(barcodes.first.rawValue ?? '');
            }
          } finally {
            _isScanning = false;
          }
        }
      });
    } catch (e) {
      print('Error starting image stream: $e');
    }
  }

  Future<List<Barcode>> _processImage(CameraImage image) async {
    try {
      final InputImage inputImage = InputImage.fromBytes(
        bytes: image.planes[0].bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: InputImageRotation.rotation0deg,
          format: InputImageFormat.bgra8888,
          bytesPerRow: image.planes[0].bytesPerRow,
        ),
      );

      return await _barcodeScanner.processImage(inputImage);
    } catch (e) {
      print('Error processing image: $e');
      return [];
    }
  }

  // Update _stopBarcodeScanning method
  Future<void> _stopBarcodeScanning() async {
    try {
      await _cameraService.stopImageStream();
    } catch (e) {
      print('Error stopping barcode scanning: $e');
    }
  }

  Future<void> _handleBarcodeResult(String barcode) async {
    if (mounted) {
      setState(() {
        _isContinuousScanning = false;
      });

      // Navigate only if we haven't already
      if (_barcodeFound) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BarcodeResults(barcode: barcode),
          ),
        );
      }
    }
  }

  // Update the _takePicture method
  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      if (_controller == null || !_controller!.value.isInitialized) {
        return;
      }

      // Only stop image stream if we're in barcode mode and streaming
      if (_isBarcodeMode && _controller!.value.isStreamingImages) {
        await _stopBarcodeScanning();
      }

      final image = await _controller?.takePicture();

      if (image != null && !_isDisposed) {
        // Show loading indicator
        if (!_isDisposed) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.white),
              );
            },
          );
        }

        try {
          // Process image
          String jsonResponse = await processImageWithGemini(image.path);

          if (!_isDisposed) {
            // Remove loading dialog
            Navigator.pop(context);

            if (jsonResponse.isNotEmpty) {
              // Clean up the response
              jsonResponse = jsonResponse.trim();
              if (jsonResponse.startsWith('```json')) {
                jsonResponse = jsonResponse.substring(7);
              }
              if (jsonResponse.endsWith('```')) {
                jsonResponse =
                    jsonResponse.substring(0, jsonResponse.length - 3);
              }

              final dynamic decodedJson = json.decode(jsonResponse);
              if (decodedJson == null) {
                throw Exception('Invalid JSON response');
              }

              List<dynamic> mealData;
              if (decodedJson is Map<String, dynamic>) {
                mealData = [decodedJson];
              } else if (decodedJson is List) {
                mealData = decodedJson;
              } else {
                throw Exception('Unexpected JSON structure');
              }

              final List<AIFoodItem> foods = mealData
                  .map((food) =>
                      AIFoodItem.fromJson(food as Map<String, dynamic>))
                  .toList();

              if (foods.isNotEmpty) {
                Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => ResultsPage(foods: foods),
                  ),
                );
              } else {
                throw Exception('No food items found');
              }
            }
          }
        } catch (e) {
          if (!_isDisposed) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error processing image: ${e.toString()}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } catch (e) {
      if (!_isDisposed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error taking picture: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Restart barcode scanning if needed
      if (!_isDisposed && _isBarcodeMode) {
        await _startBarcodeScanning();
      }
    }
  }

  void _switchMode(bool barcode) async {
    if (_isBarcodeMode == barcode) return;

    await _stopBarcodeScanning();

    setState(() {
      _isBarcodeMode = barcode;
    });

    if (barcode) {
      await _startBarcodeScanning();
    }
  }

  // Add method to configure focus
  Future<void> _configureFocus() async {
    if (_controller == null) return;

    try {
      await _controller!.setFocusPoint(null);
      await _controller!.setFocusMode(
          _isAutoFocusEnabled ? FocusMode.auto : FocusMode.locked);
    } catch (e) {
      print('Error configuring focus: $e');
    }
  }

  // Add method to handle zoom
  Future<void> _setZoomLevel(double zoom) async {
    if (_controller == null) return;

    try {
      zoom = zoom.clamp(_minAvailableZoom, _maxAvailableZoom);
      await _controller!.setZoomLevel(zoom);
      setState(() {
        _currentZoom = zoom;
      });
    } catch (e) {
      print('Error setting zoom level: $e');
    }
  }

  // Add zoom gesture handler
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    _setZoomLevel(_currentZoom * details.scale);
  }

  // Add these new methods
  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _currentZoom;
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    // Multiply the base scale by the scale factor from the gesture
    double newZoom = _baseScale * details.scale;
    await _setZoomLevel(newZoom);
  }

  // Add reset method for when returning from results page
  void _resetBarcodeScanner() {
    setState(() {
      _barcodeFound = false;
      _isScanning = false;
      _isContinuousScanning = false;
    });
  }

  @override
  void dispose() {
    _barcodeFound = false; // Reset on dispose
    WidgetsBinding.instance.removeObserver(this);
    _stopBarcodeScanning();
    _cameraService.dispose();
    _isDisposed = true;
    _disposeCamera();
    super.dispose();
    // Don't dispose of the controller here as it's managed by the service
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _stopBarcodeScanning();
      _cameraService.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _disposeCamera() async {
    try {
      final CameraController? cameraController = _controller;
      if (cameraController != null && cameraController.value.isInitialized) {
        await cameraController.stopImageStream();
        await cameraController.dispose();
      }
    } catch (e) {
      // Ignore PlatformException for stream deactivation
      if (e is PlatformException && e.code == 'error') {
        print('Ignoring expected platform exception during disposal');
      } else {
        print('Error disposing camera: $e');
      }
    }
    if (!_isDisposed) {
      _controller = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.keyboard, color: Colors.white),
                        onPressed: () {
                          final TextEditingController controller =
                              TextEditingController();
                          showCupertinoDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return CupertinoAlertDialog(
                                title: Text('Enter Barcode'),
                                content: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 16.0),
                                  child: CupertinoTextField(
                                    controller: controller,
                                    keyboardType: TextInputType.number,
                                    placeholder: 'Enter barcode number',
                                    autofocus: true,
                                    onSubmitted: (value) {
                                      if (value.isNotEmpty) {
                                        Navigator.pop(context);
                                        _handleBarcodeResult(value);
                                      }
                                    },
                                  ),
                                ),
                                actions: [
                                  CupertinoDialogAction(
                                    child: Text('Cancel'),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  CupertinoDialogAction(
                                    child: Text('Search'),
                                    onPressed: () {
                                      if (controller.text.isNotEmpty) {
                                        Navigator.pop(context);
                                        _handleBarcodeResult(controller.text);
                                      }
                                    },
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.info_outline, color: Colors.white),
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Scan barcodes or take a photo',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Container(
                width: 200,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[900],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _switchMode(true);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: _isBarcodeMode
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              'Barcode',
                              style: TextStyle(
                                color: _isBarcodeMode
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _switchMode(false);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: !_isBarcodeMode
                                ? Colors.white
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Center(
                            child: Text(
                              'AI Photo',
                              style: TextStyle(
                                color: !_isBarcodeMode
                                    ? Colors.black
                                    : Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onScaleStart: _onScaleStart,
                      onScaleUpdate: _onScaleUpdate,
                      child: FutureBuilder<void>(
                        future: _initializeControllerFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                                  ConnectionState.done &&
                              _controller != null) {
                            return ClipRect(
                              child: Transform.scale(
                                scale: 1.3,
                                alignment: Alignment.center,
                                child: CameraPreview(_controller!),
                              ),
                            );
                          }
                          return Container(
                            color: Colors.grey[900],
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  if (_isBarcodeMode)
                    Center(
                      child: Container(
                        width: MediaQuery.of(context).size.width * 0.8,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.white,
                            width: 2.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    _flashOn ? Icons.flash_on : Icons.flash_off,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    setState(() {
                      _flashOn = !_flashOn;
                      _controller?.setFlashMode(
                        _flashOn ? FlashMode.torch : FlashMode.off,
                      );
                    });
                  },
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      icon: Icon(Icons.photo_library, color: Colors.white),
                      onPressed: () async {
                        final ImagePicker picker = ImagePicker();
                        final XFile? pickedFile =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white));
                            },
                          );
                          try {
                            String jsonResponse =
                                await processImageWithGemini(pickedFile.path);
                            Navigator.pop(context); // Remove loading dialog

                            jsonResponse = jsonResponse.trim();
                            if (jsonResponse.startsWith('```json')) {
                              jsonResponse = jsonResponse.substring(7);
                            }
                            if (jsonResponse.endsWith('```')) {
                              jsonResponse = jsonResponse.substring(
                                  0, jsonResponse.length - 3);
                            }

                            final dynamic decodedJson =
                                json.decode(jsonResponse);
                            List<dynamic> mealData;
                            if (decodedJson is Map<String, dynamic>) {
                              mealData = [decodedJson];
                            } else if (decodedJson is List) {
                              mealData = decodedJson;
                            } else {
                              throw Exception('Unexpected JSON structure');
                            }

                            final List<AIFoodItem> foods = mealData
                                .map((food) => AIFoodItem.fromJson(
                                    food as Map<String, dynamic>))
                                .toList();

                            if (foods.isNotEmpty) {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                    builder: (context) =>
                                        ResultsPage(foods: foods)),
                              );
                            } else {
                              throw Exception('No food items found');
                            }
                          } catch (e) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Error processing image: ${e.toString()}'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                  GestureDetector(
                    onTap: () async {
                      if (_isBarcodeMode) {
                        await _captureAndScanBarcode();
                      } else {
                        await _takePicture();
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 48, height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
