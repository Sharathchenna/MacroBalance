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
      final firstCamera = cameras.first;

      final controller = CameraController(
        firstCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.bgra8888,
      );

      await controller.initialize();

      // Configure camera
      await Future.wait([
        controller.setFocusMode(FocusMode.auto),
        controller.setExposureMode(ExposureMode.auto),
        controller.setFlashMode(FlashMode.off),
      ]);

      _controller = controller;
      _initialized = true;
    } catch (e) {
      print('Error initializing camera service: $e');
    }
  }

  void dispose() {
    _controller?.dispose();
    _controller = null;
    _initialized = false;
  }
}