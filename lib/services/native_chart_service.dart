import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;

class NativeChartService {
  static const MethodChannel _channel =
      MethodChannel('app.macrobalance.com/nativecharts');

  // Weight chart
  static Future<Widget> createWeightChart(
      List<Map<String, dynamic>> data) async {
    if (!Platform.isIOS) {
      throw PlatformException(
        code: 'UNAVAILABLE',
        message: 'Native charts are only available on iOS',
      );
    }

    try {
      debugPrint('[NativeChartService] Creating weight chart with data: $data');

      // Call method channel and expect "success" rather than data
      final result =
          await _channel.invokeMethod('createWeightChart', {'data': data});
      debugPrint(
          '[NativeChartService] Weight chart method channel result: $result');

      if (result != "success") {
        debugPrint(
            '[NativeChartService] Warning: Unexpected result from native side');
      }

      debugPrint('[NativeChartService] Creating UiKitView for weight chart');
      return SizedBox(
        height: 300,
        child: UiKitView(
          viewType: 'weightChart',
          creationParams: {
            'chartType': 'weight',
            'data': data,
          },
          creationParamsCodec: const StandardMessageCodec(),
          layoutDirection: TextDirection.ltr,
          onPlatformViewCreated: (int id) {
            debugPrint(
                '[NativeChartService] Weight chart view created with id: $id');
          },
        ),
      );
    } on PlatformException catch (e) {
      debugPrint(
          '[NativeChartService] Error creating weight chart: ${e.message}');
      rethrow;
    }
  }

  // Steps chart
  static Future<Widget> createStepsChart(
      List<Map<String, dynamic>> data) async {
    if (!Platform.isIOS) {
      throw PlatformException(
        code: 'UNAVAILABLE',
        message: 'Native charts are only available on iOS',
      );
    }

    try {
      debugPrint('[NativeChartService] Creating steps chart with data: $data');

      // Call method channel and expect "success" rather than data
      final result =
          await _channel.invokeMethod('createStepsChart', {'data': data});
      debugPrint(
          '[NativeChartService] Steps chart method channel result: $result');

      if (result != "success") {
        debugPrint(
            '[NativeChartService] Warning: Unexpected result from native side');
      }

      debugPrint('[NativeChartService] Creating UiKitView for steps chart');
      return SizedBox(
        height: 300,
        child: UiKitView(
          viewType: 'stepsChart',
          creationParams: {
            'chartType': 'steps',
            'data': data,
          },
          creationParamsCodec: const StandardMessageCodec(),
          layoutDirection: TextDirection.ltr,
          onPlatformViewCreated: (int id) {
            debugPrint(
                '[NativeChartService] Steps chart view created with id: $id');
          },
        ),
      );
    } on PlatformException catch (e) {
      debugPrint(
          '[NativeChartService] Error creating steps chart: ${e.message}');
      rethrow;
    }
  }

  // Calories chart
  static Future<Widget> createCaloriesChart(
      List<Map<String, dynamic>> data) async {
    if (!Platform.isIOS) {
      throw PlatformException(
        code: 'UNAVAILABLE',
        message: 'Native charts are only available on iOS',
      );
    }

    try {
      debugPrint(
          '[NativeChartService] Creating calories chart with data: $data');

      // Call method channel and expect "success" rather than data
      final result =
          await _channel.invokeMethod('createCaloriesChart', {'data': data});
      debugPrint(
          '[NativeChartService] Calories chart method channel result: $result');

      if (result != "success") {
        debugPrint(
            '[NativeChartService] Warning: Unexpected result from native side');
      }

      debugPrint('[NativeChartService] Creating UiKitView for calories chart');
      return Container(
        height: 300,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1), // Debug background
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: UiKitView(
            viewType: 'caloriesChart',
            creationParams: {
              'chartType': 'calories',
              'data': data,
            },
            creationParamsCodec: const StandardMessageCodec(),
            layoutDirection: TextDirection.ltr,
            onPlatformViewCreated: (int id) {
              debugPrint(
                  '[NativeChartService] Calories chart view created with id: $id');
            },
          ),
        ),
      );
    } on PlatformException catch (e) {
      debugPrint(
          '[NativeChartService] Error creating calories chart: ${e.message}');
      rethrow;
    }
  }

  // Macros chart
  static Future<Widget> createMacrosChart(
      List<Map<String, dynamic>> data) async {
    if (!Platform.isIOS) {
      throw PlatformException(
        code: 'UNAVAILABLE',
        message: 'Native charts are only available on iOS',
      );
    }

    try {
      debugPrint('[NativeChartService] Creating macros chart with data: $data');

      // Call method channel and expect "success" rather than data
      final result =
          await _channel.invokeMethod('createMacrosChart', {'data': data});
      debugPrint(
          '[NativeChartService] Macros chart method channel result: $result');

      if (result != "success") {
        debugPrint(
            '[NativeChartService] Warning: Unexpected result from native side');
      }

      debugPrint('[NativeChartService] Creating UiKitView for macros chart');
      return Container(
        height: 300,
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: UiKitView(
            viewType: 'macrosChart',
            creationParams: {
              'chartType': 'macros',
              'data': data,
            },
            creationParamsCodec: const StandardMessageCodec(),
            layoutDirection: TextDirection.ltr,
            onPlatformViewCreated: (int id) {
              debugPrint(
                  '[NativeChartService] Macros chart view created with id: $id');
            },
          ),
        ),
      );
    } on PlatformException catch (e) {
      debugPrint(
          '[NativeChartService] Error creating macros chart: ${e.message}');
      rethrow;
    }
  }
}
