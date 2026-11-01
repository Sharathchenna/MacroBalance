import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/camera/ai_food_detail_page.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:macrotracker/widgets/app_toast.dart';
import 'package:macrotracker/AI/gemini.dart' show PhotoAnalysisException;
import 'package:macrotracker/services/photo_analysis_service.dart';

class ResultsPage extends StatefulWidget {
  final List<AIFoodItem> foods;

  /// Meal and day to log into; set when reviewing a photo that was analysed
  /// in the background, so it lands where the photo was taken for.
  final String? meal;
  final DateTime? date;

  /// The analysed photo. With it the page offers Edit: tell the AI what's
  /// wrong and it revises the foods.
  final Uint8List? photo;

  /// What the user added about the meal in the camera.
  final String? note;

  /// Revises the foods; defaults to Gemini. Tests pass their own.
  final PhotoReviser? reviser;

  const ResultsPage({
    super.key,
    required this.foods,
    this.meal,
    this.date,
    this.photo,
    this.note,
    this.reviser,
  });

  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  late List<AIFoodItem> _foods = widget.foods;

  /// Earlier lists, newest last, for Undo.
  final List<List<AIFoodItem>> _history = [];

  bool _editing = false;

  /// The food the next correction is about; null means the whole meal.
  int? _focus;
  bool _revising = false;
  final _fixController = TextEditingController();

  String? get meal => widget.meal;
  DateTime? get date => widget.date;
  bool get _canEdit => widget.photo != null && _foods.isNotEmpty;

  @override
  void dispose() {
    _fixController.dispose();
    super.dispose();
  }

  void _toggleEditing() {
    HapticFeedback.selectionClick();
    setState(() {
      _editing = !_editing;
      _focus = null;
    });
    if (!_editing) FocusScope.of(context).unfocus();
  }

  void _toggleFocus(int index) {
    HapticFeedback.selectionClick();
    setState(() => _focus = _focus == index ? null : index);
  }

  Future<void> _revise() async {
    final note = _fixController.text.trim();
    if (note.isEmpty || _revising) return;
    final focus = _focus == null ? null : _foods[_focus!].name;
    setState(() => _revising = true);
    try {
      final revise = widget.reviser ?? PhotoAnalysisService.reviseWithGemini;
      final revised = await revise(
        widget.photo!,
        _foods,
        note,
        focusFood: focus,
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() {
        _history.add(_foods);
        _foods = revised;
        _focus = null;
        _revising = false;
        _fixController.clear();
      });
      AppToast.show(
        'Foods updated',
        icon: Icons.auto_awesome_rounded,
        actionLabel: 'Undo',
        onAction: _undo,
      );
    } on PhotoAnalysisException catch (e) {
      if (!mounted) return;
      setState(() => _revising = false);
      AppToast.show(e.message, icon: Icons.error_outline_rounded);
    } catch (_) {
      if (!mounted) return;
      setState(() => _revising = false);
      AppToast.show(
        "Couldn't update the foods. Try again.",
        icon: Icons.error_outline_rounded,
      );
    }
  }

