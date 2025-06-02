// ignore_for_file: prefer_single_quotes

import 'package:flutter/material.dart';
import 'package:macrotracker/screens/dashboard.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/providers/food_entry_provider.dart';
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
          // Reduce timeout to prevent hanging on Supabase query
          final response = await Supabase.instance.client
              .from('user_macros')
              .select()
              .eq('id', currentUser.id)
              .order('updated_at', ascending: false)
              .limit(1)
              .maybeSingle()
              .timeout(
            const Duration(seconds: 3), // Reduced from 10 to 3 seconds
            onTimeout: () {
              debugPrint(
                  'Supabase user data check timeout - checking local data');
              return null; // Return null on timeout to check local storage
            },
          );

          if (response != null) {
            // User has data in Supabase - sync to local storage and return true
            try {
              await StorageService().put('macro_results', jsonEncode(response));
              await StorageService()
                  .put('calories_goal', response['calories_goal']);
              await StorageService()
                  .put('protein_goal', response['protein_goal']);
              await StorageService().put('carbs_goal', response['carbs_goal']);
              await StorageService().put('fat_goal', response['fat_goal']);
            } catch (e) {
              debugPrint('Error saving to local storage: $e');
              // Continue even if local save fails
            }
            return true;
          } else {
            // No data in Supabase for authenticated user - check local storage first
            String? macroResults = StorageService().get('macro_results');
            if (macroResults != null) {
              debugPrint(
                  'Found local data despite no Supabase data - using local');
              return true;
            }
            // No local data either - trigger onboarding
            debugPrint(
                'No user data found in Supabase or local - triggering onboarding');
            return false;
          }
        } catch (e) {
          debugPrint('Error checking Supabase data: $e');
          // On error, check local storage as fallback
          String? macroResults = StorageService().get('macro_results');
          if (macroResults != null) {
            debugPrint('Supabase failed, but found local data - using local');
            return true;
          }
          return false;
        }
      } else {
        // No authenticated user - check local storage only
        String? macroResults = StorageService().get('macro_results');
        return macroResults != null;
      }
    } catch (e) {
      debugPrint('Supabase not available: $e - using local storage only');
      // Continue with local storage if Supabase is not available
      try {
        String? macroResults = StorageService().get('macro_results');
        return macroResults != null;
      } catch (storageError) {
        debugPrint('Error accessing local storage: $storageError');
        return false; // If both Supabase and local storage fail, trigger onboarding
      }
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
            // If stream is null (Supabase unavailable), check local data and show appropriate screen
            if (authSnapshot.connectionState == ConnectionState.none &&
                authSnapshot.data == null) {
              // Supabase unavailable - use local data to determine screen
              if (hasLocalData) {
                return const Dashboard();
              } else {
                return const Welcomescreen();
              }
            }

            // Add timeout for waiting state to prevent infinite loading
            if (authSnapshot.connectionState == ConnectionState.waiting) {
              // Use a timeout to prevent indefinite waiting
              Future.delayed(const Duration(seconds: 5), () {
                if (mounted &&
                    authSnapshot.connectionState == ConnectionState.waiting) {
                  debugPrint(
                      'AuthState stream timeout - proceeding with local data');
                  // This will cause a rebuild and exit the waiting state
                  setState(() {});
                }
              });

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

                PostHogService.identifyUser(
                  session.user.id,
                  userProperties: {
                    'email': session.user.email,
                  },
                );
                print("[AuthGate] PostHog user identified: ${session.user.id}");
              });
            }

            if (!hasLocalData) {
              return const PaywallGate(
                child: OnboardingScreen(),
              );
            }

            return const Dashboard();
          },
        );
      },
    );
  }
}
