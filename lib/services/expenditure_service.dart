// import 'dart:convert';
// import 'dart:math';

// import 'package:collection/collection.dart'; // For average calculation
// import 'package:intl/intl.dart'; // Added for DateFormat
// import 'package:macrotracker/models/foodEntry.dart';
// import 'package:macrotracker/models/food.dart' as fatsecret_food; // Use prefix for FoodItem from food.dart
// import '../Health/Health.dart'; // Corrected import path
// import 'package:macrotracker/services/storage_service.dart';
// // import 'package:macrotracker/services/supabase_service.dart'; // Might need later if local cache is insufficient

// // Moved _DailyData class to top level
// class _DailyData {
//   final DateTime date;
//   double? weight;
//   double? calories;
//   _DailyData(this.date, {this.weight, this.calories});
// }

// class ExpenditureService {
//   final HealthService _healthService = HealthService();
//   final StorageService _storageService = StorageService();
//   // final SupabaseService _supabaseService = SupabaseService(); // Instantiate if needed

//   // --- Configuration ---
//   final int _lookbackDays = 28; // How many days of data to consider
//   final int _smoothingWindow = 7; // Days for moving average on weight
//   final double _caloriesPerKg = 7700; // Approx calories in 1kg of body weight (3500 kcal/lb * 2.20462 lb/kg)
//   final int _minDaysForCalculation = 7; // Minimum days of data needed in the lookback period
//   final int _maxMissingNutritionDaysInWeek = 3; // Max missing nutrition days allowed per 7-day rolling window


//   // --- Core Calculation Method ---
//   Future<double?> calculateCurrentExpenditure() async {
//     final endDate = DateTime.now();
//     final startDate = endDate.subtract(Duration(days: _lookbackDays - 1));

//     // 1. Fetch Data (Using Dummy Data Methods)
//     final weightData = await _fetchWeightData(startDate, endDate);
//     final calorieData = await _fetchCalorieData(startDate, endDate);

//     // 2. Combine and Prepare Data
//     final dailyDataMap = _combineData(weightData, calorieData, startDate, endDate);

//     // 3. Check Data Sufficiency and Missing Data Tolerance
//     if (!_hasSufficientData(dailyDataMap)) {
//       print("Expenditure Calculation: Insufficient data points.");
//       return null; // Not enough data
//     }
//     if (!_meetsMissingNutritionTolerance(dailyDataMap)) {
//        print("Expenditure Calculation: Too much missing nutrition data.");
//        return null; // Too much missing nutrition data
//     }


//     // 4. Smooth Weight Data
//     final smoothedWeightData = _smoothWeightData(dailyDataMap);

//     // 5. Calculate Rate of Weight Change
//     final weeklyWeightChangeKg = _calculateWeeklyWeightChange(smoothedWeightData);
//     if (weeklyWeightChangeKg == null) {
//       print("Expenditure Calculation: Could not determine weight trend.");
//       return null; // Cannot determine trend
//     }

//     // 6. Calculate Average Calorie Intake
//     final averageCalories = _calculateAverageCalories(dailyDataMap);
//     if (averageCalories == null) {
//       print("Expenditure Calculation: Could not determine average calorie intake.");
//       return null; // Cannot determine average intake
//     }

//     // 7. Calculate Expenditure
//     // Expenditure = Avg Intake - (Weekly Weight Change * Calories per Unit Weight / Days in Week)
//     final expenditure = averageCalories - (weeklyWeightChangeKg * _caloriesPerKg / 7.0);

//     print("Expenditure Calculation:");
//     print("  - Avg Calories: ${averageCalories.toStringAsFixed(0)}");
//     print("  - Weekly Weight Change: ${weeklyWeightChangeKg.toStringAsFixed(2)} kg");
//     print("  - Calculated Expenditure: ${expenditure.toStringAsFixed(0)}");

//     // Basic sanity check
//     if (expenditure <= 0 || expenditure.isNaN || expenditure.isInfinite) {
//        print("Expenditure Calculation: Result is invalid ($expenditure).");
//        return null;
//     }

//     return expenditure;
//   }

//   // --- Helper Methods ---

