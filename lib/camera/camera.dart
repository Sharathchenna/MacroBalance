// ignore_for_file: library_private_types_in_public_api, avoid_print, use_build_context_synchronously

import 'dart:convert';
import 'dart:math';

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
  bool _isDisposingCamera = false;

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
    if (!mounted) return;

    setState(() {
      _isContinuousScanning = false;
    });

    if (_barcodeFound) {
      // Set disposing flag before any async operations
      setState(() {
        _isDisposingCamera = true;
      });

      await _stopBarcodeScanning();
      await _disposeCamera();
      _cameraService.dispose();

      if (!_isDisposed && mounted) {
        Navigator.pop(context); // Close barcode entry screen
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

      // Set disposing flag to prevent UI from using controller
      setState(() {
        _isDisposingCamera = true;
      });

      // Stop streaming if needed
      if (_controller!.value.isStreamingImages) {
        try {
          await _stopBarcodeScanning();
        } catch (e) {
          print('Error stopping barcode scanning: $e');
        }
      }

      // Take picture before disposing camera
      final XFile? image = await _controller?.takePicture();
      if (image == null || _isDisposed) return;

      // Now dispose camera completely
      await _disposeCamera();
      _cameraService.dispose();

      // Show a single loading indicator with a named key
      // if (!_isDisposed && mounted) {
      //   showDialog(
      //     context: context,
      //     barrierDismissible: false,
      //     // Add a key to identify this dialog
      //     routeSettings: const RouteSettings(name: 'loading_dialog'),
      //     builder: (BuildContext context) {
      //       return const Center(
      //         child: CircularProgressIndicator(color: Colors.white),
      //       );
      //     },
      //   );
      // }

      try {
        // Process image
        String jsonResponse = await processImageWithGemini(image.path);
        // Clean up JSON code blocks and other processing...
        jsonResponse = jsonResponse.trim();
        if (jsonResponse.startsWith('```json')) {
          jsonResponse = jsonResponse.substring(7);
        }
        if (jsonResponse.endsWith('```')) {
          jsonResponse = jsonResponse.substring(0, jsonResponse.length - 3);
        }
        // Important: Make sure we have exactly one loading dialog active
        if (!_isDisposed && mounted) {
          // Pop any existing loading dialogs
          while (Navigator.of(context).canPop() &&
              ModalRoute.of(context)?.settings.name == 'loading_dialog') {
            Navigator.of(context).pop();
          }
        }

        dynamic decodedJson;
        try {
          decodedJson = json.decode(jsonResponse);
        } catch (e) {
          throw Exception('Invalid JSON: $e\nJSON: $jsonResponse');
        }

        List<dynamic> mealData;
        if (decodedJson is Map<String, dynamic>) {
          // Handle case where response is wrapped in an object
          if (decodedJson.containsKey('meal') && decodedJson['meal'] is List) {
            mealData = decodedJson['meal'] as List;
          } else {
            mealData = [decodedJson];
          }
        } else if (decodedJson is List) {
          mealData = decodedJson;
        } else {
          throw Exception('Unexpected JSON structure');
        }

        final List<AIFoodItem> foods = mealData
            .map((food) => AIFoodItem.fromJson(food as Map<String, dynamic>))
            .toList();

        if (foods.isNotEmpty) {
          // Add camera disposal before navigation
          await _disposeCamera();
          _cameraService.dispose();
          Navigator.pop(context); // Close camera screen
          Navigator.push(
            context,
            CupertinoPageRoute(
              builder: (context) => ResultsPage(foods: foods),
            ),
          );
        } else {
          throw Exception('No food items found');
        }
      } catch (e) {
        // Make sure to dismiss loading dialog on error
        if (!_isDisposed && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        // Show error message
        if (!_isDisposed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error processing image: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
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

  // Update _disposeCamera method
  Future<void> _disposeCamera() async {
    if (_isDisposingCamera) return; // Prevent multiple disposal attempts

    // setState(() {
    //   _isDisposingCamera = true;
    // });

    try {
      final CameraController? cameraController = _controller;
      if (cameraController != null && cameraController.value.isInitialized) {
        if (cameraController.value.isStreamingImages) {
          try {
            await cameraController.stopImageStream();
          } catch (e) {
            print('Error stopping image stream: $e');
          }
        }

        if (_flashOn) {
          try {
            await cameraController.setFlashMode(FlashMode.off);
          } catch (e) {
            print('Error turning off flash: $e');
          }
        }

        await cameraController.dispose();

        if (!_isDisposed && mounted) {
          setState(() {
            _controller = null;
          });
        }
      }
    } catch (e) {
      print('Error in camera disposal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with close, keyboard and info buttons
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon:
                        const Icon(Icons.close, color: Colors.white, size: 28),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard, color: Colors.white),
                        onPressed: () {
                          // Navigate to a separate full-screen route instead of showing a bottom sheet
                          Navigator.of(context).push(
                            CupertinoPageRoute(
                              builder: (context) {
                                return BarcodeEntryScreen(
                                  onBarcodeEntered: (barcode) {
                                    _handleBarcodeResult(barcode);
                                  },
                                );
                              },
                              // transitionsBuilder: (context, animation,
                              //     secondaryAnimation, child) {
                              //   const begin = Offset(0.0, 1.0);
                              //   const end = Offset.zero;
                              //   const curve = Curves.easeInOut;
                              //   var tween = Tween(begin: begin, end: end).chain(
                              //     CurveTween(curve: curve),
                              //   );
                              //   return SlideTransition(
                              //     position: animation.drive(tween),
                              //     child: child,
                              //   );
                              // },
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon:
                            const Icon(Icons.info_outline, color: Colors.white),
                        onPressed: () {
                          _showInfoDialog(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Mode Selector - Elegant minimal toggle
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  // Elegant toggle switch
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _switchMode(!_isBarcodeMode);
                    },
                    child: Container(
                      height: 32,
                      width: 110, // More compact width
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Stack(
                        children: [
                          // Track with labels
                          Row(
                            children: [
                              // Barcode label
                              Expanded(
                                child: Center(
                                  child: Opacity(
                                    opacity: _isBarcodeMode ? 0.0 : 1.0,
                                    child: Icon(
                                      Icons.qr_code,
                                      size: 14,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                              ),
                              // AI Photo label
                              Expanded(
                                child: Center(
                                  child: Opacity(
                                    opacity: !_isBarcodeMode ? 0.0 : 1.0,
                                    child: Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          // Animated thumb
                          AnimatedAlign(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            alignment: _isBarcodeMode
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              width: 55,
                              height: 26,
                              margin: const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Center(
                                child: Icon(
                                  _isBarcodeMode
                                      ? Icons.qr_code
                                      : Icons.camera_alt,
                                  color: Colors.black,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Mode name indicator
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _isBarcodeMode ? 'Barcode' : 'AI Photo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Hint text for barcode mode only
            if (_isBarcodeMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Position barcode within the frame',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ),

            // Disclaimer text for AI Photo mode
            if (!_isBarcodeMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Text(
                  'Note: AI results are estimates and should be verified for accuracy',
                  style: TextStyle(
                    color: Colors.grey[400],
                    // fontStyle: FontStyle.italic,
                    fontSize: 12,
                  ),
                ),
              ),

            // Camera preview
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Camera preview with smooth corners - consistent size for both modes
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: GestureDetector(
                        onScaleStart: _onScaleStart,
                        onScaleUpdate: _onScaleUpdate,
                        child: FutureBuilder<void>(
                          future: _initializeControllerFuture,
                          builder: (context, snapshot) {
                            if (_isDisposingCamera || _isDisposed) {
                              return Container(
                                color: Colors.black,
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            }

                            if (snapshot.connectionState ==
                                    ConnectionState.done &&
                                _controller != null &&
                                !_isDisposingCamera) {
                              return Transform.scale(
                                scale: 1.3,
                                alignment: Alignment.center,
                                child: CameraPreview(_controller!),
                              );
                            }
                            return Container(
                              color: Colors.black,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                    // Barcode scanner overlay (only shown in barcode mode)
                    if (_isBarcodeMode)
                      Center(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.7,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 100,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2.0,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Icon(
                                Icons.crop_free,
                                color: Colors.white.withOpacity(0.8),
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Keep only the flash control button:
                    Positioned(
                      top: 20,
                      left: 20,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _flashOn = !_flashOn;
                            _controller?.setFlashMode(
                              _flashOn ? FlashMode.torch : FlashMode.off,
                            );
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            _flashOn ? Icons.flash_on : Icons.flash_off,
                            color: _flashOn ? Colors.amber : Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom controls bar with elevated design
            Container(
              margin:
                  const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Gallery button with subtle background
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[900]?.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.photo_library,
                          color: Colors.white, size: 28),
                      padding: const EdgeInsets.all(12),
                      onPressed: () async {
                        HapticFeedback.selectionClick();
                        final ImagePicker picker = ImagePicker();
                        final XFile? pickedFile =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (pickedFile != null) {
                          // Set disposing flag to prevent UI from using controller
                          setState(() {
                            _isDisposingCamera = true;
                          });

                          // Dispose camera properly
                          await _disposeCamera();
                          _cameraService.dispose();

                          // Show loading indicator with name
                          if (!_isDisposed && mounted) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              routeSettings:
                                  const RouteSettings(name: 'loading_dialog'),
                              builder: (BuildContext context) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                );
                              },
                            );
                          }

                          try {
                            String jsonResponse =
                                await processImageWithGemini(pickedFile.path);
                            // Clean up JSON code blocks
                            jsonResponse = jsonResponse.trim();
                            if (jsonResponse.startsWith('```json')) {
                              jsonResponse = jsonResponse.substring(7);
                            }
                            if (jsonResponse.endsWith('```')) {
                              jsonResponse = jsonResponse.substring(
                                  0, jsonResponse.length - 3);
                            }

                            dynamic decodedJson;
                            try {
                              decodedJson = json.decode(jsonResponse);
                            } catch (e) {
                              throw Exception(
                                  'Invalid JSON: $e\nJSON: $jsonResponse');
                            }

                            List<dynamic> mealData;
                            if (decodedJson is Map<String, dynamic>) {
                              // Handle case where response is wrapped in an object
                              if (decodedJson.containsKey('meal') &&
                                  decodedJson['meal'] is List) {
                                mealData = decodedJson['meal'] as List;
                              } else {
                                mealData = [decodedJson];
                              }
                            } else if (decodedJson is List) {
                              mealData = decodedJson;
                            } else {
                              throw Exception('Unexpected JSON structure');
                            }

                            final List<AIFoodItem> foods = mealData
                                .map((food) => AIFoodItem.fromJson(
                                    food as Map<String, dynamic>))
                                .toList();

                            // Dismiss loading dialog before navigating
                            if (!_isDisposed && Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }

                            if (foods.isNotEmpty) {
                              // Add camera disposal before navigation
                              await _disposeCamera();
                              _cameraService.dispose();

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
                            // Always dismiss loading dialog on error
                            if (!_isDisposed && Navigator.canPop(context)) {
                              Navigator.pop(context);
                            }

                            if (!_isDisposed) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Error processing image: ${e.toString()}'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        }
                      },
                    ),
                  ),

                  // Capture button with enhanced design
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.selectionClick();
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
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 1,
                          )
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 65,
                          height: 65,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Empty space to balance layout (since we removed the mode switch button)
                  Container(
                    width: 52,
                    height: 52,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showInfoDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Camera Features',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Barcode Mode
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.qr_code,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Barcode Mode: Scan product barcodes to look up nutrition data',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // AI Photo Mode
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AI Photo Mode: Take a photo of your food to identify items and get nutritional info',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tips section
              const Text(
                'Tips:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _buildTipItem('Use the flash in low light conditions'),
              _buildTipItem('Pinch to zoom for better focusing'),
              _buildTipItem('For barcodes, ensure the code is clear in frame'),
              _buildTipItem('For food photos, capture the entire plate'),

              const SizedBox(height: 20),
              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withOpacity(0.1),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildTipItem(String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('• ', style: TextStyle(color: Colors.white, fontSize: 14)),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[300], fontSize: 14),
          ),
        ),
      ],
    ),
  );
}

// Create a beautiful, modern barcode entry screen
class BarcodeEntryScreen extends StatefulWidget {
  final Function(String) onBarcodeEntered;

  const BarcodeEntryScreen({
    Key? key,
    required this.onBarcodeEntered,
  }) : super(key: key);

  @override
  State<BarcodeEntryScreen> createState() => _BarcodeEntryScreenState();
}

class _BarcodeEntryScreenState extends State<BarcodeEntryScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController controller = TextEditingController();
  late AnimationController _animationController;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Add this GestureDetector to capture taps anywhere
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            // Rest of your code remains the same
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with subtle gradient
                  ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [Colors.white, Colors.white.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds);
                    },
                    child: Text(
                      'Enter Barcode',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Subtitle
                  Text(
                    'Type the number below the barcode',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Beautiful barcode design
                  Center(
                    child: Container(
                      width: double.infinity,
                      height: 110,
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(
                          colors: [
                            Colors.grey[900]!,
                            Colors.grey[800]!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          // Barcode lines - dynamically created
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(25, (index) {
                              final width = index % 3 == 0 ? 2.5 : 1.5;
                              final height =
                                  (40 + (Random().nextDouble() * 40));
                              return Container(
                                width: width,
                                height: height,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(0.5),
                                ),
                              );
                            }),
                          ),

                          // Barcode number at bottom - subtle effect
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 10,
                            child: Center(
                              child: Text(
                                '12345 67890',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                  letterSpacing: 3,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 48),

                  // Label with animation
                  AnimatedOpacity(
                    opacity: _isFocused ? 1.0 : 0.7,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      'Barcode Number',
                      style: TextStyle(
                        color: _isFocused ? Colors.white : Colors.grey[300],
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Beautiful text field with animation
                  FocusScope(
                    onFocusChange: (focused) {
                      setState(() {
                        _isFocused = focused;
                        if (focused) {
                          _animationController.forward();
                        } else {
                          _animationController.reverse();
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      padding: const EdgeInsets.symmetric(
                          vertical: 4, horizontal: 16),
                      decoration: BoxDecoration(
                        color: _isFocused ? Colors.grey[850] : Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _isFocused
                              ? Colors.white.withOpacity(0.3)
                              : Colors.transparent,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _isFocused
                                ? Colors.white.withOpacity(0.1)
                                : Colors.transparent,
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: controller,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        onSubmitted: _handleSubmit,
                        cursorColor: Colors.white,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w400,
                          letterSpacing: 2,
                        ),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '0000000000000',
                          hintStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 20,
                            letterSpacing: 2,
                            fontWeight: FontWeight.w300,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                          prefixIcon: AnimatedOpacity(
                            opacity: _isFocused ? 1.0 : 0.6,
                            duration: const Duration(milliseconds: 300),
                            child: Icon(
                              Icons.qr_code_scanner,
                              color:
                                  _isFocused ? Colors.white : Colors.grey[400],
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Helper text
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      'Usually 8-13 digits found below the barcode',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  SizedBox(height: MediaQuery.of(context).size.height * 0.15),

                  // Beautiful search button
                  Center(
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.1),
                            spreadRadius: 0,
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => _handleSubmit(controller.text),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: const Text(
                          'Search',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Cancel link
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // Add extra space to ensure no overflow
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleSubmit(String value) {
    if (value.isNotEmpty) {
      Navigator.pop(context);
      widget.onBarcodeEntered(value);
    }
  }
}
