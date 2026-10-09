import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:macrotracker/providers/finish_reminder_provider.dart';
import 'package:macrotracker/services/finish_reminder_notifier.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/providers/day_status_provider.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/saved_food_provider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/providers/themeProvider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/searchPage.dart' show FoodItem, Serving;
import 'package:macrotracker/services/photo_analysis_service.dart';
import 'package:macrotracker/services/checkin_notifier.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Native plugins the app talks to. In tests they answer with null instead of
/// throwing MissingPluginException.
const _pluginChannels = [
  'posthog_flutter',
  'home_widget',
  'app.macrobalance.com/stats',
  'plugins.flutter.io/path_provider',
  'dexterous.com/flutter/local_notifications',
  'flutter_health',
  'com.superwall/SuperwallKit',
  'purchases_flutter',
  'plugins.flutter.io/firebase_messaging',
  'plugins.flutter.io/firebase_core',
  'dev.fluttercommunity.plus/package_info',
  'dev.fluttercommunity.plus/device_info',
  'com.llfbandit.app_links/messages',
  'com.macrotracker/native_camera_view',
  'com.llfbandit.app_links/events',
];

bool _ready = false;

/// Sets up storage, Supabase (signed out, pointed at a dead local URL) and
/// plugin stubs once per test file. Nothing reaches the network or a device.
Future<void> setUpTestEnvironment() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Same as the app: fonts come from assets/google_fonts, never the network.
  GoogleFonts.config.allowRuntimeFetching = false;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in _pluginChannels) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async => null);
  }
  CheckinNotifier.device = _NoNotifications();
  FinishReminderNotifier.device = NoFinishReminders();
  if (_ready) return;
  SharedPreferences.setMockInitialValues({});
  final dir = await Directory.systemTemp.createTemp('macrotracker_test');
  Hive.init(dir.path);
  // In memory, so writes finish under the test clock instead of waiting on
  // real file I/O (which can leave Hive's write queue stuck between tests).
  await Hive.openBox<dynamic>('user_preferences', bytes: Uint8List(0));
  await StorageService().initialize();
  await Supabase.initialize(
    url: 'http://127.0.0.1:9',
    anonKey: 'test-anon-key',
    authOptions: const FlutterAuthClientOptions(
      localStorage: EmptyLocalStorage(),
      autoRefreshToken: false,
    ),
    debug: false,
  );
  await _loadAppFonts();
  _ready = true;
}

/// Wraps [child] in the app's real providers and theme, as main.dart does.
Widget testApp(
  Widget child, {
  FoodEntryProvider? foodEntryProvider,
  GoalsProvider? goalsProvider,
  DateProvider? dateProvider,
  PhotoAnalysisService? photoAnalysisService,
  WeightUnitProvider? weightUnitProvider,
  EnergyProvider? energyProvider,
  FinishReminderProvider? finishReminderProvider,
  DetailedStatsProvider? detailedStatsProvider,
  bool dark = true,
}) {
  final goals = goalsProvider ?? GoalsProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<GoalsProvider>.value(value: goals),
      ChangeNotifierProvider(create: (_) => DayStatusProvider()),
      ChangeNotifierProvider<FinishReminderProvider>.value(
          value: finishReminderProvider ?? FinishReminderProvider()),
      ChangeNotifierProvider<FoodEntryProvider>.value(
          value: (foodEntryProvider ?? FoodEntryProvider())..attachGoals(goals)),
      // No inputs unless a test sets them, so it never runs on its own.
      ChangeNotifierProvider<EnergyProvider>.value(
          value: energyProvider ?? EnergyProvider(inBackground: false)),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider<DateProvider>.value(
          value: dateProvider ?? DateProvider()),
      if (photoAnalysisService != null)
        ChangeNotifierProvider<PhotoAnalysisService>.value(value: photoAnalysisService)
      else
        ChangeNotifierProvider(create: (_) => PhotoAnalysisService()),
      ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
      ChangeNotifierProvider(create: (_) => SavedFoodProvider()),
      if (weightUnitProvider != null)
        ChangeNotifierProvider<WeightUnitProvider>.value(value: weightUnitProvider)
      else
        ChangeNotifierProvider(create: (_) => WeightUnitProvider()),
      ChangeNotifierProvider<DetailedStatsProvider>.value(
          value: detailedStatsProvider ?? DetailedStatsProvider()),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      home: child,
    ),
  );
}

/// A logged food like the ones the AI search produces.
FoodEntry testEntry({
  required String name,
  required String meal,
  required DateTime date,
  double calories = 100,
  double quantity = 1,
  String serving = '1 serving',
}) {
  return FoodEntry(
    id: '${name}_${meal}_${date.millisecondsSinceEpoch}_${quantity}_$calories',
    food: FoodItem(
      fdcId: name.hashCode.toString(),
      name: name,
      calories: calories,
      nutrients: {
        'Protein': 5,
        'Carbohydrate, by difference': 10,
        'Total lipid (fat)': 3,
      },
      brandName: 'AI Detected',
      mealType: meal,
      servingSize: 100,
      servings: const <Serving>[],
    ),
    meal: meal,
    quantity: quantity,
    unit: 'serving',
    date: date,
    servingDescription: '${quantity == 1 ? '1.0' : quantity} x $serving',
  );
}

/// Lets real I/O (Hive writes) finish, then settles the UI. Plain
/// pumpAndSettle runs on a fake clock that file writes never complete under.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pumpAndSettle();
  }
}

/// Pumps a few seconds of frames without waiting for every animation to end
/// (loading spinners and Lottie animations never do).
Future<void> pumpFrames(WidgetTester tester, {int seconds = 3}) async {
  await tester.pump();
  for (var i = 0; i < seconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// Registers the bundled fonts under the names google_fonts uses, plus Roboto
/// as the default family, so text in tests is as wide as on a phone. Without
/// this, tests draw every glyph as a full square and report false overflows.
Future<void> _loadAppFonts() async {
  const variants = {
    'Regular': 'regular',
    'Italic': 'italic',
    'Medium': '500',
    'SemiBold': '600',
    'Bold': '700',
    'ExtraBold': '800',
  };
  final dir = Directory('assets/google_fonts');
  final roboto = FontLoader('Roboto');
  for (final file in dir.listSync().whereType<File>()) {
    final name = file.uri.pathSegments.last.replaceAll('.ttf', '');
    final parts = name.split('-');
    final variant = variants[parts.last];
    if (variant == null) continue;
    final bytes = file.readAsBytesSync();
    final data = Future.value(ByteData.view(bytes.buffer));
    await (FontLoader('${parts.first}_$variant')..addFont(data)).load();
    if (parts.first == 'Roboto') roboto.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await roboto.load();
}

/// The check-in notification, kept off the (absent) device.
class _NoNotifications extends CheckinNotifier {
  @override
  Future<bool> allowed() async => false;

  @override
  Future<void> schedule(DateTime at) async {}

  @override
  Future<void> cancel() async {}
}

/// The finish-day reminder, kept off the (absent) device. Tests can set
/// [permitted] and read what would have been scheduled.
class NoFinishReminders extends FinishReminderNotifier {
  bool permitted = false;
  List<DateTime> pending = [];

  @override
  Future<bool> allowed() async => permitted;

  @override
  Future<void> schedule(int id, DateTime at) async => pending.add(at);

  @override
  Future<void> cancel() async => pending = [];
}
