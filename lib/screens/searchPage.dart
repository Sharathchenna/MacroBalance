// food_search_page.dart
// ignore_for_file: unused_import, file_names, library_private_types_in_public_api, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/screens/foodDetail.dart';
import 'package:flutter/cupertino.dart';

class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({super.key});

  @override
  _FoodSearchPageState createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _searchResults = [];
  List<String> _autoCompleteResults = [];
  bool _isLoading = false;
  String? _accessToken;

  // FatSecret API credentials - replace with your own
  final String _clientId = '5c66a0001059406b8989bd179ab8897d';
  final String _clientSecret = '5de5f12d25e4418b8c78e6b80e78d9f7';

  @override
  void initState() {
    super.initState();
    _getAccessToken();
  }

  Future<void> _getAccessToken() async {
    try {
      final response = await http.post(
        Uri.parse('https://oauth.fatsecret.com/connect/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization':
              'Basic ${base64Encode(utf8.encode('$_clientId:$_clientSecret'))}',
        },
        body: {
          'grant_type': 'client_credentials',
          'scope': 'premier', // Changed from 'basic' to 'premier'
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() => _accessToken = data['access_token']);
        print('Access token obtained successfully with premier scope');
      } else {
        print('Failed to get access token: ${response.statusCode}');
        print('Error response: ${response.body}');
      }
    } catch (e) {
      print('Error getting access token: $e');
    }
  }

  Future<void> _getAutocompleteSuggestions(String query) async {
    if (query.isEmpty || _accessToken == null) {
      setState(() => _autoCompleteResults = []);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse('https://platform.fatsecret.com/rest/food/autocomplete/v2')
            .replace(
          queryParameters: {
            'expression': query,
            'max_results': '5',
            'format': 'json' // Added format parameter
          },
        ),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json', // Added Accept header
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['suggestions'] != null &&
            data['suggestions']['suggestion'] != null) {
          final suggestions = data['suggestions']['suggestion'] as List;
          setState(() {
            _autoCompleteResults = suggestions.cast<String>();
          });
        } else {
          setState(() => _autoCompleteResults = []);
        }
      } else if (response.statusCode == 401) {
        await _getAccessToken();
        if (_accessToken != null) {
          await _getAutocompleteSuggestions(query);
        }
      } else {
        print('Error status code: ${response.statusCode}');
        print('Error response: ${response.body}');
        setState(() => _autoCompleteResults = []);
      }
    } catch (e) {
      print('Autocomplete error: $e');
      setState(() => _autoCompleteResults = []);
    }
  }

  // Also update the _searchFood method to use the same headers
  Future<void> _searchFood(String query) async {
    if (query.isEmpty || _accessToken == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('https://platform.fatsecret.com/rest/server.api').replace(
          queryParameters: {
            'method': 'foods.search',
            'format': 'json',
            'search_expression': query,
            'max_results': '10',
            'page_number': '0'
          },
        ),
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Accept': 'application/json', // Added Accept header
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['foods'] != null && data['foods']['food'] != null) {
          final foods = data['foods']['food'] as List;
          setState(() {
            _searchResults =
                foods.map((food) => FoodItem.fromFatSecretJson(food)).toList();
          });
        } else {
          setState(() => _searchResults = []);
        }
      } else if (response.statusCode == 401) {
        await _getAccessToken();
        if (_accessToken != null) {
          await _searchFood(query);
        }
      } else {
        // Print error response for debugging
        print('Error status code: ${response.statusCode}');
        print('Error response: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching for food: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
        _autoCompleteResults = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Remove the loading screen check
    return Scaffold(
      // backgroundColor: const Color(0xFFF5F4F0),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: CupertinoNavigationBarBackButton(
          color: Theme.of(context).primaryColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Search Foods',
          style: TextStyle(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SearchBar(
                controller: _searchController,
                onSearch: _searchFood,
                onChanged: _getAutocompleteSuggestions,
              ),
            ),
            if (_autoCompleteResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _autoCompleteResults.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(
                        _autoCompleteResults[index],
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      onTap: () {
                        _searchController.text = _autoCompleteResults[index];
                        _searchFood(_autoCompleteResults[index]);
                      },
                    );
                  },
                ),
              ),
            if (_searchResults.isNotEmpty && _autoCompleteResults.isEmpty)
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
  final Function(String) onChanged;

  const SearchBar({
    super.key,
    required this.controller,
    required this.onSearch,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIconColor: Theme.of(context).primaryColor,
        hintText: 'Search for food...',
        hintStyle: TextStyle(
          color: Theme.of(context).primaryColor,
        ),
        prefixIcon: Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      style: TextStyle(
        color: Theme.of(context).primaryColor,
      ),
      onSubmitted: onSearch,
      onChanged: onChanged,
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
        return ListTile(
          title: Text(
            food.name,
            style: TextStyle(
              color: Theme.of(context).primaryColor,
            ),
          ),
          subtitle: Text(
            '${food.calories.round()} calories',
            style: TextStyle(
              color: Theme.of(context).primaryColor.withOpacity(0.7),
            ),
          ),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => FoodDetailPage(food: food),
              ),
            );
          },
        );
      },
    );
  }
}

class FoodItem {
  final String fdcId;
  final String name;
  final double calories;
  final String brandName;
  final Map<String, double> nutrients;
  final String mealType;

  FoodItem({
    required this.fdcId,
    required this.name,
    required this.calories,
    required this.nutrients,
    required this.brandName,
    required this.mealType,
  });

  factory FoodItem.fromFatSecretJson(Map<String, dynamic> json) {
    final description = json['food_description'] as String;
    final nutrients = _parseFatSecretNutrients(description);

    return FoodItem(
      fdcId: json['food_id'].toString(),
      name: json['food_name'] ?? '',
      calories: nutrients['calories'] ?? 0.0,
      nutrients: {
        'Protein': nutrients['protein'] ?? 0.0,
        'Total lipid (fat)': nutrients['fat'] ?? 0.0,
        'Carbohydrate, by difference': nutrients['carbs'] ?? 0.0,
      },
      brandName: json['brand_name'] ?? '',
      mealType:
          'breakfast', // Default value since FatSecret doesn't provide meal type
    );
  }

  static Map<String, double> _parseFatSecretNutrients(String description) {
    final regex = RegExp(
      r'Calories:\s*(\d+).*?Fat:\s*(\d+).*?Carbs:\s*(\d+).*?Protein:\s*(\d+)',
      caseSensitive: false,
    );

    final match = regex.firstMatch(description);
    if (match != null) {
      return {
        'calories': double.parse(match.group(1) ?? '0'),
        'fat': double.parse(match.group(2) ?? '0'),
        'carbs': double.parse(match.group(3) ?? '0'),
        'protein': double.parse(match.group(4) ?? '0'),
      };
    }
    return {};
  }
}
