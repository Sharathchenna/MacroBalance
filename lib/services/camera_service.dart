import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import '../widgets/camera/flutter_camera_screen.dart';
import '../widgets/camera/camera_controls.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? _controller;
  bool _isStreaming = false;

  Future<CameraController?> get controller async {
    if (_controller != null) return _controller;

    final cameras = await availableCameras();
    if (cameras.isEmpty) return null;

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    await _controller?.initialize();
    return _controller;
  }

  Future<void> stopImageStream() async {
    try {
      if (_controller != null &&
          _controller!.value.isInitialized &&
          _isStreaming) {
        await _controller?.stopImageStream();
        _isStreaming = false;
      }
    } catch (e) {
      print('Error stopping image stream: $e');
    }
  }

  Future<void> startImageStream(Function(CameraImage) onImage) async {
    try {
      if (_controller != null &&
          _controller!.value.isInitialized &&
          !_isStreaming) {
        await _controller?.startImageStream(onImage);
        _isStreaming = true;
      }
    } catch (e) {
      print('Error starting image stream: $e');
    }
  }

  void dispose() {
    stopImageStream();
    _controller?.dispose();
    _controller = null;
    _isStreaming = false;
  }

  // Method to show Flutter camera
  Future<Map<String, dynamic>?> showCamera({
    CameraMode initialMode = CameraMode.camera,
    required BuildContext context,
  }) async {
    // Use Flutter camera implementation
    return await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => FlutterCameraScreen(
          initialMode: initialMode,
        ),
      ),
    );
  }

  // Legacy methods for backward compatibility (now use Flutter camera)
  @Deprecated('Use showCamera instead')
  Future<void> showNativeCamera() async {
    throw UnsupportedError(
        'Native camera has been replaced with Flutter camera implementation. Use showCamera() instead.');
  }

  @Deprecated('Native camera handlers are no longer needed')
  void setupMethodCallHandler(Function handler) {
    print(
        '[CameraService] Native camera handlers are deprecated. Flutter camera handles its own results.');
  }
}
