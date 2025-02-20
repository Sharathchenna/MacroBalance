import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:intl/intl.dart';
// Import the custom painter widget:
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
    // Use a local variable to hold the new weight value, initialized to currentWeight.
    double newWeight = currentWeight;
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Log New Weight"),
              backgroundColor: Colors.white,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Increment / Decrement Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {
                          setStateDialog(() {
                            // Decrement weight by 0.5 (or your preferred step), ensuring it doesn't go below 0.
                            newWeight =
                                (newWeight - 0.1).clamp(0, double.infinity);
                          });
                        },
                        icon: const Icon(Icons.remove),
                      ),
                      Text(
                        newWeight.toStringAsFixed(1),
                        style: const TextStyle(fontSize: 20),
                      ),
                      IconButton(
                        onPressed: () {
                          setStateDialog(() {
                            // Increment weight by 0.5 (or your preferred step)
                            newWeight = newWeight + 0.1;
                          });
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Date Picker Row
                  Row(
                    children: [
                      Text("Date: ${DateFormat('yMMMd').format(selectedDate)}"),
                      const Spacer(),
                      TextButton(
                        child: const Text("Pick Date"),
                        onPressed: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setStateDialog(() {
                              selectedDate = picked;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      currentWeight = newWeight;
                    });
                    print("New Weight: $newWeight, Date: $selectedDate");
                    Navigator.of(context).pop();
                  },
                  child: const Text("Log"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _editGoalWeight() async {
    final TextEditingController goalController =
        TextEditingController(text: goalWeight.toString());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text("Edit Goal Weight"),
          content: TextField(
            controller: goalController,
            decoration: const InputDecoration(
              labelText: "Goal Weight",
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final newGoal = double.tryParse(goalController.text);
                if (newGoal != null) {
                  setState(() {
                    goalWeight = newGoal;
                  });
                  print("Updated Goal Weight: $newGoal");
                  Navigator.of(context).pop();
                } else {
                  // Optionally show an error message.
                }
              },
              child: const Text("Update"),
            ),
          ],
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

            // ...other content...
          ],
        ),
      ),
    );
  }
}
