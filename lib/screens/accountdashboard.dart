import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/screens/settingsScreen.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:intl/intl.dart';
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
              backgroundColor: Colors.white,
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
                          selectedTextStyle: const TextStyle(
                            color: Colors.black,
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
                          selectedTextStyle: const TextStyle(
                            color: Colors.black,
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
                            children: const [
                              Center(
                                child: Text(
                                  'kg',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  'lbs',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
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
                        horizontal: 16.0, vertical: 10.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12.0),
                      border: Border.all(color: Colors.grey.shade200),
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
                          icon: const Icon(CupertinoIcons.calendar,
                              color: Colors.black),
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
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.black),
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
              backgroundColor: Colors.white,
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
                          selectedTextStyle: const TextStyle(
                            color: Colors.black,
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
                          selectedTextStyle: const TextStyle(
                            color: Colors.black,
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
                            children: const [
                              Center(
                                child: Text(
                                  'kg',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              Center(
                                child: Text(
                                  'lbs',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black,
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
                      child: const Text(
                        "Cancel",
                        style: TextStyle(color: Colors.black),
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
    final List<WeightEntry> weightEntries = List.generate(
      10,
      (i) => WeightEntry(
          dateTime: DateTime.now().subtract(Duration(days: i * 3)),
          weight: 75 + i.toDouble()),
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF5F4F0),
      appBar: AppBar(
        title: Text(
          'Profile',
          style: GoogleFonts.roboto(
            color: CupertinoColors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              CupertinoIcons.square_arrow_right,
              color: Colors.black87,
            ),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => CupertinoAlertDialog(
                  title: const Text('Confirm Logout'),
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
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: DefaultTextStyle.of(context).style,
                        children: const [
                          TextSpan(
                            text: 'John Doe', // replace with dynamic user name
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          WidgetSpan(child: SizedBox(width: 8)),
                          TextSpan(
                            text: '30', // replace with dynamic user age
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(CupertinoIcons.pencil),
                    onPressed: _editUserData,
                  ),
                ],
              ),
            ),

            // Weight Journey Subheading
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Weight Journey',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
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
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title with icon on top right
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  'Current Weight',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Icon(
                                  Icons.add,
                                  size: 20,
                                  color: Colors.black,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8.0),
                            Text(
                              '$currentWeight kg',
                              style: const TextStyle(
                                fontSize: 20,
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
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title with icon on top right
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: const [
                                Text(
                                  'Goal Weight',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
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
                              style: const TextStyle(
                                fontSize: 20,
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
                      children: const [
                        Icon(
                          CupertinoIcons.settings,
                          size: 30,
                          color: Colors.black87,
                        ),
                        SizedBox(width: 12),
                        Center(
                          child: Text(
                            'Settings',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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

            // ...other content...
          ],
        ),
      ),
    );
  }
}
