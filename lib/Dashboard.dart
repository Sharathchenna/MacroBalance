import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Color(0xFFF5F4F0),
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              DateNavigatorbar(),
              CalorieTracker(),
              Expanded(child: MealSection())
            ],
          ),
        ));
  }
}

class DateNavigatorbar extends StatelessWidget {
  const DateNavigatorbar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavigationButton(icon: Icons.chevron_left),
          _buildTodayButton(),
          _buildNavigationButton(icon: Icons.chevron_right),
        ],
      ),
    );
  }
}

Widget _buildNavigationButton({required IconData icon}) {
  return InkWell(
    onTap: () {
      // Add your navigation logic here (e.g., go to previous/next day)
      print('Navigation button tapped!');
    },
    child: Container(
      padding: EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Color(0xFFF0E9DF), // Background color of the buttons
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: Colors.black,
      ),
    ),
  );
}

Widget _buildTodayButton() {
  return InkWell(
    onTap: () {
      // Add your logic to go back to the current day
      print('Today button tapped!');
    },
    child: Container(
      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Color(0xFFF0E9DF), // Background color of the button
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today,
            color: Colors.black,
            size: 16,
          ),
          SizedBox(width: 8.0),
          Text('Today', style: TextStyle(color: Colors.black)),
        ],
      ),
    ),
  );
}

class CalorieTracker extends StatelessWidget {
  const CalorieTracker({super.key});

  // mock data

  final int caloriesRemaining = 500;
  final int caloriesConsumed = 1500;
  final int carbIntake = 50;
  final int carbGoal = 75;
  final int fatIntake = 60;
  final int fatGoal = 80;
  final int proteinIntake = 100;
  final int proteinGoal = 150;

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    double totalCalories = (caloriesConsumed + caloriesRemaining).toDouble();
    double progress = 0.75;
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 95.0),
            spreadRadius: 1,
            blurRadius: 1,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                height: 120,
                width: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        backgroundColor: Color(0xFFB8EAC5),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF34C85A)),
                      ),
                    ),
                    Text(
                      '$caloriesRemaining cal\nremaining',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.roboto(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$caloriesConsumed cal\nconsumed',
                textAlign: TextAlign.start,
                style: GoogleFonts.roboto(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 20,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroBar(
                  label: 'C',
                  intake: carbIntake,
                  goal: carbGoal,
                  color: Colors.blue),
              _buildMacroBar(
                  label: 'F',
                  intake: fatIntake,
                  goal: fatGoal,
                  color: Colors.orange),
              _buildMacroBar(
                  label: 'P',
                  intake: proteinIntake,
                  goal: proteinGoal,
                  color: Colors.red),
            ],
          )
        ],
      ),
    );
  }
}

