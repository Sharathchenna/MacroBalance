// ignore_for_file: unused_import

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:macrotracker/auth/auth_gate.dart';
import 'package:macrotracker/auth/paywall_gate.dart';
import 'package:macrotracker/firebase_options.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/screens/NativeStatsScreen.dart'; // Replace GoalsPage import with NativeStatsScreen
import 'package:macrotracker/screens/dashboard.dart';
import 'package:macrotracker/screens/accountdashboard.dart'; // Added import
import 'package:macrotracker/AI/gemini.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
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
import 'package:app_links/app_links.dart'; // Replaced uni_links with app_links
import 'dart:io' show Platform;
import 'package:intl/intl.dart';
import 'package:macrotracker/screens/MacroTrackingScreen.dart';
import 'package:macrotracker/screens/WeightTrackingScreen.dart'; // Needed for date formatting
import 'package:macrotracker/screens/StepsTrackingScreen.dart';
import 'package:macrotracker/screens/expenditure_screen.dart'; // Added ExpenditureScreen
import 'package:macrotracker/services/subscription_service.dart';
import 'package:macrotracker/services/paywall_manager.dart';
import 'package:hive_flutter/hive_flutter.dart'; // Added for Hive
import 'package:macrotracker/services/storage_service.dart'; // Added StorageService
import 'package:macrotracker/providers/expenditure_provider.dart'; // Added ExpenditureProvider

// Add a global key for widget test access
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Instance for app_links
final _appLinks = AppLinks();

// Define the channel for stats communication (presentation AND data)
const MethodChannel _statsChannel = MethodChannel('app.macrobalance.com/stats');

// Global instance of FoodEntryProvider (consider a better DI approach later)
// This is needed because the method handler is outside the widget tree.
// Ensure it's initialized after Supabase and before runApp.
late FoodEntryProvider _foodEntryProviderInstance;

// Add these variables at the top of the file, after imports
DateTime? _lastStatsUpdate;
Map<String, List<Map<String, dynamic>>>? _statsCache;
const _minimumUpdateInterval = Duration(minutes: 15); // Increased to 15 minutes
DateTime? _lastRequestTime;
const _requestThrottleInterval =
    Duration(seconds: 2); // Throttle requests to max once every 2 seconds

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
  static const String weightTracking = '/weightTracking';
  static const String macroTracking = '/macroTracking';
  static const String expenditure = '/expenditure'; // Added expenditure route
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

Future<void> main() async {
  // Ensure Flutter binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive (must be done before opening boxes)
  await Hive.initFlutter();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Supabase - make sure this completes before accessing Supabase.instance
  await Supabase.initialize(
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kaXZ0YmxhYm1uZnRkcWxneXN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg4NjUyMDksImV4cCI6MjA1NDQ0MTIwOX0.zzdtVddtl8Wb8K2k-HyS3f95j3g9FT0zy-pqjmBElrU",
    url: "https://mdivtblabmnftdqlgysv.supabase.co",
  );

  // Initialize Storage Service (opens Hive box, handles migration)
  await StorageService().initialize();

  // Setup Firebase Messaging service
  await _setupFirebaseMessaging();

  // Initialize RevenueCat
  await _initializePlatformState();

  // Initialize subscription service
  await SubscriptionService().initialize();

  // Increment app session count for paywall logic (now synchronous)
  PaywallManager().incrementAppSession();

  // Initialize widget service
  await WidgetService.initWidgetService();

  // Register error handlers
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // Initialize deep links
  await _initializeDeepLinks();

  // Setup Stats Channel Handler for widgets
  _setupStatsChannelHandler();

  // Initialize food entry provider
  _foodEntryProviderInstance = FoodEntryProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _foodEntryProviderInstance),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => DateProvider()),
        ChangeNotifierProvider(create: (_) => MealProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => WeightUnitProvider()),
        // Pass FoodEntryProvider instance to ExpenditureProvider
        // ChangeNotifierProvider(
        //     create: (_) => ExpenditureProvider(_foodEntryProviderInstance)),
        ChangeNotifierProvider(create: (_) => WeightUnitProvider()),
      ],
      child: const MyApp(),
    ),
  );

  // Delayed widget refresh to avoid impacting startup time
  _delayedWidgetRefresh();
}

