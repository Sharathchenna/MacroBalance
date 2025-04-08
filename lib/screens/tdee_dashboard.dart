// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:macrotracker/providers/expenditure_provider.dart';
// import 'package:macrotracker/providers/foodEntryProvider.dart';
// import 'package:macrotracker/theme/app_theme.dart';
// import 'package:provider/provider.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:syncfusion_flutter_charts/charts.dart';
// import 'package:syncfusion_flutter_sliders/sliders.dart';
// import 'package:intl/intl.dart';
// import 'dart:math';

// class TdeeDashboardScreen extends StatefulWidget {
//   final bool hideAppBar;

//   const TdeeDashboardScreen({
//     super.key,
//     this.hideAppBar = false,
//   });

//   @override
//   State<TdeeDashboardScreen> createState() => _TdeeDashboardScreenState();
// }

// class _TdeeDashboardScreenState extends State<TdeeDashboardScreen> {
//   double _proteinPercentage = 25;
//   double _carbsPercentage = 45;
//   double _fatPercentage = 30;

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
//     final theme = Theme.of(context);
//     final customColors = theme.extension<CustomColors>()!;

//     return Scaffold(
//       backgroundColor: theme.scaffoldBackgroundColor,
//       appBar: widget.hideAppBar
//           ? null
//           : AppBar(
//               title: Text(
//                 'TDEE Dashboard',
//                 style: GoogleFonts.inter(
//                   fontSize: 24,
//                   fontWeight: FontWeight.w600,
//                   color: customColors.textPrimary,
//                 ),
//               ),
//               backgroundColor: Colors.transparent,
//               elevation: 0,
//               systemOverlayStyle: theme.brightness == Brightness.light
//                   ? SystemUiOverlayStyle.dark
//                   : SystemUiOverlayStyle.light,
//               leading: IconButton(
//                 icon: Icon(Icons.arrow_back, color: customColors.textPrimary),
//                 onPressed: () => Navigator.of(context).pop(),
//               ),
//             ),
//       body: Consumer2<ExpenditureProvider, FoodEntryProvider>(
//         builder: (context, expenditureProvider, foodProvider, child) {
//           if (expenditureProvider.isLoading) {
//             return const Center(child: CupertinoActivityIndicator());
//           } else if (expenditureProvider.error != null) {
//             return Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Text(
//                   expenditureProvider.error!,
//                   style:
//                       GoogleFonts.inter(color: Colors.redAccent, fontSize: 14),
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//             );
//           } else if (expenditureProvider.currentExpenditure != null) {
//             return _buildTdeeDashboard(
//                 context, expenditureProvider, foodProvider, customColors);
//           } else {
//             return Center(
//               child: Padding(
//                 padding: const EdgeInsets.all(20.0),
//                 child: Text(
//                   'Calculating expenditure & goals... Please ensure you have logged sufficient weight and nutrition data.',
//                   style: GoogleFonts.inter(fontSize: 14),
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//             );
//           }
//         },
//       ),
//     );
//   }

//   Widget _buildTdeeDashboard(
//       BuildContext context,
//       ExpenditureProvider expenditureProvider,
//       FoodEntryProvider foodProvider,
//       CustomColors customColors) {
//     final tdee = expenditureProvider.currentExpenditure!;

//     // Calculate data quality/confidence level based on available data
//     final confidenceLevel = _calculateConfidenceLevel(expenditureProvider);

//     return RefreshIndicator(
//       onRefresh: () => expenditureProvider.updateExpenditure(),
//       child: SingleChildScrollView(
//         physics: const AlwaysScrollableScrollPhysics(),
//         child: Padding(
//           padding: const EdgeInsets.all(16.0),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               // Central TDEE Display Card
//               _buildTdeeDisplayCard(
//                   context, tdee, confidenceLevel, customColors),

//               const SizedBox(height: 24),

//               // Interactive Macro Distribution Visualizer
//               _buildMacroDistributionCard(
//                   context, tdee, foodProvider, customColors),

//               const SizedBox(height: 24),

//               // Data Quality Indicator
//               _buildDataQualityCard(context, confidenceLevel, customColors),

//               const SizedBox(height: 24),

//               // Body Composition Card (if BMI/body fat data is available)
//               _buildBodyCompositionCard(context, foodProvider, customColors),

//               const SizedBox(height: 24),

//               // Trend Analysis Section
//               _buildTrendAnalysisCard(context, customColors),

//               const SizedBox(height: 24),

//               // Adaptive Recommendations Panel
//               _buildRecommendationsCard(
//                   context, tdee, confidenceLevel, customColors),

//               const SizedBox(height: 20),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   // TDEE Display Card
//   Widget _buildTdeeDisplayCard(BuildContext context, double tdee,
//       double confidenceLevel, CustomColors customColors) {
//     final colorScheme = Theme.of(context).colorScheme;
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
//       decoration: BoxDecoration(
//         color: customColors.cardBackground,
//         borderRadius: BorderRadius.circular(24),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.06),
//             blurRadius: 12,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Daily Energy Needs',
//                     style: GoogleFonts.inter(
//                       fontSize: 20,
//                       fontWeight: FontWeight.w700,
//                       color: customColors.textPrimary,
//                     ),
//                   ),
//                   const SizedBox(height: 4),
//                   Text(
//                     'Based on your weight and calorie data',
//                     style: GoogleFonts.inter(
//                       fontSize: 14,
//                       color: customColors.textSecondary,
//                     ),
//                   ),
//                 ],
//               ),
//               _buildConfidenceIndicator(confidenceLevel, customColors),
//             ],
//           ),
//           const SizedBox(height: 24),
//           Container(
//             padding: const EdgeInsets.all(24),
//             decoration: BoxDecoration(
//               color: customColors.dateNavigatorBackground.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(20),
//             ),
//             child: Center(
//               child: Column(
//                 children: [
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     crossAxisAlignment: CrossAxisAlignment.end,
//                     children: [
//                       Text(
//                         tdee.toStringAsFixed(0),
//                         style: GoogleFonts.inter(
//                           fontSize: 48,
//                           fontWeight: FontWeight.bold,
//                           color: customColors.accentPrimary,
//                         ),
//                       ),
//                       Padding(
//                         padding: const EdgeInsets.only(bottom: 8.0),
//                         child: Text(
//                           ' kcal',
//                           style: GoogleFonts.inter(
//                             fontSize: 20,
//                             color: customColors.textSecondary,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 16),
//                   Text(
//                     'TDEE = Total Daily Energy Expenditure',
//                     style: GoogleFonts.inter(
//                       fontSize: 14,
//                       color: customColors.textSecondary,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 20),
//           const Divider(height: 1),
//           const SizedBox(height: 20),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.center,
//             children: [
//               Icon(
//                 Icons.info_outline,
//                 size: 16,
//                 color: customColors.textSecondary,
//               ),
//               const SizedBox(width: 8),
//               Flexible(
//                 child: Text(
//                   'This is calculated based on your weight changes and calorie intake over time',
//                   style: GoogleFonts.inter(
//                     fontSize: 13,
//                     color: customColors.textSecondary,
//                     fontStyle: FontStyle.italic,
//                   ),
//                   textAlign: TextAlign.center,
//                 ),
//               ),
//             ],
//           ),
//         ],
//       ),
//     );
//   }

