// ignore_for_file: unused_import

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:macrotracker/auth/auth_gate.dart';
import 'package:macrotracker/firebase_options.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/NativeStatsScreen.dart'; // Replace GoalsPage import with NativeStatsScreen
import 'package:macrotracker/screens/dashboard.dart';
import 'package:macrotracker/screens/accountdashboard.dart'; // Added import
import 'package:macrotracker/AI/gemini.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:macrotracker/screens/welcomescreen.dart';
import 'package:macrotracker/services/api_service.dart';
import 'package:macrotracker/services/camera_service.dart';
import 'package:macrotracker/services/notification_service.dart';
import 'package:macrotracker/services/widget_service.dart';
import 'package:macrotracker/providers/themeProvider.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'providers/meal_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_auth_ui/supabase_auth_ui.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:uni_links/uni_links.dart';
import 'dart:io' show Platform;
import 'package:intl/intl.dart'; // Needed for date formatting

// Add a global key for widget test access
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Define the channel for stats communication (presentation AND data)
const MethodChannel _statsChannel = MethodChannel('app.macrobalance.com/stats');

// Global instance of FoodEntryProvider (consider a better DI approach later)
// This is needed because the method handler is outside the widget tree.
// Ensure it's initialized after Supabase and before runApp.
late FoodEntryProvider _foodEntryProviderInstance;

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