//   // --- DUMMY DATA IMPLEMENTATION ---
//   Future<List<Map<String, dynamic>>> _fetchWeightData(DateTime start, DateTime end) async {
//     print("--- USING DUMMY WEIGHT DATA ---");
//     List<Map<String, dynamic>> dummyWeight = [];
//     final random = Random();
//     double currentWeight = 75.0; // Starting weight in kg
//     final days = end.difference(start).inDays + 1;

//     for (int i = 0; i < days; i++) {
//       final date = start.add(Duration(days: i));
//       // Simulate slight downward trend with daily noise
//       currentWeight -= (random.nextDouble() * 0.05); // Trend
//       double noise = (random.nextDouble() - 0.5) * 0.4; // Noise up to +/- 0.2 kg
//       dummyWeight.add({
//         'date': date,
//         'weight': (currentWeight + noise).clamp(70.0, 80.0), // Clamp within a range
//       });
//     }
//     // Simulate a couple of missing days
//     if (dummyWeight.length > 5) dummyWeight.removeAt(dummyWeight.length - 3);
//     if (dummyWeight.length > 10) dummyWeight.removeAt(dummyWeight.length - 8);

//     return dummyWeight;
//     // --- END DUMMY DATA ---

//     // Original implementation (commented out):
//     // return await _healthService.getWeightDataForDateRange(start, end);
//   }

//   Future<Map<DateTime, double>> _fetchCalorieData(DateTime start, DateTime end) async {
//      print("--- USING DUMMY CALORIE DATA ---");
//      Map<DateTime, double> dummyCalories = {};
//      final random = Random();
//      final days = end.difference(start).inDays + 1;

//      for (int i = 0; i < days; i++) {
//        final date = DateTime(start.year, start.month, start.day).add(Duration(days: i)); // Use dayKey format
//        // Simulate intake around 2300 kcal with noise
//        dummyCalories[date] = (2300 + (random.nextDouble() - 0.5) * 400).clamp(1800.0, 2800.0);
//      }
//      // Simulate a few missing days (different from weight)
//      final sortedDates = dummyCalories.keys.toList()..sort();
//      if (sortedDates.length > 4) dummyCalories.remove(sortedDates[sortedDates.length - 2]);
//      if (sortedDates.length > 9) dummyCalories.remove(sortedDates[sortedDates.length - 5]);
//      if (sortedDates.length > 15) dummyCalories.remove(sortedDates[sortedDates.length - 11]);

//      return dummyCalories;
//      // --- END DUMMY DATA ---

//     // Original implementation (commented out):
//     /*
//     final entriesJson = _storageService.get('food_entries');
//     if (entriesJson == null || entriesJson.isEmpty || entriesJson is! String) {
//       // TODO: Optionally try fetching from Supabase if local cache is empty/stale
//       print("Expenditure Calculation: No local food entries found.");
//       return {};
//     }

//     List<dynamic> localEntriesRaw;
//     try {
//       localEntriesRaw = json.decode(entriesJson) as List<dynamic>;
//     } catch (e) {
//       print("Expenditure Calculation: Error decoding local food entries: $e");
//       _storageService.delete('food_entries'); // Clear corrupted data
//       return {};
//     }

//     final Map<DateTime, double> dailyCalories = {};

//     for (var entryRaw in localEntriesRaw) {
//       if (entryRaw is Map<String, dynamic>) {
//         try {
//           // Assuming stored data matches FoodEntry.toJson() structure
//           final foodData = entryRaw['food'];
//           if (foodData == null || foodData is! Map<String, dynamic>) {
//             print("Expenditure Calc: Skipping entry with invalid food data: $entryRaw");
//             continue;
//           }

//           final quantity = (entryRaw['quantity'] as num?)?.toDouble();
//           final unit = entryRaw['unit'] as String?;
//           final dateStr = entryRaw['date'] as String?;

//           // Extract base nutritional info from the nested food object
//           final baseCalories = (foodData['calories'] as num?)?.toDouble();
//           final baseServingSize = (foodData['servingSize'] as num?)?.toDouble() ?? 100.0; // Default to 100g if missing
//           // final baseServingUnit = foodData['servingUnit'] as String? ?? 'g'; // Assuming 'g' if missing