//   // Helper method to build confidence indicator
//   Widget _buildConfidenceIndicator(
//       double confidenceLevel, CustomColors customColors) {
//     Color color;
//     String label;

//     if (confidenceLevel >= 0.8) {
//       color = Colors.green;
//       label = 'High';
//     } else if (confidenceLevel >= 0.5) {
//       color = Colors.orange;
//       label = 'Medium';
//     } else {
//       color = Colors.red;
//       label = 'Low';
//     }

//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
//       decoration: BoxDecoration(
//         color: color.withOpacity(0.2),
//         borderRadius: BorderRadius.circular(12),
//       ),
//       child: Row(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           Text(
//             'Confidence: ',
//             style: GoogleFonts.inter(
//               fontSize: 12,
//               color: customColors.textSecondary,
//             ),
//           ),
//           Text(
//             label,
//             style: GoogleFonts.inter(
//               fontSize: 12,
//               color: color,
//               fontWeight: FontWeight.bold,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Macro Distribution Card
//   Widget _buildMacroDistributionCard(BuildContext context, double tdee,
//       FoodEntryProvider foodProvider, CustomColors customColors) {
//     final colorScheme = Theme.of(context).colorScheme;

//     // Calculate macros based on TDEE and percentages
//     final caloriesFromProtein = tdee * (_proteinPercentage / 100);
//     final caloriesFromCarbs = tdee * (_carbsPercentage / 100);
//     final caloriesFromFat = tdee * (_fatPercentage / 100);

//     // Convert calories to grams (protein: 4 cal/g, carbs: 4 cal/g, fat: 9 cal/g)
//     final proteinGrams = caloriesFromProtein / 4;
//     final carbsGrams = caloriesFromCarbs / 4;
//     final fatGrams = caloriesFromFat / 9;

//     // Data for the pie chart - use app-specific colors
//     final List<MacroData> macroData = [
//       MacroData('Protein', _proteinPercentage, Colors.blue.shade600),
//       MacroData('Carbs', _carbsPercentage, Colors.red.shade600),
//       MacroData('Fat', _fatPercentage, Colors.amber.shade600),
//     ];

//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
//       decoration: BoxDecoration(
//         color: customColors.cardBackground,
//         borderRadius: BorderRadius.circular(24),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.06),
//             blurRadius: 12,
//             offset: const Offset(0, 5),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 'Macro Distribution',
//                 style: GoogleFonts.inter(
//                   fontSize: 20,
//                   fontWeight: FontWeight.w700,
//                   color: customColors.textPrimary,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               Text(
//                 'Daily macronutrient breakdown',
//                 style: GoogleFonts.inter(
//                   fontSize: 14,
//                   color: customColors.textSecondary,
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 24),

//           // Enhanced chart section with better styling
//           Container(
//             height: 220,
//             padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
//             decoration: BoxDecoration(
//               color: customColors.dateNavigatorBackground.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: Row(
//               children: [
//                 // Pie Chart
//                 Expanded(
//                   flex: 5,
//                   child: Stack(
//                     alignment: Alignment.center,
//                     children: [
//                       AspectRatio(
//                         aspectRatio: 1,
//                         child: Container(
//                           padding: const EdgeInsets.all(20),
//                           child: CustomPaint(
//                             painter: MacroPieChartPainter(
//                               macroData: macroData,
//                               holeRadius: 0.6,
//                               backgroundColor: customColors.cardBackground,
//                             ),
//                             size: Size.infinite,
//                           ),
//                         ),
//                       ),
//                       Column(
//                         mainAxisSize: MainAxisSize.min,
//                         children: [
//                           Text(
//                             'Daily',
//                             style: GoogleFonts.inter(
//                               fontSize: 11,
//                               color: customColors.textSecondary,
//                             ),
//                           ),
//                           Text(
//                             'Calories',
//                             style: GoogleFonts.inter(
//                               fontSize: 11,
//                               color: customColors.textSecondary,
//                             ),
//                           ),
//                           Text(
//                             tdee.toStringAsFixed(0),
//                             style: GoogleFonts.inter(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                               color: customColors.accentPrimary,
//                             ),
//                           ),
//                         ],
//                       ),
//                       // Macro labels positioned around the chart
//                       ...macroData.asMap().entries.map((entry) {
//                         final i = entry.key;
//                         final data = entry.value;
//                         final angle = (i * 2 * pi / macroData.length) -
//                             pi / 2 +
//                             (macroData.take(i).fold(0.0,
//                                         (sum, data) => sum + data.percentage) +
//                                     data.percentage / 2) *
//                                 2 *
//                                 pi /
//                                 100;

//                         final labelRadius = 0.85;
//                         final x = cos(angle) * labelRadius;
//                         final y = sin(angle) * labelRadius;

