import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:macrotracker/widgets/shimmer_loading.dart';
import 'package:macrotracker/widgets/nutrient_row.dart';
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

  @override
  void initState() {
    super.initState();
    _searchBarcode(widget.barcode);

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
    super.dispose();
  }

  Future<void> _searchBarcode(String barcode) async {
    if (barcode.isEmpty) return;

    try {
      final response = await http.get(
        Uri.parse(
          'https://world.openfoodfacts.org/api/v0/product/$barcode.json',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1) {
          setState(() {
            _productData = data['product'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = 'Product not found';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Failed to fetch product data';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  void _addToMeal(String meal) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);

    // Get the nutriments data
    final nutriments = _productData?['nutriments'] ?? {};

    // Create food entry with explicit double conversion
    final entry = FoodEntry(
      id: const Uuid().v4(),
      food: FoodEntry.createFood(
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
      ),
      meal: meal,
      quantity: 100.0,
      unit: 'g',
      date: dateProvider.selectedDate,
    );

    // Add entry to provider
    foodEntryProvider.addEntry(entry);

    // Show success message
    _showSuccessSnackbar(meal);

    // Navigate directly to Dashboard
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  Widget _buildMealOption(BuildContext context, String meal, IconData icon) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            _addToMeal(meal);
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              border: Border.all(color: primaryColor.withOpacity(0.2)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(icon, color: primaryColor),
                const SizedBox(width: 16),
                Text(
                  meal,
                  style: AppTypography.body1.copyWith(
                    color: customColors!.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: customColors.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessSnackbar(String meal) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Theme.of(context).primaryColor,
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

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        // Remove the floatingActionButton
        bottomNavigationBar:
            _isLoading || _error != null ? null : _buildMealSelector(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildMealSelector() {
    final customColors = Theme.of(context).extension<CustomColors>();
    final List<String> mealOptions = ["Breakfast", "Lunch", "Snacks", "Dinner"];
    final primaryColor = Theme.of(context).primaryColor;

    // Track selected meal
    String selectedMeal = mealOptions[0]; // Default to Breakfast

    return StatefulBuilder(
      builder: (context, setState) {
        return Container(
          padding: EdgeInsets.fromLTRB(
              20, 12, 20, 30 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Meal selection slider
              Container(
                height: 60,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: customColors!.dateNavigatorBackground.withOpacity(0.6),
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
                            color: isSelected ? mealColor : Colors.transparent,
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

              const SizedBox(height: 16),

              // Add to meal button
              Container(
                width: double.infinity,
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
                          height: 60,
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.black.withOpacity(0.8)
                                    : const Color(0xFFFFC107).withOpacity(0.9),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Add to ${selectedMeal}',
                                style: AppTypography.button.copyWith(
                                  color: Theme.of(context).brightness ==
                                          Brightness.light
                                      ? Colors.black
                                      : const Color(0xFFFFC107)
                                          .withOpacity(0.9),
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
            ],
          ),
        );
      },
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

          // Product Name Card
          Container(
            margin: const EdgeInsets.only(bottom: 24),
            padding: const EdgeInsets.all(24),
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
                if (_productData?['brands'] != null)
                  Text(
                    _productData!['brands'],
                    style: AppTypography.body2.copyWith(
                      color: customColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                SizedBox(height: 8),
                Text(
                  _productData?['product_name'] ?? 'Unknown Product',
                  style: AppTypography.h2.copyWith(
                    color: customColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_productData?['quantity'] != null) ...[
                  SizedBox(height: 8),
                  Text(
                    _productData!['quantity'],
                    style: AppTypography.body2.copyWith(
                      color: customColors.textSecondary,
                    ),
                  ),
                ]
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
                  'Per 100g serving',
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

  String _formatNutrientValue(String key, String unit) {
    final value = _productData?['nutriments']?[key];
    if (value == null) return '0.0$unit';

    return '${value.toStringAsFixed(1)}$unit';
  }
}
