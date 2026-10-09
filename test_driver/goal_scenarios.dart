// Run only with: flutter run -t test_driver/goal_scenarios.dart
// This entrypoint never opens the production Hive directory or saved auth.
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:macrotracker/models/foodEntry.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/day_status_provider.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/providers/finish_reminder_provider.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/providers/saved_food_provider.dart';
import 'package:macrotracker/providers/subscription_provider.dart';
import 'package:macrotracker/providers/themeProvider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/TrackingPagesScreen.dart';
import 'package:macrotracker/screens/energy/checkin_sheet.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/screens/onboarding/pages/adaptive_page.dart';
import 'package:macrotracker/screens/onboarding/results_screen.dart';
import 'package:macrotracker/screens/searchPage.dart' show FoodItem, Serving;
import 'package:macrotracker/services/checkin_notifier.dart';
import 'package:macrotracker/services/checkin_sync_service.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/phase_engine.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/finish_reminder_notifier.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';
import 'package:macrotracker/services/phase_sync_service.dart';
import 'package:macrotracker/services/photo_analysis_service.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/theme/app_theme.dart';
import 'goal_scenario_data.dart';

Future<void> main() async {
  _OfflineQABinding();
  if (!kDebugMode) {
    throw UnsupportedError('Synthetic QA entrypoint is debug only');
  }
  GoogleFonts.config.allowRuntimeFetching = false;
  final documents = await getApplicationDocumentsDirectory();
  final isolated = Directory('${documents.path}/goal_scenarios_qa');
  await isolated.create(recursive: true);
  Hive.init(isolated.path);
  final box = await Hive.openBox<dynamic>('user_preferences');
  // Prevent the production SharedPreferences migration importing live data.
  await box.put('prefs_migrated_to_hive_v1', true);
  await StorageService().initialize();
  await Supabase.initialize(
      url: 'http://127.0.0.1:9',
      anonKey: 'qa-local-only',
      authOptions: const FlutterAuthClientOptions(
          localStorage: EmptyLocalStorage(), autoRefreshToken: false),
      debug: false);
  CheckinNotifier.device = _NoCheckinNotifications();
  FinishReminderNotifier.device = _NoFinishNotifications();
  runApp(const _ScenarioApp());
}

/// Do not let production analytics/purchase widgets touch native SDKs whose
/// settings may have been saved by the live app. Rendering and device services
/// continue through the normal messenger.
class _OfflineQABinding extends WidgetsFlutterBinding {
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
      channel.contains('superwall');
  @override
  Future<ByteData?> send(String channel, ByteData? message) => blocked(channel)
      ? Future.value(const StandardMethodCodec().encodeSuccessEnvelope(null))
      : delegate.send(channel, message) ?? Future.value(null);
  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (!blocked(channel)) delegate.setMessageHandler(channel, handler);
  }

  @override
  Future<void> handlePlatformMessage(String channel, ByteData? data,
          PlatformMessageResponseCallback? callback) =>
      // Required by BinaryMessenger's interface; forwarding preserves the
      // normal platform-message behavior for unblocked channels.
      // ignore: deprecated_member_use
      delegate.handlePlatformMessage(channel, data, callback);
}

// Replace only remote transports. Local staging, adoption, estimator, phase
// transitions and applying targets retain their normal production behavior.
class _LocalCheckins extends CheckinSyncService {
  _LocalCheckins(String id) : super(userId: id);
  @override
  Future<GoalCheckin?> insertRemote(Map<String, Object?> row) async => null;
  @override
  Future<void> markSeenRemote(DateTime weekStart, DateTime at) async {}
  @override
  Future<List<GoalCheckin>> fetchRemote() async => loadCache().values.toList();
}

class _LocalPhases extends PhaseSyncService {
  _LocalPhases(String id) : super(userId: id);
  @override
  Future<void> upsertRemote(Map<String, Object?> row) async {}
  @override
  Future<void> deleteRemote(int seq) async {}
  @override
  Future<List<GoalPhase>> fetchRemote() async => loadCache();
}

