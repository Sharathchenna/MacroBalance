# Algorithm verification — maintaining, losing, gaining

2026-10-09. Estimator and target formulas unchanged. New tests: `test/unit/energy/goal_matrix_integration_test.dart` (24) and `test/unit/energy/goal_bias_audit_test.dart` (3). Measurements are summarized below; diagnostic tests remain in the repository.

## What passed

The tests run the actual `EnergyEstimator`, `decideCheckin`, `phaseTargets` / `applySafetyLimits`, macro split and `projectToGoal`, rather than mocking the decisions. They verify:

- All three goals learn from clean complete food logs, adjust weekly targets, preserve whole-gram calorie consistency within 5 cals, and obey the 50-cals/day estimate and 150-cals/week ordinary-change caps.
- Closed feedback journeys: tomorrow's food follows the calorie target actually applied at the last check-in, and tomorrow's tissue weight follows food minus true expenditure. Lose/gain switch to maintenance only after their **trend** crosses the goal on a check-in. Maintaining never gets a goal-reached event from a stale lose-goal weight.
- Learning and paused states keep targets unchanged. Once-weekly weigh-ins never meet the 4-readings/3-weeks gate; twice-weekly readings can learn despite imperfect food logging. A clear 20-kg typo is excluded from fitting.
- Known water shifts reset the fitting window; no update happens before the 4 settling days plus 7 complete food days. Paired water/no-water replays preserve causal timing.
- Projection calorie paths satisfy their physical weight equation and absolute safety bounds, accounting explicitly for floor priority and whole-calorie rounding. Check-in projections match the same standalone projection inputs.
- Fixed targets that imply zero progress or movement away from a goal have no goal date. A loss target held above expenditure by the calorie floor also has no date. Maintaining has no completion forecast.

## Accuracy remains below the original spec

Each primary cohort has **200 held-out seeds 10000–10199**, forced to one goal, over 84 days. Conditions match the existing harness: true expenditure 1,800–3,200, daily scale noise SD 0.7 kg, 20% missing food days, 10% partial days, constant 15% under-reporting, ±1 kg initial water for lose/gain, intake variability and expenditure drift. Initial formula error is SD 300 cals around the **logged-basis** truth.

| Metric | Losing | Maintaining | Gaining |
|---|---:|---:|---:|
| Day 28 within 150 cals | 53.0% | 64.5% | 54.5% |
| Day 28 mean absolute error | 157 | 137 | 169 |
| Day 28 mean signed error | +85 | -26 | -83 |
| Day 42 within 250 cals | 93.5% | 97.0% | 90.5% |
| Truth within 1.28 SD, all 84 days | 74.8% | 88.9% | 79.6% |

The **original requirement, ≥90% within 150 cals by day 28, is NOT met**. The unchanged existing mixed-goal test reran and skips with its live result: tuning 61.5%, held-out 58.6%. The new per-goal measurements are diagnostic, not substitute acceptance thresholds. No thresholds were lowered, no held-out model tuning was performed, and no production reporting correction was invented.

Mixed calibration obscures differences: maintaining uncertainty is conservative (88.9% coverage versus the intended 75–85%); loss coverage is just below 75% on this subset. Neither result proves per-user confidence accuracy.

## Cause of the goal-specific bias

For constant under-reporting fraction `u`, logged intake is `(1-u)*I`, but the production observation subtracts the **full** tissue-energy change `I-T`. Against logged-basis maintenance `(1-u)*T`, the observation bias is therefore `u*(T-I)`: positive for loss, negative for gain, approximately zero for maintenance. This is the known spec/model mismatch from AG-07.

Paired tests remove scale noise, water, prior error, expenditure drift, missed/partial days and intake variability while keeping 15% under-reporting. Day 28 bias becomes **+66.57 / ~0 / -33.81** cals for lose/maintain/gain. A harness-only comparator that knows the exact reporting factor scales the energy-density term by 0.85 and reduces the bias to **-0.088 / ~0 / -0.022**. The residual attributable to tissue-vs-trend energy-density/OLS lag is tiny in this isolated scenario. Production cannot know the reporting factor, so this comparator is evidence about cause rather than a deployable fix.

In the noisy baseline, knowing that factor changes bias from **+85 to +41** for loss and **-83 to -63** for gain; day 28 within 150 improves from53 to64% and54.5 to59.5%. Removing water changes bias to +60/-55. Removing scale noise improves within 150 to74.5/90.0/72.5%; removing prior error improves it to65.5/77.5/67.5%. These are separate ablations, not additive contributions. Window/gate delay, scale noise and prior error remain substantial even after accounting for reporting bias.

