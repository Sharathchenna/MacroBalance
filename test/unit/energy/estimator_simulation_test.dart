import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/constants.dart';

import 'simulated_user.dart';

/// Spec §10 phase 1: the estimator against 200 synthetic users (see
/// simulated_user.dart for the scenario and what "logged-basis TDEE" means).
void main() {
  late SimReport report;
  late Duration elapsed;

  setUpAll(() {
    final sw = Stopwatch()..start();
    report = SimReport.run();
    elapsed = sw.elapsed;
  });

  test('runs 200 seeds well within the CI budget', () {
    expect(report.seeds, 200);
    expect(elapsed, lessThan(const Duration(seconds: 30)), reason: '$report');
  });

  test('calibration: the truth is within ±1.28 sd on 75–85% of seed-days', () {
    expect(report.calibration, inInclusiveRange(0.75, 0.85), reason: '$report');
  });

  test('no day-to-day change is over kMaxDailyTdeeStep', () {
    expect(report.maxStep, lessThanOrEqualTo(kMaxDailyTdeeStep + 1e-9),
        reason: '$report');
  });

  test('day 28: no worse than measured when kOverlapInflation was tuned', () {
    // Measured at 16: 59.5% within 150, 78.5% within 250 (seeds 0–199).
    expect(report.within(150), greaterThanOrEqualTo(0.55), reason: '$report');
    expect(report.within(250), greaterThanOrEqualTo(0.75), reason: '$report');
  });

  test('day 28: within 150 of the logged-basis TDEE for ≥ 90% of seeds', () {
    expect(report.within(150), greaterThanOrEqualTo(0.90), reason: '$report');
  },
      skip: 'Spec bar, unreachable at 0.7 kg daily scale noise: even the '
          'noise-only oracle below reaches about 82%. See ticket 07 Outcome.');

  test('the spec bar is beyond any estimator at 0.7 kg scale noise', () {
    // With perfect logs and nothing but scale noise, the best possible
    // day-28 estimate still misses 150 cals for more than 10% of users.
    expect(noiseOnlyOracleWithin(150), lessThan(0.90));
  });
}
