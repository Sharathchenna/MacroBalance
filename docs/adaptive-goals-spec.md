# Adaptive goals — spec

Status: ready to build (2026-10-07). The research and reasoning behind each choice are in [adaptive-goals-plan.md](adaptive-goals-plan.md); this document is what to build.

## 1. Scope

**In scope**
- Corrected goal maths: BMR, pace, safety limits, macros, energy density.
- One goals provider.
- An adaptive expenditure estimator, plus trend weight and day status.
- An Energy tab, Weight-tab additions and a "Finish day" row.
- Weekly check-ins, with auto-apply when the user opted in.
- Phased plans: steady, phased and diet breaks.
- Onboarding questions: adaptive and plan style.
- A trimmed recalculate flow and editable profile fields.

**Out of scope (later)**
- Steps as an input to the estimator.
- Body fat from HealthKit.
- Training-type onboarding question. The protein table below already has a slot for it, defaulting to `unknown`.
- Gain-phase cycles.
- Menstrual-cycle annotations.

**Constraints**
- There are no live users, so stored goal fields can break freely and no data migration is needed.
- Every feature sits behind the existing trial/premium paywall. The estimator keeps running while a subscription is lapsed.
- Copy says "cals", never "kcal" or "calories".

## 2. Glossary

| Term | Meaning |
|---|---|
| **Trend weight** | Smoothed body weight (6.2). This is what the user's progress is measured on. |
| **Expenditure / TDEE** | The estimated cals burned per day (6.4). |
| **Complete day** | A day whose food log is trusted for the estimate (6.3). |
| **Check-in** | The weekly event that may change targets (6.6). |
| **Phase** | A stretch of lose / maintain / gain with its own target rule (6.7). |
| **Plan style** | How the phases are arranged: `steady`, `phased` or `breaks`. |
| **Adaptive** | The user's onboarding choice. On means check-ins auto-apply new targets. |

## 3. Architecture

### 3.1 Code layout
```
lib/services/energy/              # pure Dart, no Flutter/Supabase imports, fully unit-tested
  constants.dart                  # every tunable in §5
  body_composition.dart           # fat-mass estimate, energy density
  bmr.dart                        # Mifflin, Katch–McArdle, TDEE prior
  trend_weight.dart               # EMA trend + outlier rule
  day_status.dart                 # complete / partial / untracked / fasting classification
  energy_estimator.dart           # daily Kalman-style step
  targets.dart                    # pace → cals, safety limits, macro split
  phase_engine.dart               # phase state machine
  checkin.dart                    # weekly check-in decision → variant
  projection.dart                 # weeks-to-goal simulation
lib/providers/goals_provider.dart   # NEW: owns all goal settings + targets (extracted from FoodEntryProvider)
lib/providers/energy_provider.dart  # NEW: runs estimator, persists/syncs estimates, phases, check-ins
lib/screens/energy/…                # Energy tab + check-in sheet
```

### 3.2 Removals and changes
- **Delete** `lib/providers/nutrition_goals_provider.dart`. It's dead code: never registered or imported.
- **Delete** the commented-out `lib/services/expenditure_service.dart`, `lib/providers/expenditure_provider.dart`, `lib/screens/expenditure_screen.dart` and `lib/screens/tdee_dashboard.dart`, plus their commented references and the `/expenditure` route in `main.dart`.
- **Extract** every goal field, `recalculateMacroGoals` and the goal sync logic (`nutritionGoalsPayload`, `_syncNutritionGoalsToSupabase`, `loadNutritionGoals`) from `FoodEntryProvider` into `GoalsProvider`. `FoodEntryProvider` keeps food entries only.
  - Every reader switches to `GoalsProvider`: onboarding prefill, `WeightTrackingScreen`, `editGoals.dart`, `CalorieTracker`, `auth_gate.dart`.
- **Rewrite** `MacroCalculatorService` as a thin facade over `lib/services/energy/*`. Remove the formula auto-selection, original Harris–Benedict, revised Harris–Benedict and the hard-coded 7,700.

