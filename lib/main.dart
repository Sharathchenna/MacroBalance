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
import 'package:app_links/app_links.dart';
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
import 'package:macrotracker/providers/meal_planning_provider.dart'; // Added MealPlanningProvider
import 'package:macrotracker/providers/workout_planning_provider.dart'; // Added WorkoutPlanningProvider
import 'package:macrotracker/screens/loginscreen.dart';
import 'package:macrotracker/services/posthog_service.dart';
import 'package:lottie/lottie.dart';

// Add a global key for widget test access
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Define the channel for stats communication (presentation AND data)
const MethodChannel _statsChannel = MethodChannel('app.macrobalance.com/stats');

// REMOVED Global instance of FoodEntryProvider
// late FoodEntryProvider _foodEntryProviderInstance;

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

bool _initialUriHandled = false;

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
  debugPrint("[Startup Timing] Before Supabase.initialize: ${DateTime.now()}");
  await Supabase.initialize(
    anonKey:
        "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kaXZ0YmxhYm1uZnRkcWxneXN2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzg4NjUyMDksImV4cCI6MjA1NDQ0MTIwOX0.zzdtVddtl8Wb8K2k-HyS3f95j3g9FT0zy-pqjmBElrU",
    url: "https://mdivtblabmnftdqlgysv.supabase.co",
  );
  debugPrint("[Startup Timing] After Supabase.initialize: ${DateTime.now()}");

  // Initialize PostHog
  debugPrint("[PostHog] Initializing PostHogService...");
  await PostHogService.initialize();
  debugPrint("[PostHog] PostHogService initialization attempted.");

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

  // Setup Stats Channel Handler for widgets
  // Setup Stats Channel Handler for widgets - Needs access to context now or a lookup mechanism
  // We will fetch the provider inside the handler for now.
  // Setup Stats Channel Handler for widgets - Needs access to context now or a lookup mechanism
  // We will fetch the provider inside the handler for now.
  _setupStatsChannelHandler();

  // REMOVED global provider initialization

  runApp(
    // Wrap MultiProvider with a StreamProvider for AuthState
    StreamProvider<User?>.value(
      value: Supabase.instance.client.auth.onAuthStateChange
          .map((data) => data.session?.user), // Provide the User? object
      initialData: () {
        debugPrint(
            "[Startup Timing] Before Supabase.instance.client.auth.currentUser: ${DateTime.now()}");
        final currentUser = Supabase.instance.client.auth.currentUser;
        debugPrint(
            "[Startup Timing] After Supabase.instance.client.auth.currentUser: ${DateTime.now()}");
        return currentUser;
      }(), // Immediately invoke the function to get the value
      child: MultiProvider(
        providers: [
          // Use ChangeNotifierProxyProvider linked to the User? stream
          ChangeNotifierProxyProvider<User?, FoodEntryProvider>(
            create: (_) => FoodEntryProvider(), // Initial empty provider
            update: (context, user, previousProvider) {
              // This update function runs whenever the User? changes
              if (user == null) {
                // User logged out, return a NEW empty provider
                debugPrint(
                    "[ProxyProvider] User is null. Creating new empty FoodEntryProvider.");
                // Ensure previous provider data is cleared if necessary (though disposal should handle it)
                // previousProvider?.clearEntries(); // Optional: Explicit clear before returning new one
                return FoodEntryProvider();
              } else {
                // User logged in
                if (previousProvider == null ||
                    previousProvider.entries.isEmpty) {
                  // If previous was null or empty (likely just logged in or first load)
                  // Create a new provider instance and trigger loading
                  debugPrint(
                      "[ProxyProvider] User logged in (${user.id}). Creating new FoodEntryProvider and triggering load.");
                  final newProvider = FoodEntryProvider();
                  // Don't await here, let it load in background
                  debugPrint(
                      "[Startup Timing] Calling loadEntriesForCurrentUser: ${DateTime.now()}");
                  newProvider.loadEntriesForCurrentUser();
                  return newProvider;
                } else {
                  // User is the same, reuse the existing provider
                  debugPrint(
                      "[ProxyProvider] User (${user.id}) remains. Reusing existing FoodEntryProvider.");
                  return previousProvider;
                }
              }
            },
          ), // Added comma here
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => DateProvider()),
          ChangeNotifierProvider(create: (_) => MealProvider()),
          ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
          ChangeNotifierProvider(
              create: (_) => WeightUnitProvider()), // Keep this instance
          // Meal and Workout Planning Providers - Using empty constructors
          ChangeNotifierProvider(create: (_) => MealPlanningProvider()),
          ChangeNotifierProvider(create: (_) => WorkoutPlanningProvider()),
          // Pass FoodEntryProvider instance to ExpenditureProvider
          // ChangeNotifierProvider(
          //     create: (_) => ExpenditureProvider(_foodEntryProviderInstance)),
          // Removed duplicate WeightUnitProvider entry if it existed
        ],
        child: const MyApp(),
      ),
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
          "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1kaXZ0YmxhYm1uZnRkcWxneXN2Iiwicm9zZSI6ImFub24iLCJpYXQiOjE3Mzg4NjUyMDksImV4cCI6MjA1NDQ0MTIwOX0.zzdtVddtl8Wb8K2k-HyS3f95j3g9FT0zy-pqjmBElrU",
      url: "https://mdivtblabmnftdqlgysv.supabase.co",
    );
  } catch (e) {
    debugPrint("Supabase initialization error: $e");
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
// Note: Accessing provider here is tricky as it's outside the widget tree.
// We'll use the navigatorKey's context if available, otherwise log an error.
void _setupStatsChannelHandler() {
  _statsChannel.setMethodCallHandler((MethodCall call) async {
    // Get the context from the navigatorKey if possible
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint(
          "[Stats Handler] Error: Cannot get context to access FoodEntryProvider.");
      // Return an empty list or throw an error, depending on desired behavior
      return []; // Return empty list to avoid crashing the widget
    }
    // Fetch the provider instance using the context
    final foodEntryProvider =
        Provider.of<FoodEntryProvider>(context, listen: false);

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
            // Use the fetched provider instance
            final entries = foodEntryProvider.getAllEntriesForDate(currentDate);

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

            // Use the fetched provider instance
            final proteinGoal = foodEntryProvider.proteinGoal;
            final carbGoal = foodEntryProvider.carbsGoal;
            final fatGoal = foodEntryProvider.fatGoal;

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

  // Handle email verification callback
  if (uri.path.startsWith('/login-callback')) {
    // <-- Change this line
    WidgetsBinding.instance.addPostFrameCallback((_) {
      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );

      // Show success message
      if (navigatorKey.currentContext != null) {
        ScaffoldMessenger.of(navigatorKey.currentContext!).showSnackBar(
          const SnackBar(
            content: Text('Email verified successfully! Please log in.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }
}

// Add this before the MyApp class
class MyRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // Optional: Add non-PostHog analytics or logging here if needed
    // PostHog screen tracking is handled by PosthogObserver
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    // Optional: Add analytics or logging here
  }
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription? _linkSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initDeepLinks(); // Keep initialization here within the state
    // Removed provider linking logic
    // Trigger initial expenditure calculation after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Provider.of<ExpenditureProvider>(context, listen: false)
      //     .updateExpenditure();
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel(); // Ensure cancellation on dispose
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // This function now handles all deep link initialization logic
  Future<void> _initDeepLinks() async {
    final appLinks = AppLinks();
    try {
      // Handle incoming links when the app is running
      _linkSubscription = appLinks.uriLinkStream.listen((Uri? uri) {
        if (uri != null && mounted) {
          // Check if mounted before handling
          _handleDeepLink(uri);
        }
      }, onError: (err) {
        debugPrint('Error handling deep links: $err');
      });

      // Handle the case where the app was launched via a deep link
      // Needs to be done carefully as context might not be fully ready
      // Use addPostFrameCallback to ensure navigatorKey is available
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        try {
          // Get the initial link directly as Uri?
          final initialUriFromLink = await appLinks.getInitialLink();
          // Check if the Uri is not null and the widget is still mounted
          if (initialUriFromLink != null && mounted) {
            // No parsing needed, pass the Uri object directly
            _handleDeepLink(initialUriFromLink);
          }
        } on PlatformException {
          debugPrint('Failed to get initial app link.');
        } catch (e) {
          debugPrint('Error processing initial deep link: $e');
        }
      });
    } catch (e) {
      debugPrint('Deep link initialization error: $e');
    }
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
    // Update theme when system brightness changes
    if (mounted) {
      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      if (themeProvider.useSystemTheme) {
        setState(() {}); // Trigger rebuild instead of direct notifyListeners
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(builder: (context, themeProvider, child) {
      return PostHogWidget(
        // Wrap MaterialApp with PostHogWidget
        child: MaterialApp(
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
          navigatorObservers: [
            MyRouteObserver(),
            PosthogObserver(), // Add PostHog observer for automatic screen tracking
          ],
          routes: {
            Routes.initial: (context) => const AuthGate(),
            Routes.onboarding: (context) => const OnboardingScreen(),
            Routes.home: (context) => const PaywallGate(child: Dashboard()),
            Routes.dashboard: (context) =>
                const PaywallGate(child: Dashboard()),
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
        ),
      );
    });
  }
}
