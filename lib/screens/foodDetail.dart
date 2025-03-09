// ignore_for_file: file_names, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'searchPage.dart'; // or import the file where FoodItem is defined
import 'package:provider/provider.dart';
import '../providers/foodEntryProvider.dart';
import '../models/foodEntry.dart';
import 'package:uuid/uuid.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:fl_chart/fl_chart.dart';

class MacroCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final double percentage;

  const MacroCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withAlpha((0.08 * 255).round()),
            color.withAlpha((0.02 * 255).round()),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha((0.2 * 255).round())),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: 60,
                width: 60,
                child: CircularProgressIndicator(
                  value: percentage,
                  backgroundColor: color.withAlpha((0.1 * 255).round()),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeWidth: 5,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FoodDetailPage extends StatefulWidget {
  final FoodItem food;

  const FoodDetailPage({super.key, required this.food});

  @override
  _FoodDetailPageState createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage>
    with SingleTickerProviderStateMixin {
  final List<String> mealOptions = ["Breakfast", "Lunch", "Snacks", "Dinner"];
  final List<String> unitOptions = ["g", "oz", "kg", "lbs"];
  final List<double> presetMultipliers = [0.5, 1.0, 1.5, 2.0];

  String selectedMeal = "Breakfast";
  String selectedUnit = "g";
  double selectedMultiplier = 1.0;
  final TextEditingController quantityController =
      TextEditingController(text: '100');
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    quantityController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Converts the entered quantity to grams based on the selected unit.
  double getConvertedQuantity() {
    double qty = double.tryParse(quantityController.text) ?? 100;
    switch (selectedUnit) {
      case "oz":
        return qty * 28.35;
      case "kg":
        return qty * 1000;
      case "lbs":
        return qty * 453.59;
      case "g":
      default:
        return qty;
    }
  }

  // Returns the recalculated nutrient value as a formatted string
  String getNutrientValue(String nutrientKey) {
    final nutrientPer100 = widget.food.nutrients[nutrientKey];
    if (nutrientPer100 == null) {
      return "N/A";
    }
    final convertedQty = getConvertedQuantity();
    final recalculated = nutrientPer100 * (convertedQty / 10000);
    return recalculated.toStringAsFixed(1);
  }

  // Calculate percentage for macro chart
  Map<String, double> getMacroPercentages() {
    double carbs =
        double.tryParse(getNutrientValue("Carbohydrate, by difference")) ?? 0;
    double protein = double.tryParse(getNutrientValue("Protein")) ?? 0;
    double fat = double.tryParse(getNutrientValue("Total lipid (fat)")) ?? 0;

    double total = carbs + protein + fat;
    if (total <= 0) return {"carbs": 0.33, "protein": 0.33, "fat": 0.34};

    return {
      "carbs": carbs / total,
      "protein": protein / total,
      "fat": fat / total,
    };
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    final macroPercentages = getMacroPercentages();
    final convertedQty = getConvertedQuantity();
    final caloriesPer100 = widget.food.calories;
    final calculatedCalories = caloriesPer100 * (convertedQty / 100);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeInAnimation,
            child: Stack(
              children: [
                // Main content
                CustomScrollView(
                  slivers: [
                    // App bar
                    SliverAppBar(
                      expandedHeight: 180.0,
                      floating: false,
                      pinned: true,
                      backgroundColor:
                          Theme.of(context).scaffoldBackgroundColor,
                      leading: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .cardColor
                                .withAlpha((0.8 * 255).round()),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Theme.of(context)
                                    .primaryColor
                                    .withAlpha((0.2 * 255).round()),
                                Theme.of(context).scaffoldBackgroundColor,
                              ],
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 16),
                            alignment: Alignment.bottomLeft,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  food.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Theme.of(context).primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text(
                                  food.brandName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .primaryColor
                                            .withAlpha((0.7 * 255).round()),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Main content
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Calories and macro chart
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Theme.of(context)
                                        .primaryColor
                                        .withAlpha((0.05 * 255).round()),
                                    Theme.of(context).cardColor,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withAlpha((0.05 * 255).round()),
                                    spreadRadius: 0,
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "${calculatedCalories.toStringAsFixed(0)}",
                                        style: TextStyle(
                                          fontSize: 40,
                                          fontWeight: FontWeight.bold,
                                          color: Theme.of(context).primaryColor,
                                        ),
                                      ),
                                      Text(
                                        " kcal",
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.w300,
                                          color: Theme.of(context)
                                              .primaryColor
                                              .withAlpha((0.7 * 255).round()),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),
                                  // Macro cards row with animated progress indicators
                                  Row(
                                    children: [
                                      Expanded(
                                        child: MacroCard(
                                          label: 'Carbs',
                                          value:
                                              '${getNutrientValue("Carbohydrate, by difference")}g',
                                          color: Colors.blue,
                                          percentage:
                                              macroPercentages["carbs"] ?? 0.33,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: MacroCard(
                                          label: 'Protein',
                                          value:
                                              '${getNutrientValue("Protein")}g',
                                          color: Colors.red,
                                          percentage:
                                              macroPercentages["protein"] ??
                                                  0.33,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: MacroCard(
                                          label: 'Fat',
                                          value:
                                              '${getNutrientValue("Total lipid (fat)")}g',
                                          color: Colors.orange,
                                          percentage:
                                              macroPercentages["fat"] ?? 0.34,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Serving size section with quick multiplier buttons
                            Text(
                              "Serving Size",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withAlpha((0.2 * 255).round()),
                                ),
                              ),
                              child: Column(
                                children: [
                                  // Quick multiplier buttons
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children:
                                        presetMultipliers.map((multiplier) {
                                      bool isSelected =
                                          multiplier == selectedMultiplier;
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            selectedMultiplier = multiplier;
                                            quantityController.text =
                                                (100 * multiplier)
                                                    .toStringAsFixed(
                                                        multiplier % 1 == 0
                                                            ? 0
                                                            : 1);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Theme.of(context).primaryColor
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(30),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Theme.of(context)
                                                      .primaryColor
                                                  : Theme.of(context)
                                                      .dividerColor,
                                            ),
                                          ),
                                          child: Text(
                                            "${multiplier}x",
                                            style: TextStyle(
                                              color: isSelected
                                                  ? Colors.white
                                                  : Theme.of(context)
                                                      .primaryColor,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                  // Quantity input
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: TextField(
                                          controller: quantityController,
                                          keyboardType: TextInputType.number,
                                          onChanged: (value) {
                                            setState(() {
                                              // Reset multiplier selection when manually entered
                                              selectedMultiplier = 0;
                                            });
                                          },
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                          decoration: InputDecoration(
                                            labelText: "Quantity",
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: DropdownButtonFormField<String>(
                                          value: selectedUnit,
                                          decoration: InputDecoration(
                                            labelText: "Unit",
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 18,
                                            ),
                                          ),
                                          style: TextStyle(
                                            color:
                                                Theme.of(context).primaryColor,
                                            fontSize: 16,
                                          ),
                                          dropdownColor: Theme.of(context)
                                              .scaffoldBackgroundColor,
                                          onChanged: (val) {
                                            setState(() {
                                              selectedUnit = val!;
                                            });
                                          },
                                          items: unitOptions
                                              .map((unit) => DropdownMenuItem(
                                                    value: unit,
                                                    child: Text(unit),
                                                  ))
                                              .toList(),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  // Meal selection
                                  DropdownButtonFormField<String>(
                                    value: selectedMeal,
                                    decoration: InputDecoration(
                                      labelText: "Add to Meal",
                                      prefixIcon:
                                          const Icon(Icons.restaurant_menu),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 18,
                                      ),
                                    ),
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontSize: 16,
                                    ),
                                    dropdownColor: Theme.of(context)
                                        .scaffoldBackgroundColor,
                                    onChanged: (val) {
                                      setState(() {
                                        selectedMeal = val!;
                                      });
                                    },
                                    items: mealOptions
                                        .map((meal) => DropdownMenuItem(
                                              value: meal,
                                              child: Text(meal),
                                            ))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Nutrition facts section
                            Text(
                              "Nutrition Facts",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                            Text(
                              'Values shown for selected quantity',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).hintColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Theme.of(context)
                                      .dividerColor
                                      .withAlpha((0.2 * 255).round()),
                                ),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: widget.food.nutrients.length,
                                separatorBuilder: (context, index) => Divider(),
                                itemBuilder: (context, index) {
                                  final entry = widget.food.nutrients.entries
                                      .elementAt(index);
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            entry.key,
                                            style: TextStyle(
                                              fontSize: 15,
                                              color: Theme.of(context)
                                                  .primaryColor,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${(entry.value * getConvertedQuantity() / 100).toStringAsFixed(1)}g',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                            color:
                                                Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                            // Add extra space at the bottom to account for the FAB
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Add button as a floating action button
                Positioned(
                  bottom: 20,
                  right: 20,
                  left: 20,
                  child: ElevatedButton(
                    onPressed: () {
                      final dateProvider =
                          Provider.of<DateProvider>(context, listen: false);
                      final entry = FoodEntry(
                        id: const Uuid().v4(),
                        food: widget.food,
                        meal: selectedMeal,
                        quantity: double.parse(quantityController.text),
                        unit: selectedUnit,
                        date: dateProvider.selectedDate,
                      );

                      Provider.of<FoodEntryProvider>(context, listen: false)
                          .addEntry(entry);

                      // Pop both pages
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Added ${widget.food.name} to $selectedMeal'),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          action: SnackBarAction(
                            label: 'UNDO',
                            onPressed: () {
                              // Add undo functionality here
                              Provider.of<FoodEntryProvider>(context,
                                      listen: false)
                                  .removeEntry(entry.id);
                            },
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Add to Diary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