//           if (quantity == null || unit == null || dateStr == null || baseCalories == null) {
//              print("Expenditure Calc: Skipping entry with missing required fields: $entryRaw");
//              continue;
//           }

//           double entryCalories = 0;

//           // --- Calorie Calculation Logic ---
//           // Assumption: baseCalories are per baseServingSize (e.g., 100g)
//           // We need to scale based on the quantity and unit logged.
//           // This is still simplified - needs robust unit conversion (e.g., oz to g, serving to g)
//           // For now, assume logged unit is 'g' or directly corresponds to baseServingSize if not 'g'

//           if (unit.toLowerCase() == 'g' || unit.toLowerCase() == 'gram' || unit.toLowerCase() == 'grams') {
//              if (baseServingSize > 0) {
//                 entryCalories = (quantity / baseServingSize) * baseCalories;
//              }
//           } else {
//              // If unit is not 'g', assume quantity directly applies to the baseCalories
//              // (e.g., quantity=1, unit='serving', baseCalories is per serving)
//              // This is a major simplification and likely needs adjustment based on how
//              // serving sizes and units are actually handled during logging.
//              entryCalories = quantity * baseCalories;
//           }
//           // --- End Calorie Calculation Logic ---


//           if (entryCalories > 0) {
//             final dateTime = DateTime.tryParse(dateStr);
//             // Check if dateTime is valid and within the requested range
//             if (dateTime != null &&
//                 !dateTime.isBefore(start) &&
//                 !dateTime.isAfter(end.add(const Duration(days: 1)))) { // Ensure end date is inclusive
//               final dayKey = DateTime(dateTime.year, dateTime.month, dateTime.day);
//               dailyCalories[dayKey] = (dailyCalories[dayKey] ?? 0) + entryCalories;
//             }
//           }
//         // Moved the catch block to be associated with the outer try for the entry processing
//         } catch (e) {
//            print("Expenditure Calculation: Error processing food entry: $e, Entry: $entryRaw");
//         }
//       } // End if (entryRaw is Map<String, dynamic>)
//     } // End for loop
//     // Ensure the method always returns a map, even if empty
//     return dailyCalories;
//     */
//   }


//   Map<DateTime, _DailyData> _combineData(
//       List<Map<String, dynamic>> weightData,
//       Map<DateTime, double> calorieData,
//       DateTime startDate,
//       DateTime endDate)
//   {
//     final Map<DateTime, _DailyData> combinedData = {};
//     final days = endDate.difference(startDate).inDays + 1;

//     for (int i = 0; i < days; i++) {
//       final date = DateTime(startDate.year, startDate.month, startDate.day).add(Duration(days: i));
//       combinedData[date] = _DailyData(date);
//     }

//     // Add weight data
//     for (var wd in weightData) {
//       final date = wd['date'] as DateTime?;
//       final weight = wd['weight'] as double?;
//       if (date != null && weight != null) {
//          final dayKey = DateTime(date.year, date.month, date.day);
//          final dayData = combinedData[dayKey];
//          if (dayData != null) {
//             // Use the latest weight entry for the day if multiple exist
//             // Check if current entry's date is later than the date stored in _DailyData (if any)
//             // Note: HealthKit might return multiple entries for a day, we want the latest.
//             // We store the actual timestamp in _DailyData now for comparison.
//             if (dayData.weight == null || date.isAfter(dayData.date)) {
//                // Update weight and potentially the timestamp if this entry is later
//                dayData.weight = weight;
//                // We could update dayData.date = date here if we wanted the exact timestamp
//                // but keeping the dayKey's date is fine for grouping.
//             }
//          }
//       }
//     }

//     // Add calorie data
//     calorieData.forEach((dateKey, calories) {
//       // dateKey is already DateTime(year, month, day) from _fetchCalorieData
//       final dayData = combinedData[dateKey];
//       if (dayData != null) {
//         dayData.calories = calories;
//       }
//     });

//     return combinedData;
//   }

