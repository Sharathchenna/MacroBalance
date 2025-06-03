import 'package:flutter/material.dart';
import 'package:macrotracker/camera/barcode_results.dart';

class TestBarcodeNavigation extends StatelessWidget {
  const TestBarcodeNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Barcode Navigation'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                print(
                    'TEST: Testing navigation to BarcodeResults with test barcode');
                try {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) {
                      print('TEST: Building BarcodeResults widget');
                      return const BarcodeResults(
                          barcode: '33613666'); // Oreo cookies barcode
                    }),
                  ).then((value) {
                    print('TEST: Navigation completed successfully');
                  }).catchError((error) {
                    print('TEST: Navigation failed with error: $error');
                  });
                } catch (e) {
                  print('TEST: Exception during navigation: $e');
                }
              },
              child: const Text('Test Known Product (Oreo)'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                print(
                    'TEST: Testing navigation to BarcodeResults with invalid barcode');
                try {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) {
                      print(
                          'TEST: Building BarcodeResults widget with invalid barcode');
                      return const BarcodeResults(
                          barcode: '1234567890123'); // Invalid barcode
                    }),
                  ).then((value) {
                    print('TEST: Navigation completed successfully');
                  }).catchError((error) {
                    print('TEST: Navigation failed with error: $error');
                  });
                } catch (e) {
                  print('TEST: Exception during navigation: $e');
                }
              },
              child: const Text('Test Invalid Product'),
            ),
            const SizedBox(height: 40),
            const Text(
              'Use these buttons to test if navigation to BarcodeResults works.\nCheck the console for debug logs.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