Widget _buildMacroBar(
    {required String label,
    required int intake,
    required int goal,
    required Color color}) {
  double progress = intake / goal;
  progress = progress.clamp(0, 1); // Ensure progress is between 0 and 1

  return Column(
    children: [
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      SizedBox(
        width: 50,
        child: LinearProgressIndicator(
          value: progress,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
      Text('$intake/$goal'),
    ],
  );
}

// class MealList extends StatefulWidget {
//   @override
//   _MealListState createState() => _MealListState();
// }

// class _MealListState extends State<MealList> {
//   bool _isBreakfastExpanded = false;
//   List<FoodItem> _breakfastItems = [];
//   double _totalBreakfastCalories = 0;

//   void _toggleBreakfast() {
//     setState(() {
//       _isBreakfastExpanded = !_isBreakfastExpanded;
//     });
//   }

//   void _addFoodItem() {
//     setState(() {
//       _breakfastItems.add(FoodItem());
//       _recalculateTotalCalories(); // Recalculate immediately after adding
//     });
//   }

//   void _removeFoodItem(int index) {
//     setState(() {
//       _breakfastItems.removeAt(index);
//       _recalculateTotalCalories(); // Recalculate immediately after removing
//     });
//   }

//   void _updateFoodItem(int index, String foodName, double calories,
//       {double? carbs, double? fat, double? protein}) {
//     setState(() {
//       _breakfastItems[index].foodName = foodName;
//       _breakfastItems[index].calories = calories;
//       if (carbs != null) _breakfastItems[index].carbs = carbs;
//       if (fat != null) _breakfastItems[index].fat = fat;
//       if (protein != null) _breakfastItems[index].protein = protein;
//       _recalculateTotalCalories();
//     });
//   }

//   void _recalculateTotalCalories() {
//     _totalBreakfastCalories = 0;
//     for (var item in _breakfastItems) {
//       _totalBreakfastCalories += item.calories;
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16.0),
//       child: Column(
//         children: [
//           // Breakfast Section
//           InkWell(
//             onTap: _toggleBreakfast,
//             child: Container(
//               padding: const EdgeInsets.all(16.0),
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                 children: [
//                   Row(
//                     children: [
//                       const Text('Breakfast'),
//                       Icon(_isBreakfastExpanded
//                           ? Icons.arrow_drop_up
//                           : Icons.arrow_drop_down),
//                     ],
//                   ),
//                   Text('${_totalBreakfastCalories.toStringAsFixed(0)} Kcal'),
//                 ],
//               ),
//             ),
//           ),
//           if (_isBreakfastExpanded)
//             Container(
//               padding: const EdgeInsets.all(16.0),
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.grey.shade300),
//                 borderRadius: BorderRadius.circular(8.0),
//               ),
//               child: Column(
//                 children: [
//                   ElevatedButton(
//                     onPressed: _addFoodItem,
//                     child: const Text('+ Add Food'),
//                   ),
//                   ..._breakfastItems.asMap().entries.map((entry) {
//                     int index = entry.key;
//                     FoodItem item = entry.value;
//                     return FoodItemRow(
//                       foodItem: item,
//                       onRemove: () => _removeFoodItem(index),
//                       onUpdate: (foodName, calories, {carbs, fat, protein}) =>
//                           _updateFoodItem(index, foodName, calories,
//                               carbs: carbs, fat: fat, protein: protein),
//                     );
//                   }).toList(),
//                 ],
//               ),
//             ),

//           // Example for other meals (Lunch, Snacks, Dinner) - similar structure
//           const MealSection(mealName: "Lunch"),
//           const MealSection(mealName: "Snacks"),
//           const MealSection(mealName: "Dinner"),
//         ],
//       ),
//     );
//   }
// }

// class FoodItem {
//   String foodName = '';
//   double calories = 0;
//   double carbs = 0;
//   double fat = 0;
//   double protein = 0;
// }

// class FoodItemRow extends StatefulWidget {
//   final FoodItem foodItem;
//   final VoidCallback onRemove;
//   final Function(String, double, {double? carbs, double? fat, double? protein})
//       onUpdate;

//   const FoodItemRow({
//     Key? key,
//     required this.foodItem,
//     required this.onRemove,
//     required this.onUpdate,
//   }) : super(key: key);

//   @override
//   _FoodItemRowState createState() => _FoodItemRowState();
// }

// class _FoodItemRowState extends State<FoodItemRow> {
//   late TextEditingController _foodNameController;
//   late TextEditingController _calorieController;
//   late TextEditingController _carbsController;
//   late TextEditingController _fatController;
//   late TextEditingController _proteinController;

//   @override
//   void initState() {
//     super.initState();
//     _foodNameController = TextEditingController(text: widget.foodItem.foodName);
//     _calorieController =
//         TextEditingController(text: widget.foodItem.calories.toString());
//     _carbsController =
//         TextEditingController(text: widget.foodItem.carbs.toString());
//     _fatController =
//         TextEditingController(text: widget.foodItem.fat.toString());
//     _proteinController =
//         TextEditingController(text: widget.foodItem.protein.toString());
//   }

//   @override
//   void dispose() {
//     _foodNameController.dispose();
//     _calorieController.dispose();
//     _carbsController.dispose();
//     _fatController.dispose();
//     _proteinController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       margin: const EdgeInsets.symmetric(vertical: 8.0),
//       padding: const EdgeInsets.all(8.0),
//       decoration: BoxDecoration(
//         border: Border.all(color: Colors.grey.shade300),
//         borderRadius: BorderRadius.circular(8.0),
//       ),
//       child: Row(
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 TextFormField(
//                   controller: _foodNameController,
//                   decoration: const InputDecoration(labelText: 'Food Name'),
//                   onChanged: (value) {
//                     widget.onUpdate(
//                         value, double.tryParse(_calorieController.text) ?? 0,
//                         carbs: double.tryParse(_carbsController.text),
//                         fat: double.tryParse(_fatController.text),
//                         protein: double.tryParse(_proteinController.text));
//                   },
//                 ),
//                 TextFormField(
//                   controller: _calorieController,
//                   decoration: const InputDecoration(labelText: 'Calories'),
//                   keyboardType: TextInputType.number,
//                   onChanged: (value) {
//                     widget.onUpdate(
//                         _foodNameController.text, double.tryParse(value) ?? 0,
//                         carbs: double.tryParse(_carbsController.text),
//                         fat: double.tryParse(_fatController.text),
//                         protein: double.tryParse(_proteinController.text));
//                   },
//                 ),
//                 Row(
//                   children: [
//                     Expanded(
//                       child: TextFormField(
//                         controller: _carbsController,
//                         decoration: const InputDecoration(labelText: 'Carbs'),
//                         keyboardType: TextInputType.number,
//                         onChanged: (value) {
//                           widget.onUpdate(_foodNameController.text,
//                               double.tryParse(_calorieController.text) ?? 0,
//                               carbs: double.tryParse(value),
//                               fat: double.tryParse(_fatController.text),
//                               protein:
//                                   double.tryParse(_proteinController.text));
//                         },
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: TextFormField(
//                         controller: _fatController,
//                         decoration: const InputDecoration(labelText: 'Fat'),
//                         keyboardType: TextInputType.number,
//                         onChanged: (value) {
//                           widget.onUpdate(_foodNameController.text,
//                               double.tryParse(_calorieController.text) ?? 0,
//                               carbs: double.tryParse(_carbsController.text),
//                               fat: double.tryParse(value),
//                               protein:
//                                   double.tryParse(_proteinController.text));
//                         },
//                       ),
//                     ),
//                     const SizedBox(width: 8),
//                     Expanded(
//                       child: TextFormField(
//                         controller: _proteinController,
//                         decoration: const InputDecoration(labelText: 'Protein'),
//                         keyboardType: TextInputType.number,
//                         onChanged: (value) {
//                           widget.onUpdate(_foodNameController.text,
//                               double.tryParse(_calorieController.text) ?? 0,
//                               carbs: double.tryParse(_carbsController.text),
//                               fat: double.tryParse(_fatController.text),
//                               protein: double.tryParse(value));
//                         },
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//           IconButton(
//             icon: const Icon(Icons.delete),
//             onPressed: widget.onRemove,
//           ),
//         ],
//       ),
//     );
//   }
// }

// class MealSection extends StatelessWidget {
//   final String mealName;

//   const MealSection({Key? key, required this.mealName}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(16.0),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//         children: [
//           Text(mealName),
//           const Text('0 Kcal'), // Placeholder
//         ],
//       ),
//     );
//   }
// }

// Add this class after your existing code
class MealSection extends StatefulWidget {
  const MealSection({super.key});

  @override
  State<MealSection> createState() => _MealSectionState();
}

class _MealSectionState extends State<MealSection> {
  Map<String, bool> expandedState = {
    'Breakfast': false,
    'Lunch': false,
    'Snacks': false,
    'Dinner': false,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildMealCard('Breakfast'),
          _buildMealCard('Lunch'),
          _buildMealCard('Snacks'),
          _buildMealCard('Dinner'),
        ],
      ),
    );
  }

  Widget _buildMealCard(String mealType) {
    return Card(
      margin: EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          ListTile(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      mealType,
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Icon(
                      expandedState[mealType]!
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                    ),
                  ],
                ),
                Text(
                  '0 Kcals',
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            onTap: () {
              setState(() {
                expandedState[mealType] = !expandedState[mealType]!;
              });
            },
          ),
          if (expandedState[mealType]!)
            Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
              child: Row(
                children: [
                  Icon(Icons.add, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Add Food',
                    style: GoogleFonts.roboto(
                      color: Colors.blue,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
