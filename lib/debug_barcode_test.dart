import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/camera/flutter_camera_screen.dart';
import 'widgets/camera/camera_controls.dart';

class DebugBarcodeTest extends StatefulWidget {
  const DebugBarcodeTest({super.key});

  @override
  State<DebugBarcodeTest> createState() => _DebugBarcodeTestState();
}

class _DebugBarcodeTestState extends State<DebugBarcodeTest> {
  String _lastResult = 'No result yet';
  int _attemptCount = 0;
  List<String> _detectionLog = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Barcode Test'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Barcode Detection Debug Tool',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Attempts: $_attemptCount'),
                    const SizedBox(height: 8),
                    Text('Last Result: $_lastResult'),
                    const SizedBox(height: 8),
                    Text('Detection Log: ${_detectionLog.length} entries'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _testBarcodeDetection,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Test Barcode Detection'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _clearLog,
              icon: const Icon(Icons.clear),
              label: const Text('Clear Log'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Detection Log:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _detectionLog.length,
                          itemBuilder: (context, index) {
                            return Text(
                              '${index + 1}. ${_detectionLog[index]}',
                              style: const TextStyle(fontSize: 12),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testBarcodeDetection() async {
    setState(() {
      _attemptCount++;
    });

    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    _addToLog('[$timestamp] Attempt $_attemptCount: Opening camera');

    try {
      HapticFeedback.lightImpact();

      final result = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => const FlutterCameraScreen(
            initialMode: CameraMode.barcode,
          ),
        ),
      );

      final resultTimestamp =
          DateTime.now().toIso8601String().substring(11, 19);

      if (result != null) {
        final type = result['type'] as String;
        final value = result['value'] as String;

        setState(() {
          _lastResult = '$type: $value';
        });

        _addToLog('[$resultTimestamp] SUCCESS: $type detected - $value');

        // Show success dialog
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Detection Success!'),
              content: Text('Detected: $value\nType: $type'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      } else {
        setState(() {
          _lastResult = 'No result (user cancelled or error)';
        });
        _addToLog(
            '[$resultTimestamp] NO RESULT: User cancelled or error occurred');
      }
    } catch (e) {
      final errorTimestamp = DateTime.now().toIso8601String().substring(11, 19);
      setState(() {
        _lastResult = 'Error: $e';
      });
      _addToLog('[$errorTimestamp] ERROR: $e');
    }
  }

  void _addToLog(String message) {
    setState(() {
      _detectionLog.insert(0, message);
      // Keep only last 20 entries
      if (_detectionLog.length > 20) {
        _detectionLog = _detectionLog.take(20).toList();
      }
    });

    // Also print to console for debugging
    print('DebugBarcodeTest: $message');
  }

  void _clearLog() {
    setState(() {
      _detectionLog.clear();
      _attemptCount = 0;
      _lastResult = 'No result yet';
    });
  }
}
