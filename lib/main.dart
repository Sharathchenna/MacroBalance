// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:macrotracker/auth/auth_gate.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/GoalsPage.dart';
import 'package:macrotracker/screens/dashboard.dart';
import 'package:macrotracker/screens/accountdashboard.dart'; // Added import
import 'package:macrotracker/AI/gemini.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:macrotracker/services/api_service.dart';
import 'package:macrotracker/services/camera_service.dart';
import 'package:macrotracker/services/widget_service.dart';
import 'package:macrotracker/providers/themeProvider.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'providers/meal_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:uni_links/uni_links.dart';

// Add a global key for widget test access
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Add route name constants at the top level
class Routes {
  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String initial = '/';
  static const String authGate = '/auth';
  static const String dashboard = '/dashboard';
  static const String goals = '/goals';
  static const String search = '/search';
  static const String account = '/account';
}

// Add route observer
class MyRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('Navigation: Pushed ${route.settings.name}');
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('Navigation: Popped ${route.settings.name}');
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    debugPrint(
        'Navigation: Replaced ${oldRoute?.settings.name} with ${newRoute?.settings.name}');
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    debugPrint('Navigation: Removed ${route.settings.name}');
  }
}

bool _initialUriHandled = false;

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

  // Initialize the widget service
  await WidgetService.initWidgetService();

  // Force refresh widgets when app starts to ensure sync
  try {
    await WidgetService.forceWidgetRefresh();
  } catch (e) {
    debugPrint('Failed to refresh widgets on app start: $e');
  }

  await Posthog().screen(screenName: "MainScreen");

  // Initialize deep link handling
  initDeepLinks();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FoodEntryProvider()),
        ChangeNotifierProvider(create: (_) => DateProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MealProvider()), // Move this here
      ],
      child: const MyApp(), // Add const
    ),
  );
}

// Add this function to handle deep links
Future<void> initDeepLinks() async {
  // Handle app opened from a link
  try {
    final initialUri = await getInitialUri();
    if (initialUri != null) {
      debugPrint('Initial URI: $initialUri');
      _handleDeepLink(initialUri);
    }
    _initialUriHandled = true;
  } on PlatformException catch (e) {
    debugPrint('Failed to get initial URI: ${e.message}');
  }

  // Handle links when app is already running
  uriLinkStream.listen((Uri? uri) {
    if (!_initialUriHandled) return;
    if (uri != null) {
      debugPrint('URI link received: $uri');
      _handleDeepLink(uri);
    }
  }, onError: (Object err) {
    debugPrint('URI link error: $err');
  });
}

// Function to handle the deep link
void _handleDeepLink(Uri uri) {
  // Extract the path from the URI
  final path = uri.path;

  debugPrint('Handling deep link path: $path');

  // Navigate based on the path
  if (path.isEmpty || path == '/') {
    navigatorKey.currentState?.pushNamed(Routes.dashboard);
    return;
  }

  // Check if the path exists in our routes
  switch (path) {
    case '/dashboard':
      navigatorKey.currentState?.pushNamed(Routes.dashboard);
      break;
    case '/goals':
      navigatorKey.currentState?.pushNamed(Routes.goals);
      break;
    case '/search':
      navigatorKey.currentState?.pushNamed(Routes.search);
      break;
    case '/account':
      navigatorKey.currentState?.pushNamed(Routes.account);
      break;
    default:
      // If we don't recognize the path, go to dashboard
      navigatorKey.currentState?.pushNamed(Routes.dashboard);
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
      return MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'MacroTracker',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
        initialRoute: Routes.initial,
        navigatorObservers: [MyRouteObserver()],
        routes: {
          Routes.initial: (context) => const AuthGate(),
          Routes.onboarding: (context) => const OnboardingScreen(),
          Routes.home: (context) => const Dashboard(),
          Routes.dashboard: (context) => const Dashboard(),
          Routes.goals: (context) => const GoalsScreen(),
          Routes.search: (context) => const FoodSearchPage(),
          Routes.account: (context) => const AccountDashboard(),
        },
        onGenerateRoute: (settings) {
          // Handle any dynamic routes or routes with parameters here
          debugPrint('Generating route for: ${settings.name}');
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const AuthGate(),
          );
        },
        onUnknownRoute: (settings) {
          debugPrint('Unknown route: ${settings.name}');
          return MaterialPageRoute(
            settings: settings,
            builder: (_) => const AuthGate(),
          );
        },
      );
    });
  }
}
