// Run only with: flutter run -t test_driver/feature_demo.dart
// The signed-in shell on a hand-made week of food, for recording a walkthrough
// of the meal-logging changes. Offline, in its own Hive directory, like
// store_screenshots.dart.
//
// The host drives it with taps on the simulator, plus one command file the app
// polls: <Documents>/demo_cmd.txt with a line "photo <Meal>" starts a meal
// photo analysis that takes a few seconds and returns two foods.
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:macrotracker/main.dart' show navigatorKey;
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/providers/finish_reminder_provider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/meal_provider.dart';
import 'package:macrotracker/providers/saved_food_provider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/providers/themeProvider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/providers/day_status_provider.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/screens/app_shell.dart';
import 'package:macrotracker/screens/dashboard/components/photo_job_card.dart';
import 'package:macrotracker/screens/searchPage.dart' show FoodItem, Serving;
import 'package:macrotracker/services/checkin_notifier.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/finish_reminder_notifier.dart';
import 'package:macrotracker/services/photo_analysis_service.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'goal_scenarios.dart' show QAGoalScenario;

Future<void> main() async {
  _OfflineBinding();
  if (!kDebugMode) throw UnsupportedError('Demo entrypoint is debug only');
  GoogleFonts.config.allowRuntimeFetching = false;
  final documents = await getApplicationDocumentsDirectory();
  final isolated = Directory('${documents.path}/feature_demo');
  if (isolated.existsSync()) isolated.deleteSync(recursive: true);
  await isolated.create(recursive: true);
  Hive.init(isolated.path);
  final box = await Hive.openBox<dynamic>('user_preferences');
  await box.put('prefs_migrated_to_hive_v1', true);
  await StorageService().initialize();
  await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'qa-local-only',
      authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(), autoRefreshToken: false),
      debug: false);
  CheckinNotifier.device = _NoCheckins();
  FinishReminderNotifier.device = _NoFinish();

  final s = await QAGoalScenario.load(GoalKind.lose);
  await StorageService().put('isDarkMode', true);
  await s.food.clearEntries();
  await _seed(s.food);

  final photos = PhotoAnalysisService(
    onReady: showPhotoJobBanner,
    analyzer: (_) async {
      await Future<void>.delayed(const Duration(seconds: 7));
      return [
        AIFoodItem(
            name: 'Paneer Butter Masala',
            servingSizes: ['1 bowl (250g)', '100g'],
            calories: [420, 168],
            protein: [18, 7.2],
            carbohydrates: [16, 6.4],
            fat: [32, 12.8],
            fiber: [3, 1.2]),
        AIFoodItem(
            name: 'Butter Naan',
            servingSizes: ['1 piece (90g)', '100g'],
            calories: [260, 289],
            protein: [8, 8.9],
            carbohydrates: [40, 44],
            fat: [7, 7.8],
            fiber: [2, 2.2]),
      ];
    },
  );
  _pollCommands(documents, photos);
  runApp(_DemoApp(s, photos));
}

typedef _Food = (String name, String serving, double kcal, double p, double c, double f);

const _coffee = ('Filter Coffee', '1 cup', 60.0, 2.0, 6.0, 3.0);
const _snackSides = <_Food>[
  ('Marie Biscuits', '4 biscuits', 120, 2, 20, 4),
  ('Samosa', '1 piece', 260, 4, 30, 14),
  ('Roasted Peanuts', '1 handful', 170, 7, 5, 14),
  ('Banana', '1 medium', 105, 1, 27, 0),
  ('Masala Chips', '1 small pack', 160, 2, 15, 10),
];

Future<void> _seed(FoodEntryProvider food) async {
  final now = DateTime.now();
  var n = 0;
  Future<void> log(int daysAgo, String meal, _Food f, {int hour = 12}) =>
      food.addEntry(FoodEntry(
          id: 'demo-${n++}',
          food: FoodItem(
              fdcId: 'demo-${f.$1}',
              name: f.$1,
              calories: f.$3,
              nutrients: {
                'Protein': f.$4,
                'Carbohydrate, by difference': f.$5,
                'Total lipid (fat)': f.$6,
              },
              brandName: 'AI Detected',
              mealType: meal,
              servingSize: 100,
              servings: const <Serving>[]),
          meal: meal,
          quantity: 1,
          unit: 'serving',
          date: DateTime(now.year, now.month, now.day - daysAgo, hour),
          servingDescription: '1.0 x ${f.$2}'));

  // Coffee with the evening snack on three of the last few days, next to
  // something different each time.
  for (final (d, side) in [(1, 0), (2, 1), (4, 2)]) {
    await log(d, 'Snacks', _coffee, hour: 17);
    await log(d, 'Snacks', _snackSides[side], hour: 17);
  }
  // Oats most mornings, so they're "most logged".
  for (final d in [1, 2, 3, 5]) {
    await log(d, 'Breakfast', ('Overnight Oats', '1 jar', 320, 14, 48, 8), hour: 8);
  }
  await log(1, 'Lunch', ('Rajma Chawal', '1 plate', 520, 18, 86, 10), hour: 13);
  await log(1, 'Dinner', ('Chicken Biryani', '1 plate', 610, 32, 72, 20), hour: 20);
  await log(1, 'Dinner', ('Raita', '1 bowl', 90, 4, 7, 5), hour: 20);
  await log(2, 'Dinner', ('Dal Tadka', '1 bowl', 230, 12, 30, 7), hour: 20);
  await log(3, 'Lunch', ('Veg Pulao', '1 plate', 420, 9, 70, 11), hour: 13);

  // Today: a full breakfast and lunch, so dinner sits below the fold.
  for (final f in <_Food>[
    ('Overnight Oats', '1 jar', 320, 14, 48, 8),
    ('Boiled Eggs', '2 large eggs', 140, 12, 1, 10),
    ('Orange Juice', '1 glass', 110, 2, 26, 0),
    ('Almonds', '10 almonds', 70, 3, 2, 6),
  ]) {
    await log(0, 'Breakfast', f, hour: 8);
  }
  for (final f in <_Food>[
    ('Chicken Wrap', '1 wrap', 480, 32, 44, 18),
    ('Greek Salad', '1 bowl', 180, 5, 10, 14),
    ('Buttermilk', '1 glass', 60, 3, 5, 3),
    ('Green Apple', '1 medium', 80, 0, 21, 0),
  ]) {
    await log(0, 'Lunch', f, hour: 13);
  }

  // Logged once and then deleted: it should still show in the history.
  await log(6, 'Lunch', ('Masala Dosa', '1 dosa', 390, 8, 55, 15), hour: 13);
  await food.removeEntry('demo-${n - 1}');
}

