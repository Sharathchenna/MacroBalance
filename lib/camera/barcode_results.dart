import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:macrotracker/screens/foodDetail.dart';
import 'package:macrotracker/widgets/shimmer_loading.dart';
import 'package:macrotracker/widgets/nutrient_row.dart';
import 'package:macrotracker/widgets/macro_progress_ring.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';
import 'package:provider/provider.dart';
import '../providers/foodEntryProvider.dart';
import '../providers/dateProvider.dart';
import '../models/foodEntry.dart';
import 'package:uuid/uuid.dart';

// Extension to add withValues method to Color, similar to withOpacity
extension ColorExtension on Color {
  Color withValues({double? alpha}) {
    return withOpacity(alpha ?? opacity);
  }
}

class BarcodeResults extends StatefulWidget {
  final String barcode;

  const BarcodeResults({
    super.key,
    required this.barcode,
  });

  @override
  State<BarcodeResults> createState() => _BarcodeResultsState();
}

class _BarcodeResultsState extends State<BarcodeResults>
    with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  Map<String, dynamic>? _productData;
  String? _error;
  final _scrollController = ScrollController();
  bool _showFloatingTitle = false;

  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;

  // Add new state variables for serving selection
  final List<String> unitOptions = ["g", "oz"];
  String selectedUnit = "g";
  double selectedMultiplier = 1.0;
  late TextEditingController quantityController;
  List<Serving> servings = [];
  Serving? selectedServing;

  // Add shared meal selection state
  final List<String> mealOptions = ["Breakfast", "Lunch", "Snacks", "Dinner"];
  String selectedMeal = "Breakfast"; // Default to Breakfast

  @override
  void initState() {
    super.initState();
    _searchBarcode(widget.barcode);
    quantityController = TextEditingController(text: "100");

    // Add listener to quantityController
    quantityController.addListener(() {
      setState(() {
        // This will trigger a UI refresh when quantity changes
        selectedMultiplier = 0;
      });
    });

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
    _animationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    quantityController.dispose();
    super.dispose();
  }

  Future<void> _searchBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    try {
      print('Searching for barcode: $barcode');
      final response = await http.get(
        Uri.parse(
          'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
        ),
      );
      print('API response status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('API response data status: ${data['status']}');
        if (data['status'] == 1) {
          // Parse the product data
          Map<String, dynamic> productData = data['product'];

          // Parse serving data
          List<Serving> parsedServings =
              _parseServingsFromOpenFoodFacts(productData);

          setState(() {
            _productData = productData;
            _isLoading = false;
            servings = parsedServings;

            // Set default serving if available
            if (servings.isNotEmpty) {
              selectedServing = servings.first;
              quantityController.text =
                  selectedServing!.metricAmount.toString();
              selectedUnit = selectedServing!.metricUnit;
            }
          });
        } else {
          print('Product not found in API response');
          setState(() {
            _error = 'Product not found';
            _isLoading = false;
          });
        }
      } else {
        print('API request failed with status: ${response.statusCode}');
        setState(() {
          _error = 'Failed to fetch product data';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error in barcode search: $e');
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  // Parse servings from Open Food Facts API response
  List<Serving> _parseServingsFromOpenFoodFacts(
      Map<String, dynamic> productData) {
    List<Serving> results = [];
    final nutriments = productData['nutriments'] ?? {};

    // Always add a 100g serving
    results.add(
      Serving(
        description: '100g',
        metricAmount: 100.0,
        metricUnit: 'g',
        calories: (nutriments['energy-kcal_100g'] as num?)?.toDouble() ?? 0.0,
        nutrients: {
          'Protein': (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0.0,
          'Carbohydrate, by difference':
              (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0,
          'Total lipid (fat)':
              (nutriments['fat_100g'] as num?)?.toDouble() ?? 0.0,
          'Fiber': (nutriments['fiber_100g'] as num?)?.toDouble() ?? 0.0,
          'Saturated fat':
              (nutriments['saturated-fat_100g'] as num?)?.toDouble() ?? 0.0,
          'Sugar': (nutriments['sugars_100g'] as num?)?.toDouble() ?? 0.0,
          'Sodium': (nutriments['sodium_100g'] as num?)?.toDouble() ?? 0.0,
          'Salt': (nutriments['salt_100g'] as num?)?.toDouble() ?? 0.0,
        },
      ),
    );

    // Try to add a serving size from the product data if available
    if (productData['serving_size'] != null &&
        productData['serving_size'].toString().isNotEmpty) {
      // Extract serving size in grams if specified that way
      final servingSizeText = productData['serving_size'].toString();
      RegExp gramsRegex = RegExp(r'(\d+(?:\.\d+)?)(?:\s*)g');
      final match = gramsRegex.firstMatch(servingSizeText);

      if (match != null) {
        final servingAmount = double.parse(match.group(1) ?? '0');
        if (servingAmount > 0) {
          // Calculate nutrient values for this serving size
          double ratio = servingAmount / 100.0;

          results.add(
            Serving(
              description: 'Serving (${servingSizeText})',
              metricAmount: servingAmount,
              metricUnit: 'g',
              calories: ((nutriments['energy-kcal_100g'] as num?)?.toDouble() ??
                      0.0) *
                  ratio,
              nutrients: {
                'Protein':
                    ((nutriments['proteins_100g'] as num?)?.toDouble() ?? 0.0) *
                        ratio,
                'Carbohydrate, by difference':
                    ((nutriments['carbohydrates_100g'] as num?)?.toDouble() ??
                            0.0) *
                        ratio,
                'Total lipid (fat)':
                    ((nutriments['fat_100g'] as num?)?.toDouble() ?? 0.0) *
                        ratio,
                'Fiber':
                    ((nutriments['fiber_100g'] as num?)?.toDouble() ?? 0.0) *
                        ratio,
                'Saturated fat':
                    ((nutriments['saturated-fat_100g'] as num?)?.toDouble() ??
                            0.0) *
                        ratio,
                'Sugar':
                    ((nutriments['sugars_100g'] as num?)?.toDouble() ?? 0.0) *
                        ratio,
                'Sodium':
                    ((nutriments['sodium_100g'] as num?)?.toDouble() ?? 0.0) *
                        ratio,
                'Salt': ((nutriments['salt_100g'] as num?)?.toDouble() ?? 0.0) *
                    ratio,
              },
            ),
          );
        }
      }
    }

    // Add a per-package serving if 'quantity' field is available
    if (productData['quantity'] != null &&
        productData['quantity'].toString().isNotEmpty) {
      final quantityText = productData['quantity'].toString();
      RegExp gramsRegex = RegExp(r'(\d+(?:\.\d+)?)(?:\s*)g');
      final match = gramsRegex.firstMatch(quantityText);

      if (match != null) {
        final packageSize = double.parse(match.group(1) ?? '0');
        if (packageSize > 0 && packageSize != 100) {
          // Calculate nutrient values for this serving size
          double ratio = packageSize / 100.0;

          results.add(
            Serving(
              description: 'Package (${quantityText})',
              metricAmount: packageSize,
              metricUnit: 'g',
              calories: ((nutriments['energy-kcal_100g'] as num?)?.toDouble() ??
                      0.0) *
                  ratio,
              nutrients: {
                'Protein':
                    ((nutriments['proteins_100g'] as num?)?.toDouble() ?? 0.0) *
                        ratio,
                'Carbohydrate, by difference':
                    ((nutriments['carbohydrates_100g'] as num?)?.toDouble() ??
                            0.0) *
                        ratio,
                'Total lipid (fat)':
                    ((nutriments['fat_100g'] as num?)?.toDouble() ?? 0.0) *
                        ratio,
                'Fiber':
                    ((nutriments['fiber_100g'] as num?)?.toDouble() ?? 0.0) *
                        ratio,
                'Saturated fat':
                    ((nutriments['saturated-fat_100g'] as num?)?.toDouble() ??
                            0.0) *
                        ratio,
                'Sugar':
                    ((nutriments['sugars_100g'] as num?)?.toDouble() ?? 0.0) *
                        ratio,
                'Sodium':
                    ((nutriments['sodium_100g'] as num?)?.toDouble() ?? 0.0) *
                        ratio,
                'Salt': ((nutriments['salt_100g'] as num?)?.toDouble() ?? 0.0) *
                    ratio,
              },
            ),
          );
        }
      }
    }

    return results;
  }

  // Get converted quantity based on unit selection
  double getConvertedQuantity() {
    double qty = double.tryParse(quantityController.text) ?? 100;

    switch (selectedUnit) {
      case "oz":
        return qty * 28.35; // Convert to grams
      case "g":
      default:
        return qty;
    }
  }

  // Format nutrient values based on selected serving size
  String _formatNutrientValue(String key, String unit) {
    final nutriments = _productData?['nutriments'];
    if (nutriments == null) return '0.0$unit';

    final value = nutriments[key];
    if (value == null) return '0.0$unit';

    if (selectedServing != null) {
      // If a serving is selected, get the value from the serving
      double? servingValue;
      switch (key) {
        case 'energy-kcal_100g':
          servingValue = selectedServing!.calories;
          break;
        case 'proteins_100g':
          servingValue = selectedServing!.nutrients['Protein'];
          break;
        case 'carbohydrates_100g':
          servingValue =
              selectedServing!.nutrients['Carbohydrate, by difference'];
          break;
        case 'fat_100g':
          servingValue = selectedServing!.nutrients['Total lipid (fat)'];
          break;
      }

      // Apply quantity multiplier
      double multiplier = selectedMultiplier;
      if (selectedMultiplier == 0) {
        double enteredQty = double.tryParse(quantityController.text) ?? 0;
        multiplier = enteredQty / selectedServing!.metricAmount;
      }

      final adjustedValue = (servingValue ?? 0.0) * multiplier;
      // Trigger UI refresh when nutrient values change
      setState(() {});
      return '${adjustedValue.toStringAsFixed(1)}$unit';
    } else {
      // If no specific serving is selected, calculate based on quantity
      final convertedQty = getConvertedQuantity();
      final adjustedValue = (value as num).toDouble() * (convertedQty / 100);
      // Trigger UI refresh when nutrient values change
      setState(() {});
      return '${adjustedValue.toStringAsFixed(1)}$unit';
    }
  }

  String _getNutrientValue(String nutrient) {
    final nutriments = _productData?['nutriments'];
    if (nutriments == null) return "0.0";

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
      // Calculate based on 100g values and current quantity
      final convertedQty = getConvertedQuantity();

      double? value;
      switch (nutrient.toLowerCase()) {
        case "calories":
          value = (nutriments['energy-kcal_100g'] as num?)?.toDouble() ?? 0.0;
          break;
        case "protein":
          value = (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0.0;
          break;
        case "carbohydrate":
          value = (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0;
          break;
        case "fat":
          value = (nutriments['fat_100g'] as num?)?.toDouble() ?? 0.0;
          break;
      }

      if (value == null) return "0.0";
      value = value * (convertedQty / 100);
      return value.toStringAsFixed(1);
    }
  }

  Map<String, double> _getMacroPercentages() {
    double carbs = double.tryParse(_getNutrientValue("carbohydrate")) ?? 0;
    double protein = double.tryParse(_getNutrientValue("protein")) ?? 0;
    double fat = double.tryParse(_getNutrientValue("fat")) ?? 0;

    double total = carbs + protein + fat;
    if (total <= 0) return {"carbs": 0.33, "protein": 0.33, "fat": 0.34};

    return {
      "carbs": carbs / total,
      "protein": protein / total,
      "fat": fat / total,
    };
  }

  void _addToMeal(String meal) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);

    // Get the nutriments data
    final nutriments = _productData?['nutriments'] ?? {};

    // Get the quantity to use
    double quantity = double.tryParse(quantityController.text) ?? 100.0;

    // Create food with servings data
    final food = FoodEntry.createFood(
      fdcId: widget.barcode,
      name: _productData?['product_name'] ?? 'Unknown Product',
      brandName: _productData?['brands'] ?? 'Unknown Brand',
      calories: (nutriments['energy-kcal_100g'] as num?)?.toDouble() ?? 0.0,
      nutrients: {
        'Protein': (nutriments['proteins_100g'] as num?)?.toDouble() ?? 0.0,
        'Carbohydrate, by difference':
            (nutriments['carbohydrates_100g'] as num?)?.toDouble() ?? 0.0,
        'Total lipid (fat)':
            (nutriments['fat_100g'] as num?)?.toDouble() ?? 0.0,
        'Fiber': (nutriments['fiber_100g'] as num?)?.toDouble() ?? 0.0,
      },
      mealType: meal,
    );

    // Create food entry
    final entry = FoodEntry(
      id: const Uuid().v4(),
      food: food,
      meal: meal,
      quantity: quantity,
      unit: selectedUnit,
      date: dateProvider.selectedDate,
      servingDescription: selectedServing?.description,
    );

    // Add entry to provider
    foodEntryProvider.addEntry(entry);

    // Show success message
    _showSuccessSnackbar(meal);

    // Navigate directly to Dashboard
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                                  color: Colors.black.withValues(alpha: 0.1),
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
                      'Product Details',
                      style: TextStyle(
                        color: customColors.textPrimary,
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
                            Colors.grey.withValues(alpha: 0.2),
                            Theme.of(context).scaffoldBackgroundColor,
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(24, 60, 24, 0),
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
                                  child: Text(
                                    'Product Details',
                                    style: AppTypography.h1.copyWith(
                                      color: customColors.textPrimary,
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
                    child: _isLoading
                        ? ShimmerLoading()
                        : _error != null
                            ? _buildErrorState()
                            : _buildProductDetails(),
                  ),
                ),
              ],
            ),
            if (!_isLoading && _error == null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                      20, 12, 20, 30 + MediaQuery.of(context).padding.bottom),
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
                  child: _buildAddToDiaryButton(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddToDiaryButton() {
    final customColors = Theme.of(context).extension<CustomColors>();
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.light
              ? Colors.black.withOpacity(0.3)
              : Colors.white.withOpacity(0.3),
          width: 0.5,
        ),
      ),
      child: ElevatedButton(
        onPressed: () => _addToMeal(selectedMeal),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: customColors!.textPrimary,
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
                height: 60,
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black.withOpacity(0.8)
                          : const Color(0xFFFFC107).withOpacity(0.9),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Add to Diary',
                      style: AppTypography.button.copyWith(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : const Color(0xFFFFC107).withOpacity(0.9),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Show which meal is selected
                    // Container(
                    //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    //   decoration: BoxDecoration(
                    //     color: Theme.of(context).brightness == Brightness.light
                    //         ? Colors.black.withOpacity(0.05)
                    //         : Colors.white.withOpacity(0.1),
                    //     borderRadius: BorderRadius.circular(12),
                    //   ),
                    //   child: Row(
                    //     mainAxisSize: MainAxisSize.min,
                    //     children: [
                    //       Text(
                    //         selectedMeal,
                    //         style: TextStyle(
                    //           color: Theme.of(context).brightness == Brightness.light
                    //               ? Colors.black.withOpacity(0.7)
                    //               : const Color(0xFFFFC107).withOpacity(0.9),
                    //           fontWeight: FontWeight.bold,
                    //           fontSize: 12,
                    //         ),
                    //       ),
                    //       const SizedBox(width: 2),
                    //       Icon(
                    //         Icons.arrow_drop_down,
                    //         size: 16,
                    //         color: Theme.of(context).brightness == Brightness.light
                    //             ? Colors.black.withOpacity(0.7)
                    //             : const Color(0xFFFFC107).withOpacity(0.9),
                    //       ),
                    //     ],
                    //   ),
                    // ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final customColors = Theme.of(context).extension<CustomColors>();
    final primaryColor = Theme.of(context).primaryColor;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 64,
              color: primaryColor,
            ),
            SizedBox(height: 24),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: AppTypography.body1.copyWith(
                color: customColors!.textPrimary,
                height: 1.5,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _searchBarcode(widget.barcode),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: Text(
                'Try Again',
                style: AppTypography.button.copyWith(
                  fontWeight: FontWeight.w600,
                  color: customColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductDetails() {
    final customColors = Theme.of(context).extension<CustomColors>();
    final primaryColor = Theme.of(context).primaryColor;

    // Calculate calories and macro percentages
    final calculatedCalories =
        double.tryParse(_getNutrientValue("calories")) ?? 0;
    final macroPercentages = _getMacroPercentages();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Image Card
          if (_productData?['image_url'] != null)
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              color: customColors!.cardBackground,
              margin: const EdgeInsets.only(bottom: 24),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.network(
                    _productData!['image_url'],
                    height: 250,
                    width: double.infinity,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return SizedBox(
                        height: 250,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: primaryColor,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return SizedBox(
                        height: 250,
                        child: Center(
                          child: Icon(
                            Icons.broken_image_rounded,
                            size: 64,
                            color: primaryColor.withOpacity(0.5),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

          // Main Nutrition Card with Macro Info
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: customColors!.cardBackground,
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Name and Brand
                if (_productData?['brands'] != null)
                  Text(
                    _productData!['brands'],
                    style: AppTypography.body2.copyWith(
                      color: customColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  _productData?['product_name'] ?? 'Unknown Product',
                  style: AppTypography.h2.copyWith(
                    color: customColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                // Macro info grid
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // First row: Calories and Protein
                    Row(
                      children: [
                        // Calories
                        Expanded(
                          child: MacroInfoBox(
                            icon: "🔥",
                            iconColor: Colors.black,
                            value: _getNutrientValue("calories"),
                            label: "Calories",
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Protein
                        Expanded(
                          child: MacroInfoBox(
                            icon: "🍗",
                            iconColor: Colors.black,
                            value: _getNutrientValue("protein"),
                            label: "Protein (g)",
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // Second row: Carbs and Fat
                    Row(
                      children: [
                        // Carbs
                        Expanded(
                          child: MacroInfoBox(
                            icon: "🟫",
                            iconColor: Colors.black,
                            value: _getNutrientValue("carbohydrate"),
                            label: "Carbs (g)",
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Fat
                        Expanded(
                          child: MacroInfoBox(
                            icon: "🥑",
                            iconColor: Colors.black,
                            value: _getNutrientValue("fat"),
                            label: "Fat (g)",
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Add Macro Progress Rings after the image
          // Container(
          //   margin: const EdgeInsets.only(bottom: 24),
          //   padding: const EdgeInsets.fromLTRB(
          //       16, 24, 16, 40), // Increased bottom padding
          //   decoration: BoxDecoration(
          //     color: customColors.cardBackground,
          //     borderRadius: BorderRadius.circular(24),
          //     boxShadow: [
          //       BoxShadow(
          //         color: Colors.black.withOpacity(0.06),
          //         blurRadius: 15,
          //         offset: const Offset(0, 5),
          //       ),
          //     ],
          //   ),
          //   child: Column(
          //     children: [
          //       Row(
          //         mainAxisAlignment: MainAxisAlignment.center,
          //         crossAxisAlignment: CrossAxisAlignment.start,
          //         children: [
          //           Text(
          //             calculatedCalories.toStringAsFixed(0),
          //             style: AppTypography.h1.copyWith(
          //               color: customColors.textPrimary,
          //               fontWeight: FontWeight.bold,
          //               height: 0.9,
          //               fontSize: 40, // Increased font size
          //             ),
          //           ),
          //           Text(
          //             " kcal",
          //             style: AppTypography.h3.copyWith(
          //               color: customColors.textSecondary,
          //               fontWeight: FontWeight.w300,
          //             ),
          //           ),
          //         ],
          //       ),
          //       const SizedBox(height: 36), // Increased spacing
          //       Row(
          //         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          //         children: [
          //           Expanded(
          //             child: Padding(
          //               padding: const EdgeInsets.symmetric(horizontal: 4),
          //               child: SizedBox(
          //                 height: 140, // Increased height for larger rings
          //                 child: MacroProgressRing(
          //                   key: ValueKey(
          //                       'carbs-${quantityController.text}-$selectedUnit'),
          //                   label: 'Carbs',
          //                   value: _getNutrientValue("carbohydrate"),
          //                   color: const Color(0xFF4285F4), // Google blue
          //                   percentage: macroPercentages["carbs"] ?? 0.33,
          //                 ),
          //               ),
          //             ),
          //           ),
          //           Expanded(
          //             child: Padding(
          //               padding: const EdgeInsets.symmetric(horizontal: 4),
          //               child: SizedBox(
          //                 height: 140, // Increased height for larger rings
          //                 child: MacroProgressRing(
          //                   key: ValueKey(
          //                       'protein-${quantityController.text}-$selectedUnit}'),
          //                   label: 'Protein',
          //                   value: _getNutrientValue("protein"),
          //                   color: const Color(0xFFEA4335), // Google red
          //                   percentage: macroPercentages["protein"] ?? 0.33,
          //                 ),
          //               ),
          //             ),
          //           ),
          //           Expanded(
          //             child: Padding(
          //               padding: const EdgeInsets.symmetric(horizontal: 4),
          //               child: SizedBox(
          //                 height: 140, // Increased height for larger rings
          //                 child: MacroProgressRing(
          //                   key: ValueKey(
          //                       'fat-${quantityController.text}-$selectedUnit'),
          //                   label: 'Fat',
          //                   value: _getNutrientValue("fat"),
          //                   color: const Color(0xFFFBBC05), // Google yellow
          //                   percentage: macroPercentages["fat"] ?? 0.34,
          //                 ),
          //               ),
          //             ),
          //           ),
          //         ],
          //       ),
          //     ],
          //   ),
          // ),

          // Add meal selector right after the image
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
                        color: customColors.textSecondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.restaurant_menu_rounded,
                        color: customColors.textSecondary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      "Add to Meal",
                      style: AppTypography.h3.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? Colors.white
                            : primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Meal selection
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      height: 60,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: customColors.dateNavigatorBackground
                            .withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: mealOptions.map((meal) {
                          final isSelected = meal == selectedMeal;
                          final mealColor =
                              Theme.of(context).brightness == Brightness.dark
                                  ? Color(0xFFFBBC05).withValues(alpha: 0.8)
                                  : customColors.textPrimary;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                setState(() => selectedMeal = meal);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? mealColor
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Center(
                                  child: Text(
                                    meal,
                                    style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : customColors.textSecondary,
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

          // Product Name Card
          // Container(
          //   margin: const EdgeInsets.only(bottom: 24),
          //   padding: const EdgeInsets.all(24),
          //   decoration: BoxDecoration(
          //     color: customColors.cardBackground,
          //     borderRadius: BorderRadius.circular(24),
          //     boxShadow: [
          //       BoxShadow(
          //         color: Colors.black.withOpacity(0.06),
          //         blurRadius: 15,
          //         offset: const Offset(0, 5),
          //       ),
          //     ],
          //   ),
          //   child: Column(
          //     crossAxisAlignment: CrossAxisAlignment.start,
          //     children: [
          //       if (_productData?['brands'] != null)
          //         Text(
          //           _productData!['brands'],
          //           style: AppTypography.body2.copyWith(
          //             color: customColors.textSecondary,
          //             fontWeight: FontWeight.w500,
          //           ),
          //         ),
          //       SizedBox(height: 8),
          //       Text(
          //         _productData?['product_name'] ?? 'Unknown Product',
          //         style: AppTypography.h2.copyWith(
          //           color: customColors.textPrimary,
          //           fontWeight: FontWeight.bold,
          //         ),
          //       ),
          //       if (_productData?['quantity'] != null) ...[
          //         SizedBox(height: 8),
          //         Text(
          //           _productData!['quantity'],
          //           style: AppTypography.body2.copyWith(
          //             color: customColors.textSecondary,
          //           ),
          //         ),
          //       ]
          //     ],
          //   ),
          // ),

          // Serving Size Section (New)
          if (servings.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              child: Text(
                "Serving Size",
                style: AppTypography.h2.copyWith(
                  color: customColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
                          color: customColors.textSecondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
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
                          color: Theme.of(context).brightness == Brightness.dark
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
                      itemCount: servings.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final serving = servings[index];
                        final isSelected =
                            selectedServing?.description == serving.description;

                        // Create a more neutral color scheme for dark mode
                        final cardColor = isSelected
                            ? Theme.of(context).brightness == Brightness.dark
                                ? customColors.cardBackground.withOpacity(1)
                                : primaryColor
                            : Theme.of(context).brightness == Brightness.dark
                                ? customColors.cardBackground.withOpacity(0.05)
                                : primaryColor.withOpacity(0.05);

                        final textColor = isSelected
                            ? Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : Colors.white
                            : Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withOpacity(0.87)
                                : Theme.of(context).primaryColor;

                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              selectedServing = serving;
                              quantityController.text =
                                  serving.metricAmount.toString();
                              selectedUnit = serving.metricUnit;
                              selectedMultiplier = 1.0;
                            });
                          },
                          child: Container(
                            width: 140,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Color(0xFF64748B) // Slate 500
                                        : primaryColor
                                    : Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? Color(0xFF475569)
                                            .withOpacity(0.5) // Slate 600
                                        : primaryColor.withOpacity(0.2),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Color(0xFF0F172A)
                                                .withOpacity(0.5) // Slate 900
                                            : primaryColor.withOpacity(0.2),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      )
                                    ]
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Check or number indicator
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white.withOpacity(0.15)
                                            : Colors.white.withOpacity(0.3)
                                        : Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white.withOpacity(0.1)
                                            : primaryColor.withOpacity(0.1),
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
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                // Serving name
                                Text(
                                  _formatServingDescription(
                                      serving.description),
                                  style: AppTypography.body2.copyWith(
                                    color: textColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const Spacer(),
                                // Amount
                                Text(
                                  "${serving.metricAmount} ${serving.metricUnit}",
                                  style: AppTypography.caption.copyWith(
                                    color: isSelected
                                        ? textColor.withOpacity(0.9)
                                        : customColors.textSecondary,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Calories
                                Text(
                                  "${serving.calories.toStringAsFixed(0)} kcal",
                                  style: AppTypography.caption.copyWith(
                                    color: isSelected
                                        ? textColor
                                        : Theme.of(context).brightness ==
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
                ],
              ),
            ),
          ],

          // Quantity Input (New)
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
                Text(
                  "Quantity",
                  style: AppTypography.body2.copyWith(
                    color: customColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: quantityController,
                        keyboardType:
                            TextInputType.numberWithOptions(decimal: true),
                        textInputAction: TextInputAction.done,
                        onEditingComplete: () {
                          FocusScope.of(context).unfocus();
                          setState(() {
                            selectedMultiplier = 0;
                          });
                        },
                        onChanged: (value) {
                          setState(() {
                            selectedMultiplier = 0;
                          });
                        },
                        style: AppTypography.body1.copyWith(
                          color: customColors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: "Amount",
                          labelStyle: TextStyle(
                            color: customColors.textSecondary,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: customColors.dateNavigatorBackground,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: primaryColor,
                              width: 2,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
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
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: customColors.dateNavigatorBackground,
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
                            if (val == selectedUnit) return;

                            double currentQty =
                                double.tryParse(quantityController.text) ?? 0.0;

                            setState(() {
                              // Convert between g and oz
                              if (val == "oz" && selectedUnit == "g") {
                                // Convert g to oz (1 oz = 28.35g)
                                quantityController.text =
                                    (currentQty / 28.35).toStringAsFixed(1);
                              } else if (val == "g" && selectedUnit == "oz") {
                                // Convert oz to g
                                quantityController.text =
                                    (currentQty * 28.35).toStringAsFixed(0);
                              }
                              selectedUnit = val!;
                              selectedMultiplier = 0;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: "Unit",
                            labelStyle: TextStyle(
                              color: customColors.textSecondary,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
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
                          dropdownColor: customColors.cardBackground,
                          isExpanded: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Nutritional Information Card
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
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
                        value: _formatNutrientValue('energy-kcal_100g', 'kcal'),
                        isHighlighted: true,
                      ),
                      Divider(color: customColors.dateNavigatorBackground),
                      NutrientRow(
                        name: 'Protein',
                        value: _formatNutrientValue('proteins_100g', 'g'),
                        isHighlighted: true,
                      ),
                      Divider(color: customColors.dateNavigatorBackground),
                      NutrientRow(
                        name: 'Carbohydrates',
                        value: _formatNutrientValue('carbohydrates_100g', 'g'),
                        isHighlighted: true,
                      ),
                      Divider(color: customColors.dateNavigatorBackground),
                      NutrientRow(
                        name: 'Fat',
                        value: _formatNutrientValue('fat_100g', 'g'),
                        isHighlighted: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Carbs Breakdown
                _buildNutrientSection(
                  "Carbohydrate Breakdown",
                  [
                    MapEntry('Fiber', _formatNutrientValue('fiber_100g', 'g')),
                    MapEntry(
                        'Sugars', _formatNutrientValue('sugars_100g', 'g')),
                  ],
                  customColors.dateNavigatorBackground,
                  const Color(0xFF4285F4), // blue
                ),

                const SizedBox(height: 16),

                // Fats Breakdown
                _buildNutrientSection(
                  "Fat Breakdown",
                  [
                    MapEntry('Saturated Fat',
                        _formatNutrientValue('saturated-fat_100g', 'g')),
                    MapEntry('Trans Fat',
                        _formatNutrientValue('trans-fat_100g', 'g')),
                  ],
                  customColors.dateNavigatorBackground,
                  const Color(0xFFFBBC05), // yellow
                ),

                const SizedBox(height: 16),

                // Other nutrients
                _buildNutrientSection(
                  "Other Nutrients",
                  [
                    MapEntry(
                        'Sodium', _formatNutrientValue('sodium_100g', 'mg')),
                    MapEntry('Salt', _formatNutrientValue('salt_100g', 'g')),
                    MapEntry('Cholesterol',
                        _formatNutrientValue('cholesterol_100g', 'mg')),
                  ],
                  customColors.dateNavigatorBackground,
                  const Color(0xFF34A853), // green
                ),
              ],
            ),
          ),

          // Ingredients Card
          if (_productData?['ingredients_text'] != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
              child: Text(
                "Ingredients",
                style: AppTypography.h2.copyWith(
                  color: customColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
              child: Text(
                _productData!['ingredients_text'],
                style: AppTypography.body1.copyWith(
                  color: customColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ],

          const SizedBox(height: 60),
        ],
      ),
    );
  }

  Widget _buildNutrientSection(
      String title,
      List<MapEntry<String, String>> nutrients,
      Color dividerColor,
      Color accentColor) {
    if (nutrients
        .every((entry) => entry.value == '0.0g' || entry.value == '0.0mg')) {
      return const SizedBox.shrink();
    }

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
              if (entry.value == '0.0g' || entry.value == '0.0mg') {
                return const SizedBox.shrink();
              }
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

  // Helper function to format long serving descriptions
  String _formatServingDescription(String description) {
    if (description.length > 18) {
      return '${description.substring(0, 15)}...';
    }
    return description;
  }

  void _showSuccessSnackbar(String meal) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Color(0xFFFFC107).withValues(alpha: 0.8),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Text('Added to $meal'),
          ],
        ),
      ),
    );
  }
}

// Add Serving class to match the one used in foodDetail.dart
class Serving {
  final String description;
  final double metricAmount;
  final String metricUnit;
  final double calories;
  final Map<String, double> nutrients;

  Serving({
    required this.description,
    required this.metricAmount,
    required this.metricUnit,
    required this.calories,
    required this.nutrients,
  });
}
