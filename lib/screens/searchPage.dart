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
import 'dart:async';

class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({super.key});

  @override
  _FoodSearchPageState createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage>
    with SingleTickerProviderStateMixin {
  IconData _getFoodIcon(String foodName) {
    final name = foodName.toLowerCase();
    if (name.contains('chicken') ||
        name.contains('meat') ||
        name.contains('beef')) {
      return Icons.restaurant;
    } else if (name.contains('salad') || name.contains('vegetable')) {
      return Icons.eco;
    } else if (name.contains('pizza') || name.contains('burger')) {
      return Icons.fastfood;
    } else if (name.contains('fruit') || name.contains('apple')) {
      return Icons.food_bank;
    }
    return Icons.restaurant_menu;
  }

  final TextEditingController _searchController = TextEditingController();
  List<FoodItem> _searchResults = [];
  List<String> _autoCompleteResults = [];
  bool _isLoading = false;
  final ApiService _apiService = ApiService();
  Timer? _debouncer;

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
    _debouncer?.cancel();
    _loadingController.dispose();
    _searchController.dispose();
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

  void _onSearchChanged(String query) {
    if (_debouncer?.isActive ?? false) _debouncer!.cancel();
    _debouncer = Timer(const Duration(milliseconds: 500), () {
      _getAutocompleteSuggestions(query);
    });
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
      _showError('Failed to search foods. Please try again.');
    } finally {
      setState(() {
        _isLoading = false;
        _autoCompleteResults = [];
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: 'Retry',
          onPressed: () => _searchFood(_searchController.text),
          textColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Container(
        // decoration: BoxDecoration(
        //   gradient: LinearGradient(
        //     begin: Alignment.topCenter,
        //     end: Alignment.bottomCenter,
        //     colors: [
        //       Theme.of(context).primaryColor.withValues(alpha: .05),
        //       Theme.of(context).scaffoldBackgroundColor,
        //     ],
        //     stops: const [0.0, 0.3],
        //   ),
        // ),
        child: SafeArea(
          child: Column(
            children: [
              SearchHeader(
                controller: _searchController,
                onSearch: _searchFood,
                onChanged: _onSearchChanged,
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  switchInCurve: Curves.easeOutCirc,
                  switchOutCurve: Curves.easeInCirc,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _buildContent(),
                ),
              ),
            ],
          ),
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withValues(alpha: .1),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: RotationTransition(
              turns: _loadingController,
              child: Icon(
                Icons.restaurant_rounded,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Finding delicious foods...',
            style: AppTypography.caption.copyWith(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    return RefreshIndicator(
      onRefresh: () => _searchFood(_searchController.text),
      child: _searchResults.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No results found',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) =>
                  _buildFoodCard(_searchResults[index]),
            ),
    );
  }

  void _navigateToFoodDetail(FoodItem food) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FoodDetailPage(food: food),
      ),
    );
  }

  // Removed duplicate _buildFoodCard implementation

  Widget _buildFoodCard(FoodItem food) {
    return Container(
      margin:
          const EdgeInsets.symmetric(vertical: 6), // Remove horizontal margin
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                    color:
                        Theme.of(context).primaryColor.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios_rounded,
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
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

  Widget _buildNutrientChip(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientItem(
      String label, String value, Color accentColor, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: .15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 12,
            color: accentColor,
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The illustration container
              Container(
                width: 160, // Slightly smaller
                height: 160, // Slightly smaller
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: .1),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          Theme.of(context).primaryColor.withValues(alpha: .05),
                      blurRadius: 15,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.restaurant_menu_rounded,
                  size: 72,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Find your favorite foods',
                style: AppTypography.h2.copyWith(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Search for any food to see detailed nutrition information and track your meals.',
                style: AppTypography.body1.copyWith(
                  color: Theme.of(context).primaryColor.withValues(alpha: .7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // Add a hint button
              Material(
                color: Theme.of(context).primaryColor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    _searchController.text = "chicken";
                    _searchFood("chicken");
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 18,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Try searching "chicken"',
                          style: AppTypography.button.copyWith(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              'Suggestions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _autoCompleteResults.length,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemBuilder: (context, index) {
                final suggestion = _autoCompleteResults[index];
                // Generate a unique but consistent color for each suggestion
                final Color suggestionColor =
                    Color(suggestion.hashCode).withOpacity(1.0);
                final hsl = HSLColor.fromColor(suggestionColor);
                final accentColor = hsl
                    .withLightness(
                        Theme.of(context).brightness == Brightness.dark
                            ? 0.7
                            : 0.4)
                    .toColor();

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.black12
                            : Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        _searchController.text = suggestion;
                        _searchFood(suggestion);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.search_rounded,
                                color: accentColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                suggestion,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
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
            ),
          ),
        ],
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
