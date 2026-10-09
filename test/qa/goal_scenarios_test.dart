import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/checkin.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/targets.dart';
import '../../test_driver/goal_scenarios.dart';
import '../helpers/test_app.dart';

void main() {
  setUpAll(setUpTestEnvironment);
  for (final goal in GoalKind.values) {
    test('isolated ${goal.name} observations run real weekly pipeline',
        () async {
      final scenario = await QAGoalScenario.load(goal);
      addTearDown(scenario.dispose);
      expect(scenario.energy.latest!.state, isNot(EnergyState.learning));
      expect(scenario.energy.checkins.length, greaterThan(5));
      expect(scenario.energy.lastCheckin!.variant,
          isNot(CheckinVariant.goalReached));
      final first = scenario.data.inputs.weights.first.weightKg;
      final trend = scenario.energy.latest!.trendWeightKg!;
      if (goal == GoalKind.lose) expect(trend, lessThan(first));
      if (goal == GoalKind.gain) expect(trend, greaterThan(first));
      for (final checkin in scenario.energy.checkins) {
        final targets = checkin.newTargets;
        expect(
            (4 * targets.protein +
                    4 * targets.carbs +
                    9 * targets.fat -
                    targets.cals)
                .abs(),
            lessThanOrEqualTo(10));
      }
      expect(scenario.results['weight_stats'], isA<Map>());
    });
  }
  for (final goal in [GoalKind.lose, GoalKind.gain]) {
    test('real ${goal.name} trend crosses QA reached goal', () async {
      final scenario = await QAGoalScenario.load(goal, reached: true);
      addTearDown(scenario.dispose);
      expect(scenario.energy.lastCheckin!.variant, CheckinVariant.goalReached);
    });
  }
  test('ten observed days stays learning with real insufficient check-in',
      () async {
    final scenario =
        await QAGoalScenario.load(GoalKind.maintain, learning: true);
    addTearDown(scenario.dispose);
    expect(scenario.energy.latest!.state, EnergyState.learning);
    expect(scenario.energy.lastCheckin!.variant, CheckinVariant.insufficient);
  });
}
