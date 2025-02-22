// ignore_for_file: constant_identifier_names, avoid_print

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/screens/settingsScreen.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:intl/intl.dart';
import 'package:macrotracker/theme/app_theme.dart';
// Import the custom painter widget:
import 'package:numberpicker/numberpicker.dart';
import 'package:macrotracker/widgets/chart_painter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// if still needed

// You can keep your model if needed, or simply use WeightEntry from ChartPainter.dart

class ProgressChart extends StatelessWidget {
  static const int NUMBER_OF_DAYS = 31;
  final List<WeightEntry> entries;

  const ProgressChart(this.entries, {super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: ChartPainter(_prepareEntryList(entries)),
      // Optionally set a size if not constrained by parent:
      size: const Size(double.infinity, 250),
    );
  }

  // Filter entries that are within chart time range.
  List<WeightEntry> _prepareEntryList(List<WeightEntry> initialEntries) {
    DateTime beginningDate =
        DateTime.now().subtract(const Duration(days: NUMBER_OF_DAYS));
    List<WeightEntry> entries = initialEntries
        .where((entry) => entry.dateTime.isAfter(beginningDate))
        .toList();
    // You can add further data adjustments here...
    return entries;
  }
}

class Accountdashboard extends StatefulWidget {
  const Accountdashboard({super.key});

  @override
  State<Accountdashboard> createState() => _AccountdashboardState();
}

class _AccountdashboardState extends State<Accountdashboard> {
  final _supabase = Supabase.instance.client;

  // Assume these are your dynamic values; in a real app you might fetch these from a database.
  double currentWeight = 75.0;
  double goalWeight = 70.0;
  String weightUnit = 'kg'; // Add this at the class level