  void _undo() {
    if (_history.isEmpty || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() {
      _foods = _history.removeLast();
      _focus = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return Scaffold(
      appBar: AppBar(
        leading: CupertinoNavigationBarBackButton(
          color: customColors!.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Detected Foods',
          style: TextStyle(
            color: customColors!.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        // actions: [
        //   TextButton.icon(
        //     onPressed: () {
        //       // Navigate to dashboard (replacing the entire stack)
        //       Navigator.of(context).pushNamedAndRemoveUntil(
        //         '/dashboard', // Your dashboard route
        //         (route) => false, // This will clear the entire navigation stack
        //       );
        //     },
        //     icon:
        //         Icon(Icons.dashboard_outlined, color: customColors.textPrimary),
        //     label: Text(
        //       'Dashboard',
        //       style: TextStyle(color: customColors.textPrimary),
        //     ),
        //   ),
        // ],
        actions: [
          if (_canEdit)
            TextButton(
              onPressed: _revising ? null : _toggleEditing,
              child: Text(
                _editing ? 'Done' : 'Edit',
                style: TextStyle(
                  color: customColors.textPrimary,
                  fontSize: 16,
                  fontWeight: _editing ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      bottomNavigationBar: _editing ? _buildFixBar(context) : null,
      body: AnimatedOpacity(
        // The foods fade back while the AI revises them.
        opacity: _revising ? 0.45 : 1,
        duration: const Duration(milliseconds: 200),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: _foods.isEmpty
              ? Center(
                  child: Text(
                    'No foods detected',
                    style: TextStyle(color: customColors.textPrimary),
                  ),
                )
              : ListView.builder(
                  key: const ValueKey('foods'),
                  itemCount: _foods.length + (widget.photo != null ? 1 : 0),
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                  itemBuilder: (context, index) {
                    if (widget.photo != null) {
                      if (index == 0) return _buildHeader(context);
                      index--;
                    }
                    return _buildFoodCard(context, _foods[index], index);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildFoodCard(BuildContext context, AIFoodItem food, int index) {
    final customColors = Theme.of(context).extension<CustomColors>();
    // Default to first serving size
    final defaultServing = food.servingSizes[0];
    final calories = food.calories[0];
    final protein = food.protein[0];
    final carbs = food.carbohydrates[0];
    final fat = food.fat[0];

    final selected = _editing && _focus == index;
    return Hero(
      // A food the AI changed gets a new key, so it animates in again.
      key: ValueKey(food.toJson().toString()),
      tag: 'food-${food.name}-$index',
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 400 + (index * 100)),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(opacity: value, child: child),
          );
        },
        child: Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: selected
                ? BorderSide(color: customColors!.accentPrimary, width: 2)
                : BorderSide.none,
          ),
          child: InkWell(
            onTap: _editing
                ? () => _toggleFocus(index)
                : () => _openFoodDetail(context, food),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Food info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              food.name,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: customColors!.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Serving: ${defaultServing}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_editing)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            selected
                                ? CupertinoIcons.checkmark_circle_fill
                                : CupertinoIcons.circle,
                            color: selected
                                ? customColors.accentPrimary
                                : customColors.textSecondary,
                          ),
                        )
                      else
                        // Add button
                        Container(
                          child: Row(
                            children: [
                              IconButton(
                                icon: Icon(
                                  CupertinoIcons.add_circled,
                                  color: customColors.textPrimary,
                                ),
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _quickAddFood(context, food);
                                },
                                tooltip: 'Add to meal',
                              ),
                              SizedBox(width: 8),
                              Icon(CupertinoIcons.chevron_right),
                            ],
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Nutrition chips row
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildNutritionChip(
                          context,
                          Icons.local_fire_department_outlined,
                          '${calories.toStringAsFixed(0)} cals',
                        ),
                        const SizedBox(width: 8),
                        _buildNutritionChip(
                          context,
                          Icons.fitness_center_outlined,
                          '${protein.toStringAsFixed(1)}g protein',
                        ),
                        const SizedBox(width: 8),
                        _buildNutritionChip(
                          context,
                          Icons.bubble_chart_outlined,
                          '${carbs.toStringAsFixed(1)}g carbs',
                        ),
                        const SizedBox(width: 8),
                        _buildNutritionChip(
                          context,
                          Icons.opacity_outlined,
                          '${fat.toStringAsFixed(1)}g fat',
                        ),
                      ],
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

  /// The photo, the meal, and in edit mode how editing works.
  Widget _buildHeader(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final count = _foods.length == 1 ? '1 food' : '${_foods.length} foods';
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              widget.photo!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meal == null ? count : '$meal · $count',
                  style: TextStyle(
                    color: customColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _editing
                      ? 'Tap a food to fix just that one, or describe a change to the whole meal.'
                      : widget.note != null
                      ? '“${widget.note}”'
                      : 'Something off? Tap Edit to tell the AI.',
                  style: TextStyle(
                    color: customColors.textSecondary,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Edit mode: what to fix, about one food or the whole meal, and Undo.
  Widget _buildFixBar(BuildContext context) {
    final customColors = Theme.of(context).extension<CustomColors>()!;
    final focus = _focus == null ? null : _foods[_focus!].name;
    return Material(
      color: customColors.cardBackground,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (focus != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InputChip(
                      label: Text(
                        'About: $focus',
                        overflow: TextOverflow.ellipsis,
                      ),
                      onDeleted: () => setState(() => _focus = null),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                Row(
                  children: [
                    if (_history.isNotEmpty)
                      IconButton(
                        onPressed: _revising ? null : _undo,
                        icon: const Icon(Icons.undo_rounded),
                        tooltip: 'Undo last change',
                        color: customColors.textPrimary,
                      ),
                    Expanded(
                      child: TextField(
                        controller: _fixController,
                        enabled: !_revising,
                        autofocus: true,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 500,
                        // Wraps over lines, but Enter sends rather than adding one.
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _revise(),
                        style: TextStyle(color: customColors.textPrimary),
                        decoration: InputDecoration(
                          counterText: '',
                          isDense: true,
                          hintText: focus != null
                              ? 'What’s different about it?'
                              : 'What should change?',
                          hintStyle: TextStyle(
                            color: customColors.textSecondary,
                          ),
                          filled: true,
                          fillColor: Theme.of(context).scaffoldBackgroundColor,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _revising
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            onPressed: _revise,
                            icon: const Icon(
                              CupertinoIcons.arrow_up_circle_fill,
                              size: 32,
                            ),
                            color: customColors.accentPrimary,
                            tooltip: 'Update foods',
                          ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionChip(
    BuildContext context,
    IconData icon,
    String label,
  ) {
    // Define specific colors for each nutrient type
    Color chipColor;
    if (label.contains('cals')) {
      chipColor = Colors.green.shade500;
    } else if (label.contains('protein')) {
      chipColor = Colors.red.shade500;
    } else if (label.contains('carbs')) {
      chipColor = Colors.blue.shade500;
    } else if (label.contains('fat')) {
      chipColor = Colors.orange.shade500;
    } else {
      chipColor = Theme.of(context).primaryColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: chipColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: chipColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _openFoodDetail(BuildContext context, AIFoodItem food) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) =>
            AIFoodDetailPage(food: food, selectedMeal: meal, logDate: date),
      ),
    );
  }

  void _quickAddFood(BuildContext context, AIFoodItem food) {
    final customColors = Theme.of(context).extension<CustomColors>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add to Meal',
              style: TextStyle(
                color: customColors!.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              food.name,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
            const SizedBox(height: 24),
            ...[
              'Breakfast',
              'Lunch',
              'Snacks',
              'Dinner',
            ].map((meal) => _buildMealOption(context, food, meal)).toList(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMealOption(BuildContext context, AIFoodItem food, String meal) {
    final customColors = Theme.of(context).extension<CustomColors>();
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        _addFoodToMeal(context, food, meal);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              meal,
              style: TextStyle(
                color: customColors!.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: customColors.textPrimary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _addFoodToMeal(BuildContext context, AIFoodItem food, String meal) {
    final dateProvider = Provider.of<DateProvider>(context, listen: false);
    final logDate = date ?? dateProvider.selectedDate;
    final foodEntryProvider = Provider.of<FoodEntryProvider>(
      context,
      listen: false,
    );

    // The nutrition values from AI are already for the serving size, but the app expects values per 100g
    // So we need to adjust the values to be per 100g
    // Default quantity is 1.0 for quick add
    final double quantity = 1.0;

    // The nutrition values from AI are already for the serving size.
    // We store the selected serving's nutrients directly and the quantity as the multiplier.
    final calories = food.calories[0];
    final protein = food.protein[0];
    final carbs = food.carbohydrates[0];
    final fat = food.fat[0];
    final fiber = food.fiber[0];

    // Create food entry using the first serving size
    final entry = FoodEntry(
      id: const Uuid().v4(),
      food: FoodEntry.createFood(
        fdcId: food.name.hashCode.toString(),
        name: food.name,
        brandName: 'AI Detected',
        calories: calories, // Use adjusted value
        nutrients: {
          'Protein': protein, // Use adjusted value
          'Carbohydrate, by difference': carbs, // Use adjusted value
          'Total lipid (fat)': fat, // Use adjusted value
          'Fiber': fiber, // Use adjusted value
        },
        mealType: meal,
      ),
      meal: meal,
      quantity: quantity,
      unit: food.servingSizes[0],
      date: logDate,
    );

    foodEntryProvider.addEntry(entry);
    Navigator.pop(context); // Close bottom sheet

    // Show confirmation
    AppToast.show(
      'Added ${food.name} to $meal',
      actionLabel: 'Undo',
      onAction: () => foodEntryProvider.removeEntry(entry.id),
    );

    // Navigate directly to Dashboard instead of staying on results page
    // Navigator.pop(context); // Close results page
  }
}
