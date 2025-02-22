import 'package:flutter/material.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'searchPage.dart'; // or import the file where FoodItem is defined
import 'package:provider/provider.dart';
import '../providers/foodEntryProvider.dart';
import '../models/foodEntry.dart';
import 'package:uuid/uuid.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:flutter/cupertino.dart';

class MacroCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const MacroCard({
    super.key,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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

class _FoodDetailPageState extends State<FoodDetailPage> {
  final List<String> mealOptions = ["Breakfast", "Lunch", "Snacks", "Dinner"];
  final List<String> unitOptions = ["g", "oz", "kg", "lbs"];

  String selectedMeal = "Breakfast";
  String selectedUnit = "g";
  final TextEditingController quantityController =
      TextEditingController(text: '100');

  @override
  void dispose() {
    quantityController.dispose();
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

  // Returns the recalculated nutrient value as a formatted string, or "N/A" if not available.
  String getNutrientValue(String nutrientKey) {
    final nutrientPer100 = widget.food.nutrients[nutrientKey];
    if (nutrientPer100 == null) {
      return "N/A";
    }
    final convertedQty = getConvertedQuantity();
    final recalculated = nutrientPer100 * (convertedQty / 100);
    return recalculated.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    return GestureDetector(
      onTap: () {
        // Dismiss keyboard when tapping outside
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: CupertinoNavigationBarBackButton(
            color: Theme.of(context).primaryColor,
            onPressed: () => Navigator.of(context).pop(),
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Text(
            'Food Details',
            style: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          actions: [
            TextButton(
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
                    content: Text('Added ${widget.food.name} to $selectedMeal'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                '+ Add',
                style: TextStyle(color: Colors.blue, fontSize: 18),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Food Title Section
                Text(
                  food.name,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Theme.of(context).primaryColor,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  food.brandName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Theme.of(context).primaryColor.withOpacity(0.7),
                      ),
                ),
                const SizedBox(height: 24),

                // Macros Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .extension<CustomColors>()
                        ?.macroCardBackground,
                    borderRadius: BorderRadius.circular(16),
                    // boxShadow: [
                    //   BoxShadow(
                    //     color: Colors.grey.withAlpha(25),
                    //     spreadRadius: 1,
                    //     blurRadius: 4,
                    //     offset: const Offset(0, 2),
                    //   ),
                    // ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Text(
                          (() {
                            String energy = food.calories.toString();
                            // return energy != "N/A" ? "$energy kcal" : "N/A";
                            return energy = "$energy kcal";
                          }()),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: MacroCard(
                              label: 'Carbs',
                              value:
                                  '${getNutrientValue("Carbohydrate, by difference")}g',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: MacroCard(
                              label: 'Protein',
                              value: '${getNutrientValue("Protein")}g',
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: MacroCard(
                              label: 'Fat',
                              value:
                                  '${getNutrientValue("Total lipid (fat)")}g',
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Input Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .extension<CustomColors>()
                        ?.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    // boxShadow: [
                    //   BoxShadow(
                    //     color: Colors.grey.withValues(alpha: 0.1),
                    //     spreadRadius: 1,
                    //     blurRadius: 10,
                    //     offset: const Offset(0, 2),
                    //   ),
                    // ],
                  ),
                  child: Column(
                    children: [
                      // Meal Row
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              "Meal",
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              dropdownColor:
                                  Theme.of(context).scaffoldBackgroundColor,
                              value: selectedMeal,
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
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
                          ),
                        ],
                      ),
                      Divider(
                        color: Theme.of(context)
                            .extension<CustomColors>()
                            ?.dateNavigatorBackground,
                      ),
                      // Quantity Row
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              "Quantity",
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: quantityController,
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {});
                              },
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
                              decoration: InputDecoration(
                                border: const OutlineInputBorder(),
                                suffixText: selectedUnit,
                                suffixStyle: TextStyle(
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Divider(
                        color: Theme.of(context)
                            .extension<CustomColors>()
                            ?.dateNavigatorBackground,
                      ),
                      // Unit Row
                      Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              "Unit",
                              style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              dropdownColor:
                                  Theme.of(context).scaffoldBackgroundColor,
                              value: selectedUnit,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              style: TextStyle(
                                color: Theme.of(context).primaryColor,
                              ),
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Nutrition Facts Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .extension<CustomColors>()
                        ?.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nutrition Facts',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                      ),
                      Text(
                        'per 100g',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey,
                            ),
                      ),
                      const SizedBox(height: 16),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: widget.food.nutrients.length,
                        separatorBuilder: (context, index) => Divider(
                          color: Theme.of(context)
                              .extension<CustomColors>()
                              ?.dateNavigatorBackground,
                          height: 1,
                        ),
                        itemBuilder: (context, index) {
                          final entry =
                              widget.food.nutrients.entries.elementAt(index);
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${entry.value.toStringAsFixed(1)}g',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