// Helper function to set status bar style correctly for iOS
void updateStatusBarForIOS(bool isDarkMode) {
  if (Platform.isIOS) {
    // The key for iOS is to set statusBarBrightness correctly
    // Light brightness = dark content (black icons)
    // Dark brightness = light content (white icons)
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarBrightness: isDarkMode ? Brightness.dark : Brightness.light,
        // Make status bar transparent
        statusBarColor: Colors.transparent,
      ),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with explicit options
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase initialized successfully with explicit options");
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }


  // Set initial status bar style for iOS
  if (Platform.isIOS) {
    // Start with light mode styling (dark icons) by default
    updateStatusBarForIOS(false);
  }

  // await CameraService().controller;
  await ApiService().getAccessToken();
  //supabase setup
  await Supabase.initialize(
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kaXZ0YmxhYm1uZnRkcWxneXN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg4NjUyMDksImV4cCI6MjA1NDQ0MTIwOX0.zzdtVddtl8Wb8K2k-HyS3f95j3g9FT0zy-pqjmBElrU",
    url: "https://mdivtblabmnftdqlgysv.supabase.co",
  );

  // Initialize notification service
  await NotificationService().initialize();
  
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
  await initPlatformState();

  // Initialize FoodEntryProvider instance
  _foodEntryProviderInstance = FoodEntryProvider();
  // Ensure it loads initial data if necessary (might need async init)
  // await _foodEntryProviderInstance.loadInitialData(); // Example if needed

  // Setup the method call handler for stats AFTER initializing the provider
  _setupStatsChannelHandler();


  runApp(
    MultiProvider(
      // Use the globally created instance here
      providers: [
        ChangeNotifierProvider.value(value: _foodEntryProviderInstance),
        ChangeNotifierProvider(create: (_) => DateProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => MealProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

// Function to setup the method channel handler
void _setupStatsChannelHandler() {
  _statsChannel.setMethodCallHandler((MethodCall call) async {
    switch (call.method) {
      case 'getMacroData':
        try {
          final args = call.arguments as Map<dynamic, dynamic>?;
          final startDateString = args?['startDate'] as String?;
          final endDateString = args?['endDate'] as String?;

          if (startDateString == null || endDateString == null) {
            throw PlatformException(code: 'INVALID_ARGS', message: 'Missing date arguments');
          }

          final startDate = DateTime.parse(startDateString).toLocal(); // Convert to local time
          final endDate = DateTime.parse(endDateString).toLocal(); // Convert to local time
          final dateFormatter = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'"); // ISO 8601 format

          // --- Logging ---
          debugPrint('[Flutter Stats Handler] Received request for dates: $startDateString to $endDateString');
          debugPrint('[Flutter Stats Handler] Parsed local dates: $startDate to $endDate');
          // --- End Logging ---


          List<Map<String, dynamic>> results = [];
          DateTime currentDate = startDate;

          while (currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
             // --- Logging ---
             debugPrint('[Flutter Stats Handler] Processing date: $currentDate');
             // --- End Logging ---

            // Calculate consumed macros for the current date
            final entries = _foodEntryProviderInstance.getAllEntriesForDate(currentDate);
             // --- Logging ---
             debugPrint('[Flutter Stats Handler] Found ${entries.length} entries for $currentDate');
             // --- End Logging ---

            double totalCarbs = 0;
            double totalFat = 0;
            double totalProtein = 0;

            for (var entry in entries) {
              final carbs = entry.food.nutrients["Carbohydrate, by difference"] ?? 0;
              final fat = entry.food.nutrients["Total lipid (fat)"] ?? 0;
              final protein = entry.food.nutrients["Protein"] ?? 0;

              double quantityInGrams = entry.quantity;
              switch (entry.unit) {
                case "oz": quantityInGrams *= 28.35; break;
                case "kg": quantityInGrams *= 1000; break;
                case "lbs": quantityInGrams *= 453.59; break;
              }
              final multiplier = quantityInGrams / 100;
              totalCarbs += carbs * multiplier;
              totalFat += fat * multiplier;
              totalProtein += protein * multiplier;
            }

            // Get goals from the provider
            final proteinGoal = _foodEntryProviderInstance.proteinGoal;
            final carbGoal = _foodEntryProviderInstance.carbsGoal;
            final fatGoal = _foodEntryProviderInstance.fatGoal;

            results.add({
              'date': dateFormatter.format(currentDate.toUtc()), // Use UTC ISO format
              'proteins': totalProtein, // Corrected key
              'carbs': totalCarbs,
              'fats': totalFat,         // Corrected key
              'proteinGoal': proteinGoal,
              'carbGoal': carbGoal,
              'fatGoal': fatGoal,
            });

            // Move to the next day
            currentDate = currentDate.add(const Duration(days: 1));
          }
          debugPrint('[Flutter Stats Handler] Sending ${results.length} macro entries to native.');
          return results; // Return the list of maps
        } catch (e) {
           debugPrint('[Flutter Stats Handler] Error handling getMacroData: $e');
           // Return an empty list or throw an error that native side can interpret
           return []; // Or throw PlatformException(...)
        }

      // Add other cases for 'getCalorieData' if needed
      // case 'getCalorieData':
      //   // ... implementation ...
      //   return calorieResults;

      default:
        throw MissingPluginException('Not implemented: ${call.method}');
    }
  });
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

Future<void> initPlatformState() async {
  await Purchases.setLogLevel(LogLevel.debug);

  PurchasesConfiguration? configuration;
  if (Platform.isAndroid) {
    // Android Implementation
  } else if (Platform.isIOS) {
    configuration = PurchasesConfiguration("appl_itDEUEEPnBRPlETERrSOFVFDMvZ");
  }

  if (configuration != null) {
    await Purchases.configure(configuration);
  }
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

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When app resumes, reset any stale presentation state
      NativeStatsScreen.resetState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
      // Update iOS status bar style based on theme
      if (Platform.isIOS) {
        updateStatusBarForIOS(themeProvider.isDarkMode);
      } else {
        // For Android, the simpler approach works fine
        SystemChrome.setSystemUIOverlayStyle(
          themeProvider.isDarkMode
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
        );
      }

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
          Routes.goals: (context) => Builder(builder: (context) {
                // Use a Builder to get a context and then call the static method
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  NativeStatsScreen.show(context);
                });
                return const Dashboard(); // Return to Dashboard as a fallback
              }),
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
