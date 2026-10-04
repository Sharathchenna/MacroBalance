// ignore_for_file: file_names, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/widgets/quantity_selector.dart';
import 'package:macrotracker/widgets/nutrient_row.dart';
import 'searchPage.dart';
import 'package:provider/provider.dart';
import '../providers/foodEntryProvider.dart';
import '../models/foodEntry.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';
import '../theme/typography.dart';
import 'dart:math';
import '../services/posthog_service.dart';
import '../providers/saved_food_provider.dart';
import 'food_detail/components/components.dart';

class FoodDetailPage extends StatefulWidget {
  final FoodItem food;
  final String? selectedMeal;

  const FoodDetailPage({
    super.key,
    required this.food,
    this.selectedMeal,
  });

  @override
  _FoodDetailPageState createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage>
    with SingleTickerProviderStateMixin {
  final List<String> mealOptions = ["Breakfast", "Lunch", "Snacks", "Dinner"];
  final List<String> unitOptions = ["g", "oz"];
  final List<double> presetMultipliers = [0.5, 1.0, 1.5, 2.0];

  late String selectedMeal;
  String selectedUnit = "g";
  double selectedMultiplier = 1.0;
  late TextEditingController quantityController;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;
  Serving? selectedServing;

  final _scrollController = ScrollController();
  bool _showFloatingTitle = false;

  @override
  void initState() {
    super.initState();
    selectedMeal = widget.selectedMeal ?? "Breakfast";
    PostHogService.trackScreen('food_detail_page');

    if (widget.food.servings.isNotEmpty) {
      selectedServing = widget.food.servings.first;
      // Match the unit to the serving, as selecting a serving does, so an
      // "oz" serving isn't read as grams.
      final unit = selectedServing!.metricUnit.toLowerCase();
      selectedUnit = (unit == 'g' || unit == 'oz') ? unit : selectedServing!.metricUnit;
      quantityController =
          TextEditingController(text: selectedServing!.metricAmount.toString());
    } else {
      quantityController =
          TextEditingController(text: widget.food.servingSize.toString());
    }

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

    Future.microtask(() {
      if (mounted) {
        Provider.of<SavedFoodProvider>(context, listen: false).initialize();
      }
    });
  }

  void _onScroll() {
    if (_scrollController.offset > 120 && !_showFloatingTitle) {
      setState(() => _showFloatingTitle = true);
    } else if (_scrollController.offset <= 120 && _showFloatingTitle) {
      setState(() => _showFloatingTitle = false);
    }
  }

  @override
  void dispose() {
    quantityController.dispose();
    _animationController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  double getConvertedQuantity() {
    double qty = double.tryParse(quantityController.text.replaceAll(',', '.')) ?? 100;
    if (selectedUnit == "oz") {
      return qty * 28.35;
    }
    return qty;
  }

  double _calculateMultiplier() {
    if (selectedServing == null) {
      double multiplier = getConvertedQuantity() /
          (widget.food.servingSize > 0 ? widget.food.servingSize : 100.0);
      return multiplier;
    }

    double baseAmount = selectedServing!.metricAmount;
    if (baseAmount <= 0) {
      print("Warning: Selected serving base amount is invalid ($baseAmount), defaulting to 1.");
      baseAmount = 1.0;
    }

    String unit = selectedServing!.metricUnit.toLowerCase();
    bool isWeightBased = (unit == 'g' || unit == 'oz');

    if (isWeightBased) {
      double convertedQtyGrams = getConvertedQuantity();
      final baseGrams = unit == 'oz' ? baseAmount * 28.35 : baseAmount;
      double multiplier = convertedQtyGrams / baseGrams;
      return multiplier;
    } else {
      double quantityEntered = double.tryParse(quantityController.text.replaceAll(',', '.')) ?? 1.0;
      if (quantityEntered < 0) quantityEntered = 0;
      double multiplier = quantityEntered / baseAmount;
      return multiplier;
    }
  }

  String getNutrientValue(String nutrient) {
    final double multiplier = _calculateMultiplier();

    if (selectedServing != null) {
      double? baseValue;
      switch (nutrient.toLowerCase()) {
        case "calories":
          baseValue = selectedServing!.calories;
          break;
        case "protein":
          baseValue = selectedServing!.nutrients['Protein'];
          break;
        case "carbohydrate":
          baseValue = selectedServing!.nutrients['Carbohydrate, by difference'];
          break;
        case "fat":
          baseValue = selectedServing!.nutrients['Total lipid (fat)'];
          break;
      }
      double value = (baseValue ?? 0.0) * multiplier;
      return value.toStringAsFixed(1);
    } else {
      double? baseValue;
      switch (nutrient.toLowerCase()) {
        case "calories":
          baseValue = widget.food.calories;
          break;
        case "protein":
          baseValue = widget.food.nutrients['Protein'];
          break;
        case "carbohydrate":
          baseValue = widget.food.nutrients['Carbohydrate, by difference'];
          break;
        case "fat":
          baseValue = widget.food.nutrients['Total lipid (fat)'];
          break;
      }
      double value = (baseValue ?? 0.0) * multiplier;
      return value.toStringAsFixed(1);
    }
  }

  Map<String, double> getMacroPercentages() {
    double carbs = double.tryParse(getNutrientValue("carbohydrate")) ?? 0;
    double protein = double.tryParse(getNutrientValue("protein")) ?? 0;
    double fat = double.tryParse(getNutrientValue("fat")) ?? 0;

    setState(() {});

    double total = carbs + protein + fat;
    if (total <= 0) return {"carbs": 0.33, "protein": 0.33, "fat": 0.34};

    return {
      "carbs": carbs / total,
      "protein": protein / total,
      "fat": fat / total,
    };
  }

  Map<String, String> getAdditionalNutrients() {
    Map<String, String> result = {};
    final double multiplier = _calculateMultiplier();

    if (selectedServing != null) {
      result['Calories'] = '${(selectedServing!.calories * multiplier).toStringAsFixed(1)} kcal';
      result['Protein'] = '${((selectedServing!.nutrients['Protein'] ?? 0.0) * multiplier).toStringAsFixed(1)}g';
      result['Carbohydrates'] = '${((selectedServing!.nutrients['Carbohydrate, by difference'] ?? 0.0) * multiplier).toStringAsFixed(1)}g';
      result['Fat'] = '${((selectedServing!.nutrients['Total lipid (fat)'] ?? 0.0) * multiplier).toStringAsFixed(1)}g';

      selectedServing!.nutrients.forEach((key, baseValue) {
        if (!['Protein', 'Carbohydrate, by difference', 'Total lipid (fat)'].contains(key)) {
          String unit = _getNutrientUnit(key);
          double calculatedValue = baseValue * multiplier;
          result[key] = '${calculatedValue.toStringAsFixed(1)}$unit';
        }
      });
    } else {
      result['Calories'] = '${(widget.food.calories * multiplier).toStringAsFixed(1)} kcal';
      result['Protein'] = '${((widget.food.nutrients['Protein'] ?? 0.0) * multiplier).toStringAsFixed(1)}g';
      result['Carbohydrates'] = '${((widget.food.nutrients['Carbohydrate, by difference'] ?? 0.0) * multiplier).toStringAsFixed(1)}g';
      result['Fat'] = '${((widget.food.nutrients['Total lipid (fat)'] ?? 0.0) * multiplier).toStringAsFixed(1)}g';

      widget.food.nutrients.forEach((key, baseValue) {
        if (!['Protein', 'Carbohydrate, by difference', 'Total lipid (fat)'].contains(key)) {
          String unit = _getNutrientUnit(key);
          double calculatedValue = baseValue * multiplier;
          result[key] = '${calculatedValue.toStringAsFixed(1)}$unit';
        }
      });
    }

    return result;
  }

  String _getNutrientUnit(String key) {
    if (key == 'Saturated fat' || key == 'Polyunsaturated fat' || key == 'Monounsaturated fat') {
      return 'g';
    } else if (key == 'Cholesterol' || key == 'Sodium' || key == 'Potassium') {
      return 'mg';
    } else if (key == 'Vitamin C' || key == 'Calcium' || key == 'Iron') {
      return 'mg';
    } else if (key == 'Fiber' || key == 'Sugar') {
      return 'g';
    } else if (key == 'Vitamin A') {
      return 'mcg';
    }
    return 'g';
  }

  void _addFoodEntry() async {
    // Accept "1,5" as well as "1.5" (comma is the decimal key in many locales).
    final quantity =
        double.tryParse(quantityController.text.trim().replaceAll(',', '.'));
    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an amount greater than 0'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final foodEntryProvider = Provider.of<FoodEntryProvider>(context, listen: false);
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final entry = FoodEntry(
      id: const Uuid().v4(),
      food: widget.food,
      meal: selectedMeal,
      quantity: quantity,
      unit: selectedUnit,
      date: dateProvider.selectedDate,
      servingDescription: selectedServing?.description,
    );

    PostHogService.trackFoodEntry(
      foodName: widget.food.name,
      calories: widget.food.calories,
      protein: widget.food.nutrients['Protein'] ?? 0,
      carbs: widget.food.nutrients['Carbohydrate, by difference'] ?? 0,
      fat: widget.food.nutrients['Total lipid (fat)'] ?? 0,
      properties: {
        'meal_type': selectedMeal,
        'quantity': entry.quantity,
        'unit': entry.unit,
        'serving_description': entry.servingDescription,
        'brand_name': widget.food.brandName,
      },
    );

    await foodEntryProvider.addEntry(entry);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                selectedServing != null
                    ? 'Added ${widget.food.name} (${selectedServing!.description}) to $selectedMeal'
                    : 'Added ${widget.food.name} to $selectedMeal',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFFC107).withOpacity(1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _showServingSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ServingSelectorSheet(
        servings: widget.food.servings,
        selectedServing: selectedServing,
        onServingSelected: (serving) {
          setState(() {
            selectedServing = serving;
            quantityController.text = serving.metricAmount.toString();
            selectedUnit = serving.metricUnit;
            selectedMultiplier = 1.0;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showNutrientsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NutrientsSheet(
        nutrients: getAdditionalNutrients(),
      ),
    );
  }

  FoodItem _createFoodItemWithSelectedServing() {
    if (selectedServing == null) {
      return widget.food;
    }

    List<Serving> reorderedServings = [];
    reorderedServings.add(selectedServing!);
    for (var serving in widget.food.servings) {
      if (serving.description != selectedServing!.description) {
        reorderedServings.add(serving);
      }
    }

    return FoodItem(
      fdcId: widget.food.fdcId,
      name: widget.food.name,
      calories: widget.food.calories,
      nutrients: widget.food.nutrients,
      brandName: widget.food.brandName,
      mealType: widget.food.mealType,
      servingSize: widget.food.servingSize,
      servings: reorderedServings,
    );
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final food = widget.food;
    final additionalNutrients = getAdditionalNutrients();
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Stack(
          children: [
            CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildAppBar(food, customColors!),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMacroCard(food, customColors, primaryColor),
                          _buildMealSelector(customColors),
                          _buildQuantitySelector(customColors, primaryColor),
                          _buildNutrientsCard(additionalNutrients, customColors, primaryColor),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            _buildBottomActionBar(customColors, primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(FoodItem food, CustomColors customColors) {
    return SliverAppBar(
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
                  color: customColors.cardBackground,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
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
          food.name,
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
                Colors.grey.withOpacity(0.2),
                Theme.of(context).scaffoldBackgroundColor,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 0),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Food Nutrition",
                            style: AppTypography.h1.copyWith(
                              color: customColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (food.brandName.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              food.brandName,
                              style: AppTypography.body1.copyWith(
                                color: customColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        Consumer<SavedFoodProvider>(
          builder: (context, savedProvider, _) {
            final bool isSaved = savedProvider.isFoodSaved(widget.food.fdcId);
            return IconButton(
              icon: Icon(
                isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: customColors.textPrimary,
              ),
              onPressed: () async {
                try {
                  if (isSaved) {
                    final saved = savedProvider.getSavedFoodByFoodId(widget.food.fdcId);
                    if (saved != null) {
                      await savedProvider.removeSavedFood(saved.id);
                    }
                  } else {
                    final foodToSave = _createFoodItemWithSelectedServing();
                    await savedProvider.addSavedFood(foodToSave);
                  }
                } catch (_) {
                  // The provider rolls the change back; say why the icon flipped back.
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isSaved
                          ? 'Couldn\'t remove from saved foods. Check your connection and try again.'
                          : 'Couldn\'t save this food. Check your connection and try again.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            );
          },
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildMacroCard(FoodItem food, CustomColors customColors, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: customColors.cardBackground,
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
          Text(
            food.name,
            style: AppTypography.h2.copyWith(
              color: customColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: MacroInfoBox(
                      icon: "🔥",
                      iconColor: Colors.black,
                      value: double.tryParse(getNutrientValue("calories"))?.toStringAsFixed(0) ?? "0",
                      label: "Calories",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MacroInfoBox(
                      icon: "🍗",
                      iconColor: Colors.black,
                      value: getNutrientValue("protein"),
                      label: "Protein (g)",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: MacroInfoBox(
                      icon: "🟫",
                      iconColor: Colors.black,
                      value: getNutrientValue("carbohydrate"),
                      label: "Carbs (g)",
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: MacroInfoBox(
                      icon: "🥑",
                      iconColor: Colors.black,
                      value: getNutrientValue("fat"),
                      label: "Fat (g)",
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMealSelector(CustomColors customColors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            "Add to Meal",
            style: AppTypography.body2.copyWith(
              color: customColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 60,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: customColors.dateNavigatorBackground.withOpacity(0.6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: mealOptions.map((meal) {
              final isSelected = meal == selectedMeal;
              final mealColor = Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFFBBC05).withOpacity(0.8)
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
                          color: isSelected ? Colors.white : customColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
    );
  }

  Widget _buildQuantitySelector(CustomColors customColors, Color primaryColor) {
    return Column(
      children: [
        const SizedBox(height: 24),
        if (widget.food.servings.isNotEmpty)
          _buildServingSelectorCard(customColors, primaryColor),
        QuantitySelector(
          presetMultipliers: presetMultipliers,
          selectedMultiplier: selectedMultiplier,
          onMultiplierSelected: (multiplier) {
            setState(() {
              selectedMultiplier = multiplier;
              if (selectedServing != null) {
                double baseAmount = selectedServing!.metricAmount;
                quantityController.text = (baseAmount * multiplier).toStringAsFixed(multiplier % 1 == 0 ? 0 : 1);
              } else {
                quantityController.text = (100 * multiplier).toStringAsFixed(multiplier % 1 == 0 ? 0 : 1);
              }
            });
          },
        ),
        _buildQuantityInput(customColors, primaryColor),
      ],
    );
  }

  Widget _buildServingSelectorCard(CustomColors customColors, Color primaryColor) {
    return Container(
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
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: min(4, widget.food.servings.length),
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => _buildServingCard(index, customColors, primaryColor),
            ),
          ),
          if (widget.food.servings.length > 4)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: TextButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _showServingSelector(context);
                  },
                  icon: Icon(
                    Icons.view_list_rounded,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white70
                        : primaryColor,
                    size: 18,
                  ),
                  label: Text(
                    "View all servings",
                    style: AppTypography.body2.copyWith(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white70
                          : primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    backgroundColor: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF334155).withOpacity(0.6)
                        : primaryColor.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildServingCard(int index, CustomColors customColors, Color primaryColor) {
    final serving = widget.food.servings[index];
    final isSelected = selectedServing?.description == serving.description;

    final cardColor = isSelected
        ? Theme.of(context).brightness == Brightness.dark
            ? customColors.cardBackground.withOpacity(1)
            : primaryColor
        : Theme.of(context).brightness == Brightness.dark
            ? customColors.cardBackground.withOpacity(0.05)
            : primaryColor.withOpacity(0.05);

    final textColor = isSelected
        ? Colors.white
        : Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withOpacity(0.87)
            : primaryColor;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          selectedServing = serving;
          quantityController.text = serving.metricAmount.toString();
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
                ? Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF64748B)
                    : primaryColor
                : Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF475569).withOpacity(0.5)
                    : primaryColor.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF0F172A).withOpacity(0.5)
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
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.15)
                    : Theme.of(context).brightness == Brightness.dark
                        ? Colors.white.withOpacity(0.1)
                        : primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isSelected
                    ? Icon(Icons.check_rounded, color: textColor, size: 18)
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
            Text(
              serving.description.length > 18
                  ? '${serving.description.substring(0, 15)}...'
                  : serving.description,
              style: AppTypography.body2.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              "${serving.metricAmount} ${serving.metricUnit}",
              style: AppTypography.caption.copyWith(
                color: isSelected ? textColor.withOpacity(0.9) : customColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "${serving.calories.toStringAsFixed(0)} kcal",
              style: AppTypography.caption.copyWith(
                color: isSelected
                    ? textColor
                    : Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFBBC05)
                        : primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityInput(CustomColors customColors, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onEditingComplete: () {
                    FocusScope.of(context).unfocus();
                    setState(() => selectedMultiplier = 0);
                  },
                  onSubmitted: (value) {
                    FocusScope.of(context).unfocus();
                    setState(() => selectedMultiplier = 0);
                  },
                  onChanged: (value) => setState(() => selectedMultiplier = 0),
                  style: AppTypography.body1.copyWith(
                    color: customColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    labelText: "Quantity",
                    labelStyle: TextStyle(color: customColors.textSecondary),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: customColors.dateNavigatorBackground),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: primaryColor, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
                  ),
                ),
              ),
              if (selectedServing != null &&
                  ['g', 'oz'].contains(selectedServing!.metricUnit.toLowerCase())) ...[
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _buildUnitDropdown(customColors, primaryColor),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUnitDropdown(CustomColors customColors, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: customColors.dateNavigatorBackground),
      ),
      child: DropdownButtonFormField<String>(
        value: selectedUnit,
        items: unitOptions
            .map((unit) => DropdownMenuItem(value: unit, child: Text(unit)))
            .toList(),
        onChanged: (val) {
          if (val == selectedUnit) return;
          double currentQty = double.tryParse(quantityController.text) ?? 0.0;

          setState(() {
            if (val == "oz" && selectedUnit == "g") {
              quantityController.text = (currentQty / 28.35).toStringAsFixed(1);
            } else if (val == "g" && selectedUnit == "oz") {
              quantityController.text = (currentQty * 28.35).toStringAsFixed(0);
            }
            selectedUnit = val!;
            selectedMultiplier = 0;
          });
        },
        decoration: InputDecoration(
          labelText: "Unit",
          labelStyle: TextStyle(color: customColors.textSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        style: AppTypography.body1.copyWith(
          color: customColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
        icon: Icon(Icons.arrow_drop_down_rounded, color: customColors.textPrimary),
        dropdownColor: customColors.cardBackground,
        isExpanded: true,
      ),
    );
  }

  Widget _buildNutrientsCard(Map<String, String> nutrients, CustomColors customColors, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
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
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.pie_chart_rounded,
                  color: primaryColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                "Nutrition Facts",
                style: AppTypography.h3.copyWith(
                  color: customColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showNutrientsSheet(context),
                icon: Icon(Icons.open_in_full_rounded, size: 16, color: primaryColor),
                label: Text(
                  "View All",
                  style: AppTypography.body2.copyWith(
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
            ),
            child: Column(
              children: [
                NutrientRow(
                  name: 'Calories',
                  value: nutrients['Calories'] ?? '0 kcal',
                  isHighlighted: true,
                ),
                Divider(color: customColors.dateNavigatorBackground),
                NutrientRow(
                  name: 'Protein',
                  value: nutrients['Protein'] ?? '0g',
                  isHighlighted: true,
                ),
                Divider(color: customColors.dateNavigatorBackground),
                NutrientRow(
                  name: 'Carbohydrates',
                  value: nutrients['Carbohydrates'] ?? '0g',
                  isHighlighted: true,
                ),
                Divider(color: customColors.dateNavigatorBackground),
                NutrientRow(
                  name: 'Fat',
                  value: nutrients['Fat'] ?? '0g',
                  isHighlighted: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(CustomColors customColors, Color primaryColor) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).scaffoldBackgroundColor.withOpacity(0.1),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Container(
          height: 60,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFFC107), Color(0xFFFFB300)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFFC107).withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _addFoodEntry,
              borderRadius: BorderRadius.circular(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_circle_outline, color: Colors.black87),
                  const SizedBox(width: 8),
                  Text(
                    "Add to $selectedMeal",
                    style: AppTypography.button.copyWith(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
