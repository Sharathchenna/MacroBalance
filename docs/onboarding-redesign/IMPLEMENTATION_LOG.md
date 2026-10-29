# Onboarding redesign: implementation log

The mock lives in `docs/onboarding-redesign/mock/*.dc.html` (one file per screen, HTML + inline CSS; the
grey notes for each screen are in `mock/canvas.json` → `notes`). `step-audit.md` lists what every step saves
and which analytics events must keep firing. The paywall (Superwall `showOnboardingPaywall`) is **not** to be
changed.

Baseline before the work: `flutter test` → 1122 passed.

## Rules for everyone

- Translate the mock faithfully: copy, layout, spacing, colours, animations. Copy rule: say "cals", never
  "kcal" or "calories". Use the real logo (`MbMark` / `MbLogoTile` in `lib/widgets/brand/mb_logo.dart`), never
  a stand-in icon.
- Colours and type only from `lib/theme/ob_theme.dart` (`ObColors.of(context)`, `ObText`, `ObMotion`). Both
  dark and light must work.
- Shared widgets: `lib/screens/onboarding/widgets/ob_widgets.dart` (`ObRise`, `ObTopBar`, `ObProgress`,
  `ObHeader`, `ObPageBody`, `ObPrimaryButton`, `ObSecondaryButton`, `ObTextButton`, `ObOptionTile`,
  `ObCheckDot`, `ObIconTile`, `ObPill`, `ObSegmented`, `ObCard`, `ObNote`) and
  `widgets/ob_ruler.dart` (`ObSnapStrip`, `ObRuler`, `ObNumberField`). Add to them only if something is
  missing, and say so in your report.
- Animations: Flutter `AnimationController` / implicit animations / `CustomPainter`. Respect
  `MediaQuery.disableAnimations`. Lottie (`lottie` package) for `assets/animations/plan_ready.json`.
- Quiz pages render **content only** (an `ObPageBody` with an `ObHeader` first). The onboarding screen owns
  the top bar (back + progress) and the bottom "Continue" button, except pages that have their own buttons
  (Apple Health, reminders), which take `onNext` / `onSkip`.
- Keep comments sparse and in the repo's style (short `///` doc comments that say why).
- Tests: widget tests under `test/widgets/onboarding/`, using `test/helpers/test_app.dart`
  (`setUpTestEnvironment()`, `testApp(...)`, `pumpFrames`). Phone-sized view (1179×2556 @3x). Only run your
  own test files and `flutter analyze` on your own files while others are working in parallel.
- Do not commit. Do not edit files owned by another group.

## Flow

Hello → Story 1 (snap) → Story 2 (learns your burn) → quiz → Building → Reveal → [Review] → Save (sign-up,
only when signed out) → How did you hear about us (once per device) → Superwall paywall (unchanged).

Quiz steps (`OnboardingStep`, new users): `goal, aboutYou, weight, activity, goalWeight, pace, obstacles,
insight, planStyle, adaptive, advanced, appleHealth, notifications, summary`.
Skips: goalWeight + pace for Maintain; planStyle unless detailed mode and Lose; advanced unless detailed mode;
activity when planning from a confident learned TDEE (recalculate only). For new users `summary` is the Review
screen, reached only from the Reveal's "Review answers".
Recalculate (Settings): `weight, activity, goal, goalWeight, pace, planStyle, adaptive, advanced, summary`.

## Page contracts

Group B (quiz 1) · `lib/screens/onboarding/pages/`
- `goal_page.dart` `GoalPage({required String currentGoal, required ValueChanged<String> onGoalChanged})` ← Goal
- `about_you_page.dart` `AboutYouPage({required String gender, required ValueChanged<String> onGenderChanged,
  required int age, required ValueChanged<int> onAgeChanged, required double heightCm, required bool
  isMetricHeight, required ValueChanged<double> onHeightChanged, required ValueChanged<bool>
  onHeightUnitChanged})` ← AboutYou / AboutYouFt. Ages 18–100, height 120–230 cm.
- `weight_page.dart` `WeightPage` (same constructor as today, incl. `trendKg` / `onUseTrend`) ← Weight
- `activity_level_page.dart` `ActivityLevelPage` (same constructor) ← Activity
- `goal_weight_page.dart` `GoalWeightPage({required String goal, required double currentWeightKg, required
  double goalWeightKg, required double minKg, required double maxKg, required bool isMetricWeight, required
  ValueChanged<double> onGoalWeightChanged, int? weeks, DateTime? projectedDate})` ← GoalWeight
- `pace_page.dart` `PacePage({required String goal, required List<PaceChoice> paceChoices, required double
  pacePct, required double recommendedPacePct, required ValueChanged<double> onPaceChanged})` ← Pace.
  `PaceChoice` and `paceLimitExplanation` move here from `set_new_goal_page.dart`, which is deleted.
- `gender_page.dart`, `age_page.dart`, `height_page.dart` stay (Settings › profile uses them); restyle them
  with the new tokens only if it's cheap.

Group C (quiz 2) · `lib/screens/onboarding/pages/`
- `obstacles_page.dart` `ObstaclesPage({required Set<String> selected, required ValueChanged<Set<String>>
  onChanged})` ← Obstacles. Export `const kObstacleCodes`.
