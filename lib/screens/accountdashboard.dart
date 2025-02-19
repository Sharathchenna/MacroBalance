import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
// Import the custom painter widget:
import 'package:macrotracker/widgets/chart_painter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart'; // if still needed

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
          "Profile",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Profile',
          style: GoogleFonts.roboto(
            color: CupertinoColors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
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

            // Weight Journey Line Graph Section
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ProgressChart(weightEntries),
            ),

            // ...other content...
          ],
        ),
      ),
    );
  }
}
