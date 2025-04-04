// ignore_for_file: file_names

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/camera/ai_food_detail_page.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:lottie/lottie.dart';

class Askai extends StatefulWidget {
  const Askai({super.key});

  @override
  State<Askai> createState() => _AskaiState();
}

class _AskaiState extends State<Askai> with AutomaticKeepAliveClientMixin {
  final TextEditingController _mealController = TextEditingController();
  String _nutritionResult = '';
  bool _isLoading = false;
  bool _canSend = false;
  List<AIFoodItem> _foodItems = [];
  bool _hasSearched = false;
  final FocusNode _mealFocusNode = FocusNode(); // Add FocusNode
  // Removed _isTextFieldReadOnly state

  @override
  void initState() {
    super.initState();

    _mealController.addListener(() {
      setState(() {
        _canSend = _mealController.text.isNotEmpty;
      });
    });
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _analyzeNutrition() async {
    if (_mealController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _foodItems = [];
      _hasSearched = true;
    });

    try {
      const apiKey = 'AIzaSyDe8qpEeJHOYJtJviyr4GVH2_ssCUy9gZc';

      final model = GenerativeModel(
        model: 'gemini-2.0-flash',
        apiKey: apiKey,
      );

      final prompt = '''
Analyze the following meal description and extract all food items with their nutritional content.
Break the meal into individual food items. For each item provide:
1. The name of the food item
2. A list of serving sizes
3. Calories, protein, carbohydrates, fat, and fiber for each serving size

Return the response as a JSON list of objects with this structure:
[
  {
    "name": "Food name",
    "servingSizes": ["1 cup", "100g", etc.],
    "calories": [200, 150, etc.],
    "protein": [10, 7.5, etc.],
    "carbohydrates": [25, 18.75, etc.],
    "fat": [8, 6, etc.],
    "fiber": [3, 2.25, etc.]
  },
  {...}
]
Important note: Do not leave any trailing commas in the JSON response.
Make educated estimates for nutrition values if needed. If the meal is complex, break it down into its main components.
Ensure each food has at least two serving size options (e.g., "1 serving" and "100g").
Meal to analyze: ${_mealController.text}
''';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);
      final responseText = response.text ?? '';

      // Extract JSON from response (in case there's any text around it)
      final jsonRegExp = RegExp(r'(\[[\s\S]*\])');
      final match = jsonRegExp.firstMatch(responseText);

      if (match != null) {
        try {
          final jsonData = json.decode(match.group(1)!);
          final List<AIFoodItem> parsedItems = [];

          for (var item in jsonData) {
            // Ensure all lists have the expected elements
            _validateAndFixJsonItem(item);

            // Convert JSON to AIFoodItem using our custom converter
            parsedItems.add(_convertToAIFoodItem(item));
          }

          setState(() {
            _foodItems = parsedItems;
            _isLoading = false;
          });
        } catch (e) {
          setState(() {
            _isLoading = false;
          });
          _showErrorSnackbar('Error parsing results: ${e.toString()}');
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackbar('Could not extract structured data from response');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackbar('Error analyzing meal: ${e.toString()}');
    }
  }

  // Helper method to validate and fix JSON data to prevent errors
  void _validateAndFixJsonItem(Map<String, dynamic> item) {
    // Ensure name exists
    item['name'] = item['name'] ?? 'Unknown Food';

    // Ensure serving sizes exist and have at least one element
    if (item['servingSizes'] == null ||
        (item['servingSizes'] as List).isEmpty) {
      item['servingSizes'] = ['1 serving', '100g'];
    }

    // Fix length of nutrition arrays to match serving sizes
    int servingCount = (item['servingSizes'] as List).length;

    void fixNutrientArray(String key) {
      if (item[key] == null) {
        item[key] = List<num>.filled(servingCount, 0);
      } else if ((item[key] as List).length < servingCount) {
        // If there are fewer values than servings, pad with the last value or 0
        List originalList = item[key] as List;
        num paddingValue = originalList.isNotEmpty ? originalList.last : 0;
        item[key] = List<num>.from(originalList)
          ..addAll(List<num>.filled(
              servingCount - originalList.length, paddingValue));
      }
    }

    fixNutrientArray('calories');
    fixNutrientArray('protein');
    fixNutrientArray('carbohydrates');
    fixNutrientArray('fat');
    fixNutrientArray('fiber');
  }

  // Custom converter for creating AIFoodItem from JSON data from Gemini
  AIFoodItem _convertToAIFoodItem(Map<String, dynamic> json) {
    // Extract the name from the JSON data
    String name = json['name'] as String? ?? 'Unknown Food';

    // Extract and convert servingSizes
    List<String> servingSizes = [];
    if (json['servingSizes'] != null) {
      servingSizes =
          (json['servingSizes'] as List).map((e) => e.toString()).toList();
    } else {
      servingSizes = ['1 serving', '100g']; // Default serving sizes if missing
    }

    // Extract and convert nutrient lists, handling various potential formats
    List<double> convertNutrientList(dynamic nutrientData) {
      if (nutrientData == null) {
        return List<double>.filled(servingSizes.length, 0.0);
      }

      List<double> result = [];
      for (var value in nutrientData as List) {
        if (value is num) {
          result.add(value.toDouble());
        } else if (value is String) {
          try {
            result.add(double.parse(value));
          } catch (_) {
            result.add(0.0);
          }
        } else {
          result.add(0.0);
        }
      }

      // Ensure the list is the same length as servingSizes
      if (result.length < servingSizes.length) {
        final lastValue = result.isNotEmpty ? result.last : 0.0;
        result.addAll(List<double>.filled(
            servingSizes.length - result.length, lastValue));
      }

      return result;
    }

    // Convert all nutrient data
    List<double> calories = convertNutrientList(json['calories']);
    List<double> protein = convertNutrientList(json['protein']);
    List<double> carbohydrates = convertNutrientList(json['carbohydrates']);
    List<double> fat = convertNutrientList(json['fat']);
    List<double> fiber = convertNutrientList(json['fiber']);

    // Create and return the AIFoodItem
    return AIFoodItem(
      name: name,
      servingSizes: servingSizes,
      calories: calories,
      protein: protein,
      carbohydrates: carbohydrates,
      fat: fat,
      fiber: fiber,
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openFoodDetail(AIFoodItem food, int index) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (context) => AIFoodDetailPage(food: food),
      ),
    );
  }

