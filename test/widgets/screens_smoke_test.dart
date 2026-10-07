import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/camera/ai_food_detail_page.dart';
import 'package:macrotracker/camera/results_page.dart';
import 'package:macrotracker/models/ai_food_item.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/screens/NutritionTrendsScreen.dart';
import 'package:macrotracker/screens/StepsTrackingScreen.dart';
import 'package:macrotracker/screens/TrackingPagesScreen.dart';
import 'package:macrotracker/screens/WeightTrackingScreen.dart';
import 'package:macrotracker/screens/WorkoutTrackingScreen.dart';
import 'package:macrotracker/screens/accountdashboard.dart';
import 'package:macrotracker/screens/app_shell.dart';
import 'package:macrotracker/screens/askAI.dart';
import 'package:macrotracker/screens/dashboard_screen.dart';
import 'package:macrotracker/screens/delete_account_screen.dart';
import 'package:macrotracker/screens/editGoals.dart';
import 'package:macrotracker/screens/feedback_screen.dart';
import 'package:macrotracker/screens/foodDetail.dart';
import 'package:macrotracker/screens/forgot_password_screen.dart';
import 'package:macrotracker/screens/loginscreen.dart';
import 'package:macrotracker/screens/onboarding/onboarding_screen.dart';
import 'package:macrotracker/screens/saved_foods_screen.dart';
import 'package:macrotracker/screens/searchPage.dart';
import 'package:macrotracker/screens/signup.dart';
import 'package:macrotracker/screens/welcomescreen.dart';

import '../helpers/test_app.dart';

/// Opens every main screen with the app's real providers, in light and dark
/// mode, and fails on any exception or layout overflow while it builds and
/// runs its first few seconds.
void main() {
  late FoodEntryProvider provider;
  final today = DateTime.now();

  setUp(() async {
    await setUpTestEnvironment();
    provider = FoodEntryProvider();
    await provider.ensureInitialized();
  });

  final sampleFood = FoodItem(
    fdcId: '1',
    name: 'Greek yogurt',
    calories: 100,
    nutrients: const {
      'Protein': 10,
      'Carbohydrate, by difference': 6,
      'Total lipid (fat)': 4,
    },
    brandName: 'Fage',
    mealType: 'Breakfast',
    servingSize: 100,
    servings: [
      Serving(
        description: '1 cup (227 g)',
        metricAmount: 227,
        metricUnit: 'g',
        calories: 227,
        nutrients: const {
          'Protein': 22.7,
          'Carbohydrate, by difference': 13.6,
          'Total lipid (fat)': 9.1,
        },
      ),
    ],
  );

  final aiFood = AIFoodItem(
    name: 'Chicken burrito',
    servingSizes: ['1 burrito', '100 g'],
    calories: [650, 210],
    protein: [32, 10],
    carbohydrates: [70, 22],
    fat: [24, 8],
    fiber: [8, 3],
  );

  final screens = <String, Widget Function()>{
    'App shell (Home)': () => const AppShell(),
    'App shell (Progress)': () => const AppShell(initialTab: AppTab.progress),
    'App shell (Profile)': () => const AppShell(initialTab: AppTab.profile),
    'Dashboard': () => const Dashboard(),
    'Food search': () => const FoodSearchPage(selectedMeal: 'Lunch'),
    'Saved foods': () => const SavedFoodsScreen(),
    'Progress pager': () => const TrackingPagesScreen(),
    'Weight': () => const WeightTrackingScreen(),
    'Nutrition': () => const NutritionTrendsScreen(),
    'Steps': () => const StepTrackingScreen(),
    'Workouts': () => const WorkoutTrackingScreen(),
    'Goals': () => const EditGoalsScreen(),
    'Settings': () => const AccountDashboard(),
    'Food detail': () => FoodDetailPage(food: sampleFood, selectedMeal: 'Breakfast'),
    'AI food detail': () => AIFoodDetailPage(food: aiFood, selectedMeal: 'Dinner'),
    'Photo results': () => ResultsPage(foods: [aiFood], meal: 'Dinner', date: today),
    'Ask AI': () => const Askai(),
    'Welcome': () => const Welcomescreen(),
    'Login': () => const LoginScreen(),
    'Sign up': () => const Signup(),
    'Forgot password': () => const ForgotPasswordScreen(),
    'Onboarding': () => const OnboardingScreen(),
    'Recalculate goals': () => const OnboardingScreen(recalculateOnly: true),
    'Feedback': () => const FeedbackScreen(),
    'Delete account': () => const DeleteAccountScreen(),
  };

  for (final dark in [true, false]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} opens without errors (${dark ? 'dark' : 'light'})',
          (tester) async {
        tester.view.physicalSize = const Size(1179, 2556); // iPhone 15/16
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        await tester.runAsync(() => provider.addEntry(testEntry(
            name: 'Toast', meal: 'Breakfast', date: today, calories: 75)));
        await tester.pumpWidget(
            testApp(entry.value(), foodEntryProvider: provider, dark: dark));
        await pumpFrames(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('screens fit a small phone (iPhone SE) without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(750, 1334);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    for (final name in ['App shell (Home)', 'App shell (Progress)', 'App shell (Profile)', 'Weight', 'Goals', 'Food detail']) {
      await tester.pumpWidget(testApp(screens[name]!(), foodEntryProvider: provider));
      await pumpFrames(tester);
      expect(tester.takeException(), isNull, reason: name);
    }
  });
}