//    bool _hasSufficientData(Map<DateTime, _DailyData> dataMap) {
//     int weightDays = dataMap.values.where((d) => d.weight != null).length;
//     int calorieDays = dataMap.values.where((d) => d.calories != null).length;
//     // Need at least a minimum number of days with *both* weight and calories
//     int completeDays = dataMap.values.where((d) => d.weight != null && d.calories != null).length;
//     return completeDays >= _minDaysForCalculation;
//   }

//   bool _meetsMissingNutritionTolerance(Map<DateTime, _DailyData> dataMap) {
//     final sortedDates = dataMap.keys.toList()..sort();
//     if (sortedDates.length < 7) return true; // Not enough data for a full week check yet

//     for (int i = 0; i <= sortedDates.length - 7; i++) {
//       int missingCount = 0;
//       for (int j = 0; j < 7; j++) {
//         final date = sortedDates[i + j];
//         if (dataMap[date]?.calories == null) {
//           missingCount++;
//         }
//       }
//       if (missingCount > _maxMissingNutritionDaysInWeek) {
//         print("Expenditure Calculation: Failed missing data check for week starting ${sortedDates[i]}");
//         return false;
//       }
//     }
//     return true;
//   }


//   Map<DateTime, _DailyData> _smoothWeightData(Map<DateTime, _DailyData> dataMap) {
//     final smoothedData = Map<DateTime, _DailyData>.from(dataMap);
//     final sortedDates = dataMap.keys.toList()..sort();
//     final halfWindow = (_smoothingWindow / 2).floor();

//     // Fill missing weights using linear interpolation for smoothing purposes
//     List<double?> weights = sortedDates.map((date) => dataMap[date]?.weight).toList();
//     // Forward fill
//     for (int i = 1; i < weights.length; i++) {
//        weights[i] ??= weights[i-1];
//     }
//     // Backward fill
//     for (int i = weights.length - 2; i >= 0; i--) {
//        weights[i] ??= weights[i+1];
//     }

//     // Apply moving average
//     for (int i = 0; i < sortedDates.length; i++) {
//       final date = sortedDates[i];
//       final start = max(0, i - halfWindow);
//       final end = min(weights.length - 1, i + halfWindow);
//       final windowWeights = weights.sublist(start, end + 1).whereNotNull().toList();
//       final dayData = smoothedData[date];

//       if (dayData != null) {
//           if (windowWeights.isNotEmpty) {
//             dayData.weight = windowWeights.average;
//           } else {
//              dayData.weight = null; // Cannot smooth if window is all null
//           }
//       }
//     }

//     return smoothedData;
//   }

//   double? _calculateWeeklyWeightChange(Map<DateTime, _DailyData> smoothedData) {
//     final validEntries = smoothedData.entries
//         .where((entry) => entry.value.weight != null)
//         .toList()
//       ..sort((a, b) => a.key.compareTo(b.key)); // Sort by date

//     if (validEntries.length < 2) return null; // Need at least two points for a trend

//     // Simple linear regression: y = mx + c (weight = slope * day_number + intercept)
//     double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
//     int n = validEntries.length;
//     final firstDay = validEntries.first.key;

//     for (var entry in validEntries) {
//       final x = entry.key.difference(firstDay).inDays.toDouble(); // Day number as x
//       final y = entry.value.weight; // Smoothed weight as y (already checked for null)
//       if (y == null) continue; // Should not happen due to filtering, but safe check
//       sumX += x;
//       sumY += y;
//       sumXY += x * y;
//       sumX2 += x * x;
//     }

//     final denominator = n * sumX2 - sumX * sumX;
//     if (denominator.abs() < 1e-6) return null; // Avoid division by zero (vertical line)

//     final slope = (n * sumXY - sumX * sumY) / denominator; // Change in weight per day

//     return slope * 7.0; // Convert daily change to weekly change
//   }

//   double? _calculateAverageCalories(Map<DateTime, _DailyData> dataMap) {
//      final validCalories = dataMap.values
//         .map((d) => d.calories)
//         .whereNotNull() // Filter out nulls (missing days)
//         .toList();

//      if (validCalories.isEmpty) return null;

//      return validCalories.average;
//   }
// }