### 3.3 Data flow
```
weight_entries ─┐
food_entries ───┼─► EnergyProvider.refresh()  (app open, weight saved, day finished, food saved for a past day)
food_day_status ┘        │
                         ├─ trend_weight → day_status → energy_estimator  (replays days since last stored estimate)
                         ├─ upsert energy_estimates
                         ├─ phase_engine.evaluate()  (daily)
                         └─ if check-in due → checkin.run() → GoalsProvider.applyTargets() → goal_checkins row → show sheet
```

## 4. Data model

Before writing the migrations, check `user_macros`' live columns. The Supabase MCP needs authorising first. Add only the columns that are missing.

```sql
-- 1. Goal settings on the existing goals table
alter table public.user_macros
  add column if not exists sex text check (sex in ('male','female')),
  add column if not exists height_cm numeric(5,1),
  add column if not exists age smallint check (age between 18 and 100),
  add column if not exists age_recorded_on date,
  add column if not exists activity_level smallint check (activity_level between 1 and 5),
  add column if not exists body_fat_pct numeric(4,1),
  add column if not exists pace_pct_per_week numeric(4,2),
  add column if not exists adaptive_goals boolean not null default true,
  add column if not exists checkin_weekday smallint check (checkin_weekday between 1 and 7), -- ISO, 1 = Monday
  add column if not exists plan_style text not null default 'steady' check (plan_style in ('steady','phased','breaks')),
  add column if not exists phase_loss_pct numeric(4,1),
  add column if not exists maintenance_weeks smallint,
  add column if not exists break_every_weeks smallint,
  add column if not exists break_weeks smallint,
  add column if not exists protein_g_per_kg numeric(3,1),   -- user override, null = default table
  add column if not exists fat_ratio numeric(3,2),
  add column if not exists formula_tdee numeric(6,0),
  add column if not exists learning_started_on date;        -- set at onboarding and on "Reset learning"

-- 2. Day status
create table public.food_day_status (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  status text not null check (status in ('complete','partial','fasting')),
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);

-- 3. Daily estimates
create table public.energy_estimates (
  user_id uuid not null references auth.users (id) on delete cascade,
  day date not null,
  tdee numeric(6,0) not null,
  tdee_sd numeric(5,0) not null,
  state text not null check (state in ('learning','estimated','confident','paused')),
  trend_weight_kg numeric(5,2),
  slope_kg_per_day numeric(6,4),
  avg_intake numeric(6,0),
  complete_days smallint not null,
  weigh_ins smallint not null,
  algo_version smallint not null,
  primary key (user_id, day)
);

-- 4. Phases
create table public.goal_phases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  seq smallint not null,
  kind text not null check (kind in ('lose','maintain','gain')),
  started_on date not null,
  start_trend_kg numeric(5,2) not null,
  target_pct numeric(4,1),            -- lose phases in 'phased' style
  planned_weeks smallint,             -- maintain phases, 'breaks' lose phases
  max_weeks smallint,
  ended_on date,
  end_reason text check (end_reason in ('reached','max_duration','planned','skipped','user_ended','goal_reached','replanned')),
  unique (user_id, seq)
);

-- 5. Check-ins
create table public.goal_checkins (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  week_start date not null,
  variant text not null check (variant in ('changed','unchanged','insufficient','goal_reached','phase_to_maintain','phase_to_lose')),
  old_targets jsonb not null,         -- {cals, protein, carbs, fat}
  new_targets jsonb not null,
  reason jsonb not null,              -- {avg_intake, complete_days, weigh_ins, trend_change_kg, tdee, tdee_prev, limit_hit}
  seen_at timestamptz,
  created_at timestamptz not null default now(),
  unique (user_id, week_start)
);
```
- Every new table gets RLS identical to `weight_entries`: select, insert, update and delete only where `(select auth.uid()) = user_id`.
- Local cache: Hive keys `food_day_status`, `energy_estimates` (last 400 days), `goal_phases`, `goal_checkins`. Sync with a pending queue, the same way `WeightSyncService` does. The local copy wins until the upload succeeds.

## 5. Constants (`constants.dart`)