// New function to initialize non-essential services in the background
Future<void> _initializeServicesInBackground() async {
  // Use multiple parallel operations for faster initialization
  await Future.wait([
    _initializeFirebase(),
    _initializeSupabase(),
    _initializeDeepLinks(),
    _initializePlatformState(),
  ]);

  // Then initialize services that depend on above initializations
  // ApiService().getAccessToken(); // Removed - Token fetched by Edge Function now
  NotificationService().initialize(); // Don't await this
  WidgetService.initWidgetService(); // Don't await this

  // Delay widget refresh to avoid slowing down initial UI rendering
  _delayedWidgetRefresh();

  // Posthog logging (not critical for initial UI)
  Posthog().screen(screenName: "MainScreen");
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase initialized successfully with explicit options");
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }
}

Future<void> _initializeSupabase() async {
  try {
    await Supabase.initialize(
      anonKey:
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kaXZ0YmxhYm1uZnRkcWxneXN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg4NjUyMDksImV4cCI6MjA1NDQ0MTIwOX0.zzdtVddtl8Wb8K2k-HyS3f95j3g9FT0zy-pqjmBElrU",
      url: "https://mdivtblabmnftdqlgysv.supabase.co",
    );
  } catch (e) {
    debugPrint("Supabase initialization error: $e");
  }
}

Future<void> _initializeDeepLinks() async {
  try {
    // Use app_links to get the initial link
    final initialUri =
        await _appLinks.getInitialLink(); // Trying getInitialLink
    if (initialUri != null) {
      debugPrint('Initial URI: $initialUri');
      _handleDeepLink(initialUri);
    }
    _initialUriHandled = true;

    // Handle links when app is already running using app_links stream
    _appLinks.uriLinkStream.listen((Uri? uri) {
      if (!_initialUriHandled) return;
      if (uri != null) {
        debugPrint('URI link received: $uri');
        _handleDeepLink(uri);
      }
    }, onError: (Object err) {
      debugPrint('URI link error: $err');
    });
  } catch (e) {
    debugPrint('Deep links initialization error: $e');
  }
}

Future<void> _setupFirebaseMessaging() async {
  try {
    // Firebase Messaging setup
    if (Platform.isIOS || Platform.isAndroid) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Optional: Add other Firebase Messaging initialization here if needed
      debugPrint('Firebase Messaging initialized successfully');
    }
  } catch (e) {
    debugPrint('Firebase Messaging initialization error: $e');
  }
}

Future<void> _initializePlatformState() async {
  try {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;
    if (Platform.isAndroid) {
      // Android Implementation
    } else if (Platform.isIOS) {
      configuration =
          PurchasesConfiguration("appl_itDEUEEPnBRPlETERrSOFVFDMvZ");
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
    }
  } catch (e) {
    debugPrint('Platform state initialization error: $e');
  }
}

// Delay widget refresh to avoid impacting startup time
Future<void> _delayedWidgetRefresh() async {
  // Delay widget refresh to avoid slowing startup
  await Future.delayed(const Duration(seconds: 3));
  try {
    // Double-check that widget service is initialized
    await WidgetService.initWidgetService();
    await WidgetService.forceWidgetRefresh();
  } catch (e) {
    debugPrint('Delayed widget refresh failed: $e');
  }
}

