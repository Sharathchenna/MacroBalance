// ignore_for_file: library_private_types_in_public_api, avoid_print, use_build_context_synchronously

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:macrotracker/camera/barcode_results.dart';
import '../AI/gemini.dart';
import 'results_page.dart';
import '../services/camera_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraService _cameraService = CameraService();
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  bool _isScanning = false;
  bool _flashOn = false;
  bool _isBarcodeMode = true;

  // Add these new variables
  final bool _isAutoFocusEnabled = true;
  // final ExposureMode _exposureMode = ExposureMode.auto;
  // final FocusMode _focusMode = FocusMode.auto;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoom = 1.0;

  @override
  void initState() {
    super.initState();
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

        if (_isBarcodeMode) {
          await _startBarcodeScanning();
        }
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
      final image = await _controller?.takePicture();
      if (image == null) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(child: CircularProgressIndicator(color: Colors.white));
        },
      );

      final inputImage = InputImage.fromFilePath(image.path);
      final barcodes = await _barcodeScanner.processImage(inputImage);

      Navigator.pop(context); // Remove loading dialog

      if (barcodes.isNotEmpty) {
        await _handleBarcodeResult(barcodes.first.rawValue ?? '');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No barcode found. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error capturing and scanning barcode: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _startBarcodeScanning() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      print('Camera not initialized');
      return;
    }

    try {
      await _controller?.startImageStream((image) async {
        if (!_isScanning) {
          _isScanning = true;
          try {
            final List<Barcode> barcodes = await _processImage(image);
            if (barcodes.isNotEmpty) {
              await _stopBarcodeScanning();
              await _handleBarcodeResult(barcodes.first.rawValue ?? '');
              // Restart scanning after processing
              if (mounted) {
                await _startBarcodeScanning();
              }
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

  Future<void> _stopBarcodeScanning() async {
    try {
      if (_controller?.value.isStreamingImages ?? false) {
        await _controller?.stopImageStream();
      }
    } catch (e) {
      print('Error stopping image stream: $e');
    }
  }

  Future<void> _handleBarcodeResult(String barcode) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeResults(barcode: barcode),
      ),
    );
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller?.takePicture();

      if (image != null) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return Center(
                child: CircularProgressIndicator(color: Colors.white));
          },
        );

        final result = await processImageWithGemini(image.path);
        Navigator.pop(context);

        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (context) => ResultsPage(nutritionInfo: result),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

  @override
  void dispose() {
    _stopBarcodeScanning();
    super.dispose();
    // Don't dispose of the controller here as it's managed by the service
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
                        onTap: () => _switchMode(true),
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
                        onTap: () => _switchMode(false),
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
                      onScaleUpdate: _handleScaleUpdate,
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
                      onPressed: () {},
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
