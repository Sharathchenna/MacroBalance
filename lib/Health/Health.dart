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

  Future<String> getHeightandWeight() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // Request authorization for height and weight.
      final accessWasGranted = await health.requestAuthorization(
        [
          HealthDataType.HEIGHT,
          HealthDataType.WEIGHT,
        ],
      );

      if (!accessWasGranted) {
        throw Exception('Authorization not granted');
      }

      // Fetch height and weight data.
      final heightData = await health.getHealthDataFromTypes(
        types: [HealthDataType.HEIGHT],
        startTime: midnight,
        endTime: now,
      );

      final weightData = await health.getHealthDataFromTypes(
        types: [HealthDataType.WEIGHT],
        startTime: midnight,
        endTime: now,
      );

      double? heightValue;
      double? weightValue;

      // Process the height data: Use the most recent entry.
      if (heightData.isNotEmpty) {
        final lastHeight = heightData.last;
        if (lastHeight.value is num) {
          heightValue = (lastHeight.value as num).toDouble();
        }
      }

      // Process the weight data: Use the most recent entry.
      if (weightData.isNotEmpty) {
        final lastWeight = weightData.last;
        if (lastWeight.value is num) {
          weightValue = (lastWeight.value as num).toDouble();
        }
      }

      if (heightValue != null && weightValue != null) {
        // Adjust units if needed; here we're assuming height is in centimeters and weight in kilograms.
        return "Height: ${heightValue.toStringAsFixed(1)} cm, Weight: ${weightValue.toStringAsFixed(1)} kg";
      } else {
        return "Height or weight data not available";
      }
    } catch (error) {
      print('Error fetching height and weight: $error');
      return "Error";
    }
  }

  Future<double> getCalories() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      // Request authorization for calories
      final accessWasGranted = await health.requestAuthorization([
        HealthDataType.ACTIVE_ENERGY_BURNED,
        HealthDataType.BASAL_ENERGY_BURNED
      ]);

      if (!accessWasGranted) {
        throw Exception('Authorization not granted');
      }

      // Get active calories
      final activeCalories = await health.getHealthDataFromTypes(
          types: [HealthDataType.ACTIVE_ENERGY_BURNED],
          startTime: midnight,
          endTime: now);

      // Get basal (resting) calories
      final basalCalories = await health.getHealthDataFromTypes(
          types: [HealthDataType.BASAL_ENERGY_BURNED],
          startTime: midnight,
          endTime: now);

      // Calculate total calories
      double totalCalories = 0;

      for (var data in activeCalories) {
        if (data.value is NumericHealthValue) {
          totalCalories += (data.value as NumericHealthValue).numericValue;
        }
      }

      for (var data in basalCalories) {
        if (data.value is NumericHealthValue) {
          totalCalories += (data.value as NumericHealthValue).numericValue;
        }
      }

      return totalCalories;
    } catch (error) {
      print('Error fetching calories: $error');
      return 0;
    }
  }
}
