import 'package:macrotracker/screens/dashboard.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final macroResults = prefs.getString('macro_results');
    setState(() {
      _hasUserData = macroResults != null && macroResults.isNotEmpty;
      _isLoading = false;
    });
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
