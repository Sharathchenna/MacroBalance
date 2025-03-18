import 'package:macrotracker/screens/dashboard.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'dart:convert'; // Add for JSON parsing

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoading = true;
  bool _hasUserData = false;

  @override
  void initState() {
    super.initState();
    _checkUserData();
  }

  Future<void> _checkUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String? macroResults = prefs.getString('macro_results');

    // If the user is authenticated, check Supabase for their data
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      try {
        // Try to fetch user macro data from Supabase - using .limit(1) and order by to ensure we get the most recent entry
        final response = await Supabase.instance.client
            .from('user_macros')
            .select()
            .eq('id', currentUser.id)
            .order('updated_at', ascending: false) // Get the most recent entry
            .limit(1) // Limit to one row
            .maybeSingle();

        // If data exists in Supabase but not locally, save it locally
        if (response != null) {
          if (macroResults == null || macroResults.isEmpty) {
            // If the response has macro_results field as a JSON object or string
            if (response['macro_results'] != null) {
              // Make sure we have a proper JSON string
              if (response['macro_results'] is Map) {
                macroResults = jsonEncode(response['macro_results']);
              } else {
                macroResults = response['macro_results'].toString();
              }

              // Try to ensure it's valid JSON before saving
              try {
                jsonDecode(macroResults);
                await prefs.setString('macro_results', macroResults);
              } catch (e) {
                print('Error parsing macro results JSON: $e');
                // Try to fix the format if it's not valid JSON
                macroResults = _fixJsonFormat(macroResults);
                await prefs.setString('macro_results', macroResults);
              }
            }
          }

          // Also sync nutrition goals
          if (response['calories_goal'] != null) {
            await prefs.setDouble(
                'calories_goal', response['calories_goal'].toDouble());
          }
          if (response['protein_goal'] != null) {
            await prefs.setDouble(
                'protein_goal', response['protein_goal'].toDouble());
          }
          if (response['carbs_goal'] != null) {
            await prefs.setDouble(
                'carbs_goal', response['carbs_goal'].toDouble());
          }
          if (response['fat_goal'] != null) {
            await prefs.setDouble('fat_goal', response['fat_goal'].toDouble());
          }
        }
        // If data exists locally but not in Supabase, upload it to Supabase
        else if (macroResults != null && macroResults.isNotEmpty) {
          await _syncMacroResultsToSupabase(macroResults, currentUser);
        }

        // Fetch food entries data if available - use .limit(1) here as well
        final foodEntriesResponse = await Supabase.instance.client
            .from('user_food_entries')
            .select('entries_json')
            .eq('user_id', currentUser.id)
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (foodEntriesResponse != null &&
            foodEntriesResponse['entries_json'] != null) {
          // Save food entries locally
          await prefs.setString(
              'food_entries', foodEntriesResponse['entries_json']);
        }
      } catch (e) {
        print('Error checking Supabase for user data: $e');
        // If error but we have local data, try to upload it
        if (macroResults != null && macroResults.isNotEmpty) {
          await _syncMacroResultsToSupabase(macroResults, currentUser);
        }
      }
    }

    setState(() {
      _hasUserData = macroResults != null && macroResults.isNotEmpty;
      _isLoading = false;
    });
  }

  // Helper method to fix incorrectly formatted JSON
  String _fixJsonFormat(String? inputJson) {
    if (inputJson == null || inputJson.isEmpty) {
      return '{}';
    }

    // If it starts with a '{' it might be JSON-like but malformed
    if (inputJson.trim().startsWith('{') && !inputJson.contains('"')) {
      // Try to convert keys without quotes to properly quoted keys
      try {
        // Common pattern: {key: value, key2: value2}
        String fixedJson = inputJson;

        // Replace occurrences of "key:" with "\"key\":" (for string keys)
        RegExp keyRegex = RegExp(r'([a-zA-Z_][a-zA-Z0-9_]*):');
        fixedJson = fixedJson.replaceAllMapped(keyRegex, (match) {
          return '"${match.group(1)}":';
        });

        // Try to parse the fixed JSON
        jsonDecode(fixedJson);
        return fixedJson;
      } catch (e) {
        print('Could not fix JSON format: $e');
        // Return a valid empty JSON object as fallback
        return '{}';
      }
    }

    return inputJson;
  }

  // Helper method to sync local data to Supabase
  Future<void> _syncMacroResultsToSupabase(
      String macroResultsString, User currentUser) async {
    try {
      // Parse the macro results
      Map<String, dynamic> parsedMacroResults;
      try {
        parsedMacroResults = jsonDecode(macroResultsString);
      } catch (e) {
        // Try to fix the JSON format
        final fixedJson = _fixJsonFormat(macroResultsString);
        parsedMacroResults = jsonDecode(fixedJson);
      }

      final prefs = await SharedPreferences.getInstance();
      final caloriesGoal = prefs.getDouble('calories_goal') ?? 2000.0;
      final proteinGoal = prefs.getDouble('protein_goal') ?? 150.0;
      final carbsGoal = prefs.getDouble('carbs_goal') ?? 225.0;
      final fatGoal = prefs.getDouble('fat_goal') ?? 65.0;

      // Use upsert with an ON CONFLICT strategy - check if a record with this ID already exists
      final existingRecord = await Supabase.instance.client
          .from('user_macros')
          .select('id')
          .eq('id', currentUser.id)
          .limit(1)
          .maybeSingle();

      if (existingRecord != null) {
        // Update the existing record
        await Supabase.instance.client.from('user_macros').update({
          'email': currentUser.email ?? '',
          'macro_results': parsedMacroResults,
          'calories_goal': caloriesGoal,
          'protein_goal': proteinGoal,
          'carbs_goal': carbsGoal,
          'fat_goal': fatGoal,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', currentUser.id);
      } else {
        // Insert a new record
        await Supabase.instance.client.from('user_macros').insert({
          'id': currentUser.id,
          'email': currentUser.email ?? '',
          'macro_results': parsedMacroResults,
          'calories_goal': caloriesGoal,
          'protein_goal': proteinGoal,
          'carbs_goal': carbsGoal,
          'fat_goal': fatGoal,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      print('Nutrition goals synced to Supabase');
    } catch (e) {
      print('Error syncing macro results to Supabase: $e');
    }
  }

  Future<void> _syncAllDataToSupabase() async {
    try {
      // Access the FoodEntryProvider to sync all data
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);
      await foodEntryProvider.syncAllDataWithSupabase();

      // Add this line to explicitly load entries from Supabase
      await foodEntryProvider.loadEntriesFromSupabase();
    } catch (e) {
      print('Error syncing all data to Supabase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || _isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = snapshot.data?.session;
        if (session == null) {
          return const Welcomescreen();
        }

        // If this is the first time authenticating, sync data to Supabase
        if (snapshot.hasData &&
            snapshot.data!.event == AuthChangeEvent.signedIn) {
          // Schedule the sync for after the build is complete
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _syncAllDataToSupabase();
          });
        }

        // If user is authenticated but doesn't have macro data,
        // redirect to the onboarding screen
        if (!_hasUserData) {
          return const OnboardingScreen();
        }

        // User is authenticated and has macro data
        return const Dashboard();
      },
    );
  }
}
