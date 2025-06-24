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
import 'package:macrotracker/services/supabase_service.dart'; // Import SupabaseService

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  _AuthGateState createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<bool> _hasLocalDataFuture;
  bool _syncTriggered = false;

  @override
  void initState() {
    super.initState();
    _hasLocalDataFuture = _checkForLocalData();
  }

  Future<bool> _checkForLocalData() async {
    final caloriesGoal = await StorageService().get('calories_goal');
    return caloriesGoal != null;
  }

  Future<void> _loadUserDataAfterLogin() async {
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) return;
    final macroResultsString =
        await StorageService().get('onboarding_macro_results');
    if (macroResultsString != null) {
      await _syncMacroResultsToSupabase(macroResultsString, currentUser);
    }
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
    final Map<String, dynamic> macroResults =
        jsonDecode(_fixJsonFormat(macroResultsString));
    await Supabase.instance.client.from('user_macros').upsert({
      'user_id': currentUser.id,
      'updated_at': DateTime.now().toIso8601String(),
      'calories_goal': macroResults['caloriesGoal'],
      'protein_goal': macroResults['proteinGoal'],
      'carbs_goal': macroResults['carbsGoal'],
      'fat_goal': macroResults['fatGoal'],
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final session = authSnapshot.data?.session;

        if (session != null && !_syncTriggered) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            SupabaseService().syncOnAppStart(session.user.id);
          });
          _syncTriggered = true;
        }
        
        if (authSnapshot.hasError) {
          return const Scaffold(
              body: Center(child: Text("Error in authentication stream")));
        }
        if (!authSnapshot.hasData || authSnapshot.data == null) {
          return const Welcomescreen();
        }

        final authEvent = authSnapshot.data!.event;
        if (authEvent == AuthChangeEvent.signedOut) {
          return const Welcomescreen();
        }

        return FutureBuilder<bool>(
          future: _hasLocalDataFuture,
          builder: (context, localDataSnapshot) {
            if (localDataSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            final hasLocalData = localDataSnapshot.data ?? false;

            if (session == null) {
              return const Welcomescreen();
            }

            if (authEvent == AuthChangeEvent.signedIn) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await _loadUserDataAfterLogin();
                if (session.user != null) {
                  PostHogService.identifyUser(
                    session.user.id,
                    userProperties: {'email': session.user.email},
                  );
                  print("[AuthGate] PostHog user identified: ${session.user.id}");
                }
              });
            }

            if (!hasLocalData) {
              return const OnboardingScreen();
            }

            return PaywallGate(
              child: const Dashboard(),
            );
          },
        );
      },
    );
  }
}
