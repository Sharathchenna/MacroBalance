// ignore_for_file: file_names, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/widgets/macro_progress_ring.dart';
import 'package:macrotracker/widgets/quantity_selector.dart';
import 'package:macrotracker/widgets/nutrient_row.dart';
import 'package:macrotracker/widgets/food_detail_components.dart';
import 'searchPage.dart'; // This has the FoodItem class we need
import 'package:provider/provider.dart';
import '../providers/foodEntryProvider.dart';
import '../models/foodEntry.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import '../theme/app_theme.dart';
import '../theme/typography.dart';
import 'dart:math'; // Add missing import for min function and pi constant

class FoodDetailPage extends StatefulWidget {
  final FoodItem food;
  final String? selectedMeal; // Add selectedMeal parameter

  const FoodDetailPage({
    super.key,
    required this.food,
    this.selectedMeal, // Make it optional
  });

  @override
  _FoodDetailPageState createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage>
    with SingleTickerProviderStateMixin {
  final List<String> mealOptions = ["Breakfast", "Lunch", "Snacks", "Dinner"];
  final List<String> unitOptions = ["g", "oz"];
  final List<double> presetMultipliers = [0.5, 1.0, 1.5, 2.0];

  late String selectedMeal; // Remove initialization
  String selectedUnit = "g";
  double selectedMultiplier = 1.0;
  late TextEditingController quantityController;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;
  Serving? selectedServing;

  final _scrollController = ScrollController();
  bool _showFloatingTitle = false;

  @override
  void initState() {
    super.initState();
    // Initialize selectedMeal with widget parameter or default to "Breakfast"
    selectedMeal = widget.selectedMeal ?? "Breakfast";

    if (widget.food.servings.isNotEmpty) {
      selectedServing = widget.food.servings.first;
      quantityController =
          TextEditingController(text: selectedServing!.metricAmount.toString());
    } else {
      quantityController =
          TextEditingController(text: widget.food.servingSize.toString());
    }

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _animationController.forward();

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.offset > 120 && !_showFloatingTitle) {
      setState(() {
        _showFloatingTitle = true;
      });
    } else if (_scrollController.offset <= 120 && _showFloatingTitle) {
      setState(() {
        _showFloatingTitle = false;
      });
    }
  }

