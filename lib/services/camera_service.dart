import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:io';

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
}
