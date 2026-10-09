// ignore_for_file: avoid_print

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/targets.dart';

import 'simulated_user.dart';

/// These held-out scenarios diagnose the existing accuracy gap. They never
/// retune the model or replace the original day-28/150-cal/90% spec test.
void main() {
  for (final goal in GoalKind.values) {
    test('${goal.name}: isolate logging-basis bias from noisy data and prior',
        () {
      final scenarios = <String, SimConfig>{
        'baseline': SimConfig(goal: goal),
        'no_scale_noise': SimConfig(goal: goal, weightNoiseSdKg: 0),
        'no_underreporting': SimConfig(goal: goal, underReporting: 0),
        'no_water': SimConfig(goal: goal, glycogenKg: 0),
        'no_prior_error': SimConfig(goal: goal, formulaErrorSd: 0),
        'no_adaptation': SimConfig(goal: goal, adaptationPerKg: 0),
        'isolated_reporting': SimConfig(
            goal: goal,
            weightNoiseSdKg: 0,
            glycogenKg: 0,
            formulaErrorSd: 0,
            adaptationPerKg: 0,
            intakeDayCv: 0,
            untrackedRate: 0,
            partialRate: 0),
      };
      final results = <String, Map<String, double>>{};
      for (final entry in scenarios.entries) {
        final report =
            SimReport.run(firstSeed: 10000, seeds: 200, config: entry.value);
        results[entry.key] = {
          'day28_bias': report.meanError(goal),
          'day28_mean_abs':
              report.absErrorsOn(28).reduce((a, b) => a + b) / 200,
          'day28_within150_pct': report.within(150) * 100,
          'calibration_pct': report.calibration * 100,
        };
      }
      final corrected = SimReport.run(
          firstSeed: 10000,
          seeds: 200,
          config: scenarios['isolated_reporting']!,
          knownReporting: true);
      results['isolated_known_reporting_comparator'] = {
        'day28_bias': corrected.meanError(goal),
        'day28_mean_abs':
            corrected.absErrorsOn(28).reduce((a, b) => a + b) / 200,
      };
      final baselineCorrected = SimReport.run(
          firstSeed: 10000,
          seeds: 200,
          config: scenarios['baseline']!,
          knownReporting: true);
      results['baseline_known_reporting_comparator'] = {
        'day28_bias': baselineCorrected.meanError(goal),
        'day28_within150_pct': baselineCorrected.within(150) * 100,
      };
      final isolated = results['isolated_reporting']!['day28_bias']!;
      if (goal == GoalKind.lose) expect(isolated, greaterThan(15));
      if (goal == GoalKind.gain) expect(isolated, lessThan(-10));
      if (goal == GoalKind.maintain) expect(isolated.abs(), lessThan(1));
      // Removing the reporting-basis mismatch leaves only body-density/OLS
      // and EMA lag. The comparator knows a factor production cannot know.
      expect(corrected.meanError(goal).abs(), lessThan(10));
      print('GOAL_BIAS ${jsonEncode({
            'goal': goal.name,
            'seeds': 200,
            'scenarios': results
          })}');
    });
  }
}
