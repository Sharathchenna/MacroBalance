import 'package:flutter/services.dart';

class StatsService {
  static const platform = MethodChannel('app.macrobalance.com/stats');

  Future<void> showStats({String? initialSection}) async {
    try {
      await platform.invokeMethod(
          'showStats', {'initialSection': initialSection ?? 'weight'});
    } catch (e) {
      print('Error showing stats: $e');
      rethrow;
    }
  }

  Future<List<double>> getWeightData() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getWeightData');
      return result.map((e) => e as double).toList();
    } catch (e) {
      print('Error getting weight data: $e');
      return [];
    }
  }

  Future<List<int>> getStepData() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getStepData');
      return result.map((e) => e as int).toList();
    } catch (e) {
      print('Error getting step data: $e');
      return [];
    }
  }

  Future<List<double>> getCalorieData() async {
    try {
      final List<dynamic> result =
          await platform.invokeMethod('getCalorieData');
      return result.map((e) => e as double).toList();
    } catch (e) {
      print('Error getting calorie data: $e');
      return [];
    }
  }

  Future<Map<String, double>> getMacroData() async {
    try {
      final List<dynamic> result = await platform.invokeMethod('getMacroData');
      final Map<String, double> macroData = {};
      for (final item in result) {
        if (item is Map) {
          final entry = item.entries.first;
          macroData[entry.key] = entry.value;
        }
      }
      return macroData;
    } catch (e) {
      print('Error getting macro data: $e');
      return {};
    }
  }
}