- `insight_page.dart` `InsightPage({required String goal, required Set<String> obstacles})` ← Insight
- `plan_style_page.dart` `PlanStylePage` (same constructor) restyled
- `adaptive_page.dart` `AdaptivePage` (same constructor) ← Adaptive
- `advanced_settings_page.dart` `AdvancedSettingsPage` (same constructor) ← FineTune
- `apple_health_page.dart` `AppleHealthPage({required VoidCallback onNext, required VoidCallback onSkip})` ←
  Health (keeps today's permission logic)
- `notify_page.dart` `NotifyPage({required VoidCallback onNext, required VoidCallback onSkip})` ← Notify (asks
  the real notification permission through the existing notification service)

Group A (intro) · `lib/screens/intro/`
- `hello_screen.dart` `HelloScreen()` ← Main. Fires `PostHogService.trackScreen('welcome_screen')`.
  "Build my plan" → stories; "I already have an account" → `LoginScreen`.
- `story_screen.dart` `StoryScreen()` ← StorySnap + StoryLearn. Ends by pushing `OnboardingScreen()`.

Group D (payoff)
- `lib/screens/onboarding/building_screen.dart` `BuildingScreen({required Future<void> Function() work,
  required VoidCallback onDone, String goal})` ← Building
- `results_screen.dart` restyled as the Reveal (lose / maintain / gain) ← Reveal, RevealMaintain, RevealGain.
  Adds `VoidCallback? onReview`. Signed-out users go to Save before the acquisition question.
- `pages/summary_page.dart` `SummaryPage` (same constructor) ← Review
- `lib/screens/onboarding/save_screen.dart` `SaveScreen()` ← Save. Pops `true` once signed in.
- `pages/acquisition_source_page.dart` + `AcquisitionSourceStep` ← Source

Lead (me): `onboarding_steps.dart`, `onboarding_screen.dart`, `lib/auth/auth_gate.dart`, flow tests.

## Progress

- [x] Foundation: `ob_theme.dart`, `mb_logo.dart`, `ob_widgets.dart`, `ob_ruler.dart`, `plan_ready.json` in
  `assets/animations/`.
- [x] `onboarding_steps.dart` (new enum, `onboardingProgress`) + `test/unit/onboarding_steps_test.dart` green.
- [x] `onboarding_screen.dart` rewired to the new pages, shared top bar/button, Building → Reveal, `onReview`,
  `obstacles_selected` on `onboarding_completed` (fires once).
- [x] AuthGate: signed out → `HelloScreen`; `AuthGate.signedOutOnboarding` holds the intro underneath while a
  signed-out user finishes onboarding and signs up. Sign-out / delete account go to `HelloScreen`.
- [x] `MacroColors` → new palette hues.
- [x] Groups A–D built (intro, quiz 1, quiz 2, payoff) with their own widget tests in `test/widgets/onboarding/`.
- [x] Flow tests rewritten for the new order: `onboarding_test`, `onboarding_simple_test`, `plan_style_test`,
  `recalculate_test`, `adaptive_choice_test`.
- [x] Paywall untouched: `_presentPaywall` in `results_screen.dart` is byte-identical to `main`.
- [x] Notifications: `NotificationService.initialize()` no longer prompts for new users; the reminders step asks
  (`requestPermissions()`). People who finished onboarding are still asked at launch as before. The native
  `requestAuthorization` call in `AppDelegate.swift` is removed.
- [x] Dry run on the iPhone 17 Pro simulator; fixes from it: story 2 check-in card no longer covers the week
  labels, pace rows read "0.5% a week · about 1.1 lb", number fields size to their digits, Health illustration
  tightened so the page fits, "lb" (not "lbs") in the reveal and review, Save card follows the weight unit, hello
  chips no longer clip "Greek yogurt".
- [x] `flutter test`: 1175 passed, 1 skipped. `flutter analyze lib`: no errors (warnings are pre-existing).
- [x] Recording: `recording/onboarding-full-flow.mp4` (debug build, iPhone 17 Pro simulator, fresh install, driven
  by `test_driver/onboarding_demo.dart` with a new @mbtest.ai account): hello → stories → quiz → primers →
  building → reveal → Save (email sign-up) → "how did you hear about us" → test paywall. After "Buy (test, free)"
  the app opened on the dashboard with the plan's 1,906 cals (`recording/dashboard-after-test-purchase.png`;
  the recorder didn't capture that last transition). No errors in the run's log.
- [x] Bugs the recorded runs found and fixed: after signing up on the Save screen, the results screen used the
  GoalsProvider / FoodEntryProvider from before sign-in (disposed when the account changes) → providers are now
  looked up when syncing; the Save screen showed raw exceptions → friendly messages in `AuthActions`.

- [x] Pre-launch review fixes:
  - A plan made signed out is saved to the account (and its phase plan) once the Save screen signs up. Checked on the simulator: the new account has its `user_macros` row and first `goal_phases` row.
  - "Keep your saved plan" drops the new plan from the device first.
  - "I already have an account" clears `AuthGate.signedOutOnboarding`.
  - Editing from the summary returns to it, through goal weight and pace when a new goal needs them.
  - Other fixes: the maintain insight line, Katch–McArdle on Building when body fat is given, goal weights bounded by the weight step's 30–200 kg, and no back swipe while building.

## Open issues

- iOS still shows the notification prompt at first launch even with the Dart and native requests removed; the
  log shows nothing in our code asking. Most likely one of the SDKs (Firebase Messaging / Superwall / PostHog
  push integration). Needs a look on device before release, otherwise the reminders primer is pre-empted.
- Simulator swipes carry a lot of momentum on the rulers; feels fine with a finger but worth a check on device.
- To re-run the demo: rebuild with `flutter build ios --simulator --debug -t test_driver/onboarding_demo.dart
  --dart-define-from-file=<file with DEMO_EMAIL / DEMO_PASSWORD>`, then `flutter run --use-application-binary`
  with the same `-t` and defines (`--use-application-binary` reuses the Dart baked into the build). Use a new
  @mbtest.ai email each time.
- `test_driver/onboarding_demo.dart` typing is slow under load; the run can drift if sign-up takes > 40 s.
