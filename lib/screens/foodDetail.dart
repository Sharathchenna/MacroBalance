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
import '../services/posthog_service.dart';
import '../providers/saved_food_provider.dart';
import 'food_detail/components/components.dart';
import '../main.dart' show navigatorKey;
import '../providers/weight_unit_provider.dart';
import '../utils/meal_time.dart';
import '../utils/number_format.dart';

class FoodDetailPage extends StatefulWidget {
  final FoodItem food;
  final String? selectedMeal;

  /// When set, the page edits this logged entry instead of adding a new one.
  final FoodEntry? existingEntry;

  const FoodDetailPage({
    super.key,
    required this.food,
    this.selectedMeal,
    this.existingEntry,
  });

  @override
  _FoodDetailPageState createState() => _FoodDetailPageState();
}

class _FoodDetailPageState extends State<FoodDetailPage>
    with SingleTickerProviderStateMixin {
  final List<String> mealOptions = MealTime.meals;
  final List<double> presetServings = [0.5, 1.0, 1.5, 2.0];

  late String selectedMeal;
  double selectedMultiplier = 1.0;

  /// Number of servings when a serving is selected; grams or ounces in
  /// weight mode (selectedServing == null).
  late TextEditingController quantityController;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<double> _slideAnimation;
  Serving? selectedServing;

  /// 'g' or 'oz', from the user's unit system.
  late String _weightUnit;

  final _scrollController = ScrollController();
  bool _showFloatingTitle = false;

  bool get _isEditing => widget.existingEntry != null;
  bool get _weightMode => selectedServing == null;

  /// The food's servings. AI foods logged from the AI screens carry no list,
  /// so their one stored serving is shown as a single option.
  late final List<Serving> _servings = _buildServingOptions();

  List<Serving> _buildServingOptions() {
    if (widget.food.servings.isNotEmpty) return widget.food.servings;
    if (widget.food.brandName == 'AI Detected') {
      return [
        Serving(
          description: _aiServingLabel(widget.existingEntry?.servingDescription),
          metricAmount: 1,
          metricUnit: 'serving',
          calories: widget.food.calories,
          nutrients: widget.food.nutrients,
        ),
      ];
    }
    return [];
  }

  // AI entries store "<qty> x <serving>"; the option shows just the serving.
  static String _aiServingLabel(String? description) {
    if (description == null || description.isEmpty) return '1 serving';
    return description.replaceAll(RegExp(r'^\d+(\.\d+)?\s*x\s*'), '').trim();
  }

  /// A serving measured in g or oz, used to price a weight amount.
  Serving? get _weightBase {
    for (final serving in _servings) {
      final unit = serving.metricUnit.toLowerCase();
      if ((unit == 'g' || unit == 'oz') && serving.metricAmount > 0) return serving;
    }
    return null;
  }

  /// Weight mode needs either a g/oz serving or per-100 g data.
  bool get _weightOptionAvailable =>
      _weightBase != null ||
      (_servings.isEmpty && widget.food.brandName != 'AI Detected');

  @override
  void initState() {
    super.initState();
    _weightUnit = Provider.of<WeightUnitProvider>(context, listen: false).foodUnit;
    final existing = widget.existingEntry;
    selectedMeal = existing?.meal ?? widget.selectedMeal ?? MealTime.suggested();
    PostHogService.trackScreen(_isEditing ? 'edit_food_entry' : 'food_detail_page');

    if (existing != null) {
      _initFromEntry(existing);
    } else if (_servings.isNotEmpty) {
      selectedServing = _servings.first;
      quantityController = TextEditingController(text: '1');
    } else {
      quantityController = TextEditingController(
          text: _weightUnit == 'oz' ? '3.5' : formatNumber(widget.food.servingSize));
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

  /// Opens a logged entry as servings when it divides into a tidy count,
  /// otherwise as the weight that was logged.
  void _initFromEntry(FoodEntry entry) {
    Serving? match;
    for (final serving in _servings) {
      if (serving.description == entry.servingDescription ||
          serving.description == _aiServingLabel(entry.servingDescription)) {
        match = serving;
        break;
      }
    }
    final entryUnit = entry.unit.toLowerCase();
    final isWeightEntry = entryUnit == 'g' || entryUnit == 'oz';

    if (match != null) {
      final servingUnit = match.metricUnit.toLowerCase();
      final base = match.metricAmount > 0 ? match.metricAmount : 1.0;
      if (!isWeightEntry || servingUnit == entryUnit) {
        final count = entry.quantity / base;
        final tidy = (count * 4 - (count * 4).round()).abs() < 0.001;
        if (!isWeightEntry || tidy) {
          selectedServing = match;
          quantityController = TextEditingController(text: formatNumber(count, maxDecimals: 2));
          return;
        }
      }
    }
    // Weight mode in the unit the entry was logged in.
    selectedServing = null;
    _weightUnit = isWeightEntry ? entryUnit : _weightUnit;
    quantityController = TextEditingController(text: formatNumber(entry.quantity));
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

  double get _amount {
    final value = parseAmount(quantityController.text) ?? 0;
    return value < 0 ? 0 : value;
  }

  /// The entry as it would be logged right now. Every figure on this page is
  /// calculated from it with the same function the dashboard uses, so what you
  /// see here is what gets counted.
  FoodEntry _draftEntry() {
    final existing = widget.existingEntry;
    final serving = selectedServing;
    double quantity;
    String unit;
    String? servingDescription;
    if (serving != null) {
      final base = serving.metricAmount > 0 ? serving.metricAmount : 1.0;
      final servingUnit = serving.metricUnit.toLowerCase();
      quantity = _amount * base;
      unit = (servingUnit == 'g' || servingUnit == 'oz') ? servingUnit : serving.metricUnit;
      servingDescription = serving.description;
    } else {
      quantity = _amount;
      unit = _weightUnit;
      servingDescription = _weightBase?.description;
    }
    return FoodEntry(
      id: existing?.id ?? const Uuid().v4(),
      food: widget.food,
      meal: selectedMeal,
      quantity: quantity,
      unit: unit,
      date: existing?.date ??
          Provider.of<DateProvider>(context, listen: false).selectedDate,
      servingDescription: servingDescription,
    );
  }

  double _nutrient(String key) => FoodEntryProvider.nutrientForEntry(_draftEntry(), key);

  String getNutrientValue(String nutrient) {
    const keys = {
      'calories': 'calories',
      'protein': 'Protein',
      'carbohydrate': 'Carbohydrate, by difference',
      'fat': 'Total lipid (fat)',
    };
    return _nutrient(keys[nutrient.toLowerCase()] ?? nutrient).toStringAsFixed(1);
  }

  Map<String, String> getAdditionalNutrients() {
    final result = <String, String>{
      'Calories': '${formatNumber(_nutrient('calories'))} kcal',
      'Protein': '${formatNumber(_nutrient('Protein'))}g',
      'Carbohydrates': '${formatNumber(_nutrient('Carbohydrate, by difference'))}g',
      'Fat': '${formatNumber(_nutrient('Total lipid (fat)'))}g',
    };
    final source = (selectedServing ?? _weightBase)?.nutrients ?? widget.food.nutrients;
    for (final key in source.keys) {
      if (['Protein', 'Carbohydrate, by difference', 'Total lipid (fat)'].contains(key)) {
        continue;
      }
      result[key] = '${formatNumber(_nutrient(key))}${_getNutrientUnit(key)}';
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
    if (_amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter an amount greater than 0'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final foodEntryProvider = Provider.of<FoodEntryProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final entry = _draftEntry();
    MealTime.remember(selectedMeal);

    if (_isEditing) {
      final previous = widget.existingEntry!;
      await foodEntryProvider.updateEntry(entry);
      PostHogService.trackEvent('food_entry_edited', properties: {
        'meal_type': selectedMeal,
        'meal_changed': previous.meal != selectedMeal,
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Updated ${widget.food.name}'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => foodEntryProvider.updateEntry(previous),
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

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

    final amountLabel = selectedServing != null
        ? '${formatServings(_amount)} × ${selectedServing!.description}'
        : '${formatNumber(_amount)} $_weightUnit';
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Added ${widget.food.name} ($amountLabel) to $selectedMeal',
          overflow: TextOverflow.ellipsis,
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => foodEntryProvider.removeEntry(entry.id),
        ),
      ),
    );

    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _deleteEntry() async {
    final entry = widget.existingEntry!;
    final foodEntryProvider = Provider.of<FoodEntryProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    await foodEntryProvider.removeEntry(entry.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('Removed ${entry.food.name}'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => foodEntryProvider.addEntry(entry),
        ),
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  void _selectServing(Serving? serving) {
    HapticFeedback.selectionClick();
    setState(() {
      if (serving == null) {
        // Switching to weight: start from the current amount's weight.
        final grams = selectedServing != null ? _draftWeightInGrams() : null;
        selectedServing = null;
        quantityController.text = grams != null
            ? formatNumber(_weightUnit == 'oz' ? grams / 28.35 : grams)
            : (_weightUnit == 'oz' ? '3.5' : '100');
      } else {
        selectedServing = serving;
        quantityController.text = '1';
      }
      selectedMultiplier = selectedServing == null ? 0 : 1.0;
    });
  }

  double? _draftWeightInGrams() {
    final serving = selectedServing;
    if (serving == null) return null;
    final unit = serving.metricUnit.toLowerCase();
    if (unit == 'g') return serving.metricAmount * _amount;
    if (unit == 'oz') return serving.metricAmount * _amount * 28.35;
    return null;
  }

  void _showServingSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ServingSelectorSheet(
        servings: _servings,
        selectedServing: selectedServing,
        onServingSelected: (serving) {
          _selectServing(serving);
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
    for (var serving in _servings) {
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
                            _isEditing ? "Edit Entry" : "Food Nutrition",
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
              tooltip: isSaved ? 'Remove from saved foods' : 'Save this food',
              onPressed: () async {
                HapticFeedback.lightImpact();
                final messenger = ScaffoldMessenger.of(context);
                try {
                  if (isSaved) {
                    final saved = savedProvider.getSavedFoodByFoodId(widget.food.fdcId);
                    if (saved != null) {
                      await savedProvider.removeSavedFood(saved.id);
                      messenger.showSnackBar(
                        SnackBar(
                          content: const Text('Removed from your saved foods'),
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(
                            label: 'Undo',
                            onPressed: () => savedProvider.addSavedFood(saved.food),
                          ),
                        ),
                      );
                    }
                  } else {
                    final foodToSave = _createFoodItemWithSelectedServing();
                    await savedProvider.addSavedFood(foodToSave);
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Saved to your foods'),
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'View',
                          onPressed: () => navigatorKey.currentState?.pushNamed('/savedFoods'),
                        ),
                      ),
                    );
                  }
                } catch (_) {
                  // The provider rolls the change back; say why the icon flipped back.
                  if (!context.mounted) return;
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
                    MealTime.remember(meal);
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
        if (_servings.isNotEmpty)
          _buildServingSelectorCard(customColors, primaryColor),
        if (!_weightMode)
          QuantitySelector(
            presetMultipliers: presetServings,
            selectedMultiplier: selectedMultiplier,
            onMultiplierSelected: (count) {
              setState(() {
                selectedMultiplier = count;
                quantityController.text = formatNumber(count, maxDecimals: 2);
              });
            },
          ),
        _buildQuantityInput(customColors, primaryColor),
      ],
    );
  }

  Widget _buildServingSelectorCard(CustomColors customColors, Color primaryColor) {
    // Serving options first, then weight ("Grams"/"Ounces") when it can be priced.
    final visibleServings = _servings.take(4).toList();
    final optionCount = visibleServings.length + (_weightOptionAvailable ? 1 : 0);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
                "Serving",
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
              itemCount: optionCount,
              separatorBuilder: (context, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) => index < visibleServings.length
                  ? _buildServingCard(index, customColors, primaryColor)
                  : _buildWeightOptionCard(customColors, primaryColor),
            ),
          ),
          if (_servings.length > 4)
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
    final serving = _servings[index];
    final isSelected = selectedServing?.description == serving.description;
    final unit = serving.metricUnit.toLowerCase();
    final showAmount = unit != 'serving' && unit != 'unit' && serving.metricAmount > 0;
    return _buildOptionCard(
      isSelected: isSelected,
      badge: "${index + 1}",
      title: serving.description,
      subtitle: showAmount ? "${formatNumber(serving.metricAmount)} ${serving.metricUnit}" : null,
      trailing: "${serving.calories.toStringAsFixed(0)} kcal",
      onTap: () => _selectServing(serving),
      customColors: customColors,
      primaryColor: primaryColor,
    );
  }

  Widget _buildWeightOptionCard(CustomColors customColors, Color primaryColor) {
    return _buildOptionCard(
      isSelected: _weightMode,
      badge: _weightUnit,
      title: _weightUnit == 'oz' ? 'Ounces' : 'Grams',
      subtitle: 'Enter by weight',
      trailing: null,
      onTap: () => _selectServing(null),
      customColors: customColors,
      primaryColor: primaryColor,
    );
  }

  Widget _buildOptionCard({
    required bool isSelected,
    required String badge,
    required String title,
    required String? subtitle,
    required String? trailing,
    required VoidCallback onTap,
    required CustomColors customColors,
    required Color primaryColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isSelected
        ? isDark
            ? customColors.cardBackground.withOpacity(1)
            : primaryColor
        : isDark
            ? customColors.cardBackground.withOpacity(0.05)
            : primaryColor.withOpacity(0.05);

    final textColor = isSelected
        ? Colors.white
        : isDark
            ? Colors.white.withOpacity(0.87)
            : primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? isDark
                    ? const Color(0xFF64748B)
                    : primaryColor
                : isDark
                    ? const Color(0xFF475569).withOpacity(0.5)
                    : primaryColor.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: isDark
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
                    : isDark
                        ? Colors.white.withOpacity(0.1)
                        : primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: isSelected
                    ? Icon(Icons.check_rounded, color: textColor, size: 18)
                    : Text(
                        badge,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTypography.body2.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            if (subtitle != null)
              Text(
                subtitle,
                style: AppTypography.caption.copyWith(
                  color: isSelected ? textColor.withOpacity(0.9) : customColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            if (trailing != null) ...[
              const SizedBox(height: 4),
              Text(
                trailing,
                style: AppTypography.caption.copyWith(
                  color: isSelected
                      ? textColor
                      : isDark
                          ? const Color(0xFFFBBC05)
                          : primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _stepServings(double delta) {
    HapticFeedback.selectionClick();
    final next = ((_amount + delta) * 4).round() / 4; // quarter-serving steps
    setState(() {
      quantityController.text = formatNumber(next < 0.25 ? 0.25 : next, maxDecimals: 2);
      selectedMultiplier = 0;
    });
  }

  Widget _buildQuantityInput(CustomColors customColors, Color primaryColor) {
    final label = _weightMode
        ? (_weightUnit == 'oz' ? 'Amount (oz)' : 'Amount (g)')
        : 'Number of servings';
    final field = TextField(
      controller: quantityController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
      textAlign: _weightMode ? TextAlign.start : TextAlign.center,
      onSubmitted: (_) => FocusScope.of(context).unfocus(),
      onChanged: (value) => setState(() => selectedMultiplier = 0),
      style: AppTypography.body1.copyWith(
        color: customColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: customColors.textSecondary),
        suffixText: _weightMode ? _weightUnit : null,
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
    );

    Widget stepButton(IconData icon, double delta) => IconButton.filledTonal(
          onPressed: () => _stepServings(delta),
          icon: Icon(icon),
          tooltip: delta > 0 ? 'Add half a serving' : 'Remove half a serving',
        );

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
      child: _weightMode
          ? field
          : Row(
              children: [
                stepButton(Icons.remove_rounded, -0.5),
                const SizedBox(width: 12),
                Expanded(child: field),
                const SizedBox(width: 12),
                stepButton(Icons.add_rounded, 0.5),
              ],
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
    final primaryButton = Container(
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
              Icon(_isEditing ? Icons.check_circle_outline : Icons.add_circle_outline,
                  color: Colors.black87),
              const SizedBox(width: 8),
              Text(
                _isEditing ? "Save Changes" : "Add to $selectedMeal",
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
    );

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
        child: _isEditing
            ? Row(
                children: [
                  SizedBox(
                    height: 60,
                    width: 60,
                    child: IconButton.outlined(
                      onPressed: _deleteEntry,
                      tooltip: 'Delete entry',
                      icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: primaryButton),
                ],
              )
            : primaryButton,
      ),
    );
  }
}