  Future<void> _handleLogout() async {
    try {
      await _supabase.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacement(
            CupertinoPageRoute(builder: (context) => const Welcomescreen()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error signing out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editUserData() {
    // Implement edit functionality here
    print("Edit user data pressed");
  }

  Future<void> _logNewWeight() async {
    double newWeight = currentWeight;
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              backgroundColor:
                  Theme.of(context).extension<CustomColors>()?.cardBackground,
              // title: Center(
              //   child: Text(
              //     "Log New Weight",
              //     style: GoogleFonts.roboto(
              //       fontWeight: FontWeight.bold,
              //       fontSize: 20,
              //     ),
              //   ),
              // ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Weight Picker Section
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Integer Part
                        NumberPicker(
                          value: newWeight.floor(),
                          minValue: 0,
                          maxValue: 200,
                          itemHeight: 60,
                          itemWidth: 60,
                          textStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 20,
                          ),
                          selectedTextStyle: TextStyle(
                            color: Theme.of(context)
                                .extension<CustomColors>()
                                ?.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Colors.grey.shade300),
                              right: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onChanged: (value) {
                            HapticFeedback.selectionClick();
                            setStateDialog(() {
                              newWeight =
                                  value + (newWeight - newWeight.floor());
                            });
                          },
                        ),
                        const Text(
                          '.',
                          style: TextStyle(
                              fontSize: 32, fontWeight: FontWeight.w600),
                        ),
                        // Decimal Part
                        NumberPicker(
                          value: ((newWeight - newWeight.floor()) * 10).round(),
                          minValue: 0,
                          maxValue: 9,
                          itemHeight: 60,
                          itemWidth: 40,
                          textStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 20,
                          ),
                          selectedTextStyle: TextStyle(
                            color: Theme.of(context)
                                .extension<CustomColors>()
                                ?.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onChanged: (value) {
                            HapticFeedback.selectionClick();
                            setStateDialog(() {
                              newWeight = newWeight.floor() + (value / 10);
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        // Unit Picker (kg/lbs)
                        SizedBox(
                          width: 60, // Fixed width for the unit picker
                          height: 60,
                          child: ListWheelScrollView(
                            renderChildrenOutsideViewport: true,
                            clipBehavior: Clip.none,
                            itemExtent: 40,
                            perspective: 0.0005,
                            diameterRatio: 1.2,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setStateDialog(() {
                                weightUnit = index == 0 ? 'kg' : 'lbs';
                                // Optional: Convert the weight value when unit changes
                                if (weightUnit == 'lbs') {
                                  newWeight =
                                      (newWeight * 2.20462).roundToDouble();
                                } else {
                                  newWeight =
                                      (newWeight / 2.20462).roundToDouble();
                                }
                              });
                            },
                            children: [
                              Center(
                                child: Text(
                                  'kg',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .extension<CustomColors>()
                                        ?.textPrimary,
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  'lbs',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .extension<CustomColors>()
                                        ?.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Date Picker Row
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.light
                          ? Colors.white
                          : Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(
                          color: Theme.of(context).colorScheme.onSurface),
                    ),
                    child: Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              DateFormat('EEEE, MMMM d').format(selectedDate),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: Icon(CupertinoIcons.calendar,
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.black
                                  : Colors.white),
                          onPressed: () {
                            if (Theme.of(context).platform ==
                                TargetPlatform.iOS) {
                              // iOS - CupertinoDatePicker
                              showCupertinoModalPopup(
                                context: context,
                                builder: (BuildContext context) {
                                  return Container(
                                    height: 216,
                                    padding: const EdgeInsets.only(top: 6.0),
                                    margin: EdgeInsets.only(
                                      bottom: MediaQuery.of(context)
                                          .viewInsets
                                          .bottom,
                                    ),
                                    color: CupertinoColors.systemBackground
                                        .resolveFrom(context),
                                    child: SafeArea(
                                      top: false,
                                      child: CupertinoDatePicker(
                                        initialDateTime: selectedDate,
                                        maximumDate: DateTime.now(),
                                        minimumDate: DateTime(2000),
                                        mode: CupertinoDatePickerMode.date,
                                        onDateTimeChanged: (DateTime newDate) {
                                          setStateDialog(() {
                                            selectedDate = newDate;
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                },
                              );
                            } else {
                              // Android - Material DatePicker
                              showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: Theme.of(context).copyWith(
                                      colorScheme: ColorScheme.light(
                                        primary: Colors
                                            .blue, // header background color
                                        onPrimary:
                                            Colors.white, // header text color
                                        onSurface:
                                            Colors.black, // body text color
                                      ),
                                      textButtonTheme: TextButtonThemeData(
                                        style: TextButton.styleFrom(
                                          foregroundColor:
                                              Colors.blue, // button text color
                                        ),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              ).then((picked) {
                                if (picked != null) {
                                  setStateDialog(() {
                                    selectedDate = picked;
                                  });
                                }
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.black
                                    : Colors.white),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                          ),
                          elevation: 2,
                          backgroundColor: Colors.grey.shade200),
                      child: Text("Log", style: TextStyle(color: Colors.black)),
                      onPressed: () {
                        setState(() {
                          currentWeight = newWeight;
                        });
                        // TODO: Perform any additional logging actions here.
                        print("New Weight: $newWeight, Date: $selectedDate");
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editGoalWeight() async {
    double newGoalWeight = goalWeight;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              backgroundColor:
                  Theme.of(context).extension<CustomColors>()?.cardBackground,
              // title: Text(
              //   "Edit Goal Weight",
              //   style: GoogleFonts.roboto(
              //     fontWeight: FontWeight.bold,
              //     fontSize: 20,
              //   ),
              // ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Integer Part
                        NumberPicker(
                          value: newGoalWeight.floor(),
                          minValue: 0,
                          maxValue: 200,
                          itemHeight: 60,
                          itemWidth: 60,
                          textStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 20,
                          ),
                          selectedTextStyle: TextStyle(
                            color: Theme.of(context)
                                .extension<CustomColors>()
                                ?.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              left: BorderSide(color: Colors.grey.shade300),
                              right: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onChanged: (value) {
                            HapticFeedback.selectionClick();
                            setStateDialog(() {
                              newGoalWeight = value +
                                  (newGoalWeight - newGoalWeight.floor());
                            });
                          },
                        ),
                        const Text(
                          '.',
                          style: TextStyle(
                              fontSize: 32, fontWeight: FontWeight.w600),
                        ),
                        // Decimal Part
                        NumberPicker(
                          value: ((newGoalWeight - newGoalWeight.floor()) * 10)
                              .round(),
                          minValue: 0,
                          maxValue: 9,
                          itemHeight: 60,
                          itemWidth: 40,
                          textStyle: const TextStyle(
                            color: Colors.grey,
                            fontSize: 20,
                          ),
                          selectedTextStyle: TextStyle(
                            color: Theme.of(context)
                                .extension<CustomColors>()
                                ?.textPrimary,
                            fontSize: 32,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              right: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          onChanged: (value) {
                            HapticFeedback.selectionClick();
                            setStateDialog(() {
                              newGoalWeight =
                                  newGoalWeight.floor() + (value / 10);
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        // Unit Picker (kg/lbs)
                        SizedBox(
                          width: 60,
                          height: 60,
                          child: ListWheelScrollView(
                            itemExtent: 40,
                            perspective: 0.005,
                            diameterRatio: 1.2,
                            clipBehavior: Clip.none,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (index) {
                              setStateDialog(() {
                                weightUnit = index == 0 ? 'kg' : 'lbs';
                                if (weightUnit == 'lbs') {
                                  newGoalWeight =
                                      (newGoalWeight * 2.20462).roundToDouble();
                                } else {
                                  newGoalWeight =
                                      (newGoalWeight / 2.20462).roundToDouble();
                                }
                              });
                            },
                            children: [
                              Center(
                                child: Text(
                                  'kg',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .extension<CustomColors>()
                                        ?.textPrimary,
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  'lbs',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .extension<CustomColors>()
                                        ?.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      child: Text(
                        "Cancel",
                        style: TextStyle(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? Colors.black
                                    : Colors.white),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        elevation: 2,
                        backgroundColor: Colors.grey.shade200,
                      ),
                      child: const Text(
                        "Update",
                        style: TextStyle(color: Colors.black),
                      ),
                      onPressed: () {
                        setState(() {
                          goalWeight = newGoalWeight;
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // For demonstration, create some dummy weight entries.
    final List<WeightEntry> weightEntries = [
      WeightEntry(dateTime: DateTime.now(), weight: 75.0),
      WeightEntry(
          dateTime: DateTime.now().subtract(const Duration(days: 3)),
          weight: 75.8),
      WeightEntry(
          dateTime: DateTime.now().subtract(const Duration(days: 6)),
          weight: 76.2),
      WeightEntry(
          dateTime: DateTime.now().subtract(const Duration(days: 9)),
          weight: 75.5),
      WeightEntry(
          dateTime: DateTime.now().subtract(const Duration(days: 12)),
          weight: 76.0),
      WeightEntry(
          dateTime: DateTime.now().subtract(const Duration(days: 15)),
          weight: 75.3),
      WeightEntry(
          dateTime: DateTime.now().subtract(const Duration(days: 18)),
          weight: 74.9),
      WeightEntry(
          dateTime: DateTime.now().subtract(const Duration(days: 21)),
          weight: 75.7),
      WeightEntry(
          dateTime: DateTime.now().subtract(const Duration(days: 24)),
          weight: 76.4),
      WeightEntry(
          dateTime: DateTime.now().subtract(const Duration(days: 27)),
          weight: 76.8),
      WeightEntry(
          dateTime: DateTime.now().subtract(const Duration(days: 30)),
          weight: 77.0),
    ];
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: CupertinoNavigationBarBackButton(
          color: Theme.of(context).primaryColor,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Profile',
          style: GoogleFonts.roboto(
            color: Theme.of(context).primaryColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              CupertinoIcons.square_arrow_right,
              color: Theme.of(context).primaryColor,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: Text(
                    'Confirm Logout',
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await _handleLogout();
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // User Data Section
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                color:
                    Theme.of(context).extension<CustomColors>()?.cardBackground,
                borderRadius: BorderRadius.circular(16),
                // boxShadow: [
                //   BoxShadow(
                //     color: Colors.grey.shade200,
                //     blurRadius: 10,
                //     spreadRadius: 1,
                //     offset: const Offset(0, 2),
                //   ),
                // ],
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  // User Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'John Doe', // replace with dynamic user name
                          style: GoogleFonts.roboto(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context)
                                .extension<CustomColors>()
                                ?.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.grey.shade100
                                    : Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.calendar,
                                    size: 14,
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '30 years', // replace with dynamic user age
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                        Brightness.light
                                    ? Colors.grey.shade100
                                    : Colors.grey.shade800,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    CupertinoIcons.arrow_up_arrow_down,
                                    size: 14,
                                    color: Theme.of(context).brightness ==
                                            Brightness.light
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '175 cm', // replace with dynamic user height
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Theme.of(context).brightness ==
                                              Brightness.light
                                          ? Colors.grey.shade600
                                          : Colors.grey.shade300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Edit Button
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.light
                            ? Colors.grey.shade100
                            : Colors.grey.shade800,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        CupertinoIcons.pencil,
                        size: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    onPressed: _editUserData,
                  ),
                ],
              ),
            ),

            // Weight Journey Subheading
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Weight Journey',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 8.0),

            // Weight Journey Line Graph Section using AspectRatio for dynamic sizing
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: AspectRatio(
                aspectRatio: 12 / 9, // Adjust the ratio as needed
                child: ProgressChart(weightEntries),
              ),
            ),
            const SizedBox(height: 16.0),

            // New Section: Current Weight and Goal Weight
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  // Current Weight Box (clickable)
                  Expanded(
                    child: GestureDetector(
                      onTap: _logNewWeight, // Show log new weight pop-up
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .extension<CustomColors>()
                              ?.cardBackground,
                          border: Border.all(
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade800),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title with icon on top right
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Current Weight',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                Icon(
                                  Icons.add,
                                  size: 20,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              '$currentWeight kg',
                              style: TextStyle(
                                fontSize: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  // Goal Weight Box (editable)
                  Expanded(
                    child: GestureDetector(
                      onTap: _editGoalWeight, // Trigger edit functionality
                      child: Container(
                        padding: const EdgeInsets.all(16.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .extension<CustomColors>()
                              ?.cardBackground,
                          border: Border.all(
                              color: Theme.of(context).brightness ==
                                      Brightness.light
                                  ? Colors.grey.shade300
                                  : Colors.grey.shade800),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title with icon on top right
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Goal Weight',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                Icon(
                                  Icons.edit,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              '$goalWeight kg',
                              style: TextStyle(
                                fontSize: 20,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Separator Line
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Container(
                height: 1,
                color: Colors.grey.shade300,
              ),
            ),

            // Settings Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16.0),
                    // decoration: BoxDecoration(
                    //   borderRadius: BorderRadius.circular(8),
                    //   border: Border.all(color: Colors.grey.shade300),
                    // ),
                    child: Row(
                      children: [
                        Icon(
                          CupertinoIcons.settings,
                          size: 30,
                          color: Theme.of(context).primaryColor,
                        ),
                        SizedBox(width: 12),
                        Center(
                          child: Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        Spacer(),
                        Icon(
                          CupertinoIcons.chevron_right,
                          size: 20,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 150),
            // ...other content...
          ],
        ),
      ),
    );
  }
}