/// Reads <Documents>/demo_cmd.txt: "photo <Meal>" starts a photo analysis.
void _pollCommands(Directory documents, PhotoAnalysisService photos) {
  final file = File('${documents.path}/demo_cmd.txt');
  Timer.periodic(const Duration(milliseconds: 300), (_) async {
    if (!file.existsSync()) return;
    final lines = file.readAsLinesSync();
    file.deleteSync();
    for (final line in lines) {
      final parts = line.trim().split(' ');
      if (parts.first == 'photo' && parts.length > 1) {
        photos.start(await _platePhoto(), meal: parts[1], date: DateTime.now());
      }
    }
  });
}

/// A drawn plate of food, standing in for a camera photo.
Future<Uint8List> _platePhoto() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  const size = 300.0;
  canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), Paint()..color = const Color(0xFF6D4C41));
  canvas.drawCircle(const Offset(150, 150), 130, Paint()..color = const Color(0xFFF5F5F5));
  canvas.drawCircle(const Offset(115, 140), 70, Paint()..color = const Color(0xFFE65100));
  canvas.drawCircle(const Offset(105, 130), 18, Paint()..color = const Color(0xFFFFF3E0));
  canvas.drawOval(const Rect.fromLTWH(150, 110, 110, 80), Paint()..color = const Color(0xFFD7A86E));
  final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

class _DemoApp extends StatelessWidget {
  const _DemoApp(this.s, this.photos);
  final QAGoalScenario s;
  final PhotoAnalysisService photos;
  @override
  Widget build(BuildContext context) => StreamProvider<User?>.value(
      value: const Stream.empty(),
      initialData: null,
      child: MultiProvider(
          providers: [
            ChangeNotifierProvider<GoalsProvider>.value(value: s.goals),
            ChangeNotifierProvider<FoodEntryProvider>.value(value: s.food),
            ChangeNotifierProvider<DayStatusProvider>.value(value: s.status),
            ChangeNotifierProvider<EnergyProvider>.value(value: s.energy),
            ChangeNotifierProvider(create: (_) => ThemeProvider()),
            ChangeNotifierProvider(
                create: (_) => DetailedStatsProvider(showDetailedStats: false)),
            ChangeNotifierProvider(create: (_) => WeightUnitProvider()..setMetric(true)),
            ChangeNotifierProvider(create: (_) => DateProvider()),
            ChangeNotifierProvider(create: (_) => FinishReminderProvider()),
            ChangeNotifierProvider<PhotoAnalysisService>.value(value: photos),
            ChangeNotifierProvider(create: (_) => MealProvider()),
            ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
            ChangeNotifierProvider(create: (_) => SavedFoodProvider()),
          ],
          child: Builder(
              builder: (context) => MaterialApp(
                  navigatorKey: navigatorKey,
                  debugShowCheckedModeBanner: false,
                  theme: AppTheme.lightTheme,
                  darkTheme: AppTheme.darkTheme,
                  themeMode: context.watch<ThemeProvider>().isDarkMode
                      ? ThemeMode.dark
                      : ThemeMode.light,
                  home: const AppShell()))));
}

class _OfflineBinding extends WidgetsFlutterBinding {
  @override
  BinaryMessenger createBinaryMessenger() =>
      _OfflineMessenger(super.createBinaryMessenger());
}

class _OfflineMessenger implements BinaryMessenger {
  _OfflineMessenger(this.delegate);
  final BinaryMessenger delegate;
  bool blocked(String channel) =>
      channel == 'posthog_flutter' ||
      channel == 'purchases_flutter' ||
      channel == 'flutter_health' ||
      channel.contains('superwall');
  @override
  Future<ByteData?> send(String channel, ByteData? message) {
    const codec = StandardMethodCodec();
    return blocked(channel)
        ? Future.value(codec.encodeSuccessEnvelope(null))
        : delegate.send(channel, message) ?? Future.value(null);
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (!blocked(channel)) delegate.setMessageHandler(channel, handler);
  }

  @override
  Future<void> handlePlatformMessage(String channel, ByteData? data,
          PlatformMessageResponseCallback? callback) =>
      // ignore: deprecated_member_use
      delegate.handlePlatformMessage(channel, data, callback);
}

class _NoCheckins extends CheckinNotifier {
  @override
  Future<bool> allowed() async => false;
  @override
  Future<void> schedule(DateTime at) async {}
  @override
  Future<void> cancel() async {}
}

class _NoFinish extends FinishReminderNotifier {
  @override
  Future<bool> allowed() async => false;
  @override
  Future<void> schedule(int id, DateTime at) async {}
  @override
  Future<void> cancel() async {}
}
