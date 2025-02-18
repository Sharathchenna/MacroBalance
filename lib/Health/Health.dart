import 'package:health/health.dart';

class HealthService {
  final health = Health();

  Future<int> getSteps() async {
    try {
      // Get everything from midnight until now
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // Define the types to get
      final types = [HealthDataType.STEPS];

      // Request authorization
      final accessWasGranted = await health.requestAuthorization(types);

      if (!accessWasGranted) {
        throw Exception('Authorization not granted');
      }

      // Fetch steps from local device
      final steps = await health.getTotalStepsInInterval(midnight, now);

      return steps?.toInt() ?? 0;
    } catch (error) {
      print('Error fetching steps: $error');
      return 0;
    }
  }

  // Method to check if health data is available
  Future<bool> isHealthDataAvailable() async {
    try {
      return await health.hasPermissions([HealthDataType.STEPS]) ?? false;
    } catch (e) {
      print('Error checking health data availability: $e');
      return false;
    }
  }
}
