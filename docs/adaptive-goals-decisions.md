# Adaptive goals: implementation decisions

Updated 2026-10-09. The [spec](adaptive-goals-spec.md) and [research plan](adaptive-goals-plan.md) describe the intended system; this document records implementation choices, the accepted interface direction and outstanding gaps.

## Interface decisions

- Progress opens on Weight. Tab order is Weight, Nutrition, Steps, Workouts, Energy.
- **Show detailed stats** is off by default and persisted on the device, matching theme/unit preferences. Enabling it restores detailed charts, confidence, ranges and calculation breakdowns.
- Simple mode prioritizes one useful number and a plain sentence per card. Explanations belong behind **Why?** or **How it works**. Pace choices use familiar labels and approximate weight changes/dates; extra plan settings stay under **More options**.
- Maintaining shows weight stability rather than an obsolete loss/gain goal. Losing and gaining show progress in the chosen direction. Goal celebrations require the trend to cross the goal, consistent with the check-in decision.
- The adaptive setup uses a compact weekly illustration, a bordered switch card and copy that responds to the switch. It scrolls on narrow phones and with larger text; light and dark themes are supported.
- The user approved the redesigned direction on 2026-10-09 and requested a PR. No separate Pencil design artifact was produced.

## Calculation and persistence decisions

- `GoalsProvider` owns goal settings and targets; food entries remain with `FoodEntryProvider`. Shared pure Dart energy services are the source for calculations and projections.
- Trend weight is time-aware and ignores isolated outliers. After a confirmed level shift, later readings are judged against the new level. Phase switches widen the outlier band to 6% for ten days.
- Morning weight on day d reflects intake through d−1. Estimator replay is causal and resumed replay matches full replay. Overlapping-observation inflation is 12 rather than the original spec's tunable value of 7.
- Recalculation uses trend weight and sufficiently confident learned expenditure when available. Static profile facts are prefilled. Age advances from the recorded date.
- Weekly updates follow the adaptive flag. Fixed plans change targets at phase boundaries; goal-reached choices also remain available. Initial learning waits a week before its first scheduled check-in.
- Check-in persistence uses per-account records, a pending upload queue and a durable local apply queue. Applying targets locally is separate from guarded, targets-only cloud writes. A week decided without a check-in row is not reconsidered midway through that week.
- New check-in snapshots preserve the exact selected goal weight. Historical snapshots already rounded to a tenth of a kilogram retain their recorded values.
- Every plan has phases, including steady plans. Phase-transition check-ins apply targets automatically; their secondary action can undo the transition. Explicit early phase endings use `goal_phases.end_requested_on`.
- Adaptive goal-date projections replan future safe weekly targets rather than replaying the exact current step-capped target. Expenditure falls as weight falls; the spec's sign ambiguity is resolved in that direction. Fixed or floor-blocked targets that cannot move toward a goal have no completion date.
- Finish-day reminders are off by default. Separate reminder times are stored locally; when merged with meal reminders, the meal reminder's time applies. Logout/delete-account cancels local reminders.

## Verification and remaining gaps

The final implementation run passed **1,115 tests with one existing skipped estimator accuracy acceptance test**. Touched-file analysis added no issues; four existing informational lints remained in `WeightTrackingScreen.dart`. Native iOS builds and isolated maintaining/losing/gaining journeys were checked in both themes, including recalculation, saving, learning and reached-goal states. Narrow-screen and doubled-text widget checks passed.

Native QA runs through the actual estimator, provider, check-in and calculator using a debug-only entrypoint, separate local storage, synthetic histories and offline transports. It preserves the signed-in account's goals. It does not verify authenticated cloud synchronization or real-world physiological accuracy. Recordings are attached to the PR, rather than stored as repository assets.

The [algorithm verification report](adaptive-goals-verification.md) records the unresolved four-week accuracy requirement and the conflict between gradual weekly changes and the latest absolute target bounds. No replacement acceptance criterion has been approved. The latest audit changed neither estimator/target formulas nor safety priority ordering.

Other outstanding follow-ups:

- Meal-reminder code writes/requires `user_notification_preferences.enabled`, which the linked schema lacks. Saving/sending meal reminders and the finish-day merge depend on fixing this mismatch. Server reminder scheduling also compares against UTC, and `NotificationService` does not initialize `tz.local`.
- Multi-device/account staleness remains around unscoped `nutrition_goals`/`energy_estimates`, plan-style/adaptive flag overwrites and the absence of live goal pulls.
- Changing a goal type outside recalculation should replan phases. Phase settings need Settings controls; non-adaptive phased plans need access to the check-in-day choice.
- Phased projections can add a whole maintenance break for a small remaining loss. Nutrition trends' legacy maintenance estimate should be reconciled with the new estimator.
- The original phase-switch simulation does not keep every user's movement below 75 cals: approximately 99.5–100% meet the bar, with worst cases of 81–90 cals.

## Schema and deployment record

Eight migrations cover goal/profile settings, automatic ageing, food-day status, estimates, adaptive goals, check-ins, phases and reminders. The original build recorded all as applied to the linked development project via SQL because the remote migration history prevented `db push`. It also recorded deployment of `send-notifications`. PR creation and cleanup perform no new deployment.

The goal-settings migration replaces legacy profile columns and changes activity level to a 1–5 integer. The spec assumes no live users; older clients require compatibility handling if that assumption changes.

## Temporary verification files

`.scratch/` is ignored and excluded from this PR's commit history. Review captures are temporary: upload selected evidence to the PR, record durable decisions/results in docs, and delete local captures after review. Keep regression tests and the reusable QA harness in source control.
