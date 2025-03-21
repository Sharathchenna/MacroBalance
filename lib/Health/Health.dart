// ignore_for_file: file_names, avoid_print

import 'package:health/health.dart';
import 'package:intl/intl.dart';

class HealthService {
  final health = Health();

  // Add all required health data types
  static final _healthTypes = [
    HealthDataType.STEPS,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.BASAL_ENERGY_BURNED,
    HealthDataType.HEIGHT,
    HealthDataType.WEIGHT,
  ];

  // New method to request permissions
  Future<bool> requestPermissions() async {
    try {
      final granted = await health.requestAuthorization(_healthTypes);
      return granted;
    } catch (e) {
      print('Error requesting health permissions: $e');
      return false;
    }
  }

  Future<int> getSteps() async {
    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);

      final hasPermissions =
          await health.hasPermissions([HealthDataType.STEPS]);

      if (hasPermissions == null || !hasPermissions) {
        final granted = await requestPermissions();
        if (!granted) {
          throw Exception('Health data access not authorized');
        }
      }

      final steps = await health.getTotalStepsInInterval(midnight, now);
      return steps?.toInt() ?? 0;
    } catch (error) {
      print('Error fetching steps: $error');
      return 0;
    }
  }

  // New method to get steps for a specific date range
  Future<int> getStepsForDateRange(DateTime startDate, DateTime endDate) async {
    try {
      final hasPermissions =
          await health.hasPermissions([HealthDataType.STEPS]);

      if (hasPermissions == null || !hasPermissions) {
        final granted = await requestPermissions();
        if (!granted) {
          throw Exception('Health data access not authorized');
        }
      }

      final stepsData = await health.getHealthDataFromTypes(
        startTime: startDate,
        endTime: endDate,
        types: [HealthDataType.STEPS],
      );

      int totalSteps = 0;

      // Sum up all step entries for the date range
      for (var dataPoint in stepsData) {
        if (dataPoint.value is NumericHealthValue) {
          totalSteps +=
              (dataPoint.value as NumericHealthValue).numericValue.toInt();
        } else if (dataPoint.value is int) {
          totalSteps += dataPoint.value as int;
        } else if (dataPoint.value is double) {
          totalSteps += (dataPoint.value as double).toInt();
        }
      }

      return totalSteps;
    } catch (error) {
      print('Error fetching steps for date range: $error');
      return 0;
    }
  }

  // Enhanced method to get steps for the last 7 days
  Future<List<Map<String, dynamic>>> getStepsForLastWeek() async {
    final List<Map<String, dynamic>> result = [];
    final now = DateTime.now();

    try {
      final hasPermissions =
          await health.hasPermissions([HealthDataType.STEPS]);

      if (hasPermissions == null || !hasPermissions) {
        final granted = await requestPermissions();
        if (!granted) {
          throw Exception('Health data access not authorized');
        }
      }

      // Fetch steps for each of the last 7 days
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

        int steps = 0;

        // Special case for today - use getTotalStepsInInterval for more accurate data
        if (i == 0) {
          final todaySteps =
              await health.getTotalStepsInInterval(startOfDay, now);
          steps = todaySteps?.toInt() ?? 0;
        } else {
          // For previous days, use the standard approach
          final stepsData = await health.getHealthDataFromTypes(
            startTime: startOfDay,
            endTime: endOfDay,
            types: [HealthDataType.STEPS],
          );

          // Sum up all steps for the day
          for (var dataPoint in stepsData) {
            if (dataPoint.value is NumericHealthValue) {
              steps +=
                  (dataPoint.value as NumericHealthValue).numericValue.toInt();
            } else if (dataPoint.value is int) {
              steps += dataPoint.value as int;
            } else if (dataPoint.value is double) {
              steps += (dataPoint.value as double).toInt();
            }
          }
        }

        result.add({
          'date': startOfDay.toIso8601String(), // Convert to ISO8601
          'steps': steps,
          'goal':
              9000 // Using default goal, you might want to make this dynamic
        });
      }
      return result;
    } catch (error) {
      print('Error fetching steps for the week: $error');
      return [];
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

  Future<int> getStepsForDate(DateTime date) async {
    try {
      // Set the time to start of day and end of day for the given date
      final startTime = DateTime(date.year, date.month, date.day);
      final endTime = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final steps = await health.getTotalStepsInInterval(startTime, endTime);
      return steps ?? 0;
    } catch (e) {
      print('Error getting steps for date: $e');
      return 0;
    }
  }

  Future<double> getCaloriesForDate(DateTime date) async {
    try {
      // Set the time to start of day and end of day for the given date
      final startTime = DateTime(date.year, date.month, date.day);
      final endTime = DateTime(date.year, date.month, date.day, 23, 59, 59);

      // Use getHealthDataFromTypes to get active energy burned data
      List<HealthDataPoint> healthData = await health.getHealthDataFromTypes(
          types: [
            HealthDataType.ACTIVE_ENERGY_BURNED,
            HealthDataType.BASAL_ENERGY_BURNED
          ],
          startTime: startTime,
          endTime: endTime).catchError((error) {
        print('Error fetching health data: $error');
        return [];
      });

      double totalCalories = 0;
      // Sum up all active energy burned values
      for (HealthDataPoint point in healthData) {
        if (point.type == HealthDataType.ACTIVE_ENERGY_BURNED) {
          if (point.value is NumericHealthValue) {
            totalCalories += (point.value as NumericHealthValue).numericValue;
          } else if (point.value is double) {
            totalCalories += point.value as double;
          } else if (point.value is int) {
            totalCalories += (point.value as int).toDouble();
          }
        }
      }

      return totalCalories;
    } catch (e) {
      print('Error getting calories for date: $e');
      return 0.0;
    }
  }
}
