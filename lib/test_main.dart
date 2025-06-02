import 'package:flutter/material.dart';
import 'test_flutter_camera.dart';

void main() {
  runApp(const TestCameraApp());
}

class TestCameraApp extends StatelessWidget {
  const TestCameraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Camera Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const TestFlutterCameraScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