class _LocalGoals extends GoalsProvider {
  _LocalGoals(String id, DateTime Function() clock)
      : super(userId: id, clock: clock);
  @override
  Future<bool> uploadCheckinTargets(GoalCheckin checkin) async => true;
}

class _NoCheckinNotifications extends CheckinNotifier {
  @override
  Future<bool> allowed() async => false;
  @override
  Future<void> schedule(DateTime at) async {}
  @override
  Future<void> cancel() async {}
}

class _NoFinishNotifications extends FinishReminderNotifier {
  @override
  Future<bool> allowed() async => false;
  @override
  Future<void> schedule(int id, DateTime at) async {}
  @override
  Future<void> cancel() async {}
}

class QAGoalScenario {
  QAGoalScenario(
      this.data, this.goals, this.food, this.status, this.energy, this.results);
  final GoalScenarioData data;
  final GoalsProvider goals;
  final FoodEntryProvider food;
  final DayStatusProvider status;
  final EnergyProvider energy;
  final Map<String, dynamic> results;
  void dispose() {
    energy.dispose();
    food.dispose();
    status.dispose();
    goals.dispose();
  }

  static Future<QAGoalScenario> load(GoalKind goal,
      {bool learning = false, bool reached = false}) async {
    final today = DateTime.now();
    final data = GoalScenarioData(
        goal: goal, today: today, learning: learning, reached: reached);
    final input = data.inputs;
    var clock = input.learningStartedOn;
    final storage = StorageService();
    await storage.clearAllPreferences();
    await storage.put('useSystemTheme', false);
    await storage.put('isDarkMode', true);
    final body = input.body;
    Map<String, dynamic> calculate(double weight, double tdee) =>
        MacroCalculatorService().calculateAll(
            gender: body.sex.name,
            weightKg: weight,
            heightCm: body.heightCm!,
            age: body.age!,
            activityLevel: body.activityLevel ?? 3,
            goal: goal.name,
            pacePct: data.pacePct,
            goalWeightKg: data.goalWeightKg,
            tdee: tdee,
            today: today);
    final initial = calculate(input.weights.first.weightKg, input.formulaTdee);
    await storage.put(
        'nutrition_goals',
        jsonEncode({
          'macro_targets': {
            'calories': initial['target_calories'],
            'protein': initial['protein_g'],
            'carbs': initial['carb_g'],
            'fat': initial['fat_g']
          },
          'sex': body.sex.name,
          'height_cm': body.heightCm,
          'age': body.age,
          'age_recorded_on': today.toIso8601String(),
          'activity_level': body.activityLevel ?? 3,
          'goal_type': goal.name,
          'pace_pct_per_week': data.pacePct,
          'goal_weight_kg': data.goalWeightKg,
          'current_weight_kg': input.weights.last.weightKg,
          'tdee': input.formulaTdee,
          'formula_tdee': input.formulaTdee,
          'learning_started_on': input.learningStartedOn.toIso8601String(),
          'adaptive_goals': true,
          'checkin_weekday': today.weekday,
          'plan_style': 'steady'
        }));
    await storage.put(
        'weight_history',
        jsonEncode([
          for (final weight in input.weights)
            {'date': weight.day.toIso8601String(), 'weight': weight.weightKg}
        ]));
    final entries = <FoodEntry>[];
    for (final day in input.food.entries) {
      if (day.value.loggedCals <= 0) continue;
      // Synthetic meals produce precisely the logged observations used by the
      // simulator; nutrient totals are plausible, not estimator outputs.
      for (final meal in ['Breakfast', 'Lunch', 'Dinner']) {
        final cals = day.value.loggedCals / 3;
        entries.add(FoodEntry(
            id: 'qa-${day.key.toIso8601String()}-$meal',
            food: FoodItem(
                fdcId: 'qa',
                name: 'Simulated balanced meal',
                calories: cals,
                nutrients: {
                  'Protein': cals * .22 / 4,
                  'Carbohydrate, by difference': cals * .5 / 4,
                  'Total lipid (fat)': cals * .28 / 9
                },
                brandName: 'AI Detected',
                mealType: meal,
                servingSize: 100,
                servings: const <Serving>[]),
            meal: meal,
            quantity: 1,
            unit: 'serving',
            date: DateTime(day.key.year, day.key.month, day.key.day, 12),
            servingDescription: '1 serving'));
      }
    }
    await storage.put(
        'food_entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
    final id = 'isolated-qa-${data.label}';
    final goals = _LocalGoals(id, () => clock);
    final food = FoodEntryProvider()..attachGoals(goals);
    await food.loadEntriesForCurrentUser();
    final status = DayStatusProvider();
    for (final day in input.food.entries) {
      if (day.value.explicit != null) {
        await status.setStatus(day.key, day.value.explicit);
      }
    }
    final energy = EnergyProvider(
        inBackground: false,
        checkinSync: _LocalCheckins(id),
        phaseSync: _LocalPhases(id),
        clock: () => clock)
      ..goals = goals;
    energy.inputs = () => EnergyProvider.inputsFrom(
        goals: goals,
        food: food,
        dayStatus: status,
        weights: input.weights,
        today: clock,
        phases: energy.phases);
    await energy.replan(
        style: PlanStyle.steady,
        goal: goal,
        trendKg: input.weights.first.weightKg,
        heightCm: body.heightCm);
    // Visit each real weekly due date, allowing real check-ins to change the
    // targets. Replay is causal: future observations are never consulted.
    for (var d = 1;
        d <= today.difference(input.learningStartedOn).inDays;
        d++) {
      clock = DateTime(input.learningStartedOn.year,
          input.learningStartedOn.month, input.learningStartedOn.day + d);
      if (clock.weekday == today.weekday || d == 5) await energy.refresh();
    }
    clock = today;
    await energy.refresh();
    final trend = energy.latest?.trendWeightKg ?? input.weights.last.weightKg;
    final results = calculate(trend, energy.latest?.tdee ?? input.formulaTdee);
    debugPrint(
        'QA ${data.label}: seed=${data.seed} ${energy.latest?.state.name}, '
        'TDEE=${energy.latest?.tdee}, targets=${goals.caloriesGoal}, '
        'checkins=${energy.checkins.map((c) => c.variant.code).join(',')}');
    return QAGoalScenario(data, goals, food, status, energy, results);
  }
}

class _ScenarioApp extends StatefulWidget {
  const _ScenarioApp();
  @override
  State<_ScenarioApp> createState() => _ScenarioAppState();
}

class _ScenarioAppState extends State<_ScenarioApp> {
  QAGoalScenario? scenario;
  String? error;
  bool loading = true;
  @override
  void initState() {
    super.initState();
    select(GoalKind.maintain);
  }

