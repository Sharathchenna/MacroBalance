import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // Added for WidgetsBinding
import 'package:macrotracker/services/expenditure_service.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart'; // Import FoodEntryProvider

class ExpenditureProvider with ChangeNotifier {
  final ExpenditureService _expenditureService = ExpenditureService();
  // Add reference to FoodEntryProvider
  final FoodEntryProvider _foodEntryProvider;

  double? _currentExpenditure;
  bool _isLoading = false;
  String? _error;

  // Modify constructor to accept FoodEntryProvider
  ExpenditureProvider(this._foodEntryProvider);

  double? get currentExpenditure => _currentExpenditure;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> updateExpenditure() async {
    if (_isLoading) return; // Prevent concurrent updates

    _isLoading = true;
    _error = null;
    // Notify listeners immediately about loading state change
    // Use WidgetsBinding to avoid issues during build phase if called from initState
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (hasListeners) { // Check if there are listeners before notifying
          notifyListeners();
       }
    });


    try {
      final calculatedTDEE = await _expenditureService.calculateCurrentExpenditure();

      if (calculatedTDEE != null) {
         _currentExpenditure = calculatedTDEE;
         print("ExpenditureProvider: Updated expenditure to ${_currentExpenditure?.toStringAsFixed(0)}");

         // --- Trigger goal recalculation ---
         // Ensure FoodEntryProvider is initialized before recalculating
         await _foodEntryProvider.ensureInitialized();
         await _foodEntryProvider.recalculateMacroGoals(_currentExpenditure!);
         // --- End trigger ---

      } else {
         // Handle cases where calculation couldn't complete (insufficient data, etc.)
         _error = "Could not calculate expenditure. Ensure sufficient weight and nutrition data is logged.";
         print("ExpenditureProvider: Calculation returned null.");
         _currentExpenditure = null; // Clear potentially stale value
      }

    } catch (e) {
      print("ExpenditureProvider: Error updating expenditure: $e");
      _error = "An error occurred while calculating expenditure.";
      _currentExpenditure = null; // Clear potentially stale value on error
    } finally {
      _isLoading = false;
      // Notify listeners again after calculation is complete (success or error)
       if (hasListeners) {
          notifyListeners();
       }
    }
  }

  // Optional: Method to clear expenditure data (e.g., on logout)
  void clearExpenditure() {
     _currentExpenditure = null;
     _error = null;
     _isLoading = false;
     notifyListeners();
  }
}
