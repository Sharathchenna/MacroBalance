import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/targets.dart';
import 'package:macrotracker/services/energy/trend_weight.dart';

import '../test/unit/energy/simulated_user.dart';

/// Synthetic observations only. Every displayed estimate/target/check-in is
/// calculated by the production services after these observations are loaded.
class GoalScenarioData {
  GoalScenarioData(
      {required this.goal,
      required this.today,
      this.learning = false,
      this.reached = false}) {
    final days = learning ? 10 : 70;
    SimulatedUser? selected;
    for (var seed = 1; seed < 10000; seed++) {
      final user = SimulatedUser.generate(
          seed,
          SimConfig(
            days: days,
            goal: goal,
            tdeeMin: 2300,
            tdeeMax: 2700,
            weightNoiseSdKg: .25,
            untrackedRate: .06,
            partialRate: .03,
            underReporting: .04,
            intakeDayCv: .06,
            formulaErrorSd: 180,
            glycogenKg: .5,
          ));
      final initial = user.inputs.weights.first.weightKg;
      final body = user.inputs.body;
      final desiredPace = goal == GoalKind.lose ? .5 : .25;
      if (initial >= 70 &&
          initial <= 85 &&
          body.age! >= 25 &&
          body.age! <= 40 &&
          bmi(weightKg: initial, heightCm: body.heightCm!) < 28 &&
          (goal == GoalKind.maintain || user.pacePct == desiredPace)) {
        selected = user;
        break;
      }
    }
    if (selected == null) throw StateError('No deterministic scenario seed');
    seed = selected.seed;
    pacePct = selected.pacePct;
    final original = selected.inputs;
    final start = DateTime(today.year, today.month, today.day - days);
    DateTime shift(DateTime day) => DateTime(start.year, start.month,
        start.day + day.difference(original.learningStartedOn).inDays);
    inputs = EstimatorInputs(
        learningStartedOn: start,
        formulaTdee: original.formulaTdee,
        body: original.body,
        food: {for (final e in original.food.entries) shift(e.key): e.value},
        weights: [
          for (final w in original.weights)
            WeightReading(shift(w.day), w.weightKg)
        ],
        phaseStarts: original.phaseStarts.map(shift).toList());
    final initial = inputs.weights.first.weightKg;
    goalWeightKg = switch (goal) {
      GoalKind.maintain => initial,
      GoalKind.lose => initial - (reached ? 1 : 8),
      GoalKind.gain => initial + (reached ? .6 : 4),
    };
  }

  final GoalKind goal;
  final DateTime today;
  final bool learning;
  final bool reached;
  late final int seed;
  late final double pacePct;
  late final double goalWeightKg;
  late final EstimatorInputs inputs;
  String get label =>
      '${goal.name}${learning ? ' • learning' : ''}${reached ? ' • reached' : ''}';
}
