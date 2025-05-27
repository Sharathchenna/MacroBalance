import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/meal_planning_provider.dart';
import '../models/meal_plan.dart';
import '../models/recipe.dart';
import '../models/user_preferences.dart';
import 'package:flutter/cupertino.dart';

class MealPlanningScreen extends StatefulWidget {
  const MealPlanningScreen({Key? key}) : super(key: key);

  @override
  State<MealPlanningScreen> createState() => _MealPlanningScreenState();
}

class _MealPlanningScreenState extends State<MealPlanningScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Initialize meal plans when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<MealPlanningProvider>(context, listen: false);
      provider.fetchMealPlanForDate(_selectedDate);
    });
  }

  Future<void> _generateMealPlan() async {
    final provider = Provider.of<MealPlanningProvider>(context, listen: false);

    // Create basic user preferences
    final userPrefs = UserPreferences(
      userId: 'default',
      targetCalories: 2000,
      targetProtein: 150,
      targetCarbohydrates: 200,
      targetFat: 65,
      dietaryPreferences: DietaryPreferences(
        preferences: [],
        allergies: [],
        dislikedFoods: [],
        mealsPerDay: 3,
      ),
      fitnessGoals: FitnessGoals(
        primary: 'general_fitness',
        secondary: [],
        workoutsPerWeek: 3,
      ),
      equipment: EquipmentAvailability(),
    );

    await provider.generateMealPlan(
      date: _selectedDate,
      userPreferences: userPrefs,
    );
  }

  Future<void> _addCustomMeal() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddMealDialog(),
    );

    if (result != null) {
      final provider =
          Provider.of<MealPlanningProvider>(context, listen: false);
      final meal = Meal(
        name: result['name'],
        items: [],
        time: DateTime.now(),
      );
      await provider.logMeal(
        date: _selectedDate,
        meal: meal,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MealPlanningProvider>(
      builder: (context, provider, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Meal Planning'),
            actions: [
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: _addCustomMeal,
              ),
            ],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.error != null
                  ? Center(child: Text(provider.error!))
                  : _buildMealPlanContent(provider),
          floatingActionButton: FloatingActionButton(
            onPressed: provider.isGeneratingMealPlan ? null : _generateMealPlan,
            child: provider.isGeneratingMealPlan
                ? const CircularProgressIndicator(color: Colors.white)
                : const Icon(Icons.restaurant_menu),
          ),
        );
      },
    );
  }

  Widget _buildMealPlanContent(MealPlanningProvider provider) {
    final mealPlan = provider.currentMealPlan;

    if (mealPlan == null) {
      return const Center(
        child: Text('No meal plan found. Generate one!'),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateSelector(),
          const SizedBox(height: 16),
          _buildNutritionSummary(mealPlan),
          const SizedBox(height: 24),
          const Text(
            'Planned Meals',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...mealPlan.plannedMeals.map((meal) => _buildMealCard(meal)),
          if (mealPlan.loggedMeals.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Logged Meals',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...mealPlan.loggedMeals.map((meal) => _buildMealCard(meal)),
          ],
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.subtract(const Duration(days: 1));
            });
            Provider.of<MealPlanningProvider>(context, listen: false)
                .fetchMealPlanForDate(_selectedDate);
          },
        ),
        TextButton(
          onPressed: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _selectedDate,
              firstDate: DateTime.now().subtract(const Duration(days: 365)),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (date != null) {
              setState(() {
                _selectedDate = date;
              });
              Provider.of<MealPlanningProvider>(context, listen: false)
                  .fetchMealPlanForDate(date);
            }
          },
          child: Text(
            '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
            style: const TextStyle(fontSize: 18),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            setState(() {
              _selectedDate = _selectedDate.add(const Duration(days: 1));
            });
            Provider.of<MealPlanningProvider>(context, listen: false)
                .fetchMealPlanForDate(_selectedDate);
          },
        ),
      ],
    );
  }

  Widget _buildNutritionSummary(DailyMealPlan mealPlan) {
    double totalCalories = 0;
    double totalProtein = 0;
    double totalCarbs = 0;
    double totalFat = 0;

    for (final meal in [...mealPlan.plannedMeals, ...mealPlan.loggedMeals]) {
      for (final item in meal.items) {
        totalCalories += item.calories;
        totalProtein += item.protein;
        totalCarbs += item.carbohydrates;
        totalFat += item.fat;
      }
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Daily Nutrition',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            _buildNutrientProgress(
              'Calories',
              totalCalories,
              mealPlan.targetCalories,
              Colors.blue,
            ),
            _buildNutrientProgress(
              'Protein',
              totalProtein,
              mealPlan.targetProtein,
              Colors.red,
            ),
            _buildNutrientProgress(
              'Carbs',
              totalCarbs,
              mealPlan.targetCarbohydrates,
              Colors.green,
            ),
            _buildNutrientProgress(
              'Fat',
              totalFat,
              mealPlan.targetFat,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientProgress(
      String label, double current, double target, Color color) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
            '$label: ${current.toStringAsFixed(1)}/${target.toStringAsFixed(1)}g'),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: progress,
          backgroundColor: color.withOpacity(0.2),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildMealCard(Meal meal) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  meal.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${meal.time.hour.toString().padLeft(2, '0')}:${meal.time.minute.toString().padLeft(2, '0')}',
                ),
              ],
            ),
            if (meal.items.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Divider(),
              ...meal.items.map((item) => _buildMealItem(item)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMealItem(MealItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name),
                Text(
                  '${item.calories.toStringAsFixed(0)} cal • P: ${item.protein.toStringAsFixed(1)}g • C: ${item.carbohydrates.toStringAsFixed(1)}g • F: ${item.fat.toStringAsFixed(1)}g',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text('${item.servings}x'),
        ],
      ),
    );
  }
}

class _AddMealDialog extends StatefulWidget {
  @override
  _AddMealDialogState createState() => _AddMealDialogState();
}

class _AddMealDialogState extends State<_AddMealDialog> {
  final _nameController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Custom Meal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Meal Name',
              hintText: 'Enter meal name',
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: const Text('Time'),
            trailing: Text(_selectedTime.format(context)),
            onTap: () async {
              final time = await showTimePicker(
                context: context,
                initialTime: _selectedTime,
              );
              if (time != null) {
                setState(() {
                  _selectedTime = time;
                });
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            if (_nameController.text.isNotEmpty) {
              Navigator.pop(context, {
                'name': _nameController.text,
                'time': _selectedTime,
              });
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}
