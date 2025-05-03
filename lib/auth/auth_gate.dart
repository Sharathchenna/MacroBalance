import 'package:macrotracker/screens/dashboard.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
// Removed shared_preferences import
import 'package:provider/provider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/auth/paywall_gate.dart'; // Import the PaywallGate
import 'dart:convert'; // Add for JSON parsing
import 'package:macrotracker/services/storage_service.dart'; // Added StorageService
import 'package:macrotracker/services/posthog_service.dart'; // Added PostHogService import

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Remove _isLoading and _hasUserData
  // bool _isLoading = true;
  // bool _hasUserData = false;
  late Future<bool> _userDataCheckFuture; // Future to track data check

  @override
  void initState() {
    super.initState();
    // Initialize the future in initState
    _userDataCheckFuture = _checkUserData();
  }

  // Modify _checkUserData to return Future<bool> and remove setState
  Future<bool> _checkUserData() async {
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

        if (response != null) {
          // If we have data in Supabase, ensure it's synced to Hive
          await StorageService().put('macro_results', jsonEncode(response));
          await StorageService()
              .put('calories_goal', response['calories_goal']);
          await StorageService().put('protein_goal', response['protein_goal']);
          await StorageService().put('carbs_goal', response['carbs_goal']);
          await StorageService().put('fat_goal', response['fat_goal']);
          return true;
        }
      } catch (e) {
        debugPrint('Error checking Supabase data: $e');
      }
    }

    // If no Supabase data, check Hive as fallback
    String? macroResults = StorageService().get('macro_results');
    return macroResults != null;
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

      // Get goals from StorageService
      final caloriesGoal =
          StorageService().get('calories_goal', defaultValue: 2000.0);
      final proteinGoal =
          StorageService().get('protein_goal', defaultValue: 150.0);
      final carbsGoal = StorageService().get('carbs_goal', defaultValue: 225.0);
      final fatGoal = StorageService().get('fat_goal', defaultValue: 65.0);

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

  // Renamed function to load data after login, calling the correct provider method
  Future<void> _loadUserDataAfterLogin() async {
    // Renamed from _syncAllDataToSupabase
    try {
      // Access the FoodEntryProvider
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);

      // Call the method designed to clear and load fresh data for the current user
      await foodEntryProvider.loadEntriesForCurrentUser();
      print("[AuthGate] User data loaded after login.");

      // Optionally sync other provider data if needed here
      // e.g., await Provider.of<OtherProvider>(context, listen: false).loadData();

    } catch (e) {
      print('Error loading user data after login: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Wrap StreamBuilder with FutureBuilder
    return FutureBuilder<bool>(
      future: _userDataCheckFuture,
      builder: (context, futureSnapshot) {
        // Show loading while checking local data
        if (futureSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Handle potential error during data check (optional but recommended)
        if (futureSnapshot.hasError) {
          print("Error checking user data: ${futureSnapshot.error}");
          // Decide what to show on error, maybe login screen or an error message
          return const Welcomescreen(); // Fallback to welcome/login
        }

        // Data check complete, get the result
        final bool hasLocalData = futureSnapshot.data ?? false;

        // Now proceed with the authentication check using StreamBuilder
        return StreamBuilder<AuthState>(
          stream: Supabase.instance.client.auth.onAuthStateChange,
          builder: (context, authSnapshot) {
            // Show loading while checking auth state
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final authEvent = authSnapshot.data?.event;
            final session = authSnapshot.data?.session;

            // --- Handle Logout: Clear Provider Data and Navigate ---
            if (authEvent == AuthChangeEvent.signedOut) {
              // Use addPostFrameCallback to schedule the clear after the build phase,
              // and ensure it's awaited before potential navigation/rebuild.
              WidgetsBinding.instance.addPostFrameCallback((_) async { // Make async
                // Check if mounted before accessing provider
                if (mounted) {
                  try {
                    print("[AuthGate] User signed out. Clearing FoodEntryProvider...");
                    // Await the clearing process
                    await Provider.of<FoodEntryProvider>(context, listen: false)
                        .clearEntries();
                    print("[AuthGate] FoodEntryProvider cleared on logout.");
                    // Optionally clear other providers if needed

                    // Reset PostHog user identification
                    PostHogService.resetUser();
                    print("[AuthGate] PostHog user reset.");
                  } catch (e) {
                    print("Error clearing provider data or resetting PostHog user on logout: $e");
                  }
                }
              });
              // Return Welcomescreen immediately. The clearing happens async but is awaited.
              return const Welcomescreen();
            }
            // --- End Handle Logout ---

            // If session is null (and not specifically a signedOut event handled above), show welcome
            if (session == null) {
              return const Welcomescreen();
            }

            // If this is the first time authenticating, sync data to Supabase
            if (authSnapshot.hasData &&
                authSnapshot.data!.event == AuthChangeEvent.signedIn) {
              // Schedule the *load* for after the build is complete
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                // Make callback async
                // Call the renamed function to load user data
                await _loadUserDataAfterLogin();

                // Identify the user in PostHog
                if (session?.user != null) {
                  PostHogService.identifyUser(
                    session!.user.id, // Pass userId as positional argument
                    userProperties: {
                      'email': session.user.email,
                      // Add any other relevant user properties here
                    },
                  );
                  print("[AuthGate] PostHog user identified: ${session.user.id}");
                }
              });
            }

            // If user is authenticated but doesn't have macro data (based on FutureBuilder result),
            // redirect to the onboarding screen
            if (!hasLocalData) {
              return const OnboardingScreen();
            }

            // User is authenticated and has macro data
            // Wrap the Dashboard with the PaywallGate
            return PaywallGate(
              child: const Dashboard(),
            );
          },
        );
      },
    );
  }
}
