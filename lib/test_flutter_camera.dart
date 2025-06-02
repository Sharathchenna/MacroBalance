import 'dart:io';
import 'package:flutter/material.dart';
import 'services/camera_service.dart';
import 'widgets/camera/camera_controls.dart';

class TestFlutterCameraScreen extends StatefulWidget {
  const TestFlutterCameraScreen({super.key});

  @override
  State<TestFlutterCameraScreen> createState() =>
      _TestFlutterCameraScreenState();
}

class _TestFlutterCameraScreenState extends State<TestFlutterCameraScreen> {
  final CameraService _cameraService = CameraService();
  String _result = 'No result yet';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Camera Test'),
        backgroundColor: const Color(0xFFEDC953), // Premium gold
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Flutter Camera Implementation Test',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Platform.isAndroid
                    ? Colors.green.shade100
                    : Colors.blue.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Platform.isAndroid
                      ? Colors.green.shade300
                      : Colors.blue.shade300,
                ),
              ),
              child: Text(
                'Barcode Detection: ${Platform.isAndroid ? "Google ML Kit" : "iOS Native Vision"}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Platform.isAndroid
                      ? Colors.green.shade700
                      : Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(height: 40),

            // Test buttons for different modes
            _buildTestButton(
              'Test Barcode Scanner',
              CameraMode.barcode,
              Icons.qr_code_scanner,
              const Color(0xFF47B9D1),
            ),
            const SizedBox(height: 16),

            _buildTestButton(
              'Test Camera',
              CameraMode.camera,
              Icons.camera_alt,
              const Color(0xFFEDC953),
            ),
            const SizedBox(height: 16),

            _buildTestButton(
              'Test Label Scanner',
              CameraMode.label,
              Icons.text_fields,
              const Color(0xFF6366F1),
            ),

            const SizedBox(height: 40),

            // Result display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Result:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _result,
                    style: TextStyle(
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Info display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF47B9D1).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF47B9D1).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.flutter_dash,
                    color: Color(0xFF47B9D1),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Using Flutter Camera Implementation',
                    style: TextStyle(
                      color: Color(0xFF47B9D1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTestButton(
      String title, CameraMode mode, IconData icon, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: () => _testCamera(mode),
        icon: Icon(icon, size: 24),
        label: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
      ),
    );
  }

  Future<void> _testCamera(CameraMode mode) async {
    try {
      final result = await _cameraService.showCamera(
        initialMode: mode,
        context: context,
      );

      setState(() {
        if (result != null) {
          _result = '''
Mode: ${result['mode']}
Type: ${result['type']}
Value: ${_formatValue(result['value'])}
          ''';
        } else {
          _result = 'Camera was cancelled or no result returned';
        }
      });
    } catch (e) {
      setState(() {
        _result = 'Error: $e';
      });
    }
  }

  String _formatValue(dynamic value) {
    if (value is String) {
      return value;
    } else if (value is List<int>) {
      return 'Image data: ${value.length} bytes';
    } else if (value is List) {
      return 'Food items: ${value.length} items';
    } else {
      return value.toString();
    }
  }
}
