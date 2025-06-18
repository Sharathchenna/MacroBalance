import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/models/food.dart';
import 'package:macrotracker/screens/foodDetail.dart';
import 'package:macrotracker/widgets/quantity_selector.dart';
import 'package:macrotracker/widgets/food_detail_components.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/saved_food_provider.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:uuid/uuid.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/theme/typography.dart';
import 'dart:ui';

class AIFoodDetailPage extends StatefulWidget {
  final AIFoodItem food;

  const AIFoodDetailPage({
    super.key,
    required this.food,
  });

  @override
  State<AIFoodDetailPage> createState() => _AIFoodDetailPageState();
}

class _AIFoodDetailPageState extends State<AIFoodDetailPage>
    with SingleTickerProviderStateMixin {
  int selectedServingIndex = 0;
  String selectedMeal = 'Breakfast';
  final List<String> mealOptions = ["Breakfast", "Lunch", "Snacks", "Dinner"];
  final List<double> presetMultipliers = [
    0.5,
    1.0,
    1.5,
    2.0,
  ];
  double selectedMultiplier = 1.0;
  late TextEditingController quantityController;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;
  final _scrollController = ScrollController();
  bool _showFloatingTitle = false;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller first
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Then initialize the animations that depend on it
    _fadeInAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // Initialize other controllers
    quantityController = TextEditingController(text: '1.0');

    // Add scroll listener
    _scrollController.addListener(_onScroll);

    // Start the animation
    _animationController.forward();
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

  Map<String, double> getMacroPercentages() {
    final nutrition = widget.food.getNutritionForIndex(
      selectedServingIndex,
      double.tryParse(quantityController.text) ?? 1.0,
    );

    double total = nutrition.protein + nutrition.carbohydrates + nutrition.fat;
    if (total <= 0) return {"carbs": 0.33, "protein": 0.33, "fat": 0.34};

    return {
      "carbs": nutrition.carbohydrates / total,
      "protein": nutrition.protein / total,
      "fat": nutrition.fat / total,
    };
  }

  FoodItem _convertToFoodItem() {
    // Use the currently selected serving size for the conversion
    final selectedServing = widget.food.servingSizes[selectedServingIndex];
    
    // Create a ServingInfo object for the selected serving
    final servingInfo = ServingInfo(
      description: selectedServing,
      amount: 1.0,
      unit: 'serving',
      metricAmount: 1.0,
      metricUnit: 'serving',
      calories: widget.food.calories[selectedServingIndex],
      carbohydrate: widget.food.carbohydrates[selectedServingIndex],
      protein: widget.food.protein[selectedServingIndex],
      fat: widget.food.fat[selectedServingIndex],
      saturatedFat: 0.0, // Default value since AI food doesn't have this
      fiber: widget.food.fiber[selectedServingIndex],
    );
    
    return FoodItem(
      id: widget.food.name.hashCode.toString(),
      name: widget.food.name,
      brandName: 'AI Detected',
      foodType: 'AI Food',
      servings: [servingInfo],
      nutrients: {
        'Protein': widget.food.protein[selectedServingIndex],
        'Carbohydrate, by difference': widget.food.carbohydrates[selectedServingIndex],
        'Total lipid (fat)': widget.food.fat[selectedServingIndex],
        'Fiber': widget.food.fiber[selectedServingIndex],
      },
    );
  }

  void _saveFood() async {
    final savedFoodProvider = Provider.of<SavedFoodProvider>(context, listen: false);
    final foodItem = _convertToFoodItem();
    
    try {
      await savedFoodProvider.addSavedFood(foodItem);
      
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.bookmark_added_rounded, 
                     color: Theme.of(context).colorScheme.onPrimary),
                const SizedBox(width: 8),
                Text(
                  'Food saved successfully!',
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFFFC107),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(8),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save food: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(8),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    final nutrition = widget.food.getNutritionForIndex(
      selectedServingIndex,
      double.tryParse(quantityController.text) ?? 1.0,
    );
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
                SliverAppBar(
                  expandedHeight: 140.0,
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
                  actions: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Consumer<SavedFoodProvider>(
                        builder: (context, savedFoodProvider, child) {
                          final foodId = widget.food.name.hashCode.toString();
                          final isSaved = savedFoodProvider.isFoodSaved(foodId);
                          
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                if (isSaved) {
                                  // Show already saved message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Food is already saved!'),
                                      backgroundColor: Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      margin: const EdgeInsets.all(8),
                                      duration: const Duration(seconds: 1),
                                    ),
                                  );
                                } else {
                                  _saveFood();
                                }
                              },
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
                                  isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                  color: isSaved ? const Color(0xFFFFC107) : customColors.textPrimary,
                                  size: 20,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  title: AnimatedOpacity(
                    opacity: _showFloatingTitle ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      "Food Nutrition",
                      style: TextStyle(
                        color: Theme.of(context)
                            .extension<CustomColors>()!
                            .textPrimary,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Food Nutrition",
                                        style: AppTypography.h1.copyWith(
                                          color: Theme.of(context)
                                              .extension<CustomColors>()!
                                              .textPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
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
                                // Food title
                                Text(
                                  widget.food.name,
                                  style: AppTypography.h2.copyWith(
                                    color: customColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(height: 20),

                                // Macro info grid (now in column)
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // First row: Calories and Protein
                                    Row(
                                      children: [
                                        // Calories
                                        Expanded(
                                          child: MacroInfoBox(
                                            icon: "🔥",
                                            iconColor: Colors.black,
                                            value: nutrition.calories
                                                .toStringAsFixed(0),
                                            label: "Calories",
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        // Protein
                                        Expanded(
                                          child: MacroInfoBox(
                                            icon: "🍗",
                                            iconColor: Colors.black,
                                            value: nutrition.protein
                                                .toStringAsFixed(1),
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
                                            value: nutrition.carbohydrates
                                                .toStringAsFixed(1),
                                            label: "Carbs (g)",
                                          ),
                                        ),

                                        const SizedBox(width: 12),

                                        // Fat
                                        Expanded(
                                          child: MacroInfoBox(
                                            icon: "🥑",
                                            iconColor: Colors.black,
                                            value: nutrition.fat
                                                .toStringAsFixed(1),
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
                          // Add Meal Type Section here
                          Column(
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
                                  color: customColors!.dateNavigatorBackground
                                      .withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: mealOptions.map((meal) {
                                    final isSelected = meal == selectedMeal;
                                    final mealColor =
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Color(0xFFFBBC05).withOpacity(0.8)
                                            : customColors.textPrimary;

                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          setState(() => selectedMeal = meal);
                                        },
                                        child: AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? mealColor
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          child: Center(
                                            child: Text(
                                              meal,
                                              style: TextStyle(
                                                color: isSelected
                                                    ? Colors.white
                                                    : customColors
                                                        .textSecondary,
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
                          // Add Serving Size Section here
                          // Padding(
                          //   padding: const EdgeInsets.symmetric(
                          //       vertical: 16, horizontal: 4),
                          //   child: Text(
                          //     "Serving Size",
                          //     style: AppTypography.h2.copyWith(
                          //       color: customColors.textPrimary,
                          //       fontWeight: FontWeight.bold,
                          //     ),
                          //   ),
                          // ),
                          const SizedBox(height: 24),

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
                                        color: customColors.textSecondary
                                            .withOpacity(0.15),
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
                                        color: Theme.of(context).brightness ==
                                                Brightness.dark
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
                                    itemCount: widget.food.servingSizes.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final isSelected =
                                          selectedServingIndex == index;
                                      final servingSize =
                                          widget.food.servingSizes[index];
                                      final calories =
                                          widget.food.calories[index];

                                      return GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          setState(() {
                                            selectedServingIndex = index;
                                            selectedMultiplier = 1.0;
                                            quantityController.text = '1.0';
                                          });
                                        },
                                        child: Container(
                                          width: 140,
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? customColors
                                                        .cardBackground
                                                        .withOpacity(1)
                                                    : primaryColor
                                                : Theme.of(context)
                                                            .brightness ==
                                                        Brightness.dark
                                                    ? customColors
                                                        .cardBackground
                                                        .withOpacity(0.05)
                                                    : primaryColor
                                                        .withOpacity(0.05),
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isSelected
                                                  ? primaryColor
                                                  : primaryColor
                                                      .withOpacity(0.2),
                                              width: isSelected ? 2 : 1,
                                            ),
                                          ),
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: isSelected
                                                      ? Colors.white
                                                          .withOpacity(0.3)
                                                      : primaryColor
                                                          .withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Center(
                                                  child: isSelected
                                                      ? Icon(
                                                          Icons.check_rounded,
                                                          color: Colors.white,
                                                          size: 18,
                                                        )
                                                      : Text(
                                                          "${index + 1}",
                                                          style: TextStyle(
                                                            color: primaryColor,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                ),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                servingSize,
                                                style: AppTypography.body2
                                                    .copyWith(
                                                  color: isSelected
                                                      ? Colors.white
                                                      : customColors
                                                          .textPrimary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const Spacer(),
                                              Text(
                                                "$calories kcal",
                                                style: AppTypography.caption
                                                    .copyWith(
                                                  color: isSelected
                                                      ? Colors.white
                                                          .withOpacity(0.9)
                                                      : Color(0xFFFBBC05),
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

                          // Quantity Selector
                          QuantitySelector(
                            presetMultipliers: presetMultipliers,
                            selectedMultiplier: selectedMultiplier,
                            onMultiplierSelected: (multiplier) {
                              setState(() {
                                selectedMultiplier = multiplier;
                                quantityController.text =
                                    (multiplier).toStringAsFixed(1);
                              });
                            },
                          ),

                          // Add Quantity Input Section
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
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: TextField(
                                        controller: quantityController,
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                                decimal: true),
                                        textInputAction: TextInputAction.done,
                                        onEditingComplete: () {
                                          FocusScope.of(context).unfocus();
                                          setState(
                                              () => selectedMultiplier = 0);
                                        },
                                        onSubmitted: (value) {
                                          FocusScope.of(context).unfocus();
                                          setState(
                                              () => selectedMultiplier = 0);
                                        },
                                        onChanged: (value) {
                                          setState(
                                              () => selectedMultiplier = 0);
                                        },
                                        style: AppTypography.body1.copyWith(
                                          color: customColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: "Quantity",
                                          labelStyle: TextStyle(
                                            color: customColors.textSecondary,
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: customColors!
                                                  .dateNavigatorBackground,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                            borderSide: BorderSide(
                                              color: primaryColor,
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 10),

                          const SizedBox(height: 24),
                          Text(
                            "Nutrition Facts",
                            style: AppTypography.h2.copyWith(
                              color: customColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Main nutrients section
                          NutrientSection(
                            title: "Macronutrients",
                            nutrients: [
                              MapEntry("Calories",
                                  "${nutrition.calories.toStringAsFixed(0)} kcal"),
                              MapEntry("Protein",
                                  "${nutrition.protein.toStringAsFixed(1)}g"),
                              MapEntry("Carbohydrates",
                                  "${nutrition.carbohydrates.toStringAsFixed(1)}g"),
                              MapEntry("Fat",
                                  "${nutrition.fat.toStringAsFixed(1)}g"),
                              MapEntry("Fiber",
                                  "${nutrition.fiber.toStringAsFixed(1)}g"),
                            ],
                            accentColor: primaryColor,
                            dividerColor:
                                customColors?.dateNavigatorBackground ??
                                    Colors.grey,
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
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
                      Theme.of(context)
                          .scaffoldBackgroundColor
                          .withOpacity(0.1),
                      Theme.of(context).scaffoldBackgroundColor,
                    ],
                  ),
                ),
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.black.withValues(alpha: 0.3)
                          : Colors.white.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      _addToMeal();
                    },
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
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Container(
                              height: 60,
                              alignment: Alignment.center,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(width: 8),
                                  Text(
                                    'Add to Diary',
                                    style: AppTypography.button.copyWith(
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.black
                                          : const Color(0xFFFFC107)
                                              .withValues(alpha: 0.9),
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToMeal() {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);

    // Get the selected quantity
    final double quantity = double.tryParse(quantityController.text) ?? 1.0;
    print('--- AIFoodDetailPage Debug ---'); // Log Start
    print('Raw quantity input: ${quantityController.text}'); // Log Raw Input
    print('Parsed quantity: $quantity'); // Log Parsed Quantity

    // Calculate nutrition based on selected serving and quantity
    final nutrition = widget.food.getNutritionForIndex(
      selectedServingIndex,
      quantity,
    );
    print(
        'Calculated Nutrition for quantity $quantity:'); // Log Calculated Nutrition
    print('  Calories: ${nutrition.calories}');
    print('  Protein: ${nutrition.protein}');
    print('  Carbs: ${nutrition.carbohydrates}');
    print('  Fat: ${nutrition.fat}');

    // Get the current serving size description
    final String servingDescription =
        widget.food.servingSizes[selectedServingIndex];
    print(
        'Selected serving description: $servingDescription'); // Log Serving Description

    // Create food entry with proper serving information
    final entry = FoodEntry(
      id: const Uuid().v4(),
      food: FoodEntry.createFood(
        fdcId: widget.food.name.hashCode
            .toString(), // Use a unique ID if available, otherwise hash is okay
        name: widget.food.name,
        brandName: 'AI Detected',
        // *** FIX: Store the BASE nutrition values for the selected serving, NOT the calculated totals ***
        calories: widget.food.calories[selectedServingIndex],
        nutrients: {
          'Protein': widget.food.protein[selectedServingIndex],
          'Carbohydrate, by difference':
              widget.food.carbohydrates[selectedServingIndex],
          'Total lipid (fat)': widget.food.fat[selectedServingIndex],
          'Fiber': widget.food.fiber[selectedServingIndex],
        },
        mealType: selectedMeal,
      ),
      meal: selectedMeal,
      quantity: quantity, // Store the multiplier/quantity
      unit: 'serving', // Unit reflects the selected serving size
      date: dateProvider.selectedDate,
      servingDescription:
          "$quantity x $servingDescription", // Combine quantity and original description
    );
    print('Created FoodEntry object:'); // Log FoodEntry Object
    print('  ID: ${entry.id}');
    print('  Food Name: ${entry.food.name}');
    print('  Calories (in entry): ${entry.food.calories}');
    print('  Protein (in entry): ${entry.food.nutrients['Protein']}');
    print('  Quantity (in entry): ${entry.quantity}');
    print('  Serving Description (in entry): ${entry.servingDescription}');
    print('--- End AIFoodDetailPage Debug ---'); // Log End

    // Add entry to provider
    foodEntryProvider.addEntry(entry);

    // Pop back to camera results page
    Navigator.pop(context);

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.onPrimary),
            const SizedBox(width: 8),
            Text(
              'Added to $selectedMeal',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFFFC107),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(8),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