  Future<void> select(GoalKind goal,
      {bool learning = false, bool reached = false}) async {
    setState(() {
      loading = true;
      error = null;
    });
    scenario?.dispose();
    try {
      scenario =
          await QAGoalScenario.load(goal, learning: learning, reached: reached);
    } catch (e, stack) {
      error = '$e\n$stack';
      debugPrint(error);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = scenario;
    if (loading || s == null || error != null) {
      return MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
              body: Center(
                  child: error == null
                      ? const CircularProgressIndicator()
                      : Text(error!))));
    }
    return MultiProvider(
        key: ValueKey(s),
        providers: [
          ChangeNotifierProvider<GoalsProvider>.value(value: s.goals),
          ChangeNotifierProvider<FoodEntryProvider>.value(value: s.food),
          ChangeNotifierProvider<DayStatusProvider>.value(value: s.status),
          ChangeNotifierProvider<EnergyProvider>.value(value: s.energy),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(
              create: (_) => DetailedStatsProvider(showDetailedStats: false)),
          ChangeNotifierProvider(create: (_) => WeightUnitProvider()),
          ChangeNotifierProvider(create: (_) => DateProvider()),
          ChangeNotifierProvider(create: (_) => FinishReminderProvider()),
          ChangeNotifierProvider(create: (_) => PhotoAnalysisService()),
          ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
          ChangeNotifierProvider(create: (_) => SavedFoodProvider()),
        ],
        child: Builder(
            builder: (context) => MaterialApp(
                theme: AppTheme.lightTheme,
                darkTheme: AppTheme.darkTheme,
                themeMode: context.watch<ThemeProvider>().isDarkMode
                    ? ThemeMode.dark
                    : ThemeMode.light,
                home: Builder(builder: (context) => _menu(context, s)))));
  }

