import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/camera_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = 'com.macrotracker/native_camera_view';

  /// Sends [method] from the native side, as the camera does with a result.
  Future<Object?> fromNative(String method, [Object? args]) async {
    const codec = StandardMethodCodec();
    ByteData? reply;
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(channel,
            codec.encodeMethodCall(MethodCall(method, args)), (data) => reply = data);
    return reply == null ? null : codec.decodeEnvelope(reply!);
  }

  test('the most recently added listener gets camera results', () async {
    final camera = CameraService();
    final calls = <String>[];
    Future<dynamic> search(MethodCall c) async => calls.add('search:${c.method}');
    Future<dynamic> dashboard(MethodCall c) async {
      calls.add('dashboard:${c.method}');
      return 'handled';
    }

    camera.addResultListener(dashboard);
    camera.addResultListener(search);
    await fromNative('photoTaken');
    expect(calls, ['search:photoTaken']);

    // Leaving Search hands results back to the dashboard.
    camera.removeResultListener(search);
    expect(await fromNative('barcodeScanned', '123'), 'handled');
    expect(calls, ['search:photoTaken', 'dashboard:barcodeScanned']);

    camera.removeResultListener(dashboard);
  });

  test('adding a listener again moves it to the top', () async {
    final camera = CameraService();
    final calls = <String>[];
    Future<dynamic> a(MethodCall c) async => calls.add('a');
    Future<dynamic> b(MethodCall c) async => calls.add('b');

    camera
      ..addResultListener(a)
      ..addResultListener(b)
      ..addResultListener(a);
    await fromNative('photoTaken');
    camera.removeResultListener(a);
    await fromNative('photoTaken');
    expect(calls, ['a', 'b']);
    camera.removeResultListener(b);
  });

  test('results with no screen listening are ignored safely', () async {
    Future<dynamic> gone(MethodCall c) async => fail('removed listener called');
    CameraService()
      ..addResultListener(gone)
      ..removeResultListener(gone);
    expect(await fromNative('photoTaken'), isNull);
  });
}
