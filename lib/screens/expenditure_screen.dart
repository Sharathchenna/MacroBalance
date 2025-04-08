// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:macrotracker/providers/expenditure_provider.dart';
// import 'package:macrotracker/providers/foodEntryProvider.dart'; // Import FoodEntryProvider
// import 'package:provider/provider.dart';

// class ExpenditureScreen extends StatefulWidget {
//   const ExpenditureScreen({super.key});

//   @override
//   State<ExpenditureScreen> createState() => _ExpenditureScreenState();
// }

// class _ExpenditureScreenState extends State<ExpenditureScreen> {
//   @override
//   void initState() {
//     super.initState();
//     // Trigger an update when the screen is first loaded, if not already loading
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final provider = Provider.of<ExpenditureProvider>(context, listen: false);
//       if (!provider.isLoading && provider.currentExpenditure == null) {
//         provider.updateExpenditure();
//       }
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text(
//           'Expenditure & Goals', // Updated title
//           style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
//         ),
//         backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
//         elevation: Theme.of(context).appBarTheme.elevation,
//         iconTheme: Theme.of(context).appBarTheme.iconTheme,
//         titleTextStyle: Theme.of(context).appBarTheme.titleTextStyle,
//       ),
//       // Use Consumer2 to listen to both providers
//       body: Consumer2<ExpenditureProvider, FoodEntryProvider>(
//         builder: (context, expenditureProvider, foodProvider, child) {
//           Widget content;
//           if (expenditureProvider.isLoading) {
//             content = const Center(child: CupertinoActivityIndicator());
//           } else if (expenditureProvider.error != null) {
//             content = Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Text(
//                   expenditureProvider.error!,
//                   style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 14),
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//             );
//           } else if (expenditureProvider.currentExpenditure != null) {
//             // Data is available, display TDEE and Goals
//             content = Center(
//               child: Padding( // Added padding around the content
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     // TDEE Section
//                     Text(
//                       'Estimated TDEE:',
//                       style: GoogleFonts.poppins(
//                         fontSize: 18,
//                         color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       '${expenditureProvider.currentExpenditure!.toStringAsFixed(0)}',
//                       style: GoogleFonts.poppins(
//                         fontSize: 42, // Slightly smaller
//                         fontWeight: FontWeight.bold,
//                         color: Theme.of(context).colorScheme.primary,
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                      Text(
//                       'kcal / day',
//                       style: GoogleFonts.poppins(
//                         fontSize: 14, // Slightly smaller
//                         color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 25),
//                     Divider(color: Colors.grey.withOpacity(0.3)),
//                     const SizedBox(height: 25),

//                     // Dynamic Goals Section
//                     Text(
//                       'Your Dynamic Goals:',
//                       style: GoogleFonts.poppins(
//                         fontSize: 18,
//                         color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.8),
//                       ),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 15),
//                     _buildGoalRow(
//                       context,
//                       'Calories:',
//                       foodProvider.caloriesGoal.round(),
//                       'kcal',
//                       Icons.local_fire_department_outlined,
//                       Colors.orange,
//                     ),
//                     const SizedBox(height: 12),
//                     _buildGoalRow(
//                       context,
//                       'Protein:',
//                       foodProvider.proteinGoal.round(),
//                       'g',
//                       Icons.fitness_center, // Example icon
//                       Colors.redAccent,
//                     ),
//                     const SizedBox(height: 12),
//                     _buildGoalRow(
//                       context,
//                       'Carbs:',
//                       foodProvider.carbsGoal.round(),
//                       'g',
//                       Icons.grain, // Example icon
//                       Colors.blueAccent,
//                     ),
//                     const SizedBox(height: 12),
//                     _buildGoalRow(
//                       context,
//                       'Fat:',
//                       foodProvider.fatGoal.round(),
//                       'g',
//                       Icons.opacity, // Example icon
//                       Colors.green,
//                     ),

//                     const SizedBox(height: 30),
//                      Padding(
//                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
//                        child: Text(
//                          'TDEE is calculated based on your logged weight and nutrition. Goals are set based on your TDEE and selected goal (lose/maintain/gain).',
//                          style: GoogleFonts.poppins(
//                            fontSize: 12, // Smaller font size
//                            color: Theme.of(context).textTheme.bodySmall?.color,
//                            fontStyle: FontStyle.italic,
//                          ),
//                          textAlign: TextAlign.center,
//                        ),
//                      ),
//                   ],
//                 ),
//               ),
//             );
//           } else {
//             // Case where calculation hasn't run or returned null without error
//             content = Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Text(
//                   'Calculating expenditure & goals... Please ensure you have logged sufficient weight and nutrition data.',
//                   style: GoogleFonts.poppins(fontSize: 14),
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//             );
//           }

//           // Wrap content in a ListView for RefreshIndicator and ensure it fills height
//           return RefreshIndicator(
//              onRefresh: () => expenditureProvider.updateExpenditure(), // Trigger update on pull
//              child: LayoutBuilder( // Use LayoutBuilder to get constraints
//                builder: (context, constraints) {
//                  return SingleChildScrollView( // Use SingleChildScrollView for content taller than screen
//                    physics: const AlwaysScrollableScrollPhysics(),
//                    child: ConstrainedBox( // Ensure content takes at least screen height
//                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
//                      child: content,
//                    ),
//                  );
//                }
//              ),
//           );
//         },
//       ),
//     );
//   }

//   // Helper widget to display a goal row
//   Widget _buildGoalRow(BuildContext context, String label, int value, String unit, IconData icon, Color color) {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.center,
//       children: [
//         Icon(icon, color: color, size: 18),
//         const SizedBox(width: 8),
//         SizedBox(
//           width: 70, // Fixed width for label
//           child: Text(
//             label,
//             style: GoogleFonts.poppins(
//               fontSize: 15,
//               fontWeight: FontWeight.w500,
//               color: Theme.of(context).textTheme.bodyMedium?.color,
//             ),
//           ),
//         ),
//         const SizedBox(width: 10),
//         Text(
//           value.toString(),
//           style: GoogleFonts.poppins(
//             fontSize: 16,
//             fontWeight: FontWeight.w600,
//             color: Theme.of(context).textTheme.bodyLarge?.color,
//           ),
//         ),
//         const SizedBox(width: 4),
//         Text(
//           unit,
//           style: GoogleFonts.poppins(
//             fontSize: 14,
//             color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
//           ),
//         ),
//       ],
//     );
//   }
// }