//                         return Positioned(
//                           left: MediaQuery.of(context).size.width *
//                               0.2 *
//                               (0.5 + x * 0.8),
//                           top: 110 * (0.5 + y * 0.8),
//                           child: Container(
//                             padding: const EdgeInsets.symmetric(
//                                 horizontal: 4, vertical: 2),
//                             decoration: BoxDecoration(
//                               color: data.color.withOpacity(0.2),
//                               borderRadius: BorderRadius.circular(4),
//                             ),
//                             child: Text(
//                               '${data.percentage.toStringAsFixed(0)}%',
//                               style: GoogleFonts.inter(
//                                 fontSize: 10,
//                                 fontWeight: FontWeight.bold,
//                                 color: data.color,
//                               ),
//                             ),
//                           ),
//                         );
//                       }).toList(),
//                     ],
//                   ),
//                 ),

//                 // Macro details
//                 Expanded(
//                   flex: 3,
//                   child: Padding(
//                     padding: const EdgeInsets.only(left: 8),
//                     child: Column(
//                       mainAxisAlignment: MainAxisAlignment.center,
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         _buildEnhancedMacroDetailRow(
//                           'Protein',
//                           proteinGrams.round(),
//                           'g',
//                           Colors.blue.shade600,
//                           caloriesFromProtein.round(),
//                           customColors,
//                         ),
//                         const SizedBox(height: 16),
//                         _buildEnhancedMacroDetailRow(
//                           'Carbs',
//                           carbsGrams.round(),
//                           'g',
//                           Colors.red.shade600,
//                           caloriesFromCarbs.round(),
//                           customColors,
//                         ),
//                         const SizedBox(height: 16),
//                         _buildEnhancedMacroDetailRow(
//                           'Fat',
//                           fatGrams.round(),
//                           'g',
//                           Colors.amber.shade600,
//                           caloriesFromFat.round(),
//                           customColors,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           const SizedBox(height: 24),

//           // Sliders section with better styling
//           Container(
//             padding: const EdgeInsets.all(16),
//             decoration: BoxDecoration(
//               color: customColors.dateNavigatorBackground.withOpacity(0.2),
//               borderRadius: BorderRadius.circular(16),
//             ),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   children: [
//                     Icon(
//                       Icons.tune,
//                       size: 16,
//                       color: customColors.accentPrimary,
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       'Adjust Macro Distribution',
//                       style: GoogleFonts.inter(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w600,
//                         color: customColors.textPrimary,
//                       ),
//                     ),
//                   ],
//                 ),
//                 const SizedBox(height: 16),
//                 _buildEnhancedMacroSlider(
//                   context,
//                   'Protein',
//                   _proteinPercentage,
//                   Colors.blue.shade600,
//                   (value) {
//                     setState(() {
//                       _proteinPercentage = value;
//                       // Adjust other macros to ensure they sum to 100%
//                       _adjustOtherMacros('protein');
//                     });
//                   },
//                   customColors,
//                 ),
//                 const SizedBox(height: 12),
//                 _buildEnhancedMacroSlider(
//                   context,
//                   'Carbs',
//                   _carbsPercentage,
//                   Colors.red.shade600,
//                   (value) {
//                     setState(() {
//                       _carbsPercentage = value;
//                       _adjustOtherMacros('carbs');
//                     });
//                   },
//                   customColors,
//                 ),
//                 const SizedBox(height: 12),
//                 _buildEnhancedMacroSlider(
//                   context,
//                   'Fat',
//                   _fatPercentage,
//                   Colors.amber.shade600,
//                   (value) {
//                     setState(() {
//                       _fatPercentage = value;
//                       _adjustOtherMacros('fat');
//                     });
//                   },
//                   customColors,
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // Enhanced macro detail row with calories
//   Widget _buildEnhancedMacroDetailRow(
//     String label,
//     int value,
//     String unit,
//     Color color,
//     int calories,
//     CustomColors customColors,
//   ) {
//     return Row(
//       children: [
//         Container(
//           width: 12,
//           height: 12,
//           decoration: BoxDecoration(
//             color: color,
//             shape: BoxShape.circle,
//           ),
//         ),
//         const SizedBox(width: 8),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 label,
//                 style: GoogleFonts.inter(
//                   fontSize: 12,
//                   fontWeight: FontWeight.w500,
//                   color: customColors.textPrimary,
//                 ),
//               ),
//               FittedBox(
//                 fit: BoxFit.scaleDown,
//                 alignment: Alignment.centerLeft,
//                 child: Row(
//                   children: [
//                     Text(
//                       '$value$unit',
//                       style: GoogleFonts.inter(
//                         fontSize: 14,
//                         fontWeight: FontWeight.bold,
//                         color: color,
//                       ),
//                     ),
//                     Text(
//                       ' • $calories kcal',
//                       style: GoogleFonts.inter(
//                         fontSize: 11,
//                         color: customColors.textSecondary,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     );
//   }

//   // Enhanced macro slider with better styling
//   Widget _buildEnhancedMacroSlider(
//     BuildContext context,
//     String label,
//     double value,
//     Color color,
//     Function(double) onChanged,
//     CustomColors customColors,
//   ) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             Text(
//               label,
//               style: GoogleFonts.inter(
//                 fontSize: 13,
//                 fontWeight: FontWeight.w500,
//                 color: color,
//               ),
//             ),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
//               decoration: BoxDecoration(
//                 color: color.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: Text(
//                 '${value.toStringAsFixed(1)}%',
//                 style: GoogleFonts.inter(
//                   fontSize: 13,
//                   fontWeight: FontWeight.bold,
//                   color: color,
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         SfSlider(
//           min: 5.0,
//           max: 70.0,
//           value: value,
//           interval: 10,
//           showTicks: false,
//           showLabels: false,
//           enableTooltip: true,
//           activeColor: color,
//           inactiveColor: color.withOpacity(0.2),
//           onChanged: (dynamic newValue) {
//             onChanged(newValue as double);
//           },
//         ),
//       ],
//     );
//   }

//   // Helper method to adjust other macros when one is changed
//   void _adjustOtherMacros(String changedMacro) {
//     // Ensure all macros sum to 100%
//     final total = _proteinPercentage + _carbsPercentage + _fatPercentage;

//     if (total != 100) {
//       final difference = 100 - total;

//       if (changedMacro == 'protein') {
//         // Distribute the difference proportionally between carbs and fat
//         final totalOthers = _carbsPercentage + _fatPercentage;
//         if (totalOthers > 0) {
//           _carbsPercentage += difference * (_carbsPercentage / totalOthers);
//           _fatPercentage += difference * (_fatPercentage / totalOthers);
//         } else {
//           // If others are 0, split evenly
//           _carbsPercentage += difference / 2;
//           _fatPercentage += difference / 2;
//         }
//       } else if (changedMacro == 'carbs') {
//         final totalOthers = _proteinPercentage + _fatPercentage;
//         if (totalOthers > 0) {
//           _proteinPercentage += difference * (_proteinPercentage / totalOthers);
//           _fatPercentage += difference * (_fatPercentage / totalOthers);
//         } else {
//           _proteinPercentage += difference / 2;
//           _fatPercentage += difference / 2;
//         }
//       } else if (changedMacro == 'fat') {
//         final totalOthers = _proteinPercentage + _carbsPercentage;
//         if (totalOthers > 0) {
//           _proteinPercentage += difference * (_proteinPercentage / totalOthers);
//           _carbsPercentage += difference * (_carbsPercentage / totalOthers);
//         } else {
//           _proteinPercentage += difference / 2;
//           _carbsPercentage += difference / 2;
//         }
//       }

//       // Round to one decimal place
//       _proteinPercentage = double.parse(_proteinPercentage.toStringAsFixed(1));
//       _carbsPercentage = double.parse(_carbsPercentage.toStringAsFixed(1));
//       _fatPercentage = double.parse(_fatPercentage.toStringAsFixed(1));
//     }
//   }

//   // Helper method for confidence level
//   double _calculateConfidenceLevel(ExpenditureProvider provider) {
//     // This is a placeholder. In a real implementation, this would be based on
//     // the quality of data used to calculate TDEE (e.g., number of days with data, consistency)
//     return 0.75; // 75% confidence
//   }

//   // Body Composition Card
//   Widget _buildBodyCompositionCard(BuildContext context,
//       FoodEntryProvider foodProvider, CustomColors customColors) {
//     final colorScheme = Theme.of(context).colorScheme;

//     // Placeholder values - in a real implementation, these would come from user data
//     const double bodyWeight = 75.0; // kg
//     const double bodyFatPercentage = 20.0; // %

//     // Calculate lean body mass and fat mass
//     final double leanBodyMass = bodyWeight * (1 - bodyFatPercentage / 100);
//     final double fatMass = bodyWeight * (bodyFatPercentage / 100);

//     // Calculate recommended protein based on lean body mass
//     final double proteinRecommendation =
//         leanBodyMass * 1.8; // 1.8g per kg of LBM

//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Body Composition',
//               style: GoogleFonts.poppins(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 color: colorScheme.onSurface,
//               ),
//             ),
//             const SizedBox(height: 16),

//             // Weight and body fat percentage
//             Row(
//               mainAxisAlignment: MainAxisAlignment.spaceAround,
//               children: [
//                 Column(
//                   children: [
//                     Text(
//                       'Weight',
//                       style: GoogleFonts.poppins(
//                         fontSize: 14,
//                         color: colorScheme.onSurface.withOpacity(0.7),
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       '${bodyWeight.toStringAsFixed(1)} kg',
//                       style: GoogleFonts.poppins(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//                 Column(
//                   children: [
//                     Text(
//                       'Body Fat',
//                       style: GoogleFonts.poppins(
//                         fontSize: 14,
//                         color: colorScheme.onSurface.withOpacity(0.7),
//                       ),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       '${bodyFatPercentage.toStringAsFixed(1)}%',
//                       style: GoogleFonts.poppins(
//                         fontSize: 18,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   ],
//                 ),
//               ],
//             ),

//             const SizedBox(height: 24),

//             // Body composition visualization
//             SizedBox(
//               height: 120,
//               child: Stack(
//                 alignment: Alignment.center,
//                 children: [
//                   SfCircularChart(
//                     margin: EdgeInsets.zero,
//                     series: <CircularSeries>[
//                       DoughnutSeries<Map<String, dynamic>, String>(
//                         dataSource: [
//                           {
//                             'category': 'Lean Mass',
//                             'value': leanBodyMass,
//                             'color': colorScheme.primary
//                           },
//                           {
//                             'category': 'Fat Mass',
//                             'value': fatMass,
//                             'color': colorScheme.secondary
//                           },
//                         ],
//                         xValueMapper: (data, _) => data['category'] as String,
//                         yValueMapper: (data, _) => data['value'] as double,
//                         pointColorMapper: (data, _) => data['color'] as Color,
//                         radius: '80%',
//                         innerRadius: '60%',
//                         dataLabelSettings: const DataLabelSettings(
//                           isVisible: false,
//                         ),
//                       ),
//                     ],
//                   ),
//                   Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Text(
//                         'Lean Body Mass',
//                         style: GoogleFonts.poppins(
//                           fontSize: 12,
//                           color: colorScheme.onSurface.withOpacity(0.7),
//                         ),
//                       ),
//                       Text(
//                         '${leanBodyMass.toStringAsFixed(1)} kg',
//                         style: GoogleFonts.poppins(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),

//             const SizedBox(height: 16),

//             // Protein recommendation based on lean body mass
//             Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: colorScheme.primary.withOpacity(0.1),
//                 borderRadius: BorderRadius.circular(8),
//               ),
//               child: Row(
//                 children: [
//                   Icon(
//                     Icons.fitness_center,
//                     color: colorScheme.primary,
//                     size: 20,
//                   ),
//                   const SizedBox(width: 12),
//                   Expanded(
//                     child: Column(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         Text(
//                           'Recommended Protein',
//                           style: GoogleFonts.poppins(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w500,
//                           ),
//                         ),
//                         const SizedBox(height: 4),
//                         Text(
//                           '${proteinRecommendation.round()} g daily based on your lean body mass',
//                           style: GoogleFonts.poppins(
//                             fontSize: 12,
//                             color: colorScheme.onSurface.withOpacity(0.7),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Trend Analysis Card
//   Widget _buildTrendAnalysisCard(
//       BuildContext context, CustomColors customColors) {
//     final colorScheme = Theme.of(context).colorScheme;

//     // Sample data for the charts - in a real implementation, this would come from user's history
//     final List<WeightData> weightData = List.generate(
//       14,
//       (index) => WeightData(
//         DateTime.now().subtract(Duration(days: 13 - index)),
//         75 -
//             (index * 0.1) +
//             (index % 3 == 0
//                 ? 0.2
//                 : -0.1), // Generate a downward trend with some noise
//       ),
//     );

//     final List<CalorieData> calorieData = List.generate(
//       14,
//       (index) => CalorieData(
//         DateTime.now().subtract(Duration(days: 13 - index)),
//         1900 +
//             (index * 10) +
//             (index % 2 == 0
//                 ? 100
//                 : -100), // Generate an upward trend with some noise
//       ),
//     );

//     // Calculate weight trend (simple linear regression)
//     final double weightTrend = _calculateWeightTrend(weightData);

//     // Projected weight in 4 weeks based on current trend
//     final double currentWeight = weightData.last.weight;
//     final double projectedWeight =
//         currentWeight + (weightTrend * 28); // 28 days

//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Trend Analysis',
//               style: GoogleFonts.poppins(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 color: colorScheme.onSurface,
//               ),
//             ),
//             const SizedBox(height: 16),

//             // Enhanced chart with custom styling
//             Container(
//               height: 250,
//               padding: const EdgeInsets.all(8),
//               decoration: BoxDecoration(
//                 color: colorScheme.surface,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.03),
//                     blurRadius: 8,
//                     spreadRadius: 0,
//                     offset: const Offset(0, 2),
//                   )
//                 ],
//               ),
//               child: SfCartesianChart(
//                 plotAreaBorderWidth: 0,
//                 margin: const EdgeInsets.all(10),
//                 primaryXAxis: DateTimeAxis(
//                   intervalType: DateTimeIntervalType.days,
//                   interval: 2,
//                   dateFormat: DateFormat.MMMd(),
//                   majorGridLines: const MajorGridLines(width: 0),
//                   axisLine: const AxisLine(width: 0.5, color: Colors.grey),
//                   labelStyle: GoogleFonts.poppins(
//                     fontSize: 10,
//                     color: colorScheme.onSurface.withOpacity(0.6),
//                   ),
//                 ),
//                 primaryYAxis: NumericAxis(
//                   labelFormat: '{value} kg',
//                   axisLine: const AxisLine(width: 0),
//                   majorTickLines: const MajorTickLines(size: 0),
//                   labelStyle: GoogleFonts.poppins(
//                     fontSize: 10,
//                     color: colorScheme.onSurface.withOpacity(0.6),
//                   ),
//                   majorGridLines: MajorGridLines(
//                     width: 0.5,
//                     color: Colors.grey.withOpacity(0.3),
//                     dashArray: const [5, 5],
//                   ),
//                 ),
//                 axes: <ChartAxis>[
//                   NumericAxis(
//                     name: 'calorieAxis',
//                     opposedPosition: true,
//                     labelFormat: '{value} kcal',
//                     axisLine: const AxisLine(width: 0),
//                     majorTickLines: const MajorTickLines(size: 0),
//                     labelStyle: GoogleFonts.poppins(
//                       fontSize: 10,
//                       color: colorScheme.onSurface.withOpacity(0.6),
//                     ),
//                   ),
//                 ],
//                 series: <CartesianSeries>[
//                   // Weight data
//                   AreaSeries<WeightData, DateTime>(
//                     name: 'Weight',
//                     dataSource: weightData,
//                     xValueMapper: (WeightData data, _) => data.date,
//                     yValueMapper: (WeightData data, _) => data.weight,
//                     markerSettings: MarkerSettings(
//                       isVisible: true,
//                       height: 6,
//                       width: 6,
//                       shape: DataMarkerType.circle,
//                       borderWidth: 2,
//                       borderColor: colorScheme.primary,
//                       color: colorScheme.background,
//                     ),
//                     borderColor: colorScheme.primary,
//                     borderWidth: 2,
//                     color: colorScheme.primary.withOpacity(0.2),
//                     gradient: LinearGradient(
//                       begin: Alignment.topCenter,
//                       end: Alignment.bottomCenter,
//                       colors: [
//                         colorScheme.primary.withOpacity(0.2),
//                         colorScheme.primary.withOpacity(0.05),
//                       ],
//                     ),
//                   ),
//                   // Calorie data
//                   LineSeries<CalorieData, DateTime>(
//                     name: 'Calories',
//                     dataSource: calorieData,
//                     xValueMapper: (CalorieData data, _) => data.date,
//                     yValueMapper: (CalorieData data, _) => data.calories,
//                     yAxisName: 'calorieAxis',
//                     markerSettings: MarkerSettings(
//                       isVisible: true,
//                       height: 6,
//                       width: 6,
//                       shape: DataMarkerType.circle,
//                       borderWidth: 2,
//                       borderColor: colorScheme.secondary,
//                       color: colorScheme.background,
//                     ),
//                     color: colorScheme.secondary,
//                     width: 2,
//                     dashArray: const [5, 3],
//                   ),
//                 ],
//                 legend: Legend(
//                   isVisible: true,
//                   position: LegendPosition.bottom,
//                   alignment: ChartAlignment.center,
//                   overflowMode: LegendItemOverflowMode.wrap,
//                   textStyle: GoogleFonts.poppins(
//                     fontSize: 12,
//                     color: colorScheme.onSurface,
//                   ),
//                   iconHeight: 12,
//                   iconWidth: 12,
//                   padding: 10,
//                 ),
//                 tooltipBehavior: TooltipBehavior(
//                   enable: true,
//                   animationDuration: 150,
//                   color: colorScheme.surface,
//                   textStyle: GoogleFonts.poppins(
//                     color: colorScheme.onSurface,
//                   ),
//                   borderColor: Colors.grey.withOpacity(0.3),
//                   borderWidth: 1,
//                 ),
//               ),
//             ),

//             const SizedBox(height: 20),

//             // Enhanced projection info
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 color: colorScheme.surface,
//                 borderRadius: BorderRadius.circular(12),
//                 boxShadow: [
//                   BoxShadow(
//                     color: Colors.black.withOpacity(0.03),
//                     blurRadius: 8,
//                     spreadRadius: 0,
//                     offset: const Offset(0, 2),
//                   ),
//                 ],
//                 border: Border.all(color: Colors.grey.withOpacity(0.1)),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   // Trend information with icon
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       Row(
//                         children: [
//                           Container(
//                             padding: const EdgeInsets.all(8),
//                             decoration: BoxDecoration(
//                               color:
//                                   (weightTrend < 0 ? Colors.green : Colors.red)
//                                       .withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(8),
//                             ),
//                             child: Icon(
//                               weightTrend < 0
//                                   ? Icons.arrow_downward
//                                   : Icons.arrow_upward,
//                               size: 16,
//                               color:
//                                   weightTrend < 0 ? Colors.green : Colors.red,
//                             ),
//                           ),
//                           const SizedBox(width: 12),
//                           Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 'Current Trend',
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 12,
//                                   color: colorScheme.onSurface.withOpacity(0.6),
//                                 ),
//                               ),
//                               Text(
//                                 '${(weightTrend * 7).abs().toStringAsFixed(1)} kg/week',
//                                 style: GoogleFonts.poppins(
//                                   fontSize: 16,
//                                   fontWeight: FontWeight.bold,
//                                   color: weightTrend < 0
//                                       ? Colors.green
//                                       : Colors.red,
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ],
//                       ),
//                       Column(
//                         crossAxisAlignment: CrossAxisAlignment.end,
//                         children: [
//                           Text(
//                             'Projected in 4 weeks',
//                             style: GoogleFonts.poppins(
//                               fontSize: 12,
//                               color: colorScheme.onSurface.withOpacity(0.6),
//                             ),
//                           ),
//                           Text(
//                             '${projectedWeight.toStringAsFixed(1)} kg',
//                             style: GoogleFonts.poppins(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                               color: colorScheme.onSurface,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),

//                   const SizedBox(height: 16),

//                   // Goal progress tracker
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Row(
//                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                         children: [
//                           Text(
//                             'Goal Progress',
//                             style: GoogleFonts.poppins(
//                               fontSize: 12,
//                               fontWeight: FontWeight.w500,
//                               color: colorScheme.onSurface,
//                             ),
//                           ),
//                           Text(
//                             '40%',
//                             style: GoogleFonts.poppins(
//                               fontSize: 12,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.green,
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 8),
//                       Stack(
//                         children: [
//                           // Background track
//                           Container(
//                             height: 8,
//                             width: double.infinity,
//                             decoration: BoxDecoration(
//                               color: Colors.grey.withOpacity(0.1),
//                               borderRadius: BorderRadius.circular(4),
//                             ),
//                           ),
//                           // Progress indicator
//                           Container(
//                             height: 8,
//                             width: MediaQuery.of(context).size.width *
//                                 0.4 *
//                                 0.7, // 40% of available width (minus padding)
//                             decoration: BoxDecoration(
//                               gradient: LinearGradient(
//                                 colors: [
//                                   Colors.green.shade300,
//                                   Colors.green,
//                                 ],
//                                 begin: Alignment.centerLeft,
//                                 end: Alignment.centerRight,
//                               ),
//                               borderRadius: BorderRadius.circular(4),
//                               boxShadow: [
//                                 BoxShadow(
//                                   color: Colors.green.withOpacity(0.3),
//                                   blurRadius: 4,
//                                   offset: const Offset(0, 1),
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 8),
//                       Row(
//                         children: [
//                           Icon(
//                             Icons.check_circle,
//                             size: 14,
//                             color: Colors.green,
//                           ),
//                           const SizedBox(width: 4),
//                           Text(
//                             'On track to reach your goal',
//                             style: GoogleFonts.poppins(
//                               fontSize: 12,
//                               color: Colors.green,
//                             ),
//                           ),
//                         ],
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Recommendations Card
//   Widget _buildRecommendationsCard(BuildContext context, double tdee,
//       double confidenceLevel, CustomColors customColors) {
//     final colorScheme = Theme.of(context).colorScheme;

//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.all(8),
//                   decoration: BoxDecoration(
//                     color: colorScheme.primary.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   child: Icon(
//                     Icons.lightbulb_outline,
//                     color: colorScheme.primary,
//                     size: 20,
//                   ),
//                 ),
//                 const SizedBox(width: 12),
//                 Text(
//                   'Adaptive Recommendations',
//                   style: GoogleFonts.poppins(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                     color: colorScheme.onSurface,
//                   ),
//                 ),
//               ],
//             ),
//             const SizedBox(height: 8),
//             Text(
//               'Personalized insights based on your data',
//               style: GoogleFonts.poppins(
//                 fontSize: 12,
//                 color: colorScheme.onSurface.withOpacity(0.6),
//                 fontStyle: FontStyle.italic,
//               ),
//             ),
//             const SizedBox(height: 20),

//             // Macro recommendations with improved styling
//             _buildEnhancedRecommendationItem(
//               context,
//               'Macronutrient Balance',
//               'Increasing your protein intake may help preserve lean muscle mass while losing weight.',
//               Icons.fitness_center,
//               Colors.blue,
//               actionText: 'Adjust Macros',
//             ),

//             const SizedBox(height: 16),

//             // Activity recommendations
//             _buildEnhancedRecommendationItem(
//               context,
//               'Activity Level',
//               'Adding 2,000 more steps daily could increase your TDEE by ~100 calories.',
//               Icons.directions_walk,
//               Colors.green,
//               actionText: 'Track Activity',
//             ),

//             const SizedBox(height: 16),

//             // Data recommendations (if confidence is less than ideal)
//             if (confidenceLevel < 0.8)
//               _buildEnhancedRecommendationItem(
//                 context,
//                 'Improve Accuracy',
//                 'Log your weight and food consistently to get more accurate TDEE estimates.',
//                 Icons.data_usage,
//                 Colors.orange,
//                 priority: true,
//                 actionText: 'Log Data',
//               ),

//             if (confidenceLevel < 0.8) const SizedBox(height: 16),

//             // Calorie recommendations
//             _buildEnhancedRecommendationItem(
//               context,
//               'Calorie Timing',
//               'Consider spreading your calories more evenly throughout the day for better energy levels.',
//               Icons.schedule,
//               Colors.purple,
//               actionText: 'View Meal Times',
//             ),

//             const SizedBox(height: 24),

//             // Weekly summary card
//             Container(
//               padding: const EdgeInsets.all(16),
//               decoration: BoxDecoration(
//                 gradient: LinearGradient(
//                   colors: [
//                     colorScheme.primary.withOpacity(0.1),
//                     colorScheme.primaryContainer.withOpacity(0.2),
//                   ],
//                   begin: Alignment.topLeft,
//                   end: Alignment.bottomRight,
//                 ),
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(color: colorScheme.primary.withOpacity(0.2)),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Icon(
//                         Icons.calendar_today,
//                         size: 16,
//                         color: colorScheme.primary,
//                       ),
//                       const SizedBox(width: 8),
//                       Text(
//                         'Weekly Summary',
//                         style: GoogleFonts.poppins(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w600,
//                           color: colorScheme.primary,
//                         ),
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       _buildWeeklySummaryItem(
//                         'Avg. Deficit',
//                         '320 kcal',
//                         Icons.trending_down,
//                         Colors.green,
//                       ),
//                       _buildWeeklySummaryItem(
//                         'Weight Change',
//                         '-0.4 kg',
//                         Icons.monitor_weight,
//                         Colors.blue,
//                       ),
//                       _buildWeeklySummaryItem(
//                         'Protein Goal',
//                         '86%',
//                         Icons.check_circle,
//                         Colors.orange,
//                       ),
//                     ],
//                   ),
//                   const SizedBox(height: 12),
//                   Text(
//                     'You\'re making good progress toward your weight loss goal. Keep it up!',
//                     style: GoogleFonts.poppins(
//                       fontSize: 12,
//                       fontStyle: FontStyle.italic,
//                       color: colorScheme.onSurface.withOpacity(0.7),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Enhanced recommendation item with better styling and optional action button
//   Widget _buildEnhancedRecommendationItem(
//     BuildContext context,
//     String title,
//     String description,
//     IconData icon,
//     Color accentColor, {
//     bool priority = false,
//     String? actionText,
//   }) {
//     final colorScheme = Theme.of(context).colorScheme;

//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: BoxDecoration(
//         color: priority ? accentColor.withOpacity(0.15) : colorScheme.surface,
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(
//           color: priority
//               ? accentColor.withOpacity(0.5)
//               : Colors.grey.withOpacity(0.2),
//         ),
//         boxShadow: priority
//             ? [
//                 BoxShadow(
//                   color: accentColor.withOpacity(0.1),
//                   blurRadius: 8,
//                   offset: const Offset(0, 2),
//                 ),
//               ]
//             : null,
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Container(
//                 padding: const EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: accentColor.withOpacity(0.1),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Icon(
//                   icon,
//                   color: accentColor,
//                   size: 18,
//                 ),
//               ),
//               const SizedBox(width: 12),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Text(
//                           title,
//                           style: GoogleFonts.poppins(
//                             fontSize: 14,
//                             fontWeight: FontWeight.w600,
//                             color:
//                                 priority ? accentColor : colorScheme.onSurface,
//                           ),
//                         ),
//                         if (priority)
//                           Container(
//                             padding: const EdgeInsets.symmetric(
//                                 horizontal: 8, vertical: 2),
//                             decoration: BoxDecoration(
//                               color: accentColor.withOpacity(0.2),
//                               borderRadius: BorderRadius.circular(12),
//                             ),
//                             child: Text(
//                               'Priority',
//                               style: GoogleFonts.poppins(
//                                 fontSize: 10,
//                                 fontWeight: FontWeight.bold,
//                                 color: accentColor,
//                               ),
//                             ),
//                           ),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Text(
//                       description,
//                       style: GoogleFonts.poppins(
//                         fontSize: 12,
//                         color: colorScheme.onSurface.withOpacity(0.7),
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           if (actionText != null) ...[
//             const SizedBox(height: 12),
//             Align(
//               alignment: Alignment.centerRight,
//               child: TextButton(
//                 onPressed: () {},
//                 style: TextButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 16,
//                     vertical: 8,
//                   ),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(8),
//                   ),
//                   backgroundColor: accentColor.withOpacity(0.1),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Text(
//                       actionText,
//                       style: GoogleFonts.poppins(
//                         fontSize: 12,
//                         fontWeight: FontWeight.w500,
//                         color: accentColor,
//                       ),
//                     ),
//                     const SizedBox(width: 4),
//                     Icon(
//                       Icons.arrow_forward,
//                       size: 14,
//                       color: accentColor,
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ],
//       ),
//     );
//   }

//   // Weekly summary item
//   Widget _buildWeeklySummaryItem(
//     String label,
//     String value,
//     IconData icon,
//     Color color,
//   ) {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(10),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.1),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(
//             icon,
//             size: 20,
//             color: color,
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           value,
//           style: GoogleFonts.poppins(
//             fontSize: 14,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//         Text(
//           label,
//           style: GoogleFonts.poppins(
//             fontSize: 10,
//             color: Colors.grey,
//           ),
//         ),
//       ],
//     );
//   }

//   // Helper method to calculate weight trend (change per day)
//   double _calculateWeightTrend(List<WeightData> weightData) {
//     if (weightData.length < 2) return 0;

//     // Simple linear regression
//     double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
//     int n = weightData.length;

//     for (int i = 0; i < n; i++) {
//       // X is the day number (0, 1, 2, ...)
//       double x = i.toDouble();
//       // Y is the weight
//       double y = weightData[i].weight;

//       sumX += x;
//       sumY += y;
//       sumXY += x * y;
//       sumX2 += x * x;
//     }

//     // Calculate slope (change per day)
//     double slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
//     return slope;
//   }

//   // Data Quality Indicator Card
//   Widget _buildDataQualityCard(
//       BuildContext context, double confidenceLevel, CustomColors customColors) {
//     final colorScheme = Theme.of(context).colorScheme;

//     // Calculate relative values for visualization
//     final daysWithData =
//         (confidenceLevel * 28).round(); // Assuming 28 days lookback
//     final dataCompleteness = confidenceLevel;
//     final dataConsistency = confidenceLevel *
//         0.8; // Slightly lower than confidence for demonstration

//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'Data Quality',
//               style: GoogleFonts.poppins(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w600,
//                 color: colorScheme.onSurface,
//               ),
//             ),
//             const SizedBox(height: 16),

//             // Data completeness indicator
//             Row(
//               children: [
//                 Expanded(
//                   flex: 2,
//                   child: Text(
//                     'Completeness:',
//                     style: GoogleFonts.poppins(fontSize: 14),
//                   ),
//                 ),
//                 Expanded(
//                   flex: 3,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(4),
//                         child: LinearProgressIndicator(
//                           value: dataCompleteness,
//                           minHeight: 8,
//                           backgroundColor: Colors.grey.withOpacity(0.2),
//                           valueColor: AlwaysStoppedAnimation<Color>(
//                               _getQualityColor(dataCompleteness)),
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         '$daysWithData days logged',
//                         style: GoogleFonts.poppins(
//                           fontSize: 12,
//                           color: colorScheme.onSurface.withOpacity(0.6),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 16),

//             // Data consistency indicator
//             Row(
//               children: [
//                 Expanded(
//                   flex: 2,
//                   child: Text(
//                     'Consistency:',
//                     style: GoogleFonts.poppins(fontSize: 14),
//                   ),
//                 ),
//                 Expanded(
//                   flex: 3,
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       ClipRRect(
//                         borderRadius: BorderRadius.circular(4),
//                         child: LinearProgressIndicator(
//                           value: dataConsistency,
//                           minHeight: 8,
//                           backgroundColor: Colors.grey.withOpacity(0.2),
//                           valueColor: AlwaysStoppedAnimation<Color>(
//                               _getQualityColor(dataConsistency)),
//                         ),
//                       ),
//                       const SizedBox(height: 4),
//                       Text(
//                         'Few missing days',
//                         style: GoogleFonts.poppins(
//                           fontSize: 12,
//                           color: colorScheme.onSurface.withOpacity(0.6),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 16),

//             // Overall confidence
//             Row(
//               children: [
//                 Expanded(
//                   flex: 2,
//                   child: Text(
//                     'Overall:',
//                     style: GoogleFonts.poppins(
//                         fontSize: 14, fontWeight: FontWeight.w500),
//                   ),
//                 ),
//                 Expanded(
//                   flex: 3,
//                   child: Row(
//                     children: [
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                             horizontal: 12, vertical: 4),
//                         decoration: BoxDecoration(
//                           color: _getQualityColor(confidenceLevel)
//                               .withOpacity(0.2),
//                           borderRadius: BorderRadius.circular(12),
//                         ),
//                         child: Text(
//                           '${(confidenceLevel * 100).round()}% Confidence',
//                           style: GoogleFonts.poppins(
//                             fontSize: 12,
//                             fontWeight: FontWeight.bold,
//                             color: _getQualityColor(confidenceLevel),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),

//             const SizedBox(height: 12),
//             Text(
//               'Better data leads to more accurate TDEE calculation. Log daily for best results.',
//               style: GoogleFonts.poppins(
//                 fontSize: 12,
//                 fontStyle: FontStyle.italic,
//                 color: colorScheme.onSurface.withOpacity(0.5),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   // Helper method to get color based on quality level
//   Color _getQualityColor(double qualityLevel) {
//     if (qualityLevel >= 0.8) {
//       return Colors.green;
//     } else if (qualityLevel >= 0.5) {
//       return Colors.orange;
//     } else {
//       return Colors.red;
//     }
//   }
// }

// // Data classes for charts
// class MacroData {
//   final String name;
//   final double percentage;
//   final Color color;

//   MacroData(this.name, this.percentage, this.color);
// }

// class WeightData {
//   final DateTime date;
//   final double weight;

//   WeightData(this.date, this.weight);
// }

// class CalorieData {
//   final DateTime date;
//   final double calories;

//   CalorieData(this.date, this.calories);
// }

// class MacroPieChartPainter extends CustomPainter {
//   final List<MacroData> macroData;
//   final double holeRadius;
//   final Color backgroundColor;

//   MacroPieChartPainter({
//     required this.macroData,
//     required this.holeRadius,
//     required this.backgroundColor,
//   });

//   @override
//   void paint(Canvas canvas, Size size) {
//     final paint = Paint()
//       ..style = PaintingStyle.fill
//       ..color = Colors.transparent;

//     final center = Offset(size.width / 2, size.height / 2);
//     final radius = min(size.width, size.height) / 2;

//     double startAngle = -pi / 2;
//     for (var data in macroData) {
//       final sweepAngle = 2 * pi * (data.percentage / 100);
//       final endAngle = startAngle + sweepAngle;

//       final path = Path();
//       path.moveTo(center.dx, center.dy);
//       path.arcTo(
//         Rect.fromCircle(center: center, radius: radius),
//         startAngle,
//         sweepAngle,
//         false,
//       );
//       path.lineTo(center.dx, center.dy);
//       path.close();

//       paint.color = data.color;
//       canvas.drawPath(path, paint);

//       startAngle = endAngle;
//     }

//     // Draw the center hole (to create a donut chart)
//     paint.color = backgroundColor;
//     canvas.drawCircle(center, radius * holeRadius, paint);
//   }

//   @override
//   bool shouldRepaint(CustomPainter oldDelegate) {
//     return true; // Return true to redraw when data changes
//   }
// }
