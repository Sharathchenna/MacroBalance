// food_search_page.dart
// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:macrotracker/screens/foodDetail.dart';

class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({super.key});

  @override
  _FoodSearchPageState createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _searchResults = [];
  bool _isLoading = false;
  var usdaApiKey = "HfaUP7Q7WTrFzJgjZ1WblvF3op1eoFjd9OPZ60Be";
  Future<void> _searchFood(String query) async {
    if (query.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse(
            'https://api.nal.usda.gov/fdc/v1/foods/search?api_key=$usdaApiKey&query=$query&dataType=Foundation,Survey%20%28FNDDS%29&pageSize=10'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _searchResults = (data['foods'] as List)
              .map((food) => FoodItem.fromJson(food))
              .toList();
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching for food: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        title: const Text('Search Foods'),
        backgroundColor: const Color(0xFFF5F4F0),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            // Search Bar Always Visible
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SearchBar(
                controller: _searchController,
                onSearch: _searchFood,
              ),
            ),
            // Conditional List Section
            if (_searchResults.isNotEmpty || _isLoading)
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : FoodList(foods: _searchResults),
              ),
          ],
        ),
      ),
    );
  }
}

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final Function(String) onSearch;

  const SearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Search for food...',
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      onSubmitted: onSearch,
    );
  }
}

class FoodList extends StatelessWidget {
  final List<FoodItem> foods;

  const FoodList({super.key, required this.foods});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: foods.length,
      itemBuilder: (context, index) {
        final food = foods[index];
        return FoodCard(food: food);
      },
    );
  }
}

class FoodCard extends StatelessWidget {
  final FoodItem food;

  const FoodCard({super.key, required this.food});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: ListTile(
        title: Text(food.name),
        subtitle: Text(
          '${food.brandName} • ${food.mealType}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          '${food.calories} kcal',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => FoodDetailPage(food: food)),
          );
        },
      ),
    );
  }
}

class FoodItem {
  final String fdcId;
  final String name;
  final double calories;
  final String brandName;
  final Map<String, double> nutrients;
  final String mealType; // new field

  FoodItem({
    required this.fdcId,
    required this.name,
    required this.calories,
    required this.nutrients,
    required this.brandName,
    required this.mealType, // require mealType in constructor
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      fdcId: json['fdcId'].toString(),
      name: json['description'] ?? '',
      calories: _findNutrient(json['foodNutrients'], 'Energy'),
      nutrients: _parseNutrients(json['foodNutrients']),
      brandName: json['brandOwner'] ?? '',
      mealType: json['mealType'] ?? 'breakfast', // default to "breakfast"
    );
  }

  static double _findNutrient(List? nutrients, String name) {
    if (nutrients == null) return 0.0;
    final nutrient = nutrients.firstWhere(
      (n) => n['nutrientName'] == name,
      orElse: () => {'value': 0.0},
    );
    return (nutrient['value'] ?? 0.0).toDouble();
  }

  static Map<String, double> _parseNutrients(List? nutrients) {
    if (nutrients == null) return {};

    final Map<String, double> result = {};
    for (var nutrient in nutrients) {
      if (nutrient['nutrientName'] != null && nutrient['value'] != null) {
        result[nutrient['nutrientName']] = nutrient['value'].toDouble();
      }
    }
    return result;
  }
}

class PortionSelector extends StatefulWidget {
  final FoodItem food;

  const PortionSelector({super.key, required this.food});

  @override
  _PortionSelectorState createState() => _PortionSelectorState();
}

class _PortionSelectorState extends State<PortionSelector> {
  double _grams = 100;
  final TextEditingController _gramsController =
      TextEditingController(text: '100');

  @override
  void dispose() {
    _gramsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Select Portion Size'),
          TextField(
            controller: _gramsController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Grams',
              suffixText: 'g',
            ),
            onChanged: (value) {
              final grams = double.tryParse(value);
              if (grams != null) {
                setState(() {
                  _grams = grams;
                });
              }
            },
          ),
          SizedBox(height: 16),
          Text(
            'Calories: ${(widget.food.calories * _grams / 100).round()} kcal',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          ElevatedButton(
            onPressed: () {
              // Create a MealEntry using the selected amount
              final int calories =
                  (widget.food.calories * _grams / 100).round();
              final double protein =
                  ((widget.food.nutrients["Protein"] ?? 0.0) * _grams / 100);
              final double fat =
                  ((widget.food.nutrients["Total lipid (fat)"] ?? 0.0) *
                      _grams /
                      100);
              final double carb =
                  ((widget.food.nutrients["Carbohydrate, by difference"] ??
                          0.0) *
                      _grams /
                      100);
              final mealEntry = MealEntry(
                food: widget.food,
                grams: _grams,
                calories: calories,
                protein: protein,
                fat: fat,
                carb: carb,
              );
              // Return the meal entry to the previous page.
              Navigator.pop(context, mealEntry);
            },
            child: Text('Add to Log'),
          ),
        ],
      ),
    );
  }
}

// class FoodDetailPage extends StatelessWidget {
//   final FoodItem food;

//   const FoodDetailPage({super.key, required this.food});

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Food Details'),
//       ),
//       body: Padding(
//         padding: EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               food.name,
//               style: Theme.of(context).textTheme.headlineMedium,
//             ),
//             SizedBox(height: 4),
//             Text(
//               food.brandName,
//               style: Theme.of(context)
//                   .textTheme
//                   .headlineSmall!
//                   .copyWith(color: Colors.grey),
//             ),
//             SizedBox(height: 16),
//             Text(
//               'Nutrition Facts (per 100g)',
//               style: Theme.of(context).textTheme.titleLarge,
//             ),
//             SizedBox(height: 8),
//             Expanded(
//               child: ListView(
//                 children: food.nutrients.entries.map((entry) {
//                   return ListTile(
//                     title: Text(entry.key),
//                     trailing: Text(entry.value.toStringAsFixed(1)),
//                   );
//                 }).toList(),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// Add a new model for meal entries
class MealEntry {
  final FoodItem food;
  final double grams;
  final int calories;
  final double protein;
  final double fat;
  final double carb;

  MealEntry({
    required this.food,
    required this.grams,
    required this.calories,
    required this.protein,
    required this.fat,
    required this.carb,
  });
}