Actionable options require a spec decision: preserve and disclose this accuracy limitation, or change the estimator/reporting/window model and revalidate on fresh seeds. Changing only overlap inflation cannot resolve the signed observation mismatch. A replacement acceptance bar proposed in AG-07 has not been accepted here.

## Safety priority conflict — explicitly not an unconditional safety pass

Across **6484 weekly check-in decisions** (stop goal-specific target updates once a goal-reached choice is available):

| Event | Losing | Maintaining | Gaining |
|---|---:|---:|---:|
| Ordinary decisions | 2195 | 2200 | 2089 |
| Step-cap recorded | 81 | 116 | 137 |
| Applied/retained target outside newest deficit/surplus envelope | 157 | 0 | 142 |
| Largest envelope miss | 103 cals | 0 | 248 cals |

These exceptions follow existing specified priority: absolute bounds are computed first, then the +/-150 ordinary step is applied, and changes under 25 cals keep the **old** targets. The no-change deadband also retains small boundary breaches (e.g. loss target1881 with TDEE 2520 should be at least 1890, but its 9-cal adjustment is suppressed). Initial/recalculated/phase targets pass absolute-bound checks separately. New tests do **not** assert that every retained ordinary target satisfies every newest bound.

Two late loss-target events were above learned expenditure; both came from the sex-specific calorie floor. The corresponding forecasts were blocked rather than inventing a goal date. There were no late opposite-direction gain targets. No cap ordering was changed. A policy that requires absolute bounds to override gradual changes/no-change suppression would be a separate spec change.

Adaptive forecasts simulate future recalculated safe targets each week, rather than the exact current step-capped target. Their dates are plan forecasts, not evidence that a user's current target already achieves that pace. Fixed-target and floor-blocked cases are tested for null dates.

## Water and closed feedback journeys

40 held-out paired seeds per goal, with known +1 kg / -1 kg shifts on days 40/54: maximum water-induced estimate movement was **44.9 / 67.2 / 31.3** cals for lose/maintain/gain, with all 120 under75. The existing phase-switch acceptance test remains separate; no new threshold is inferred from this smaller cohort.

Three 126-day closed feedback scenarios use a real constant 2400-cal expenditure, starting prior 2100, complete logged food, and deterministic 0.25 kg scale noise:

| Journey | First scale crossing | Trend-based goal check-in | Final estimated expenditure | Final target |
|---|---:|---:|---:|---:|
| Losing 80→76 kg | day 51 | day 70 | 2400.3 | 2400 |
| Maintaining 80 kg | none | none | 2400.7 | 2398 |
| Gaining 80→82 kg | day 93 | day 112 | 2398.3 | 2399 |

The lag between a scale crossing and a goal-reached sheet is intentional: trend smoothing plus the weekly check-in schedule. Maintaining settles around 79.15 kg after initial underfeeding from the low prior; it learns to hold the resulting weight rather than automatically return to the original 80 kg. This matches maintenance as a calorie-balance goal, but is a meaningful journey limitation.

## Validation and limits

Targeted 8-file run: **146 passed,1 existing acceptance test skipped**; the 3 subsequently added no-progress forecast cases passed separately (**149 total targeted checks**). Both new test files analyze clean. The final full suite passed **1115 tests with 1 existing skipped accuracy acceptance test**. Analysis has **no new issues**; four existing informational lints in `WeightTrackingScreen.dart` remain.

```sh
flutter test test/unit/energy/goal_matrix_integration_test.dart test/unit/energy/goal_bias_audit_test.dart test/unit/energy/estimator_simulation_test.dart test/unit/energy/energy_estimator_test.dart test/unit/energy/checkin_test.dart test/unit/energy/safety_limits_test.dart test/unit/energy/projection_test.dart test/unit/energy/personas_test.dart
flutter analyze test/unit/energy/goal_matrix_integration_test.dart test/unit/energy/goal_bias_audit_test.dart
```

The estimator/target-math audit found no new calculation defect. Native review separately found and fixed premature Weight-page goal celebrations and rounding of the chosen goal in persisted check-in snapshots; three new regression cases cover those defects. These are synthetic validations, not clinical evidence or real-user validation. The noisy primary cohort is open-loop (food/weight generation follows the existing harness, with real weekly decisions evaluated afterwards); the 3 complete-log scenarios are closed-loop. The prior is favorably centred on logged-basis truth, so production formula priors with different reporting bias can perform worse. Body-composition estimates and physiological assumptions are shared between simulation and estimator; this does not validate their accuracy on real people. No estimator/target formulas, cap ordering or accuracy thresholds were changed. Native scenarios use separate local storage; the live account goals are preserved.