  @override
  void dispose() {
    quantityController.dispose();
    _animationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  double getConvertedQuantity() {
    double qty = double.tryParse(quantityController.text) ?? 100;

    switch (selectedUnit) {
      case "oz":
        return qty * 28.35;
      case "g":
      default:
        return qty;
    }
  }

  String getNutrientValue(String nutrient) {
    if (selectedServing != null) {
      double multiplier = selectedMultiplier;

      // If custom quantity entered, calculate actual multiplier
      if (selectedMultiplier == 0) {
        double enteredQty = double.tryParse(quantityController.text) ?? 0;
        multiplier = enteredQty / selectedServing!.metricAmount;
      }

      double? value;
      switch (nutrient.toLowerCase()) {
        case "calories":
          value = selectedServing!.calories * multiplier;
          break;
        case "protein":
          value = (selectedServing!.nutrients['Protein'] ?? 0.0) * multiplier;
          break;
        case "carbohydrate":
          value = (selectedServing!.nutrients['Carbohydrate, by difference'] ??
                  0.0) *
              multiplier;
          break;
        case "fat":
          value = (selectedServing!.nutrients['Total lipid (fat)'] ?? 0.0) *
              multiplier;
          break;
      }

      if (value == null) return "0.0";
      return value.toStringAsFixed(1);
    } else {
      final convertedQty = getConvertedQuantity();

      double? value;
      switch (nutrient.toLowerCase()) {
        case "calories":
          value = widget.food.calories * (convertedQty / 100);
          break;
        case "protein":
          value =
              (widget.food.nutrients['Protein'] ?? 0.0) * (convertedQty / 100);
          break;
        case "carbohydrate":
          value =
              (widget.food.nutrients['Carbohydrate, by difference'] ?? 0.0) *
                  (convertedQty / 100);
          break;
        case "fat":
          value = (widget.food.nutrients['Total lipid (fat)'] ?? 0.0) *
              (convertedQty / 100);
          break;
      }

      if (value == null) return "0.0";
      return value.toStringAsFixed(1);
    }
  }

  Map<String, double> getMacroPercentages() {
    double carbs = double.tryParse(getNutrientValue("carbohydrate")) ?? 0;
    double protein = double.tryParse(getNutrientValue("protein")) ?? 0;
    double fat = double.tryParse(getNutrientValue("fat")) ?? 0;

    setState(() {});

    double total = carbs + protein + fat;
    if (total <= 0) return {"carbs": 0.33, "protein": 0.33, "fat": 0.34};

    return {
      "carbs": carbs / total,
      "protein": protein / total,
      "fat": fat / total,
    };
  }

  Map<String, String> getAdditionalNutrients() {
    Map<String, String> result = {};

    if (selectedServing != null) {
      double multiplier = selectedMultiplier;

      // If custom quantity entered, calculate actual multiplier
      if (selectedMultiplier == 0) {
        double enteredQty = double.tryParse(quantityController.text) ?? 0;
        multiplier = enteredQty / selectedServing!.metricAmount;
      }

      // Add main macros first
      result['Calories'] =
          '${(selectedServing!.calories * multiplier).toStringAsFixed(1)} kcal';
      result['Protein'] =
          '${((selectedServing!.nutrients['Protein'] ?? 0.0) * multiplier).toStringAsFixed(1)}g';
      result['Carbohydrates'] =
          '${((selectedServing!.nutrients['Carbohydrate, by difference'] ?? 0.0) * multiplier).toStringAsFixed(1)}g';
      result['Fat'] =
          '${((selectedServing!.nutrients['Total lipid (fat)'] ?? 0.0) * multiplier).toStringAsFixed(1)}g';

      // Add all other available nutrients
      selectedServing!.nutrients.forEach((key, value) {
        if (key != 'Protein' &&
            key != 'Carbohydrate, by difference' &&
            key != 'Total lipid (fat)') {
          String unit = 'g';
          if (key == 'Saturated fat' ||
              key == 'Polyunsaturated fat' ||
              key == 'Monounsaturated fat') {
            unit = 'g';
          } else if (key == 'Cholesterol' ||
              key == 'Sodium' ||
              key == 'Potassium') {
            unit = 'mg';
          } else if (key == 'Vitamin C' || key == 'Calcium' || key == 'Iron') {
            unit = 'mg';
          } else if (key == 'Fiber' || key == 'Sugar') {
            unit = 'g';
          } else if (key == 'Vitamin A') {
            unit = 'mcg';
          }

          result[key] = '${(value * multiplier).toStringAsFixed(1)}$unit';
        }
      });
    } else {
      final convertedQty = getConvertedQuantity();

      // Add main macros first
      result['Calories'] =
          '${(widget.food.calories * (convertedQty / 100)).toStringAsFixed(1)} kcal';
      result['Protein'] =
          '${((widget.food.nutrients['Protein'] ?? 0.0) * (convertedQty / 100)).toStringAsFixed(1)}g';
      result['Carbohydrates'] =
          '${((widget.food.nutrients['Carbohydrate, by difference'] ?? 0.0) * (convertedQty / 100)).toStringAsFixed(1)}g';
      result['Fat'] =
          '${((widget.food.nutrients['Total lipid (fat)'] ?? 0.0) * (convertedQty / 100)).toStringAsFixed(1)}g';

      // Add all other available nutrients
      widget.food.nutrients.forEach((key, value) {
        if (key != 'Protein' &&
            key != 'Carbohydrate, by difference' &&
            key != 'Total lipid (fat)') {
          String unit = 'g';
          if (key == 'Saturated fat' ||
              key == 'Polyunsaturated fat' ||
              key == 'Monounsaturated fat') {
            unit = 'g';
          } else if (key == 'Cholesterol' ||
              key == 'Sodium' ||
              key == 'Potassium') {
            unit = 'mg';
          } else if (key == 'Vitamin A' ||
              key == 'Vitamin C' ||
              key == 'Calcium' ||
              key == 'Iron') {
            unit = '%';
          } else if (key == 'Fiber' || key == 'Sugar') {
            unit = 'g';
          }

          result[key] =
              '${(value * (convertedQty / 100)).toStringAsFixed(1)}$unit';
        }
      });
    }

    return result;
  }

//   Color _getMealColor(String meal) {
//     switch (meal) {
//       case 'Breakfast':
// return const Color(0xFFFBBC05).withValues(alpha: 0.8);
//       case 'Lunch':
//         return const Color(0xFFFBBC05).withValues(alpha: 0.9);
//       case 'Dinner':
// return const Color(0xFFFBBC05).withValues(alpha: 0.9);
//       case 'Snacks':
// return const Color(0xFFFBBC05).withValues(alpha: 0.9);
//       default:
// return const Color(0xFFFBBC05).withValues(alpha: 0.9);
//     }
//   }

  void _addFoodEntry() async {
    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final entry = FoodEntry(
      id: const Uuid().v4(),
      food: widget.food,
      meal: selectedMeal,
      quantity: double.parse(quantityController.text),
      unit: selectedUnit,
      date: dateProvider.selectedDate,
      servingDescription: selectedServing?.description,
    );

    // Add entry to provider
    await foodEntryProvider.addEntry(entry);

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selectedServing != null
                    ? 'Added ${widget.food.name} (${selectedServing!.description}) to $selectedMeal'
                    : 'Added ${widget.food.name} to $selectedMeal',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFFFFC107).withValues(alpha: 0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    // Navigate back to Dashboard - replace this line
    // Navigator.pop(context);

    // With this - pop back to the first route in the stack (Dashboard)
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final food = widget.food;
    var macroPercentages = getMacroPercentages();
    final convertedQty = getConvertedQuantity();
    final caloriesPer100 = widget.food.calories;
    final calculatedCalories = caloriesPer100 * (convertedQty / 100);
    final additionalNutrients = getAdditionalNutrients();
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverAppBar(
                  expandedHeight: 160.0,
                  floating: false,
                  pinned: true,
                  stretch: true,
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  elevation: 0,
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Hero(
                      tag: 'backButton',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                          customBorder: const CircleBorder(),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: customColors!.cardBackground,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: customColors.textPrimary,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  title: AnimatedOpacity(
                    opacity: _showFloatingTitle ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      food.name,
                      style: TextStyle(
                        color: Theme.of(context)
                            .extension<CustomColors>()!
                            .textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.grey.withOpacity(0.2),
                            Theme.of(context).scaffoldBackgroundColor,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FadeTransition(
                                opacity: _fadeInAnimation,
                                child: SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 0.2),
                                    end: Offset.zero,
                                  ).animate(_animationController),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        food.name,
                                        style: AppTypography.h1.copyWith(
                                          color: Theme.of(context)
                                              .extension<CustomColors>()!
                                              .textPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      if (food.brandName.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          food.brandName,
                                          style: AppTypography.body1.copyWith(
                                            color: customColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _slideAnimation.value),
                        child: FadeTransition(
                          opacity: _fadeInAnimation,
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 24),
                            padding: const EdgeInsets.fromLTRB(
                                16, 24, 16, 40), // Increased bottom padding
                            decoration: BoxDecoration(
                              color: customColors.cardBackground,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      calculatedCalories.toStringAsFixed(0),
                                      style: AppTypography.h1.copyWith(
                                        color: Theme.of(context)
                                            .extension<CustomColors>()!
                                            .textPrimary,
                                        fontWeight: FontWeight.bold,
                                        height: 0.9,
                                        fontSize: 40, // Increased font size
                                      ),
                                    ),
                                    Text(
                                      " kcal",
                                      style: AppTypography.h3.copyWith(
                                        color: customColors.textSecondary,
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 36), // Increased spacing
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: SizedBox(
                                          height:
                                              140, // Increased height for larger rings
                                          child: MacroProgressRing(
                                            key: ValueKey(
                                                'carbs-${quantityController.text}-$selectedUnit'),
                                            label: 'Carbs',
                                            value: getNutrientValue(
                                                "carbohydrate"),
                                            color: const Color(
                                                0xFF4285F4), // Google blue
                                            percentage:
                                                macroPercentages["carbs"] ??
                                                    0.33,
                                            // Add larger font size for numbers
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: SizedBox(
                                          height:
                                              140, // Increased height for larger rings
                                          child: MacroProgressRing(
                                            key: ValueKey(
                                                'protein-${quantityController.text}-$selectedUnit}'),
                                            label: 'Protein',
                                            value: getNutrientValue("protein"),
                                            color: const Color(
                                                0xFFEA4335), // Google red
                                            percentage: macroPercentages[
                                                    "protein"] ??
                                                0.33, // Add larger font size for numbers
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4),
                                        child: SizedBox(
                                          height:
                                              140, // Increased height for larger rings
                                          child: MacroProgressRing(
                                            key: ValueKey(
                                                'fat-${quantityController.text}-$selectedUnit'),
                                            label: 'Fat',
                                            value: getNutrientValue("fat"),
                                            color: const Color(
                                                0xFFFBBC05), // Google yellow
                                            percentage:
                                                macroPercentages["fat"] ?? 0.34,
                                            // Add larger font size for numbers
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 4),
                            child: Text(
                              "Serving Size",
                              style: AppTypography.h2.copyWith(
                                color: Theme.of(context)
                                    .extension<CustomColors>()!
                                    .textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          if (widget.food.servings.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: customColors.cardBackground,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: customColors.textSecondary
                                              .withOpacity(0.15),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.restaurant_menu_rounded,
                                          color: customColors.textSecondary,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        "Select Serving",
                                        style: AppTypography.h3.copyWith(
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? Colors.white
                                              : primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  // Serving Selector Cards
                                  SizedBox(
                                    height: 160,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: widget.food.servings.length,
                                      separatorBuilder: (context, index) =>
                                          const SizedBox(width: 12),
                                      itemBuilder: (context, index) {
                                        final serving =
                                            widget.food.servings[index];
                                        final isSelected =
                                            selectedServing?.description ==
                                                serving.description;

                                        // Create a more neutral color scheme for dark mode
                                        final cardColor = isSelected
                                            ? Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? customColors.cardBackground
                                                    .withOpacity(1)
                                                : primaryColor
                                            : Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? customColors.cardBackground
                                                    .withOpacity(0.05)
                                                : primaryColor
                                                    .withOpacity(0.05);

                                        final textColor = isSelected
                                            ? Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white
                                                : Colors.white
                                            : Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? Colors.white.withOpacity(0.87)
                                                : Theme.of(context)
                                                    .primaryColor;

                                        return GestureDetector(
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            setState(() {
                                              selectedServing = serving;
                                              quantityController.text = serving
                                                  .metricAmount
                                                  .toString();
                                              selectedUnit = serving.metricUnit;
                                              selectedMultiplier = 1.0;
                                            });
                                          },
                                          child: Container(
                                            width: 140,
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: cardColor,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              border: Border.all(
                                                color: isSelected
                                                    ? Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? Color(
                                                            0xFF64748B) // Slate 500
                                                        : primaryColor
                                                    : Theme.of(context)
                                                                .brightness ==
                                                            Brightness.dark
                                                        ? Color(0xFF475569)
                                                            .withOpacity(
                                                                0.5) // Slate 600
                                                        : primaryColor
                                                            .withOpacity(0.2),
                                                width: isSelected ? 2 : 1,
                                              ),
                                              boxShadow: isSelected
                                                  ? [
                                                      BoxShadow(
                                                        color: Theme.of(context)
                                                                    .brightness ==
                                                                Brightness.dark
                                                            ? Color(0xFF0F172A)
                                                                .withOpacity(
                                                                    0.5) // Slate 900
                                                            : primaryColor
                                                                .withOpacity(
                                                                    0.2),
                                                        blurRadius: 8,
                                                        offset:
                                                            const Offset(0, 3),
                                                      )
                                                    ]
                                                  : null,
                                            ),
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                // Check or number indicator
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: isSelected
                                                        ? Theme.of(context)
                                                                    .brightness ==
                                                                Brightness.dark
                                                            ? Colors.white
                                                                .withOpacity(
                                                                    0.15)
                                                            : Colors.white
                                                                .withOpacity(
                                                                    0.3)
                                                        : Theme.of(context)
                                                                    .brightness ==
                                                                Brightness.dark
                                                            ? Colors.white
                                                                .withOpacity(
                                                                    0.1)
                                                            : primaryColor
                                                                .withOpacity(
                                                                    0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Center(
                                                    child: isSelected
                                                        ? Icon(
                                                            Icons.check_rounded,
                                                            color: textColor,
                                                            size: 18,
                                                          )
                                                        : Text(
                                                            "${index + 1}",
                                                            style: TextStyle(
                                                              color: textColor,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                // Serving name
                                                Text(
                                                  _formatServingDescription(
                                                      serving.description),
                                                  style: AppTypography.body2
                                                      .copyWith(
                                                    color: textColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const Spacer(),
                                                // Amount
                                                Text(
                                                  "${serving.metricAmount} ${serving.metricUnit}",
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                    color: isSelected
                                                        ? textColor
                                                            .withOpacity(0.9)
                                                        : customColors
                                                            .textSecondary,
                                                    fontWeight: isSelected
                                                        ? FontWeight.w600
                                                        : FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                // Calories
                                                Text(
                                                  "${serving.calories.toStringAsFixed(0)} kcal",
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                    color: isSelected
                                                        ? textColor
                                                        : Theme.of(context)
                                                                    .brightness ==
                                                                Brightness.dark
                                                            ? Color(
                                                                0xFFFBBC05) // Amber color for calories in dark mode
                                                            : primaryColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),

                                  if (widget.food.servings.length > 4)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: TextButton.icon(
                                          onPressed: () {
                                            HapticFeedback.selectionClick();
                                            _showServingSelector(context);
                                          },
                                          icon: Icon(
                                            Icons.view_list_rounded,
                                            color:
                                                Theme.of(context).brightness ==
                                                        Brightness.dark
                                                    ? Colors.white70
                                                    : primaryColor,
                                            size: 18,
                                          ),
                                          label: Text(
                                            "View all servings",
                                            style: AppTypography.body2.copyWith(
                                              color: Theme.of(context)
                                                          .brightness ==
                                                      Brightness.dark
                                                  ? Colors.white70
                                                  : primaryColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16, vertical: 8),
                                            backgroundColor: Theme.of(context)
                                                        .brightness ==
                                                    Brightness.dark
                                                ? Color(0xFF334155).withOpacity(
                                                    0.6) // Slate 700
                                                : primaryColor.withOpacity(0.1),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                          QuantitySelector(
                            presetMultipliers: presetMultipliers,
                            selectedMultiplier: selectedMultiplier,
                            onMultiplierSelected: (multiplier) {
                              setState(() {
                                selectedMultiplier = multiplier;
                                if (selectedServing != null) {
                                  double baseAmount =
                                      selectedServing!.metricAmount;
                                  quantityController.text =
                                      (baseAmount * multiplier).toStringAsFixed(
                                          multiplier % 1 == 0 ? 0 : 1);
                                } else {
                                  quantityController.text = (100 * multiplier)
                                      .toStringAsFixed(
                                          multiplier % 1 == 0 ? 0 : 1);
                                }
                              });
                            },
                          ),

                          // Quantity and unit inputs
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: customColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Quantity and unit inputs
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: quantityController,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                                decimal: true),
                                        textInputAction: TextInputAction
                                            .done, // Ensure "Done" button appears
                                        onEditingComplete: () {
                                          // This triggers when the user clicks the done/enter button
                                          FocusScope.of(context)
                                              .unfocus(); // Dismiss keyboard
                                          setState(() {
                                            // Update UI with new values
                                            selectedMultiplier = 0;
                                          });
                                        },
                                        onSubmitted: (value) {
                                          // This also triggers when the user hits the enter/done button
                                          FocusScope.of(context)
                                              .unfocus(); // Dismiss keyboard
                                          setState(() {
                                            // Update UI with new values
                                            selectedMultiplier = 0;
                                          });
                                        },
                                        onChanged: (value) {
                                          // Keep this for live updates
                                          setState(() {
                                            selectedMultiplier = 0;
                                          });
                                        },
                                        style: AppTypography.body1.copyWith(
                                          color: customColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: "Quantity",
                                          labelStyle: TextStyle(
                                            color: customColors.textSecondary,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: customColors
                                                  .dateNavigatorBackground,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: primaryColor,
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: customColors
                                                .dateNavigatorBackground,
                                          ),
                                        ),
                                        child: DropdownButtonFormField<String>(
                                          value: selectedUnit,
                                          items: unitOptions
                                              .map((unit) => DropdownMenuItem(
                                                    value: unit,
                                                    child: Text(unit),
                                                  ))
                                              .toList(),
                                          onChanged: (val) {
                                            if (val == selectedUnit)
                                              return; // Skip if same unit

                                            double currentQty = double.tryParse(
                                                    quantityController.text) ??
                                                0.0;

                                            setState(() {
                                              // Convert between g and oz
                                              if (val == "oz" &&
                                                  selectedUnit == "g") {
                                                // Convert g to oz (1 oz = 28.35g)
                                                quantityController.text =
                                                    (currentQty / 28.35)
                                                        .toStringAsFixed(1);
                                              } else if (val == "g" &&
                                                  selectedUnit == "oz") {
                                                // Convert oz to g
                                                quantityController.text =
                                                    (currentQty * 28.35)
                                                        .toStringAsFixed(0);
                                              }
                                              selectedUnit =
                                                  val!; // Update UI with new values by triggering state refresh
                                              selectedMultiplier =
                                                  0; // Reset multiplier to update calculations
                                              macroPercentages =
                                                  getMacroPercentages();
                                            });
                                          },
                                          decoration: InputDecoration(
                                            labelText: "Unit",
                                            labelStyle: TextStyle(
                                              color: customColors.textSecondary,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 14,
                                            ),
                                          ),
                                          style: AppTypography.body1.copyWith(
                                            color: customColors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                          icon: Icon(
                                            Icons.arrow_drop_down_rounded,
                                            color: customColors.textPrimary,
                                          ),
                                          dropdownColor:
                                              customColors.cardBackground,
                                          isExpanded: true,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Meal selection
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Add to Meal",
                                      style: AppTypography.body2.copyWith(
                                        color: customColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      height: 60,
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(
                                        color: customColors
                                            .dateNavigatorBackground
                                            .withOpacity(0.6),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Row(
                                        children: mealOptions.map((meal) {
                                          final isSelected =
                                              meal == selectedMeal;
                                          final mealColor =
                                              Theme.of(context).brightness ==
                                                      Brightness.dark
                                                  ? Color(0xFFFBBC05)
                                                      .withValues(alpha: 0.8)
                                                  : customColors.textPrimary;

                                          return Expanded(
                                            child: GestureDetector(
                                              onTap: () {
                                                HapticFeedback.lightImpact();
                                                setState(
                                                    () => selectedMeal = meal);
                                              },
                                              child: AnimatedContainer(
                                                duration: const Duration(
                                                    milliseconds: 200),
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? mealColor
                                                      : Colors.transparent,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    meal,
                                                    style: TextStyle(
                                                      color: isSelected
                                                          ? Colors.white
                                                          : customColors
                                                              .textSecondary,
                                                      fontWeight: isSelected
                                                          ? FontWeight.bold
                                                          : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Nutrition Facts
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 16, horizontal: 4),
                            child: Text(
                              "Nutrition Facts",
                              style: AppTypography.h2.copyWith(
                                color: customColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: customColors.cardBackground,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  selectedServing != null
                                      ? 'Values shown for ${selectedServing!.description} (${quantityController.text} ${selectedUnit})'
                                      : 'Values shown for ${quantityController.text} ${selectedUnit}',
                                  style: AppTypography.caption.copyWith(
                                    color: customColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Main Nutrients Section
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: primaryColor.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: primaryColor.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      NutrientRow(
                                        name: 'Calories',
                                        value:
                                            additionalNutrients['Calories'] ??
                                                '0 kcal',
                                        isHighlighted: true,
                                      ),
                                      Divider(
                                          color: customColors
                                              .dateNavigatorBackground),
                                      NutrientRow(
                                        name: 'Protein',
                                        value: additionalNutrients['Protein'] ??
                                            '0g',
                                        isHighlighted: true,
                                      ),
                                      Divider(
                                          color: customColors
                                              .dateNavigatorBackground),
                                      NutrientRow(
                                        name: 'Carbohydrates',
                                        value: additionalNutrients[
                                                'Carbohydrates'] ??
                                            '0g',
                                        isHighlighted: true,
                                      ),
                                      Divider(
                                          color: customColors
                                              .dateNavigatorBackground),
                                      NutrientRow(
                                        name: 'Fat',
                                        value:
                                            additionalNutrients['Fat'] ?? '0g',
                                        isHighlighted: true,
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(height: 24),

                                // Fats Breakdown
                                if (additionalNutrients.entries.any((entry) => [
                                      'Saturated fat',
                                      'Polyunsaturated fat',
                                      'Monounsaturated fat'
                                    ].contains(entry.key)))
                                  _buildNutrientSection(
                                    "Fat Breakdown",
                                    additionalNutrients.entries
                                        .where((entry) => [
                                              'Saturated fat',
                                              'Polyunsaturated fat',
                                              'Monounsaturated fat'
                                            ].contains(entry.key))
                                        .toList(),
                                    customColors.dateNavigatorBackground,
                                    const Color(0xFFFBBC05), // yellow
                                  ),

                                const SizedBox(height: 16),

                                // Carbs Breakdown
                                if (additionalNutrients.entries.any((entry) =>
                                    ['Fiber', 'Sugar'].contains(entry.key)))
                                  _buildNutrientSection(
                                    "Carbohydrate Breakdown",
                                    additionalNutrients.entries
                                        .where((entry) => ['Fiber', 'Sugar']
                                            .contains(entry.key))
                                        .toList(),
                                    customColors.dateNavigatorBackground,
                                    const Color(0xFF4285F4), // blue
                                  ),

                                const SizedBox(height: 16),

                                // Minerals
                                if (additionalNutrients.entries.any((entry) => [
                                      'Sodium',
                                      'Potassium',
                                      'Calcium',
                                      'Iron'
                                    ].contains(entry.key)))
                                  _buildNutrientSection(
                                    "Minerals",
                                    additionalNutrients.entries
                                        .where((entry) => [
                                              'Sodium',
                                              'Potassium',
                                              'Calcium',
                                              'Iron'
                                            ].contains(entry.key))
                                        .toList(),
                                    customColors.dateNavigatorBackground,
                                    const Color(0xFF34A853), // green
                                  ),

                                const SizedBox(height: 16),

                                // Vitamins
                                if (additionalNutrients.entries.any((entry) => [
                                      'Vitamin A',
                                      'Vitamin C'
                                    ].contains(entry.key)))
                                  _buildNutrientSection(
                                    "Vitamins",
                                    additionalNutrients.entries
                                        .where((entry) => [
                                              'Vitamin A',
                                              'Vitamin C'
                                            ].contains(entry.key))
                                        .toList(),
                                    customColors.dateNavigatorBackground,
                                    const Color(0xFFEA4335), // red
                                  ),

                                const SizedBox(height: 16),

                                // Other Nutrients
                                Builder(builder: (context) {
                                  final otherNutrients =
                                      additionalNutrients.entries
                                          .where((entry) => ![
                                                'Calories',
                                                'Protein',
                                                'Carbohydrates',
                                                'Fat',
                                                'Saturated fat',
                                                'Polyunsaturated fat',
                                                'Monounsaturated fat',
                                                'Fiber',
                                                'Sugar',
                                                'Sodium',
                                                'Potassium',
                                                'Calcium',
                                                'Iron',
                                                'Vitamin A',
                                                'Vitamin C'
                                              ].contains(entry.key))
                                          .toList();

                                  if (otherNutrients.isEmpty)
                                    return const SizedBox.shrink();

                                  return _buildNutrientSection(
                                    "Other Nutrients",
                                    otherNutrients,
                                    customColors.dateNavigatorBackground,
                                    const Color(0xFF9C27B0), // purple
                                  );
                                }),
                              ],
                            ),
                          ),

                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context)
                          .scaffoldBackgroundColor
                          .withOpacity(0.1),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                    boxShadow: [
                      // BoxShadow(
                      //   color: customColors.textPrimary.withOpacity(0.3),
                      //   blurRadius: 5,
                      //   offset: const Offset(0, 4),
                      // ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _addFoodEntry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: customColors.textPrimary,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(30),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              // border: Border.all(
                              // color: customColors.dateNavigatorBackground,
                              // width: 1.5,
                              // ),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Container(
                              height: 60,
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add to Diary',
                                    style: AppTypography.button.copyWith(
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.black
                                          : const Color(0xFFFFC107)
                                              .withValues(alpha: 0.9),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientSection(
      String title,
      List<MapEntry<String, String>> nutrients,
      Color dividerColor,
      Color accentColor) {
    if (nutrients.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 16,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: AppTypography.body1.copyWith(
                fontWeight: FontWeight.w600,
                color: accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: nutrients.map((entry) {
              return Column(
                children: [
                  NutrientRow(
                    name: entry.key,
                    value: entry.value,
                  ),
                  if (nutrients.last.key != entry.key)
                    Divider(color: dividerColor.withOpacity(0.5)),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showServingSelector(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: customColors!.cardBackground,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(top: 16, bottom: 8),
                    decoration: BoxDecoration(
                      color: customColors.dateNavigatorBackground,
                      borderRadius: BorderRadius.circular(2.5),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.restaurant_menu_rounded,
                            color: customColors.textSecondary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          "All Serving Options",
                          style: AppTypography.h2.copyWith(
                            color: Theme.of(context)
                                .extension<CustomColors>()!
                                .textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(),

                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: widget.food.servings.length,
                      itemBuilder: (context, index) {
                        final serving = widget.food.servings[index];
                        final isSelected =
                            selectedServing?.description == serving.description;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? primaryColor.withOpacity(0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? customColors.dateNavigatorBackground
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  selectedServing = serving;
                                  quantityController.text =
                                      serving.metricAmount.toString();
                                  selectedUnit = serving.metricUnit;
                                  selectedMultiplier = 1.0;
                                });
                                setModalState(() {});

                                // Optional: Close the sheet after selection
                                // Navigator.of(context).pop();
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Check indicator
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? primaryColor
                                            : primaryColor.withOpacity(0.07),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: isSelected
                                            ? const Icon(
                                                Icons.check_rounded,
                                                color: Colors.white,
                                                size: 24,
                                              )
                                            : Text(
                                                "${index + 1}",
                                                style: TextStyle(
                                                  color: primaryColor,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            serving.description,
                                            style: AppTypography.body1.copyWith(
                                              color: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.color,
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: primaryColor
                                                      .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  "${serving.metricAmount} ${serving.metricUnit}",
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                    color: primaryColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                "•",
                                                style: TextStyle(
                                                  color: customColors
                                                      .textSecondary,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFF9800)
                                                      .withOpacity(0.08),
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  "${serving.calories.toStringAsFixed(0)} kcal",
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                    color:
                                                        const Color(0xFFFF9800),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: customColors.textSecondary
                                          .withOpacity(0.5),
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Done button
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                        24, 16, 24, 16 + MediaQuery.of(context).padding.bottom),
                    decoration: BoxDecoration(
                      color: customColors.cardBackground,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).brightness == Brightness.dark
                                ? customColors.dateNavigatorBackground
                                : customColors.textPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        "Done",
                        style: AppTypography.button.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatServingDescription(String description) {
    if (description.length > 18) {
      return '${description.substring(0, 15)}...';
    }
    return description;
  }
}
