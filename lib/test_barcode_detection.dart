import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/camera_service.dart';
import 'widgets/camera/camera_controls.dart';
import 'camera/barcode_results.dart';

class TestBarcodeDetection extends StatefulWidget {
  const TestBarcodeDetection({super.key});

  @override
  State<TestBarcodeDetection> createState() => _TestBarcodeDetectionState();
}

class _TestBarcodeDetectionState extends State<TestBarcodeDetection> {
  final CameraService _cameraService = CameraService();
  String _lastResult = '';
  int _detectionCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Detection Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Test Barcode Detection',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Detection stats
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Detection Count: $_detectionCount'),
                    const SizedBox(height: 8),
                    Text('Last Result: $_lastResult'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Test buttons
            ElevatedButton(
              onPressed: _testBarcodeCamera,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text('Open Barcode Camera'),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _testManualBarcode,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text('Test Manual Barcode (12345)'),
            ),

            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _resetTest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
              child: const Text('Reset Test'),
            ),

            const SizedBox(height: 20),

            const Text(
              'Instructions:\n'
              '1. Tap "Open Barcode Camera" to test the camera\n'
              '2. Point camera at a barcode and wait for detection\n'
              '3. Check the detection count and last result\n'
              '4. Use "Test Manual Barcode" to test navigation\n'
              '5. Check console logs for detailed debugging info',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testBarcodeCamera() async {
    try {
      HapticFeedback.lightImpact();
      print('TEST: Opening barcode camera...');

      final result = await _cameraService.showCamera(
        context: context,
        initialMode: CameraMode.barcode,
      );

      print('TEST: Camera result: $result');

      if (result != null && mounted) {
        final String type = result['type'] as String;
        print('TEST: Result type: $type');

        if (type == 'barcode') {
          final String barcode = result['value'] as String;
          print('TEST: Barcode detected: $barcode');

          setState(() {
            _lastResult = barcode;
            _detectionCount++;
          });

          // Navigate to barcode results
          _navigateToBarcodeResults(barcode);
        } else {
          print('TEST: Non-barcode result received');
        }
      } else {
        print('TEST: No result or widget not mounted');
      }
    } catch (e) {
      print('TEST: Error testing barcode camera: $e');
      _showErrorSnackbar('Error: $e');
    }
  }

  Future<void> _testManualBarcode() async {
    try {
      HapticFeedback.lightImpact();
      print('TEST: Testing manual barcode navigation');

      const testBarcode = '12345678901234';
      setState(() {
        _lastResult = '$testBarcode (manual test)';
        _detectionCount++;
      });

      _navigateToBarcodeResults(testBarcode);
    } catch (e) {
      print('TEST: Error in manual test: $e');
      _showErrorSnackbar('Error: $e');
    }
  }

  void _navigateToBarcodeResults(String barcode) {
    try {
      print('TEST: Navigating to BarcodeResults with: $barcode');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BarcodeResults(barcode: barcode),
        ),
      ).then((value) {
        print('TEST: Returned from BarcodeResults');
      }).catchError((error) {
        print('TEST: Navigation error: $error');
        _showErrorSnackbar('Navigation error: $error');
      });
    } catch (e) {
      print('TEST: Error navigating to results: $e');
      _showErrorSnackbar('Navigation error: $e');
    }
  }

  void _resetTest() {
    HapticFeedback.lightImpact();
    setState(() {
      _lastResult = '';
      _detectionCount = 0;
    });
    print('TEST: Test data reset');
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
