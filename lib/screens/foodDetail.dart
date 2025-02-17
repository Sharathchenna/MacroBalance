import 'package:flutter/material.dart';
import 'searchPage.dart'; // or import the file where FoodItem is defined

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
    if (nutrientPer100 == null || nutrientPer100 == 0) {
      return "N/A";
    }
    final convertedQty = getConvertedQuantity();
    final recalculated = nutrientPer100 * (convertedQty / 100);
    return recalculated.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.food;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F4F0),
        title: const Text('Food Details'),
        actions: [
          TextButton(
            onPressed: () {
              // Add button action here
            },
            child: const Text(
              '+ Add',
              style: TextStyle(color: Colors.blue, fontSize: 18),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // New Header Section
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side: food name and brand name
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          food.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          food.brandName,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall!
                              .copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  // Right side: recalculated nutrition values
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Energy value with " kcal" suffix; no label.
                      Text(
                        (() {
                          String energy = getNutrientValue("Energy");
                          return energy != "N/A" ? "$energy - kcal" : "N/A";
                        }()),
                        // style: Theme.of(context).textTheme.titleLarge,
                        style:
                            const TextStyle(fontSize: 25, color: Colors.green),
                      ),
                      const SizedBox(height: 20),
                      // Row for Carbs, Fats and Protein with labels ("C", "F", "P")
                      Row(
                        children: [
                          // Carbohydrate, by difference
                          Column(
                            children: [
                              const Text(
                                "C",
                                style:
                                    TextStyle(fontSize: 18, color: Colors.blue),
                              ),
                              Text(
                                getNutrientValue("Carbohydrate, by difference"),
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.blue),
                              ),
                            ],
                          ),
                          const SizedBox(width: 15),
                          // Total lipid (fat) using label "F"
                          Column(
                            children: [
                              const Text(
                                "F",
                                style: TextStyle(
                                    fontSize: 18, color: Colors.orange),
                              ),
                              Text(
                                getNutrientValue("Total lipid (fat)"),
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.orange),
                              ),
                            ],
                          ),
                          const SizedBox(width: 15),
                          // Protein with label "P"
                          Column(
                            children: [
                              const Text(
                                "P",
                                style:
                                    TextStyle(fontSize: 18, color: Colors.red),
                              ),
                              Text(
                                getNutrientValue("Protein"),
                                style: const TextStyle(
                                    fontSize: 18, color: Colors.red),
                              ),
                            ],
                          ),
                        ],
                      )
                    ],
                  )
                ],
              ),
              const SizedBox(height: 16),
              // New Input Section
              Column(
                children: [
                  // Meal Row
                  Row(
                    children: [
                      const SizedBox(
                        width: 80,
                        child: Text(
                          "Meal",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          dropdownColor: Colors.white,
                          value: selectedMeal,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
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
                  const Divider(),
                  // Quantity Row
                  Row(
                    children: [
                      const SizedBox(
                        width: 80,
                        child: Text(
                          "Quantity",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: quantityController,
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {});
                          },
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            suffixText: selectedUnit,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  // Unit Row
                  Row(
                    children: [
                      const SizedBox(
                        width: 80,
                        child: Text(
                          "Unit",
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          dropdownColor: Colors.white,
                          value: selectedUnit,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
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
              const SizedBox(height: 16),
              // Nutrition section
              Text(
                'Nutrition Facts (per 100g)',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: food.nutrients.entries.map((entry) {
                    return ListTile(
                      title: Text(entry.key),
                      trailing: Text(entry.value.toStringAsFixed(1)),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
