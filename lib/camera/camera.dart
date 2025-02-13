// ignore_for_file: avoid_print

import 'package:camera/camera.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:macrotracker/gemini.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  late Future<void> _initializeControllerFuture;
  String _geminiResponse = '';

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;
    _controller = CameraController(firstCamera, ResolutionPreset.high);
    await _controller!.initialize();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI'),
        backgroundColor: const Color(0xFFF5F4F0),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera preview covers 80% of the screen height.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: screenHeight * 0.6,
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done &&
                    _controller != null &&
                    _controller!.value.isInitialized) {
                  return FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width,
                      height: screenHeight * 0.8,
                      child: CameraPreview(_controller!),
                    ),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          // Gemini response overlay remains at the bottom.
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              color: Colors.black45,
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _geminiResponse,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          try {
            await _initializeControllerFuture;
            if (_controller != null && _controller!.value.isInitialized) {
              final image = await _controller!.takePicture();
              final response = await processImageWithGemini(image.path);
              setState(() {
                _geminiResponse = response;
              });
            }
          } catch (e) {
            print('Error: $e');
            setState(() {
              _geminiResponse = 'Error: $e';
            });
          }
        },
        child: const Icon(CupertinoIcons.camera),
      ),
    );
  }

  @override
  void dispose() {
    if (_controller?.value.isInitialized ?? false) {
      _controller!.dispose();
    }
    super.dispose();
  }
}