  Widget _menu(BuildContext context, QAGoalScenario s) {
    context.watch<GoalsProvider>();
    context.watch<EnergyProvider>();
    void open(Widget page) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));
    return Scaffold(
        appBar: AppBar(title: Text('QA • ${s.data.label}'), actions: [
          IconButton(
              tooltip: 'Switch theme',
              onPressed: () => context.read<ThemeProvider>().toggleTheme(),
              icon: const Icon(Icons.brightness_6_outlined))
        ]),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          const Text(
              'Synthetic observations • real production calculations\nIsolated offline storage. Live account is untouched.'),
          const SizedBox(height: 16),
          Wrap(spacing: 8, children: [
            for (final goal in GoalKind.values)
              FilledButton(
                  onPressed: () => select(goal), child: Text(goal.name))
          ]),
          Wrap(spacing: 8, children: [
            OutlinedButton(
                onPressed: () => select(GoalKind.maintain, learning: true),
                child: const Text('Learning')),
            OutlinedButton(
                onPressed: () => select(GoalKind.lose, reached: true),
                child: const Text('Lose reached')),
            OutlinedButton(
                onPressed: () => select(GoalKind.gain, reached: true),
                child: const Text('Gain reached'))
          ]),
          const SizedBox(height: 16),
          Text(
              'Seed ${s.data.seed} • ${s.data.inputs.weights.length} weigh-ins\n'
              '${s.energy.latest?.state.name} • ${s.energy.latest?.tdee.round()} kcal burned\n'
              '${s.goals.caloriesGoal.round()} kcal target • ${s.energy.checkins.length} real check-ins\n'
              'Latest: ${s.energy.lastCheckin?.variant.code ?? 'none'}'),
          const SizedBox(height: 16),
          ListTile(
              title: const Text('Weight'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(const TrackingPagesScreen())),
          ListTile(
              title: const Text('Energy'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => open(const TrackingPagesScreen(
                  initialPage: TrackingPagesScreen.energyTab))),
          ListTile(
              title: const Text('Weekly check-in'),
              enabled: s.energy.lastCheckin != null,
              onTap: s.energy.lastCheckin == null
                  ? null
                  : () => showCheckinSheet(context, s.energy.lastCheckin!,
                      source: CheckinSheetSource.history)),
          ListTile(
              title: const Text('Adaptive page'),
              onTap: () => open(const _AdaptivePreview())),
          ListTile(
              title: const Text('Recalculate'),
              onTap: () => open(const OnboardingScreen(recalculateOnly: true))),
          ListTile(
              title: const Text('Results'),
              onTap: () => open(ResultsScreen(
                  results: s.results,
                  recalculateOnly: true,
                  adaptiveGoals: true,
                  isMetricWeight: context.read<WeightUnitProvider>().isMetric,
                  goalWeightKg: s.data.goalWeightKg,
                  onSave: () async {}))),
        ]));
  }
}

class _AdaptivePreview extends StatefulWidget {
  const _AdaptivePreview();
  @override
  State<_AdaptivePreview> createState() => _AdaptivePreviewState();
}

class _AdaptivePreviewState extends State<_AdaptivePreview> {
  bool adaptive = true;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('QA • Adaptive page')),
      body: AdaptivePage(
          adaptive: adaptive,
          onChanged: (value) => setState(() => adaptive = value)));
}