| Name | Value | Notes |
|---|---|---|
| `kLeanEnergyKcalPerKg` | 1816 | Hall 2008 (7.6 MJ/kg) |
| `kFatEnergyKcalPerKg` | 9440 | Hall 2008 (39.5 MJ/kg) |
| `kForbesC` | 10.4 | kg |
| `kTrendAlpha` | 0.10 | Daily EMA factor |
| `kOutlierPct` | 0.03 | Of trend weight |
| `kOutlierRunToAccept` | 3 | Consecutive same-side outliers count as a real shift |
| `kWindowDays` | 21 | |
| `kSwitchSettleDays` | 4 | Days skipped after onboarding, a phase switch or a reset |
| `kMinCompleteDays` | 7 | In the window |
| `kMinWeighIns` | 4 | In the window, spanning ≥ 7 days |
| `kPartialFraction` | 0.5 | × current TDEE estimate |
| `kPriorSd` | 300 | cals |
| `kProcessSdPerDay` | 15 | cals |
| `kOverlapInflation` | 7 | Observation variance multiplier for overlapping windows; tune in simulation |
| `kIntakeBiasSd` | 50 | cals, floor on intake uncertainty |
| `kMaxDailyTdeeStep` | 50 | cals |
| `kConfidentSd` | 200 | cals |
| `kPausedAfterDays` | 7 | With no complete days or no weigh-ins |
| `kFloorFemale` / `kFloorMale` | 1200 / 1500 | cals |
| `kMaxDeficitFrac` / `kMaxSurplusFrac` | 0.25 / 0.15 | Of TDEE |
| `kMaxLossPct` / `kMaxGainPct` | 1.0 / 0.5 | % of body weight per week |
| `kMaxCheckinStep` | 150 | cals, ordinary check-ins only |
| `kNoChangeThreshold` | 25 | cals |
| `kPhasedLossPctObese` / `kPhasedLossPct` | 10 / 5 | %, BMI ≥ 30 or below |
| `kMaintenanceWeeks` | 4 | |
| `kMaxLossPhaseWeeks` | 16 | |
| `kBreakEveryWeeks` / `kBreakWeeks` | 8 / 2 | |
| `algoVersion` | 1 | |

## 6. Algorithms

### 6.1 Body composition and energy density (`body_composition.dart`)
- `fatMassKg`:
  - With a known body fat % (entered in Advanced, labelled "from a scan or smart scale"): `weight × bf/100`.
  - Otherwise, Deurenberg: `bf% = 1.20·BMI + 0.23·age − 10.8·(male?1:0) − 5.4`, clamped to 5–60%.
- `energyDensity(fm) = p·1816 + (1−p)·9440`, with `p = 10.4/(10.4+fm)`. The same value is used for gain and loss.

### 6.2 Trend weight (`trend_weight.dart`)
- Input: daily readings, at most one per day (from `weight_entries`).
- `trend₀ = first reading`. For each later reading:
  - `α = 1 − (1−kTrendAlpha)^Δdays`
  - `trend = trend + α·(w − trend)`
- **Outliers:**
  - A reading with `|w − trend| > kOutlierPct·trend` is flagged `ignored` and does not update the trend.
  - Exception: if `kOutlierRunToAccept` consecutive readings are outliers on the same side, accept them all and re-run from the first of them.
- Output per reading: `{day, weight, trend, ignored}`. On days with no reading, the trend is carried forward for display.

### 6.3 Day status (`day_status.dart`)
Only past days are classified. Today counts only if the user explicitly finished it.

| Rule (first match wins) | Status | Used in the intake average? |
|---|---|---|
| Explicit `fasting` | fasting | yes, as 0 cals |
| Explicit `complete` | complete | yes |
| Explicit `partial` | partial | no |
| No food entries | untracked | no |
| Logged cals < `kPartialFraction` × TDEE estimate as of that day | partial (inferred) | no |
| Otherwise | complete (inferred) | yes |

### 6.4 Expenditure estimator (`energy_estimator.dart`)
State: `{tdee, var, state, lastUpdateDay}`.

