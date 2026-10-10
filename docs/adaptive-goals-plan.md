# Adaptive macro goals — plan

Status: proposal (2026-10-07). Nothing here is built yet.

## 1. Where we are today

| Piece | State |
|---|---|
| `MacroCalculatorService.calculateAll` | Live. Formula BMR × activity multiplier → TDEE, then fixed ±kcal deficit/surplus, then macros. Runs at onboarding / when goal settings change. |
| `FoodEntryProvider.recalculateMacroGoals` | Live goals owner (synced to `user_macros`). Re-derives targets from the **stored** TDEE. TDEE itself never changes after onboarding. |
| `NutritionGoalsProvider` | Dead code: a duplicate goals provider that is never registered or imported. |
| `ExpenditureService` / `ExpenditureProvider` / `expenditure_screen.dart` / `tdee_dashboard.dart` | Fully commented out. Algorithm used dummy random data; result was never fed into goals. |
| Data we already collect | Food log (`food_entries`), daily weight (`weight_entries`, Hive `weight_history`), HealthKit read permissions for steps, active + basal energy, weight, height, dietary energy/macros. |

## 2. What the research says (and what's wrong with our current math)

### 2.1 Static formulas are a starting point, not an answer
- Mifflin–St Jeor is the best general-purpose RMR equation (within ±10% of measured RMR for ~80% of people, narrowest error range) — but that still means 1 in 5 people are off by >10%, and older adults and many ethnic groups were under-represented ([Frankenfield 2005 systematic review](https://pubmed.ncbi.nlm.nih.gov/15883556/)).
- Original Harris–Benedict (1919) is consistently worse; there's no good evidence for our rule "underweight or athlete → Revised Harris–Benedict".
- Body-composition equations (Katch–McArdle, Cunningham) only win when body fat is **measured**. A self-guessed BF% adds error. In free-living athletes Cunningham can be badly biased ([cross-validation, 2023](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9960966/)).
- Activity multipliers add more error on top of RMR error. MacroFactor's own data: formula TDEE is off by ~300 kcal/day (~12%) on average, vs ~110 kcal/day (~4%) for their adaptive estimate after it converges; adaptive beat formula for 94% of users ([MacroFactor accuracy analysis](https://macrofactor.com/algorithm-accuracy/)).

**Takeaway:** don't over-invest in picking the perfect formula. Use Mifflin as a prior with an honest ±300 kcal uncertainty and let real data take over within 2–4 weeks.

### 2.2 The 7,700 kcal/kg rule is wrong for most of our users
- 7,700 kcal/kg (3,500/lb) only roughly holds for people with lots of body fat. Leaner people lose a larger share of lean tissue per kg, which carries much less energy, so each kg lost is "cheaper" ([Hall 2008, *What is the required energy deficit per unit weight loss?*](https://pubmed.ncbi.nlm.nih.gov/17848938/)).
- Use Hall's body-composition-aware energy density instead:
  - Fraction of weight change that is lean (Forbes): `p = 10.4 / (10.4 + FM_kg)`
  - Energy density: `ED = p × 1,816 + (1 − p) × 9,440 kcal/kg` (lean tissue ≈ 7.6 MJ/kg, fat ≈ 39.5 MJ/kg)
  - e.g. FM 15 kg → ~6,300 kcal/kg; FM 40 kg → ~7,900 kcal/kg.
  - FM comes from measured BF% if we have it, otherwise an estimate from BMI/age/sex (e.g. the Deurenberg equation).
- MacroFactor's V3 update made gain and loss use the same energy equivalent ([V3 write-up](https://macrofactor.com/expenditure-v3/)). We should do the same.
- The first 1–2 weeks of a diet change include glycogen and water shifts. Expect noisy early estimates, and lean on the prior more during that time.

### 2.3 Expenditure adapts as you diet
- Metabolic adaptation is real but modest: about 50–230 kcal/day beyond what lost mass explains, mostly from reduced NEAT/non-resting expenditure ([Rosenbaum & Leibel, reviewed here](https://pmc.ncbi.nlm.nih.gov/articles/PMC4965234/)).
- Weight responds slowly to a sustained change in intake (half-time about 1 year), so static "weeks to goal" projections are wrong ([Hall et al. 2011, Lancet](https://pmc.ncbi.nlm.nih.gov/articles/PMC3880593)).
- **Takeaway:** a TDEE computed once at onboarding drifts further from reality the longer someone diets. This is the main reason to build the adaptive estimate.

### 2.4 Food logs under-report, and that's fine if the estimate is calibrated on them
- Self-reported intake under-reports by ~10–25% against doubly labeled water ([mobile food record DLW study](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5372975/)).
- An adaptive estimate computed from **logged** intake absorbs consistent under-reporting: the "TDEE" it learns is really "logged calories at which weight is stable". Targets set from it still work. That's why this approach beats wearables and formulas.
- What does break it is **inconsistent** logging, i.e. partially logged days. MacroFactor reports the error grows considerably once more than ~5–10% of days are partially logged. We need to detect or ask about incomplete days.

### 2.5 Wearable calorie burn is not trustworthy
- Wrist devices (Apple Watch, Garmin, Fitbit, Polar) are not an acceptable surrogate for energy expenditure, even though their heart rate is good ([Apple Watch 6 / Polar / Fitbit validation](https://doaj.org/article/07fd500223d7469991264a4484a9d910)).
- **Takeaway:** don't add "exercise calories burned" to the budget. Use **steps** (more reliable) as a relative signal for changes in activity, not as an absolute kcal number.

### 2.6 How fast to lose or gain
- Set rate as **% of body weight per week**, not a fixed kcal deficit. About 0.5–0.7%/week preserves lean mass and performance better than ~1.0–1.4%/week in trained people ([Garthe et al. 2011](https://www.sponet.de/sponet/Record/4017680)). Larger deficits mean more lean mass lost, even with resistance training.
- A fixed 500 kcal deficit is 0.9%/week for a 60 kg person but 0.4%/week for a 120 kg person.

### 2.7 Macros
- **Protein:** ISSN says 1.4–2.0 g/kg for exercising people. Lean people in a deficit who lift: 2.3–3.1 g/kg **of fat-free mass** ([ISSN position stand 2017](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5477153/); Helms 2014). The muscle-gain benefit plateaus around 1.6 g/kg (95% CI up to ~2.2) (Morton 2018).
  - Our bug: `weight × 2.0` on **total** body weight gives a 130 kg user 260 g/day. Base it on fat-free mass when known, otherwise on a reference weight capped at BMI ~25 for height.
  - Our male 2.0 / female 1.8 split has no evidence behind it. Drop it.
- **Fat:** stay within AMDR (20–35% of energy). Keep a floor of about 0.5–0.6 g/kg so very low calorie targets don't push fat to unhealthy levels (MacroFactor does the same and prioritises fat at low calories).
- **Carbs:** the remainder. Currently, when carbs would go negative we clamp them to 0, so the macros silently stop adding up to the calorie target. Fix the order: protein → fat floor → carbs → trim fat toward its floor if needed.

## 3. How other apps do it

| App | Approach |
|---|---|
| **MacroFactor** | Energy balance: `expenditure = intake − Δ(trend weight) × energy density`. Trend weight weights recent days more heavily. Converges in 14–30 days. Weekly check-in sets new targets. "Adherence-neutral": only what you actually ate and how your weight moved matter, not whether you hit targets. Untracked days don't penalise you; it carries forward the last high-confidence estimate. Algorithm details are proprietary ([philosophy](https://macrofactor.com/macrofactors-algorithms-and-core-philosophy/), [V3](https://macrofactor.com/expenditure-v3/), [accuracy](https://macrofactor.com/algorithm-accuracy/)). |
| **Carbon Diet Coach** | Weekly check-ins adjust macros from a trend weight, so daily fluctuations don't cause big swings ([help](https://help.joincarbon.com/en/articles/6078877-coach-trend-weight)). |
| **FoodNoms** | "Calibrated energy" from logged intake and weight ([help](https://foodnoms.com/help/calibrated-energy)). |
| **Hacker's Diet** (the original) | Trend = exponential moving average, `T = T_prev + 0.1 × (W − T_prev)` ([fourmilab](https://fourmilab.ch/hackdiet/www/subsection1_4_1_0_1.html)). |
| **NIH Body Weight Planner** | Hall's dynamic model, for projections ([NIDDK](https://www.niddk.nih.gov/research-funding/at-niddk/labs-branches/laboratory-biological-modeling/integrative-physiology-section/research/body-weight-planner)). |
| MyFitnessPal, Cronometer | Static formula, plus optional "add exercise calories back". No adaptive TDEE; Cronometer users have asked for it for years ([forum](https://forums.cronometer.com/discussion/5468/adaptive-tdee-calculation-why-dont-we-have-it)). This is a real differentiator. |

## 4. The algorithm we'll build

All of it is pure Dart functions with no Flutter imports, so it can be unit-tested with simulated users.

### 4.1 Trend weight
- Time-aware EMA: `α_eff = 1 − (1 − α)^Δdays`, with α ≈ 0.1. Gaps are handled correctly and missing days aren't invented.
- Ignore single readings more than ~3% from the trend (typos, clothes on), but keep them shown in the UI.
- *Later option:* move to a 2-state Kalman filter (weight, slope). It handles irregular weigh-ins more cleanly and gives a proper uncertainty on the slope.

### 4.2 Which intake days count
- Each day is **complete**, **partial**, or **untracked**.
- Add an explicit "Day complete ✓" control on the home date bar or end of day. This is the cleanest signal.
- Heuristic fallback: a day is suspect if kcal < 50% of the current estimate, or there's only 1 entry, unless the user marked it complete (covers fasting days).
- Partial and untracked days are excluded from the intake average. The window's weight change still counts, so the average of complete days stands in for the missing ones. Show a confidence level so users understand when it's low.

### 4.3 Expenditure estimate (scalar Kalman-style update, once per day)
```
prior (day 0):  TDEE₀ = Mifflin × activity factor,          σ₀ ≈ 300 kcal
each day, over a trailing 21-day window (recent days weighted more):
  intake̅   = weighted mean kcal of complete days
  slope    = d(trend weight)/dt  (kg/day, regression on trend over window)
  ED       = Hall energy density from current fat mass (2.2)
  TDEE_obs = intake̅ − slope × ED
  σ_obs    = f(# complete days, # weigh-ins, weight noise)   e.g. 21 days, σ_w 0.7 kg → ~190 kcal
  K        = σ²_est / (σ²_est + σ²_obs)
  TDEE     = TDEE_prev + K × (TDEE_obs − TDEE_prev)
  clamp |ΔTDEE| ≤ ~50 kcal/day; add small process noise so it keeps adapting
  if < 7 complete days or < 4 weigh-ins in window → no update (carry forward)
```
- This gives day-3 responsiveness with heavy smoothing, and the uncertainty is shown in the UI as "±X kcal".
- Store a daily row: tdee, σ, trend weight, slope, complete days used, algorithm version.

### 4.4 Weekly check-in (sets the targets)
- On a weekday the user picks:
  - `daily deficit = rate%/wk × trend weight × ED / 7` (negative for gain)
  - `calorie target = TDEE − deficit`, with a floor of max(sex-specific floor, ~BMR × 1.0) and a cap of ±~150 kcal change per week so it doesn't feel jumpy
  - macros via the fixed `distributeMacros` (2.7)
- Adherence-neutral: no "you ate over so eat less this week".
- Behaviour depends on the `adaptive_goals` flag set in onboarding (section 10):
  - **On:** auto-apply the new targets, always with an explanation of *why*, e.g. "Your trend dropped 0.3 kg while you averaged 2,140 cals → expenditure ≈ 2,450".
  - **Off:** targets never change. They stay exactly as calculated at onboarding or the last recalculation. The estimate is still computed and shown.
- When the trend weight reaches the goal weight, offer to switch to maintenance.

### 4.5 Projection
- Replace the linear `weeks_to_goal` with a forward simulation: each simulated week, recompute ED and shrink TDEE as weight falls (Mifflin delta plus a small adaptation term). Show it as a range, not a single date.

### 4.6 Phased dieting (lose X%, maintain, repeat)

**What the research says**
- **Clinical guidance:** aim to lose ~10% of starting weight over ~6 months, then switch to weight maintenance. Only attempt further loss once that's held ([NHLBI obesity guidelines](https://internet-prod.nhlbi.nih.gov/health/educational/wecan/portion/documents/CORESET3.pdf)).
- **MATADOR** (men with obesity): 2 weeks dieting / 2 weeks at maintenance, repeated. This gave **more** weight and fat loss than continuous dieting (14.1 vs 9.1 kg) and less drop in resting metabolism after adjusting for body composition. Weight held steady during the break weeks ([Byrne 2018](https://pmc.ncbi.nlm.nih.gov/articles/PMC5803575)).
- **ICECAP** (resistance-trained adults): three 1-week diet breaks over 12 weeks. Fat loss and lean mass were the **same** as continuous dieting, but hunger, irritability and leg endurance were better after breaks. Weight rose ~0.6 kg during a break, mostly fat-free mass and water, not fat ([Peos 2021](https://pubmed.ncbi.nlm.nih.gov/33587549/)).
- **Meta-analysis** (12 RCTs, 881 people): diets with breaks give the same fat loss and lean-mass retention as continuous diets. Resting metabolism ends up slightly higher, by under 100 cals/day ([Poon 2024](https://pmc.ncbi.nlm.nih.gov/articles/PMC10170537)).

**Takeaway:** breaks don't make fat loss faster or "fix" metabolism. They make the diet **easier to stick with** (less hunger, better training) and match how clinicians stage big weight losses. That's worth offering, honestly framed: "same results, easier to sustain", not "boosts your metabolism". It costs calendar time: the same loss takes longer.

**Plan styles** (chosen when goal = lose)

| Style | Rule | Default for |
|---|---|---|
| **Steady** | Continuous deficit at the chosen pace until the goal weight. | Goals ≤ 10% of current weight. |
| **Phased** *(recommended for bigger goals)* | Lose **X%** of the phase's starting trend weight, then **maintain for M weeks**, then repeat until the goal weight. Defaults: X = 10% if BMI ≥ 30, otherwise 5%; M = 4 weeks; a loss phase also ends after **16 weeks** at most, even if X isn't reached. | Goals > 10% of current weight. |
| **Diet breaks** | Every **8 weeks** of dieting, take a **1–2 week** maintenance break (ICECAP-style). | Optional; aimed at lifters on long cuts. |

X, M and break length can be edited in Settings. The defaults are product choices informed by the studies above, not values the research proves optimal.

**How phases interact with the estimator**
- **Phase switches cause water/glycogen shifts.** Going from deficit to maintenance usually adds 0.5–1.5 kg within days (glycogen, water, food volume). The reverse happens at the start of a cut. Read naively, that looks like ~4,000–10,000 cals of "fat", which would wreck the estimate.
  - For the **first 10 days after any phase switch**, scale up the observation noise (σ_obs × 3) so the estimate barely moves.
  - Show the jump on the Weight tab as "Expected: water & glycogen after your phase change", so users don't panic.
- **Phase progress is measured on trend weight**, not scale weight, so one light morning doesn't end a phase.
- **Maintenance check-ins** aim for zero trend slope, with a tolerance band of ±0.15%/wk before adjusting. Maintenance phases are actually the best calibration windows (intake is steady and the slope is near zero), so the estimate usually tightens during them.
- **Entering maintenance:** target = current TDEE estimate. Don't add the old deficit back on top of the formula; that overshoots.
- **Returning to a loss phase:** recompute the deficit from the *current* trend weight and ED, with the same safety limits (section 5 item 4).
- **Projections (4.5)** include the maintenance weeks, so "about N weeks to go" is honest.

**Adaptive off + phased:** at each phase boundary the target changes once (formula TDEE at the current weight ± pace), then stays fixed for the phase. The user chose this schedule explicitly. Within a phase nothing moves, which keeps the spirit of "fixed targets".

**Gain goals:** out of scope for v1. A later "mini-cut" mirror (gain X%, then cut back ~⅓ of it) can reuse the same phase engine.

## 5. Fixes to existing algorithms (do these first, they're small)

1. **One source of truth for goals:** delete the dead `NutritionGoalsProvider`, and extract the goal fields, `recalculateMacroGoals` and goal sync out of `FoodEntryProvider` into a new `GoalsProvider` (see spec §3.2).
2. **BMR:** default to Mifflin. Drop the auto-switch to original or revised Harris–Benedict. Use Katch–McArdle only when BF% is **measured** (smart scale or DEXA via HealthKit `BODY_FAT_PERCENTAGE`), and average it with Mifflin. Make sure the onboarding default `_bodyFatPercentage = 20.0` never leaks into the calculation unless the user actually entered a value.
3. **Goal pace:** replace "deficit 500 kcal" with % body weight per week presets:
   - Lose: 0.25 / 0.5 (recommended) / 0.75 / 1.0
   - Gain: 0.1 / 0.25 (recommended) / 0.5
   - Convert to kcal with Hall ED.
4. **Safety limits:** apply them to every goal, not just "lose" at 1,200. Every target, static or adaptive, goes through the same `applySafetyLimits()`:
   - **Calorie floor:** 1,200 cals (female) / 1,500 cals (male). This is the common guidance for diets without medical supervision.
   - **Max deficit:** 25% of current TDEE, and the loss pace is capped at 1% of body weight/week.
   - **Max surplus:** 15% of TDEE, and the gain pace is capped at 0.5%/week.
   - **Max weekly change** from a check-in: ±150 cals.
   - If a limit cuts in, show it plainly: "We've set your pace to 0.6%/week to keep your target above 1,200 cals."
   - Keep the onboarding age picker at 18+. These limits don't apply to minors, pregnancy or eating-disorder history, so the terms/onboarding copy should say the app isn't meant for those cases.
5. **Protein:** base it on fat-free mass or reference weight. Make it goal- and training-dependent (about 1.6 g/kg maintain/gain, 2.0–2.4 g/kg reference weight in a deficit, or 2.3–3.1 g/kg FFM when measured). Remove the sex split.
6. **Fat/carbs:** add a fat floor and fix the allocation order so macros always sum to the calorie target.
7. **Energy constant:** replace the hard-coded 7,700 in `calculateAll` and projections with the Hall ED function.
8. Delete the commented-out expenditure files once the new service replaces them.

## 6. Extra data that improves accuracy

In priority order (value vs effort):

| Data | Source | Used for |
|---|---|---|
| "Day complete" flag | New UI toggle | Biggest accuracy win (2.4). |
| Steps | HealthKit (already permitted) | Seed the activity factor from 14 days of history at onboarding instead of a self-reported level. Ongoing, use steps vs the user's baseline as a covariate so TDEE reacts faster to activity changes (net walking cost ≈ 0.4–0.5 kcal per kg per 1,000 steps). Optionally flex daily targets on high-step days. |
| Measured body fat / lean mass | HealthKit `BODY_FAT_PERCENTAGE`, `LEAN_BODY_MASS` (smart scales) | Energy density, protein reference, Katch–McArdle prior. |
| Training type | Onboarding question: none / cardio / lifting / both | Protein target, expected lean-mass share. |
| Weigh-in nudges | Notification and copy | "Same time, after waking, after bathroom" reduces weight noise more than any math. |
| Menstrual cycle | HealthKit (opt-in) | Mark expected water-retention days so the user isn't alarmed. Optionally give those weigh-ins less weight in the trend. |
| GLP-1 / medication flag | Optional question | Higher protein emphasis, slower floor warnings. Intake often drops sharply. |
| Active energy (watch) | HealthKit | Low-weight covariate only, never added to the budget (2.5). |

## 7. Data model (Supabase)
- `energy_estimates(user_id, day, tdee, tdee_sd, trend_weight_kg, slope_kg_per_day, complete_days, weigh_ins, algo_version)`, unique (user_id, day). RLS same as `weight_entries`.
- `goal_checkins(user_id, week_start, old_targets jsonb, new_targets jsonb, reason jsonb, status: applied|unchanged|insufficient_data, seen_at)`.
- `goal_phases(user_id, seq, kind: lose|maintain|gain, started_on, start_trend_kg, target_pct, max_weeks, planned_weeks, ended_on, end_reason: reached|max_duration|skipped|user_ended|goal_reached)`.
- Goal settings gain: `plan_style text (steady|phased|breaks)`, `phase_loss_pct`, `maintenance_weeks`, `adaptive_goals bool`, `checkin_weekday smallint`, `pace_pct_per_week numeric`, `age_recorded_on date` (so age ticks up without asking again), `training_type text`.
- `food_day_status(user_id, day, status: complete|partial|fasting)`.
- Compute on device; sync rows for multi-device use and history charts.

## 8. Phases

| Phase | Scope | Ship criteria |
|---|---|---|
| **0. Clean-up** | Section 5 fixes, single goals provider, ED function, unit tests for `MacroCalculatorService`. There are no live users yet, so breaking changes to stored goal fields are fine and need no migration. New maths applies to new onboardings and to anyone who recalculates. | Unit tests cover the formulas, the safety limits, and macros always summing to the calorie target. |
| **1. Estimator (shadow mode)** | `EnergyEstimator` pure service + trend weight + day-status flag + `energy_estimates` table. Computes daily but **doesn't change goals**. Internal debug screen. | Simulation tests: synthetic users (known TDEE, ±0.7 kg daily noise, 20% missed days, 15% under-reporting) converge to within ±150 kcal of "logged-intake TDEE" by day 28. |
| **2. Expenditure UI** | Rebuild the expenditure screen: trend vs scale weight chart, TDEE with ± band, confidence, "why". Replace the old `tdee_dashboard`. | Users see the estimate. Still no automatic goal changes. |
| **3. Weekly check-ins** | Onboarding question + `adaptive_goals` flag, auto-apply with explanation, change caps, goal-reached flow, `goal_checkins` table, check-in notification, trimmed recalculate flow (10.4). | Check-ins only change targets for users who opted in. |
| **3b. Phased plans** | Plan-style question, phase engine (4.6), phase-switch noise handling, phase timeline + transition check-ins (9.6), phase-aware projection. | Simulation: synthetic user with a +1 kg water rebound at a phase switch, estimate moves < 75 cals. |
| **4. Extra signals** | Steps covariate + step-seeded onboarding, measured BF%, training type, projection simulator. | A/B against phase 3 on the estimate's day-14 error. |

## 9. Expenditure UI

The app uses "cals" in all copy. Every screen below has a state for each of the three phases a user goes through:

| State | When | What the user sees |
|---|---|---|
| **Learning** | Fewer than 7 complete days or fewer than 4 weigh-ins in the window | The starting estimate from the formula, clearly labelled as a starting point, plus progress toward the first real estimate. |
| **Estimated** | Enough data, wide uncertainty (± > 200) | The number with a visible ± range and a "still settling" note. |
| **Confident** | ± ≤ 200 | The number, a small ± range, and a week-over-week change. |
| **Paused** | Data dried up (no complete days or weigh-ins for 7+ days) | The last confident value is carried forward and labelled "last updated <date>", with a nudge to log. |

### 9.1 Where it lives

| Surface | Change |
|---|---|
| **Progress tab** (`TrackingPagesScreen`) | New first tab **"Energy"**, before Weight / Macros / Steps / Workouts. This is the main expenditure screen (9.2). |
| **Weight tab** | Add a trend line over the scale-weight dots, and a "Trend 81.4 kg · −0.3 kg/wk" header (9.3). |
| **Home** | "Finish day" row under the meals (9.4). On check-in day, a one-time check-in sheet (9.5), then a small "Targets updated" chip on the calorie card for the rest of the day, which reopens the sheet. |
| **Settings → Goals** | Adaptive goals on/off, check-in day, pace, and "Recalculate goals" (section 10). |

The commented-out `expenditure_screen.dart`, `tdee_dashboard.dart` and `expenditure_provider.dart` get deleted and replaced, not revived.

### 9.2 Energy tab, top to bottom

**1. Headline**
```
Your daily expenditure
2,450 cals            ± 110
▲ 40 since last week   ● Confident
```
- **Learning state:** "Starting estimate: 2,300 cals" in secondary text colour, with a progress ring: "Learning your metabolism · 5 of 7 days logged · 3 of 4 weigh-ins". One line explains the idea: "We compare what you eat with how your weight moves to find what you actually burn."
- **Paused state:** "Last updated Sep 28 · log a few days to resume".

**2. Expenditure chart**
- A line of the daily estimate with a shaded ± band. Range chips: 1M / 3M / 6M / All. The starting formula estimate is a faint dashed line so users can see how far reality moved from it.
- Check-in days are marked with small ticks on the x-axis. Tapping a tick opens that check-in (9.5).
- Reuse the existing chart painter/service (`chart_painter.dart` / `native_chart_service.dart`) to stay consistent with the Weight tab.

**3. "How we got this" card**, plain-language maths for the last 3 weeks:
```
You ate on average            2,140 cals/day   (12 complete days)
Your trend weight changed     −0.30 kg/week
That change is worth          ≈ +310 cals/day
────────────────────────────────────────────
Your expenditure              ≈ 2,450 cals/day
```
- An info button opens a short explainer: why trend weight not scale weight, why partial days are left out, and why it's more accurate than a watch.

**4. Data quality card**
- A 21-dot strip, one dot per day. Filled = complete, half = partial, empty = not logged, and a small weigh-in tick under each day with a weigh-in.
- One line of guidance picked by whatever is weakest: "Weigh in 3+ times a week to sharpen this", or "Tap *Finish day* when you've logged everything".

**5. Goals card** (depends on the onboarding flag)
- **Adaptive on:** "Next check-in: Monday. Your targets will update from this estimate." It shows the current target and, if the check-in were today, the expected direction ("likely +50 cals"), so the next change isn't a surprise.
- **Adaptive off:** "Your targets are fixed at 2,000 cals. Turn on weekly updates to have them follow your real expenditure." Includes a toggle, which runs the opt-in sheet (section 10.1).

**6. Check-in history**
- A list of rows like "Oct 6 · 2,010 → 2,060 cals · Expenditure up 60". Tapping a row reopens that week's check-in sheet.
- Hidden when adaptive is off and no check-ins have happened.

**7. Footer**
- "Reset learning" (with confirm). This restarts from the formula estimate. Useful after illness, a pregnancy, or starting a new medication, or after months of not logging.

### 9.3 Weight tab additions
- The trend line is drawn over the raw weigh-in dots, and the header shows the trend weight, not the last scale reading.
- A pace row: "−0.3 kg/wk (−0.4%) · Goal pace −0.5%/wk".
  - Colour it neutral when within ±0.15%/wk of the goal pace. Use a soft accent otherwise, never red. Being off pace is information, not failure.
- Weigh-ins the trend ignored as outliers are drawn hollow, with "Ignored for trend: 4 kg from your trend" on tap.

### 9.4 "Finish day" (day status)
- Show a quiet row at the end of the home meal list for today and any past day: "Done logging today? **Finish day**". This matches the "one quiet row" style used for empty meals.
- Tapping it marks the day complete and shows a check. A long-press or overflow menu offers "Fasted / ate nothing" and "Didn't log everything".
- The date bar shows a tiny check under finished days.
- If the user never taps it, fall back to the heuristic (4.2). The UI never forces it.
- Optional evening notification (off by default; on for users with adaptive goals on): "Finished logging for today?" with the action inline.

### 9.5 Weekly check-in sheet (adaptive on)
Shown once, at the first app open on or after the check-in day. Also sent as a push notification that morning: "Your weekly check-in is ready".

**Variant A: targets changed**
```
Weekly check-in
Your new daily target
2,010 → 2,060 cals

Protein 150 g · Carbs 220 g (+12) · Fat 65 g

Why it changed
• You averaged 2,080 cals on 6 complete days
• Your trend weight fell 0.45 kg (on pace for −0.5%/wk)
• Your expenditure is about 60 cals higher than we thought

This week: −0.45 kg · Goal 75 kg · about 11 weeks to go
                                  [ Got it ]
```
**Variant B: no meaningful change (under 25 cals):** "You're right on track, targets stay the same." Shows the same "why" lines.

**Variant C: not enough data:** "Not enough data to update this week. Targets stay the same." Shows what's missing ("2 complete days, 1 weigh-in"), plus a CTA to turn on reminders.

**Variant D: goal reached** (trend weight at or past the goal weight): "You've reached 75 kg 🎉" with two buttons, **Switch to maintenance** / **Set a new goal**. This is the only time a check-in asks the user to choose instead of just auto-applying.

**Variant E: safety limit hit:** a line inside Variant A, e.g. "We kept your target at 1,200 cals, our minimum, so your pace may be a little slower."

Rules for all variants:
- Never shame. The copy is adherence-neutral ("you averaged", never "you went over").
- Macro deltas are only shown when they're 5 g or more.
- Dismissing records `seen_at`. The home chip stays for the day.

### 9.6 Phases in the UI (phased / diet-break plans)
- **Goals card on the Energy tab** gains a phase timeline: segments for loss (accent) and maintenance (neutral), with a "you are here" marker.
  - Losing: "Phase 2 · Losing · 3.1 of 4.2 kg · about 5 weeks left"
  - Maintaining: "Maintenance break · week 2 of 4 · then losing resumes Nov 3"
- **Check-in variant F: phase complete → maintenance**
  > **You've lost 5% — time for a maintenance break** 🎉
  > Your target goes up to 2,450 cals for the next 4 weeks. Expect the scale to rise 0.5–1.5 kg in the first few days. That's water and glycogen, not fat.
  > [ Start break ]  ·  Keep losing instead
- **Check-in variant G: maintenance → next loss phase**
  > **Ready for phase 3**
  > New target 1,950 cals · aiming to lose 4.0 kg (5%) · about 10 weeks
  > [ Let's go ]  ·  Extend break 2 weeks
- **"End phase early"** is in the goals card overflow menu, with confirm.
- **Weight tab:** phase boundaries appear as faint vertical bands. The post-switch water jump gets the "Expected" annotation (4.6).

### 9.7 Empty and edge cases
- **No HealthKit and no weigh-ins at all:** the Energy tab stays in Learning, with a primary CTA "Log your weight" that opens the weight entry sheet.
- **Maintain goal:** the same screens. The check-in just aims for zero change in trend weight.
- **Unit toggle (kg/lb):** respected everywhere. Pace is shown in the user's unit per week.

## 10. Onboarding and recalculate flow

### 10.1 New onboarding question: "adaptive goals"
- Placement: after **goal + goal weight/pace** (`setNewGoal`), before `advanced`. The user has just seen their goal, so "should this plan adapt?" lands naturally.
- New enum value `OnboardingStep.adaptive` in `onboarding_steps.dart`.

**Copy (recommended):**
> **Should your plan learn as you go?**
> Everyone's metabolism is different. Formulas can be off by 300 cals a day or more.
>
> ◉ **Yes, adjust my targets weekly** *(Recommended)*
> We'll learn what you actually burn from your logs and weigh-ins, then update your targets every week and tell you why.
>
> ○ **No, keep my targets fixed**
> Your targets stay as calculated today. You can turn this on anytime in Settings.

Alternatives to A/B test later:
- Headline: "Let your targets adapt to you?"
- Yes option: "Yes, keep my plan accurate"

**Details:**
- Default the selection to **Yes**.
- Check-in day defaults to the weekday 7 days after onboarding finishes. It can be changed in Settings, and isn't asked during onboarding, to keep the flow short.
- The results/summary screen gets one line under the target: "Updates weekly as we learn your metabolism" or "Fixed target".
- Saved to `adaptive_goals` in the goals table, and synced to Supabase like the other goal fields.

### 10.2 New onboarding question: training type (phase 4, optional sooner)
- "How do you train?" with options None / Mostly cardio / Mostly weights / Both. Feeds the protein target (2.7).
- Could be folded into the `activity` page to avoid adding a step.

### 10.3 New onboarding question: plan style (goal = lose only)
- Placement: right after goal weight + pace, before the adaptive question.
- Pre-select **In phases** when the goal is more than 10% of current weight, otherwise **Steady**.

> **How do you want to get there?**
> ◉ **Steady:** lose at a constant pace until you reach your goal.
> ○ **In phases:** lose 5% at a time, then take a 4-week maintenance break before the next phase. Same results, and many people find it easier to stick with.
> ○ **With diet breaks:** a 1–2 week break every 8 weeks.

- The summary screen shows the phase count and total time, including breaks: "3 loss phases + 2 breaks · about 34 weeks".
- In recalculate (10.4), this step comes right after goal weight + pace. Changing it mid-plan starts a fresh phase sequence from the current trend weight.

### 10.4 Recalculate goals, trimmed to what changes over time
Today "Recalculate Goals" (`accountdashboard.dart`) re-runs gender, weight, height, age, activity, goal, setNewGoal, advanced, summary. Most of these don't change.

| Step | In recalculate? | Why |
|---|---|---|
| Gender | ✗ | Doesn't change. It can be edited in **Profile** as a single field. |
| Height | ✗ | Doesn't change for adults. Edit in Profile. |
| Age | ✗ | Store `age_recorded_on` and add the elapsed years automatically. Edit in Profile. |
| Weight | ✓ prefilled | Prefill from **trend weight**, falling back to the last weigh-in. If weighed in the last 3 days, show as a one-tap "Use 81.4 kg (your trend)". |
| Activity | ✓, or skipped | When adaptive is on and the estimate is **Confident**, skip it. The data already knows. Show a line on the summary: "Using your learned expenditure (2,450 cals) instead of an activity estimate." When adaptive is off or still learning, ask it. |
| Goal | ✓ | Lose / maintain / gain. |
| Goal weight + pace | ✓ | Skipped for maintain, as now. |
| Plan style | ✓ prefilled | Lose goals only (10.3). |
| Adaptive | ✓ prefilled | Lets people switch on/off here as well as in Settings. |
| Advanced | ✓ collapsed | Protein and fat preferences, measured BF%. |
| Summary | ✓ | Shows old → new targets side by side before saving. |

Implementation notes:
- `onboardingStepsFor(recalculateOnly:)` already returns a separate list. Add the adaptive step, drop gender/height/age, and add a predicate (like `isOnboardingStepSkipped`) for skipping activity when the estimate is confident.
- `_prefillFromCurrentGoals` reads from the new `GoalsProvider` plus the latest `energy_estimates` row.
- A recalculation **doesn't reset** the learned expenditure. It only changes goal, pace, macro preferences and the flag. Resetting is a separate, explicit action (9.2 item 7).
- Recalculating with adaptive **off** recomputes from the formula with the new inputs. That fixed target then holds until the next recalculation.
- **Profile page:** add editable Gender / Height / Age rows. Changing one recomputes targets with the current goal settings, with a confirm sheet showing old → new.

## 11. Decisions
| # | Decision |
|---|---|
| 1 | The check-in follows the onboarding flag. **On** = auto-apply with an explanation (9.5). **Off** = targets stay fixed as set at onboarding/recalculate. Recalculate is trimmed to the fields that change over time (10.4). |
| 2 | Everything is behind the free trial / premium. No feature split is needed. The estimator should keep running through a lapsed subscription, so data isn't lost if they resubscribe. |
| 3 | Safety limits as in section 5 item 4: floors of 1,200 / 1,500 cals, max deficit 25% of TDEE and 1%/wk, max surplus 15% and 0.5%/wk, ±150 cals max change per check-in. |
| 4 | No existing users, so phase 0 makes breaking changes freely. The new maths applies to new onboardings and recalculations only. |
| 5 | Phased plans with adaptive **off**: the target changes once at each phase boundary (formula TDEE at the current weight ± pace), then stays fixed for the whole phase (4.6). |

### Resolved since
- Finish-day reminder: off by default, offered in context (spec §8).
- Phase defaults confirmed.
- Check-in sheet: Claude designs it, user reviews it before phase 3.

Build details live in [adaptive-goals-spec.md](adaptive-goals-spec.md).
