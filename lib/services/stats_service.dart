import 'package:flutter/services.dart';

class StatsService {
  static const _channel = MethodChannel('com.macrobalance.app.stats');

  Future<void> showStats() async {
    try {
      await _channel.invokeMethod('showStats');
    } catch (e) {
      print('Error showing stats view: $e');
      rethrow;
    }
  }
}
