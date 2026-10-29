# Onboarding step audit

Every step in today's flow, what it saves, what reads it, and where it goes in the redesign. Nothing the goal maths or analytics depends on is removed.

Source: `lib/screens/onboarding/onboarding_steps.dart`, `onboarding_screen.dart`, `results_screen.dart`, `lib/auth/auth_gate.dart`.

## Steps

| Today | Saves (`user_macros` / `nutrition_goals`) | Used by | Analytics | Redesign |
|---|---|---|---|---|
| Welcome screen (Sign In / Create Account) | — | — | `welcome_screen` screen view | Replaced by Hello + 2 stories (01–03). Keep the `welcome_screen` view on 01. |
| Signup (name, email, password / Apple / Google) | auth user, `username` metadata | account | PostHog `identify` at sign-in (AuthGate) | Moved to **19 Save your plan**, after the plan. Email sign-up still asks for a name. |
| `welcome` page | — | — | `onboarding_screen` screen view | Folded into the intro. |
| `gender` | `sex` | BMR (Mifflin / Katch–McArdle), energy density, safety floor (1,500 / 1,200 cals) | `gender` on `onboarding_completed` | **05 About you** |
| `weight` | `current_weight_kg`, `weight` | everything; `replan(trendKg)` | — | **06 Weight** (recalculate keeps the one-tap trend weight) |
| `height` | `height_cm` | BMR, energy density, `replan(heightCm)` | — | **05 About you** |
| `age` | `age`, `age_recorded_on` | BMR | `age` on `onboarding_completed` | **05 About you** |
| `activity` | `activity_level` | formula TDEE (`formula_tdee`, `tdee`) | `activity_level` on `onboarding_completed` | **07 Activity**. Always asked of new users; skipped only on Recalculate with a confident learned TDEE (unchanged). |
| `goal` | `goal_type` | everything | `goal` on `onboarding_completed` | **04 Goal** |
| `setNewGoal` (goal weight + pace; simple mode has plan style under More options) | `goal_weight_kg`, `pace_pct_per_week` | targets, projection, phase engine | `pace_chosen {pct, clamped}` | **08 Goal weight** + **09 Pace**. Skipped for Maintain (unchanged). All 4 lose paces (0.25/0.5/0.75/1.0 %) and 3 gain paces kept, plus the "eased" safety note. |
| `planStyle` (lose + detailed mode) | `plan_style` | phase engine, `replan(style)` | `plan_style_chosen` | Not asked in simple mode: defaults to Steady (the existing simple-mode default) and can be changed later via Recalculate. Detailed mode keeps its own plan-style step. `plan_style_chosen` still fires with the value used. |
| `adaptive` | `adaptive_goals` | check-ins auto-apply | `adaptive_choice_made` | **12 Adaptive** |
| `advanced` (detailed mode only) | `body_fat_pct`, `protein_g_per_kg`, `fat_ratio` | Katch–McArdle, protein default, macro split | — | **13 Fine-tune** (detailed mode only, as today). Ranges: body fat 5–50 %, protein 1.2–2.6 g/kg, fat 20–40 %. |
| `appleHealth` | — (permission) | steps, active/basal energy, weight, height read; nutrition written | — | **14 Apple Health primer** |
| `summary` (review with edit links) | — | — | — | **18 Review answers**, reached from the plan reveal. |
| Results screen | `macro_results`, `macro_targets`, `bmr`, `tdee`, `formula_tdee`, `steps_goal`, `checkin_weekday`, `learning_started_on` | GoalsProvider, EnergyProvider | `onboarding_completed` | **16 Building** + **17 Reveal** |
| Acquisition source (once per device, after results, before paywall) | — | — | `acquisition_source_selected`, `acquisition_source_other_text_changed`, `acquisition_source_answered` | **20 How did you hear about us**. Same position relative to the paywall. Keeps today's values (tiktok, instagram, reddit, `other: <text>`) and adds youtube, ad, friend, club, app_store. The "Somewhere else" text box is always visible. |
| Superwall `showOnboardingPaywall` | — | subscription | Superwall | **21 Trial paywall** (same placement) |

New steps that save nothing: **10 Obstacles**, **11 Reply**, **15 Reminder primer**. If obstacles are kept, log them as a PostHog property (`obstacles_selected`) so the answers are usable later.

## What moving sign-up after the plan needs in code

1. **AuthGate** (`lib/auth/auth_gate.dart`) shows `Welcomescreen` when there is no session. It has to send signed-out users into the new intro and onboarding instead.
2. **`saveMacroResults`** writes to Supabase only when `currentUser != null`. It already writes `macro_results` and `nutrition_goals` locally, so before sign-up keep the local write and skip the upsert. After sign-up, run the existing `goals.syncToCloud()` path (the results screen's `syncNutritionGoals`).
3. **`learning_started_on` and `checkin_weekday`** are set on the day onboarding completes. That stays true; they just reach the server at sign-up.
4. **Existing account on a new device:** if someone finishes the quiz and then signs in to an account that already has goals, decide which plan wins. `_loadUserDataAfterLogin` should not silently overwrite either one.
5. **Analytics:** events before sign-up are anonymous. The existing `PostHogService.identifyUser` call at sign-in merges them; keep `onboarding_completed` firing at the same moment (when the plan is calculated).
6. **Recalculate from Settings** (`recalculateOnly`) reuses these pages with its own step list. The redesign must keep that variant: weight with trend, activity, goal, goal weight and pace, plan style, adaptive, advanced, summary.

## Logo

`mb_logo.svg` (app-icon tile) and `mb_mark.svg` (monogram, `currentColor`) are traced from `assets/icons/MacroBalance_Logo.png`. They replace the PNG in the welcome screen and onboarding.
