import 'package:camera/camera.dart';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? _controller;
  bool _initialized = false;

  Future<CameraController?> get controller async {
    if (!_initialized) {
      await _initializeCamera();
    }
    return _controller;
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _controller?.initialize();
      _initialized = true;
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  Future<void> dispose() async {
    try {
      await _controller?.dispose();
      _controller = null;
      _initialized = false;
    } catch (e) {
      print('Error disposing camera: $e');
    }
  }
}