- **Initialise** at `learning_started_on`:
  - `tdee = formula_tdee` (6.5)
  - `var = kPriorSd²`
  - `state = learning`
- **Each day d**, replayed sequentially from the last stored estimate up to yesterday:
  1. **Predict:** `var += kProcessSdPerDay²`.
  2. **Window:**
     - `start = max(d − kWindowDays + 1, lastSwitch + kSwitchSettleDays)`, where `lastSwitch` is the latest of `learning_started_on` and the start of the most recent phase.
  3. **Gate:**
     - At least `kMinCompleteDays` complete or fasting days in [start, d].
     - At least `kMinWeighIns` non-ignored weigh-ins spanning ≥ 7 days.
     - If the gate fails, skip to step 6.
  4. **Observation:**
     - `intake = mean(cals of complete/fasting days)`
     - `slope, slopeSE` = OLS of non-ignored raw weights against day index. Use raw readings, not the trend, to avoid EMA lag.
     - `ED = energyDensity(fatMass(trend at d))`
     - `obs = intake − slope·ED`
     - `σ²obs = kOverlapInflation · [(slopeSE·ED)² + intakeSD²/n + kIntakeBiasSd²]`
  5. **Update:**
     - `K = var/(var+σ²obs)`
     - `tdee += clamp(K·(obs − tdee), ±kMaxDailyTdeeStep)`
     - `var = (1−K)·var`
     - `lastUpdateDay = d`
  6. **State:**
     - `paused` if the last `kPausedAfterDays` days have zero complete days or zero weigh-ins.
     - Else `learning` if there has never been an update.
     - Else `confident` if `√var ≤ kConfidentSd`.
     - Else `estimated`.
  7. **Persist** an `energy_estimates` row. Store the window stats too, for the "How we got this" card.
- **Reset learning** sets `learning_started_on = today` and re-initialises the state. Old rows are kept for the chart, which shows a gap marker at the reset.

### 6.5 BMR and formula TDEE (`bmr.dart`)
- **Mifflin–St Jeor:**
  - Male: `10w + 6.25h − 5a + 5`
  - Female: `10w + 6.25h − 5a − 161`
- If body fat % is known: `bmr = mean(Mifflin, Katch–McArdle 370 + 21.6·LBM)`.
- `formula_tdee = bmr × [1.2, 1.375, 1.55, 1.725, 1.9][activity−1]`.
- Age used = `age + floor(yearsSince(age_recorded_on))`.

### 6.6 Targets (`targets.dart`)
**Calories for a phase**
- `pace` comes from the user's chosen %/week:
  - Lose options: 0.25 / **0.5** / 0.75 / 1.0
  - Gain options: 0.1 / **0.25** / 0.5
- `delta = pace/100 · trend · ED / 7`
- `cals = tdee − delta` (lose), `tdee` (maintain) or `tdee + delta` (gain).

**`applySafetyLimits(cals, tdee, sex, weight)`**, applied in order. Any limit that bites is recorded in `limit_hit`.
1. Lose: `cals ≥ tdee·(1−kMaxDeficitFrac)`, and the implied pace is ≤ `kMaxLossPct`.
   Gain: `cals ≤ tdee·(1+kMaxSurplusFrac)`, and the implied pace is ≤ `kMaxGainPct`.
2. `cals ≥ sex floor`.
3. **Ordinary check-ins only:** `|cals − currentCals| ≤ kMaxCheckinStep`. This step is skipped for onboarding, recalculation, phase transitions and goal-reached.

**Macros** (`splitMacros`)
- `refWeight`:
  - With known body fat: lean body mass.
  - Otherwise: `min(weight, 25·(h/100)²)`.
- `proteinPerKg`: the user override if set. Otherwise:

  | Goal | LBM-based | Ref-weight-based |
  |---|---|---|
  | Lose | 2.6 | 2.0 |
  | Maintain / gain | 2.0 | 1.6 |

  Add +0.2 to the ref-weight-based values when `training_type ∈ {weights, both}` (that comes in a later phase).
