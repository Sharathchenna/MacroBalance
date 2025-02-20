import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import '../AI/gemini.dart';
import 'results_page.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  bool _isScanning = false;
  bool _flashOn = false;
  bool _isBarcodeMode = true;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;

    final controller = CameraController(
      firstCamera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.bgra8888,
    );

    _initializeControllerFuture = controller.initialize();
    setState(() {
      _controller = controller;
    });

    if (_isBarcodeMode) {
      await _startBarcodeScanning();
    }
  }

  Future<void> _startBarcodeScanning() async {
    await _controller?.startImageStream((image) {
      _processImage(image);
    });
  }

  Future<void> _processImage(CameraImage image) async {
    if (_isScanning) return;
    _isScanning = true;

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

      final List<Barcode> barcodes =
          await _barcodeScanner.processImage(inputImage);

      if (barcodes.isNotEmpty) {
        _controller?.stopImageStream();
        final String barcode = barcodes.first.rawValue ?? '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Barcode detected: $barcode'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );

        await _handleBarcodeResult(barcode);
      }
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isScanning = false;
    }
  }

  Future<void> _handleBarcodeResult(String barcode) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(child: CircularProgressIndicator(color: Colors.white));
      },
    );

    Navigator.pop(context);
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => ResultsPage(
          nutritionInfo: "Barcode: $barcode",
        ),
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

  @override
  void dispose() {
    _barcodeScanner.close();
    _controller?.dispose();
    super.dispose();
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
                        onPressed: () {},
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
                          setState(() {
                            _isBarcodeMode = true;
                            _startBarcodeScanning();
                          });
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
                          setState(() {
                            _isBarcodeMode = false;
                            _controller?.stopImageStream();
                          });
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
                    child: FutureBuilder<void>(
                      future: _initializeControllerFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
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
                        return;
                      }
                      await _takePicture();
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
