import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:macrotracker/screens/Dashboard.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/food_entry_provider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/auth/paywall_gate.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/services/posthog_service.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<bool> _userDataCheckFuture;

  @override
  void initState() {
    super.initState();
    _userDataCheckFuture = _checkUserData();
  }

  Future<bool> _checkUserData() async {
    // Check if Supabase was initialized successfully
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        try {
          // Add timeout to prevent hanging on Supabase query
          final response = await Supabase.instance.client
              .from('user_macros')
              .select()
              .eq('id', currentUser.id)
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle()
              .timeout(
            const Duration(seconds: 10), // 10 second timeout
            onTimeout: () {
              debugPrint('Supabase user data check timeout - using local data');
              return null; // Return null on timeout to check local storage
            },
          );

          if (response != null) {
            await StorageService().put('macro_results', jsonEncode(response));
            await StorageService()
                .put('calories_goal', response['calories_goal']);
            await StorageService()
                .put('protein_goal', response['protein_goal']);
            await StorageService().put('carbs_goal', response['carbs_goal']);
            await StorageService().put('fat_goal', response['fat_goal']);
            return true;
          }
        } catch (e) {
          debugPrint('Error checking Supabase data: $e');
          // Fall through to check local storage instead of failing
        }
      }
    } catch (e) {
      debugPrint('Supabase not available: $e - using local storage only');
      // Continue with local storage if Supabase is not available
    }

    String? macroResults = StorageService().get('macro_results');
    return macroResults != null;
  }

  String _fixJsonFormat(String? inputJson) {
    if (inputJson == null || inputJson.isEmpty) {
      return '{}';
    }

    if (inputJson.trim().startsWith('{') && !inputJson.contains('"')) {
      try {
        String fixedJson = inputJson;

        RegExp keyRegex = RegExp(r'([a-zA-Z_][a-zA-Z0-9_]*):');
        fixedJson = fixedJson.replaceAllMapped(keyRegex, (match) {
          return '"${match.group(1)}":';
        });

        jsonDecode(fixedJson);
        return fixedJson;
      } catch (e) {
        print('Could not fix JSON format: $e');
        return '{}';
      }
    }

    return inputJson;
  }

  Future<void> _syncMacroResultsToSupabase(
      String macroResultsString, User currentUser) async {
    try {
      Map<String, dynamic> parsedMacroResults;
      try {
        parsedMacroResults = jsonDecode(macroResultsString);
      } catch (e) {
        final fixedJson = _fixJsonFormat(macroResultsString);
        parsedMacroResults = jsonDecode(fixedJson);
      }

      final caloriesGoal =
          StorageService().get('calories_goal', defaultValue: 2000.0);
      final proteinGoal =
          StorageService().get('protein_goal', defaultValue: 150.0);
      final carbsGoal = StorageService().get('carbs_goal', defaultValue: 225.0);
      final fatGoal = StorageService().get('fat_goal', defaultValue: 65.0);

      final existingRecord = await Supabase.instance.client
          .from('user_macros')
          .select('id')
          .eq('id', currentUser.id)
          .limit(1)
          .maybeSingle();

      if (existingRecord != null) {
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

  Future<void> _loadUserDataAfterLogin() async {
    try {
      final foodEntryProvider =
          Provider.of<FoodEntryProvider>(context, listen: false);

      await foodEntryProvider.loadEntriesForCurrentUser();
      print("[AuthGate] User data loaded after login.");
    } catch (e) {
      print('Error loading user data after login: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _userDataCheckFuture,
      builder: (context, futureSnapshot) {
        if (futureSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (futureSnapshot.hasError) {
          print("Error checking user data: ${futureSnapshot.error}");
          return const Welcomescreen();
        }

        final bool hasLocalData = futureSnapshot.data ?? false;

        return StreamBuilder<AuthState>(
          stream: () {
            try {
              return Supabase.instance.client.auth.onAuthStateChange;
            } catch (e) {
              debugPrint('Auth state stream unavailable: $e');
              return null; // Return null if Supabase unavailable
            }
          }(),
          builder: (context, authSnapshot) {
            // If stream is null (Supabase unavailable), show welcome screen
            if (authSnapshot.connectionState == ConnectionState.none &&
                authSnapshot.data == null) {
              return const Welcomescreen();
            }

            if (authSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final authEvent = authSnapshot.data?.event;
            final session = authSnapshot.data?.session;

            if (authEvent == AuthChangeEvent.signedOut) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (mounted) {
                  try {
                    print(
                        "[AuthGate] User signed out. Clearing FoodEntryProvider...");
                    await Provider.of<FoodEntryProvider>(context, listen: false)
                        .clearEntries();
                    print("[AuthGate] FoodEntryProvider cleared on logout.");

                    PostHogService.resetUser();
                    print("[AuthGate] PostHog user reset.");
                  } catch (e) {
                    print(
                        "Error clearing provider data or resetting PostHog user on logout: $e");
                  }
                }
              });
              return const Welcomescreen();
            }

            if (session == null) {
              return const Welcomescreen();
            }

            if (authSnapshot.hasData &&
                authSnapshot.data!.event == AuthChangeEvent.signedIn) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await _loadUserDataAfterLogin();

                if (session?.user != null) {
                  PostHogService.identifyUser(
                    session!.user.id,
                    userProperties: {
                      'email': session.user.email,
                    },
                  );
                  print(
                      "[AuthGate] PostHog user identified: ${session.user.id}");
                }
              });
            }

            if (!hasLocalData) {
              return const OnboardingScreen();
            }

            return const Dashboard();
          },
        );
      },
    );
  }
}
