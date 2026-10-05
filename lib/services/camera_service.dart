import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'dart:io';

class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  CameraController? _controller;
  bool _isStreaming = false;

  // Keep the same channel name as used in Dashboard and native code
  static const MethodChannel _nativeCameraViewChannel =
      MethodChannel('com.macrotracker/native_camera_view');

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

  // Method to show the native camera view
  Future<void> showNativeCamera() async {
    if (!Platform.isIOS) {
      print('[CameraService] Native camera view only supported on iOS.');
      // Consider showing a platform-specific error message or handling differently
      throw PlatformException(
          code: 'UNSUPPORTED_PLATFORM',
          message: 'Camera feature is only available on iOS.');
    }

    try {
      print('[CameraService] Invoking showNativeCamera...');
      await _nativeCameraViewChannel.invokeMethod('showNativeCamera');
      print('[CameraService] showNativeCamera invoked successfully.');
    } on PlatformException catch (e) {
      print('[CameraService] Error showing native camera: ${e.message}');
      // Rethrow the exception so the caller can handle it (e.g., show UI feedback)
      rethrow;
    }
  }

  // The native camera reports back over one channel, which can only have one
  // Dart handler. Screens register a listener instead, and results go to the
  // most recently registered screen that is still alive. Previously each
  // screen replaced the channel handler, so after leaving Search, photos were
  // delivered to the disposed Search page and silently dropped.
  final List<Future<dynamic> Function(MethodCall call)> _resultListeners = [];
  bool _channelBound = false;

  void addResultListener(Future<dynamic> Function(MethodCall call) listener) {
    _resultListeners.remove(listener);
    _resultListeners.add(listener);
    if (_channelBound) return;
    _nativeCameraViewChannel.setMethodCallHandler((call) async {
      if (_resultListeners.isEmpty) {
        print('[CameraService] ${call.method} arrived with no screen listening');
        return null;
      }
      return _resultListeners.last(call);
    });
    _channelBound = true;
  }

  void removeResultListener(Future<dynamic> Function(MethodCall call) listener) {
    _resultListeners.remove(listener);
  }
}