  // Reverted to non-async
  void _quickAddFood(AIFoodItem food, String meal) {
    // Pop the bottom sheet FIRST
    Navigator.pop(context);

    // Add a small delay AFTER popping before proceeding
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!mounted) return; // Check if still mounted after delay

      final dateProvider = Provider.of<DateProvider>(context, listen: false);
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);

      // Default quantity is 1.0 for quick add
      final double quantity = 1.0;

      // Adjust nutrients to be per 100g instead of per serving
      final calories = food.calories[0] / quantity * 100;
      final protein = food.protein[0] / quantity * 100;
      final carbs = food.carbohydrates[0] / quantity * 100;
      final fat = food.fat[0] / quantity * 100;
      final fiber = food.fiber[0] / quantity * 100;

      // Create food entry using the first serving size
      final entry = FoodEntry(
        id: const Uuid().v4(),
        food: FoodEntry.createFood(
          fdcId: food.name.hashCode.toString(),
          name: food.name,
          brandName: 'AI Analyzed',
          calories: calories,
          nutrients: {
            'Protein': protein,
            'Carbohydrate, by difference': carbs,
            'Total lipid (fat)': fat,
            'Fiber': fiber,
          },
          mealType: meal,
        ),
        meal: meal,
        quantity: quantity,
        unit: food.servingSizes[0],
        date: dateProvider.selectedDate,
      );

      foodEntryProvider.addEntry(entry);
      // Navigator.pop(context); // Already popped above

      // Set readOnly before showing snackbar - REMOVED
      // setState(() {
      //   _isTextFieldReadOnly = true;
      // });

      // Show confirmation and wait for it to close - REVERTED
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle_outline,
                  color: Theme.of(context).colorScheme.onPrimary),
              SizedBox(width: 8),
              Text(
                'Added to $meal',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              ),
            ],
          ),
          backgroundColor: Color(0xFFFFC107).withValues(alpha: 1),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: EdgeInsets.all(8),
          duration: const Duration(seconds: 2),
        ),
      );

      // Wait for snackbar to close - REMOVED
      // await snackbarResult.closed;

      // Unfocus and reset readOnly after snackbar closes, checking if mounted - REMOVED
      // if (mounted) {
      //   // Try unfocusing first
      //   FocusManager.instance.primaryFocus?.unfocus();
      //   // Then reset the readOnly state
      //   setState(() {
      //     _isTextFieldReadOnly = false;
      //   });
      // }

      // Removed navigation to dashboard to allow user to continue adding foods

      // Ensure FocusManager unfocus is also called after delay, if needed
      FocusManager.instance.primaryFocus?.unfocus();
    }); // End of Future.delayed
  }

  // Add this method to handle text field submissions
  void _handleSubmitted(String value) {
    if (_canSend) {
      FocusScope.of(context).unfocus();
      _analyzeNutrition();
    }
  }

  Widget _buildFoodCard(BuildContext context, AIFoodItem food, int index) {
    final customColors = Theme.of(context).extension<CustomColors>();
    // Default to first serving size
    final defaultServing = food.servingSizes[0];
    final calories = food.calories[0];
    final protein = food.protein[0];
    final carbs = food.carbohydrates[0];
    final fat = food.fat[0];

    return Hero(
      tag: 'food-${food.name}-$index',
      child: TweenAnimationBuilder<double>(
        duration: Duration(milliseconds: 400 + (index * 100)),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        builder: (context, value, child) {
          return Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: Card(
          elevation: 3,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: InkWell(
            onTap: () => _openFoodDetail(food, index),
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

                      // Add button
                      Container(
                          child: Row(
                        children: [
                          IconButton(
                            icon: Icon(
                              CupertinoIcons.add_circled,
                              color: customColors.textPrimary,
                            ),
                            onPressed: () =>
                                _showQuickAddOptions(context, food),
                            tooltip: 'Add to meal',
                          ),
                          SizedBox(width: 8),
                          Icon(
                            CupertinoIcons.chevron_right,
                          )
                        ],
                      ))
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
                            '${calories.toStringAsFixed(0)} kcal'),
                        const SizedBox(width: 8),
                        _buildNutritionChip(
                            context,
                            Icons.fitness_center_outlined,
                            '${protein.toStringAsFixed(1)}g protein'),
                        const SizedBox(width: 8),
                        _buildNutritionChip(
                            context,
                            Icons.bubble_chart_outlined,
                            '${carbs.toStringAsFixed(1)}g carbs'),
                        const SizedBox(width: 8),
                        _buildNutritionChip(context, Icons.opacity_outlined,
                            '${fat.toStringAsFixed(1)}g fat'),
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

  Widget _buildNutritionChip(
      BuildContext context, IconData icon, String label) {
    // Define specific colors for each nutrient type
    Color chipColor;
    if (label.contains('kcal')) {
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
          Icon(
            icon,
            size: 16,
            color: chipColor,
          ),
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

  void _showQuickAddOptions(BuildContext context, AIFoodItem food) {
    // Unfocus before showing the sheet
    _mealFocusNode.unfocus();

    final customColors = Theme.of(context).extension<CustomColors>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      // Add onDismissed callback to handle focus when sheet is dismissed
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
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
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
    ); // Removed the .then() block that called FocusScope.unfocus()
  }

  Widget _buildMealOption(BuildContext context, AIFoodItem food, String meal) {
    return InkWell(
      onTap: () => _quickAddFood(food, meal),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              meal,
              style: TextStyle(
                color: Theme.of(context).extension<CustomColors>()!.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: Theme.of(context).primaryColor,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final customColors = Theme.of(context).extension<CustomColors>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: CupertinoColors.systemGrey.withOpacity(0.0),
        leading: CupertinoNavigationBarBackButton(
          color: customColors!.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Ask AI',
          style: GoogleFonts.roboto(
            color: customColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            // Removed the Container with disclaimer text
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 25, 16, 16),
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: 60,
                  maxHeight: 150,
                ),
                decoration: BoxDecoration(
                  color: customColors.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CupertinoTextField(
                  focusNode: _mealFocusNode, // Assign FocusNode
                  controller: _mealController,
                  // Removed readOnly binding
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  onSubmitted: _handleSubmitted, // Add this line
                  style: GoogleFonts.roboto(
                    // Reverted style
                    color: Theme.of(context)
                        .extension<CustomColors>()!
                        .textPrimary,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  placeholder: 'Describe your meal or food...',
                  placeholderStyle: GoogleFonts.roboto(
                    color: customColors.textSecondary,
                  ),
                  decoration: const BoxDecoration(),
                  suffix: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _canSend
                        ? () {
                            FocusScope.of(context).unfocus();
                            _analyzeNutrition();
                          }
                        : null,
                    child: Icon(
                      CupertinoIcons.arrowtriangle_right,
                      color: _canSend
                          ? const Color(0xFFFFC107)
                          : CupertinoColors.inactiveGray,
                    ),
                  ),
                ),
              ),
            ),
            // Loading indicator or results list
            Expanded(
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 150,
                            width: 150,
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              shape: BoxShape.circle,
                              // borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .primaryColor
                                      .withOpacity(0.1),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: Lottie.asset(
                              'assets/animations/potato_walking.json',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Analyzing your meal...',
                            style: TextStyle(
                              color: customColors.textSecondary,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _foodItems.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 50),
                                  Container(
                                    height: 120,
                                    width: 120,
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      color: customColors.cardBackground
                                          .withOpacity(0.7),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      _hasSearched
                                          ? CupertinoIcons
                                              .exclamationmark_circle
                                          : CupertinoIcons.doc_text_search,
                                      size: 80,
                                      color: customColors.textPrimary
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  Text(
                                    _hasSearched
                                        ? 'No food items found'
                                        : 'Describe your meal to get nutrition analysis',
                                    style: GoogleFonts.roboto(
                                      color: customColors?.textPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    _hasSearched
                                        ? 'Try rephrasing or adding more details to your meal description'
                                        : 'Try "turkey sandwich with avocado and cheese"',
                                    style: GoogleFonts.roboto(
                                      color: customColors?.textSecondary,
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Please note: AI results are estimates and should be verified for accuracy.',
                                    style: GoogleFonts.roboto(
                                      color: customColors?.textSecondary,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_hasSearched)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 24),
                                      child: ElevatedButton.icon(
                                        onPressed: _analyzeNutrition,
                                        icon: const Icon(
                                            CupertinoIcons.arrow_clockwise,
                                            color: Colors.white,
                                            size: 18),
                                        label: const Text('Try Again'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Theme.of(context).primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 24, vertical: 14),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(16),
                                          ),
                                          elevation: 2,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          key: ValueKey<int>(_foodItems.length),
                          itemCount: _foodItems.length,
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 16),
                          itemBuilder: (context, index) {
                            final food = _foodItems[index];
                            return _buildFoodCard(context, food, index);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Dispose controllers and focus nodes first
    _mealController.dispose();
    _mealFocusNode.dispose(); // Dispose the FocusNode
    // Call super.dispose() last
    super.dispose();

    // IMPORTANT: Do not access context or call any methods using context after this point
    // This ensures we don't reference deactivated widgets
  }
}