// Function to setup the method channel handler
void _setupStatsChannelHandler() {
  _statsChannel.setMethodCallHandler((MethodCall call) async {
    switch (call.method) {
      case 'getMacroData':
        try {
          // Implement request throttling
          final now = DateTime.now();
          if (_lastRequestTime != null &&
              now.difference(_lastRequestTime!) < _requestThrottleInterval) {
            // If we have any cached data, return the most recent cache
            if (_statsCache?.isNotEmpty == true) {
              final mostRecentCache = _statsCache!.entries
                  .reduce((a, b) => a.key.compareTo(b.key) > 0 ? a : b)
                  .value;
              debugPrint(
                  '[Flutter Stats Handler] Throttled request, returning most recent cache');
              return mostRecentCache;
            }
          }
          _lastRequestTime = now;

          final args = call.arguments as Map<dynamic, dynamic>?;
          final startDateString = args?['startDate'] as String?;
          final endDateString = args?['endDate'] as String?;

          if (startDateString == null || endDateString == null) {
            throw PlatformException(
                code: 'INVALID_ARGS', message: 'Missing date arguments');
          }

          final startDate = DateTime.parse(startDateString).toLocal();
          final endDate = DateTime.parse(endDateString).toLocal();

          // Check cache first
          final cacheKey = '${startDateString}_${endDateString}';
          if (_statsCache?.containsKey(cacheKey) == true &&
              _lastStatsUpdate != null &&
              now.difference(_lastStatsUpdate!) < _minimumUpdateInterval) {
            debugPrint('[Flutter Stats Handler] Returning cached data');
            return _statsCache![cacheKey];
          }

          final dateFormatter = DateFormat("yyyy-MM-dd'T'HH:mm:ss'Z'");
          List<Map<String, dynamic>> results = [];
          DateTime currentDate = startDate;

          while (currentDate.isBefore(endDate) ||
              currentDate.isAtSameMomentAs(endDate)) {
            final entries =
                _foodEntryProviderInstance.getAllEntriesForDate(currentDate);

            double totalCarbs = 0;
            double totalFat = 0;
            double totalProtein = 0;

            for (var entry in entries) {
              final carbs =
                  entry.food.nutrients["Carbohydrate, by difference"] ?? 0;
              final fat = entry.food.nutrients["Total lipid (fat)"] ?? 0;
              final protein = entry.food.nutrients["Protein"] ?? 0;

              double quantityInGrams = entry.quantity;
              switch (entry.unit) {
                case "oz":
                  quantityInGrams *= 28.35;
                  break;
                case "kg":
                  quantityInGrams *= 1000;
                  break;
                case "lbs":
                  quantityInGrams *= 453.59;
                  break;
              }
              final multiplier = quantityInGrams / 100;
              totalCarbs += carbs * multiplier;
              totalFat += fat * multiplier;
              totalProtein += protein * multiplier;
            }

            final proteinGoal = _foodEntryProviderInstance.proteinGoal;
            final carbGoal = _foodEntryProviderInstance.carbsGoal;
            final fatGoal = _foodEntryProviderInstance.fatGoal;

            results.add({
              'date': dateFormatter.format(currentDate.toUtc()),
              'proteins': totalProtein,
              'carbs': totalCarbs,
              'fats': totalFat,
              'proteinGoal': proteinGoal,
              'carbGoal': carbGoal,
              'fatGoal': fatGoal,
            });

            currentDate = currentDate.add(const Duration(days: 1));
          }

          // Update cache and last update time
          _lastStatsUpdate = now;
          _statsCache ??= {};
          _statsCache!['${startDateString}_${endDateString}'] = results;

          debugPrint(
              '[Flutter Stats Handler] Cache updated with ${results.length} entries');
          return results;
        } catch (e) {
          debugPrint('[Flutter Stats Handler] Error: $e');
          rethrow;
        }
      default:
        throw PlatformException(
          code: 'UNSUPPORTED_METHOD',
          message: 'Method ${call.method} not supported',
        );
    }
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
    // Removed provider linking logic
    // Trigger initial expenditure calculation after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Provider.of<ExpenditureProvider>(context, listen: false)
      //     .updateExpenditure();
    });
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
  void didChangePlatformBrightness() {
    super.didChangePlatformBrightness();
    // Notify theme provider when system brightness changes
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    if (themeProvider.useSystemTheme) {
      themeProvider.notifyListeners();
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
        themeMode: themeProvider.useSystemTheme
            ? ThemeMode.system
            : themeProvider.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
        initialRoute: Routes.initial,
        navigatorObservers: [MyRouteObserver()],
        routes: {
          Routes.initial: (context) => const AuthGate(),
          Routes.onboarding: (context) => const OnboardingScreen(),
          Routes.home: (context) => const PaywallGate(child: Dashboard()),
          Routes.dashboard: (context) => const PaywallGate(child: Dashboard()),
          Routes.goals: (context) =>
              const PaywallGate(child: StepTrackingScreen()),
          Routes.search: (context) =>
              const PaywallGate(child: FoodSearchPage()),
          Routes.account: (context) =>
              const PaywallGate(child: AccountDashboard()),
          Routes.weightTracking: (context) =>
              const PaywallGate(child: WeightTrackingScreen()),
          Routes.macroTracking: (context) =>
              const PaywallGate(child: MacroTrackingScreen()),
          // Routes.expenditure: (context) => const PaywallGate(
          //     child: ExpenditureScreen()), // Added expenditure route mapping
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