- **Allocation order:**
  - `protein = refWeight·proteinPerKg`
  - `fatFloor = max(0.5·refWeight, 0.20·cals/9)`
  - `fat = max(cals·fatRatio(default 0.25)/9, fatFloor)`
  - `carbs = (cals − 4p − 9f)/4`
  - If `carbs < 0`: lower fat to `fatFloor` first, then protein down to `1.2·refWeight`, then set `carbs = 0`.
- Round to whole grams, then recompute carbs from the rounded protein and fat. **Invariant:** `|4p + 4c + 9f − cals| ≤ 5`.

### 6.7 Phase engine (`phase_engine.dart`)
Evaluated daily. Transitions take effect at the next check-in (6.8), not mid-week.

```
steady:  [lose|gain|maintain until goal]
phased:  lose(target X% of start trend, max 16 wk) → maintain(M wk) → lose … until goal
breaks:  lose(8 wk) → maintain(2 wk) → lose … until goal
X = kPhasedLossPctObese if BMI(at phase start) ≥ 30 else kPhasedLossPct
```

| Phase | Is "due to end" when | `end_reason` |
|---|---|---|
| lose (phased) | `trend ≤ start·(1−X/100)` | reached |
| lose (phased) | `weeks ≥ kMaxLossPhaseWeeks` | max_duration |
| lose (breaks) | `weeks ≥ kBreakEveryWeeks` | planned |
| maintain | `weeks ≥ planned_weeks` | planned |
| any | trend has crossed the goal weight | goal_reached |

**User actions**
- **Keep losing** (on variant F): skip the maintenance phase. Insert it with `ended_on = started_on` and reason `skipped`, then start the next lose phase.
- **Extend break**: `planned_weeks += 2`.
- **End phase early**: the phase ends at the next check-in with reason `user_ended`.
- **Changing plan style, goal or pace in recalculate**: close the current phase as `replanned` and start a fresh sequence from the current trend weight.

### 6.8 Check-in (`checkin.dart`)
**When it runs**
- At the first app open at or after 04:00 local on `checkin_weekday`, if there's no `goal_checkins` row for this `week_start`. `week_start` = the date of this check-in.
- `checkin_weekday` defaults to the weekday of onboarding completion. The first check-in is ≥ 7 days after onboarding.

**Decision order** (first match wins)

| # | Condition | Variant | Targets |
|---|---|---|---|
| 1 | Trend crossed the goal weight | `goal_reached` (D) | Unchanged until the user picks **Switch to maintenance** (plan becomes steady maintain) or **Set a new goal** (opens recalculate). |
| 2 | Phase due to end, next phase is maintain | `phase_to_maintain` (F) | New maintain targets (adaptive: estimated TDEE; non-adaptive: formula TDEE at the current trend). No step cap. |
| 3 | Phase due to end, next phase is lose | `phase_to_lose` (G) | New lose targets, same TDEE source as row 2. No step cap. |
| 4 | `adaptive_goals = false` | none | No row, no sheet. |
| 5 | State is `learning` or `paused` | `insufficient` (C) | Unchanged. |
| 6 | Computed vs current `< kNoChangeThreshold` | `unchanged` (B) | Unchanged. |
| 7 | Otherwise | `changed` (A), with the limit line (E) if `limit_hit` | Applied with step cap. |

- Rows 1–3 run for non-adaptive users too. That's decision 5: targets change only at phase boundaries.
- Applying targets writes `user_macros`, then the `goal_checkins` row, then shows the sheet.

