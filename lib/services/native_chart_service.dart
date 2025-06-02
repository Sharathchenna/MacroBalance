import 'package:flutter/material.dart';

class NativeChartService {
  // Weight chart
  static Future<Widget> createWeightChart(
      List<Map<String, dynamic>> data) async {
    debugPrint('[NativeChartService] Native charts have been removed, using fallback');
    return _createFallbackChart('Weight Chart');
  }

  // Steps chart
  static Future<Widget> createStepsChart(
      List<Map<String, dynamic>> data) async {
    debugPrint('[NativeChartService] Native charts have been removed, using fallback');
    return _createFallbackChart('Steps Chart');
  }

  // Calories chart
  static Future<Widget> createCaloriesChart(
      List<Map<String, dynamic>> data) async {
    debugPrint('[NativeChartService] Native charts have been removed, using fallback');
    return _createFallbackChart('Calories Chart');
  }

  // Macros chart
  static Future<Widget> createMacrosChart(
      List<Map<String, dynamic>> data) async {
    debugPrint('[NativeChartService] Native charts have been removed, using fallback');
    return _createFallbackChart('Macros Chart');
  }
  
  // Fallback chart widget
  static Widget _createFallbackChart(String chartName) {
    return Container(
      height: 300,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.withAlpha(((0.1) * 255).round()),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha(((0.2) * 255).round())),
      ),
      child: Center(
        child: Text(
          'Native $chartName functionality removed',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }
}
