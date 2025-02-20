import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../AI/gemini.dart';
import 'results_page.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  Future<void>? _initializeControllerFuture;

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
    );

    _initializeControllerFuture = controller.initialize();
    setState(() {
      _controller = controller;
    });
  }

  @override
  void dispose() {
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
            // Camera Controls Header
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

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Scan barcodes or take a photo',
                style: TextStyle(color: Colors.grey[400]),
              ),
            ),

            // Camera Preview with aspect ratio
            Expanded(
              child: FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      _controller != null) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        width: MediaQuery.of(context).size.width,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24.0),
                          color: Colors.black,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24.0),
                          child: AspectRatio(
                            aspectRatio: 4 / 3,
                            child: ClipRect(
                              child: Transform.scale(
                                scale: 1.0,
                                child: Center(
                                  child: CameraPreview(_controller!),
                                ),
                              ),
                            ),
                          ),
                        ),
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

            // Bottom Controls
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Gallery Button
                  Container(
                    width: 48,
                    height: 48,
                    child: IconButton(
                      icon: Icon(Icons.photo_library, color: Colors.white),
                      onPressed: () {},
                    ),
                  ),
                  // Capture Button
                  GestureDetector(
                    onTap: () async {
                      try {
                        await _initializeControllerFuture;
                        final image = await _controller?.takePicture();
                        if (image != null) {
                          // Show loading indicator
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (BuildContext context) {
                              return Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              );
                            },
                          );

                          // Process image with Gemini
                          final result =
                              await processImageWithGemini(image.path);

                          // Remove loading indicator
                          Navigator.pop(context);

                          // Navigate to results page
                          Navigator.push(
                            context,
                            CupertinoSheetRoute(
                              builder: (context) => ResultsPage(
                                nutritionInfo: result,
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        print(e);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error capturing image: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
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
                  // Empty space for symmetry
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
