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
  final TextEditingController quantityController = TextEditingController();

  @override
  void dispose() {
    quantityController.dispose();
    super.dispose();
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
      body: Padding(
        padding: const EdgeInsets.all(16),
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
    );
  }
}
