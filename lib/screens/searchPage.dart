// food_search_page.dart
// ignore_for_file: unused_import, file_names, library_private_types_in_public_api, avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/screens/foodDetail.dart';
import 'package:flutter/cupertino.dart';
import 'package:macrotracker/services/api_service.dart';
import 'package:macrotracker/theme/typography.dart';
import 'package:macrotracker/widgets/search_header.dart';

class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({super.key});

  @override
  _FoodSearchPageState createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _searchResults = [];
  List<String> _autoCompleteResults = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  late AnimationController _loadingController;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeApi();
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeApi() async {
    await _apiService.getAccessToken();
  }

  Future<void> _getAccessToken() async {
    await _apiService.getAccessToken();
  }

  Future<void> _getAutocompleteSuggestions(String query) async {
    if (query.isEmpty || _apiService.accessToken == null) {
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
          'Authorization': 'Bearer ${_apiService.accessToken}',
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
        if (_apiService.accessToken != null) {
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

  Future<void> _searchFood(String query) async {
    if (query.isEmpty || _apiService.accessToken == null) return;

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
          'Authorization': 'Bearer ${_apiService.accessToken}',
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
        if (_apiService.accessToken != null) {
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            SearchHeader(
              controller: _searchController,
              onSearch: _searchFood,
              onChanged: _getAutocompleteSuggestions,
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }
    if (_autoCompleteResults.isNotEmpty) {
      return _buildSuggestions();
    }
    if (_searchResults.isNotEmpty) {
      return _buildSearchResults();
    }
    return _buildEmptyState();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _loadingController,
            child: Icon(
              Icons.refresh_rounded,
              size: 48,
              color: Theme.of(context).primaryColor.withValues(alpha: .5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Searching...',
            style: TextStyle(
              color: Theme.of(context).primaryColor.withValues(alpha: .5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final food = _searchResults[index];
        return _buildFoodCard(food);
      },
    );
  }

  Widget _buildFoodCard(FoodItem food) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _navigateToFoodDetail(food),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFoodHeader(food),
                const SizedBox(height: 12),
                _buildNutrientRow(food),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFoodHeader(FoodItem food) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                food.name,
                style: AppTypography.body1.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (food.brandName.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  food.brandName,
                  style: AppTypography.caption.copyWith(
                    color: Theme.of(context).primaryColor.withOpacity(0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios_rounded,
          color: Theme.of(context).primaryColor.withValues(alpha: .3),
          size: 16,
        ),
      ],
    );
  }

  Widget _buildNutrientRow(FoodItem food) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildNutrientChip(
            '${food.calories.round()} cal',
            Icons.local_fire_department_rounded,
            Colors.orange,
          ),
          const SizedBox(width: 8),
          _buildNutrientChip(
            '${food.nutrients['Protein']?.round() ?? 0}g protein',
            Icons.fitness_center_rounded,
            Colors.blue,
          ),
          const SizedBox(width: 8),
          _buildNutrientChip(
            '${food.nutrients['Carbohydrate, by difference']?.round() ?? 0}g carbs',
            Icons.grain_rounded,
            Colors.green,
          ),
          const SizedBox(width: 8),
          _buildNutrientChip(
            '${food.nutrients['Total lipid (fat)']?.round() ?? 0}g fat',
            Icons.circle_outlined,
            Colors.red,
          ),
        ],
      ),
    );
  }

  void _navigateToFoodDetail(FoodItem food) {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodDetailPage(food: food),
      ),
    );
  }

  Widget _buildNutrientChip(String label, IconData icon, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: accentColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: accentColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_rounded,
            size: 64,
            color: Theme.of(context).primaryColor.withValues(alpha: .5),
          ),
          const SizedBox(height: 16),
          Text(
            'Search for your favorite foods',
            style: TextStyle(
              color: Theme.of(context).primaryColor.withValues(alpha: .5),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return ListView.builder(
      itemCount: _autoCompleteResults.length,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemBuilder: (context, index) {
        final suggestion = _autoCompleteResults[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .03),
                offset: const Offset(0, 2),
                blurRadius: 5,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                _searchController.text = suggestion;
                _searchFood(suggestion);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.search_rounded,
                      color:
                          Theme.of(context).primaryColor.withValues(alpha: .7),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          color: Theme.of(context).primaryColor,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
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
              color: Theme.of(context).primaryColor.withValues(alpha: 0.7),
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