### 6.9 Projection (`projection.dart`)
- Simulate week by week from the current trend weight:
  - `ED` from the current fat mass
  - `ΔW = 7·(cals − tdee)/ED`
  - `tdee −= 10·ΔW·activityFactor` (Mifflin's weight term)
  - Recompute `cals` per 6.6 for adaptive users. Keep it fixed per phase for non-adaptive users.
  - Run the phase engine for phased plans.
- Stop at the goal weight or 156 weeks.
- Output: `weeksToGoal` with a range of `[0.85×, 1.25×]` and an estimated date. The UI shows it as "about N weeks".

## 7. UI

The detailed layout and copy are in plan §9. The requirements below are the acceptance bar.

### 7.1 Energy tab
- **Placement:** the first tab in `TrackingPagesScreen`, labelled **Energy**. The other tabs shift right and `initialPage` callers are updated.
- **R1. Headline** shows the TDEE with `± round(√var, 10)`, the state pill, and the change vs 7 days ago (hidden when `|Δ| < 10`). Per state:
  - Learning: "Starting estimate", plus a progress ring of complete days / 7 and weigh-ins / 4.
  - Paused: "Last updated <date>".
- **R2. Chart:**
  - The TDEE line with a ±1σ band. Range chips 1M / 3M / 6M / All.
  - `formula_tdee` as a dashed line.
  - Check-in ticks, which open the stored check-in sheet. Reset gaps are drawn as breaks in the line.
- **R3. "How we got this"** shows the window stats from the latest row: avg intake, complete days, trend change per week, the `slope·ED` term, and the result. Hidden in Learning.
- **R4. Data quality strip:**
  - The last 21 days: filled = complete/fasting, half = partial, empty = untracked, plus a weigh-in tick under each day with a weigh-in.
  - One tip line, chosen as: weigh-ins < 4 → "weigh in"; else partial+untracked > 30% → "Finish day"; else nothing.
- **R5. Goals card:**
  - Adaptive on: next check-in day and the current target.
  - Adaptive off: the fixed target and a toggle. Turning it on shows a confirm sheet with the onboarding copy.
  - Phased or breaks plans: the phase timeline (plan §9.6).
- **R6. Check-in history**, newest first. Hidden when empty.
- **R7. Reset learning**, with a confirm dialog.

### 7.2 Weight tab
- The trend line over the raw dots. The header shows the trend weight and the weekly change in kg/lb and %.
- The pace row compares actual vs goal pace. It's neutral within ±0.15%/wk of the goal pace, a soft accent otherwise, never red.
- Ignored readings are drawn hollow. Tapping one explains why it was ignored.
- Phase boundaries are drawn as bands. During the `kSwitchSettleDays + 6` days after a switch, the label reads "Expected: water & glycogen".

### 7.3 Finish day
- A quiet row at the end of the home meal list, for the selected date: "Done logging? **Finish day**".
- Once finished: "Day finished ✓". Tapping it again opens a menu with Not finished / Fasted (ate nothing) / Didn't log everything.
- The date bar shows a small check under finished days.
- Writes go through `food_day_status` and trigger `EnergyProvider.refresh()`.

### 7.4 Check-in sheet
- Variants A–G as in plan §9.5–9.6. It's a modal bottom sheet, and only one is shown per check-in.
- Dismissing it sets `seen_at`. The calorie card shows a "Targets updated" chip until the end of that day, which reopens the sheet.
- **Design deliverable:** I'll design the sheet (all variants, light and dark) before phase 3 is built, then you review it.

### 7.5 Onboarding
- New steps in `OnboardingStep`:
  - `planStyle`: only when goal = lose, right after `setNewGoal`.
  - `adaptive`: after `planStyle`/`setNewGoal`, before `advanced`.
- Copy is in plan §10.1 and §10.3.
- Defaults:
  - adaptive = Yes.
  - planStyle = phased if `(weight − goalWeight)/weight > 0.10`, else steady.
- `setNewGoal` replaces the kcal deficit slider with the %/week pace picker (6.6). Each option shows the resulting cals/day and "about N weeks". If a limit applies, the clamped pace is shown with an explanation.
- The summary/results screen adds "Updates weekly as we learn your metabolism" or "Fixed target", plus the phase count and total weeks for phased plans.
- The age picker minimum is 18.

### 7.6 Recalculate goals
- `onboardingStepsFor(recalculateOnly: true)` = weight, activity*, goal, setNewGoal, planStyle, adaptive, advanced, summary.
  - Weight is prefilled from the trend weight.
  - *Activity is skipped when adaptive is on and the state is `confident`. The summary then says it's using the learned expenditure.
- The summary shows old → new targets.
- A recalculation never resets learning.

### 7.7 Profile
- Add editable Sex / Height / Age rows to the account screen.
- Saving recomputes the targets with the current settings and shows an old → new confirm.

## 8. Notifications
- **Check-in ready:** a local notification at 08:00 on the check-in day, for users with adaptive on or a phased/breaks plan.
  - Body: "Your weekly check-in is ready".
  - Scheduled with `NotificationService.scheduleNotification` and rescheduled after each check-in or when the day changes.
- **Finish-day reminder:** decision 6.
  - Off by default.
  - It's only offered in context, as a "Remind me in the evening" button on check-in variant C and on the data-quality tip.
  - If the user already has meal reminders on, append the finish-day prompt to the last meal reminder instead of sending a separate push.
  - Setting: Settings → Notifications → "Finish-day reminder" with a time picker, default 21:00.

## 9. Analytics (PostHog)
`adaptive_choice_made{choice, context: onboarding|settings|recalculate}` · `plan_style_chosen{style}` · `pace_chosen{pct, clamped}` · `day_finished{status, inferred_was}` · `energy_tab_viewed{state}` · `checkin_shown{variant}` · `checkin_dismissed{variant, seconds}` · `phase_action{action: start_break|keep_losing|extend|end_early}` · `learning_reset` · `finish_reminder_enabled{source}`.

## 10. Build order and acceptance

| Phase | Deliverables | Done when |
|---|---|---|
| **0. Foundations** | §3.2 removals and extraction. `bmr.dart`, `body_composition.dart`, `targets.dart`. Pace picker, safety limits, new protein/fat rules, profile rows, 18+ age. Migration part 1. | Unit tests pass for every formula, all safety-limit branches, and the macro sum invariant across a grid of 1,000 inputs. Onboarding and recalculate produce sensible targets for the 6 reference personas in `test/unit/energy/personas.dart`. No references to `NutritionGoalsProvider` or `expenditure_*` remain. |
| **1. Estimator (shadow)** | `trend_weight`, `day_status`, `energy_estimator`, `EnergyProvider`, Finish-day row, tables 2–3, sync, debug screen behind a dev flag. | **Simulation harness** (`test/unit/energy/simulated_user.dart`): 200 seeds, true TDEE 1,800–3,200, daily weight noise σ 0.7 kg, 20% untracked days, 10% partial days (logged at 40%), constant 15% under-reporting, glycogen ±1 kg on diet start. By day 28, `|est − logged-basis TDEE| ≤ 150` for ≥ 90% of seeds. True value within ±1.28σ for 75–85% of seed-days (calibration; tune `kOverlapInflation`). No day-to-day step over 50. |
| **2. Energy tab** | §7.1–7.2. | All 4 states render with fixture data in light and dark. Widget tests cover each state. |
| **3. Check-ins + onboarding** | `checkin.dart`, `goal_checkins`, sheet design then build, adaptive step, recalculate trim, notifications. | Unit tests cover every row of the 6.8 decision table, including non-adaptive users. Onboarding step tests are updated (`onboarding_steps_test.dart`). |
| **3b. Phases** | `phase_engine`, `goal_phases`, planStyle step, phase UI, variants F/G, projection. | Unit tests cover every transition and user action. Simulation: a +1 kg rebound at a phase switch moves the estimate by < 75 cals. A non-adaptive phased user's target changes only at boundaries. |

## 11. Decisions log
1. The check-in follows the onboarding flag. On = auto-apply with an explanation. Off = fixed targets.
2. Everything is behind the trial/premium paywall. The estimator runs through lapses.
3. Safety limits are as listed in §5.
4. No existing users, so breaking changes are fine. The new maths applies to new onboardings and recalculations.
5. Phased plans with adaptive off: targets change only at phase boundaries.
6. The finish-day reminder is off by default and offered in context (§8).
7. Phase defaults are 5% / 10% loss per phase, 4-week maintenance and a 16-week cap. Breaks are every 8 weeks for 2 weeks.
8. Check-in sheet design: Claude designs it, you review it before phase 3 is built.
