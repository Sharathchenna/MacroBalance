// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:macrotracker/auth/auth_gate.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/GoalsPage.dart';
import 'package:macrotracker/screens/dashboard.dart';
import 'package:macrotracker/AI/gemini.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:macrotracker/services/api_service.dart';
import 'package:macrotracker/services/camera_service.dart';
import 'package:macrotracker/providers/themeProvider.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'providers/meal_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // await CameraService().controller;
  await ApiService().getAccessToken();
  //supabase setup
  await Supabase.initialize(
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kaXZ0YmxhYm1uZnRkcWxneXN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg4NjUyMDksImV4cCI6MjA1NDQ0MTIwOX0.zzdtVddtl8Wb8K2k-HyS3f95j3g9FT0zy-pqjmBElrU",
    url: "https://mdivtblabmnftdqlgysv.supabase.co",
  );

  await Posthog().screen(screenName: "MainScreen");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FoodEntryProvider()),
        ChangeNotifierProvider(create: (_) => DateProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MealProvider()),
        ChangeNotifierProvider(create: (_) => FoodEntryProvider()),
        ChangeNotifierProvider(create: (_) => DateProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MacroTracker',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode:
            ThemeProvider().isDarkMode ? ThemeMode.dark : ThemeMode.light,
        home: const AuthGate(),
        routes: {
          '/onboarding': (context) => const OnboardingScreen(),
          '/home': (context) =>
              const Dashboard(), // Using Dashboard as home screen
        },
      ),
    );
  }
}
