/// Spec §10 phase 3b (ticket 18): a +1 kg water and glycogen rebound at a
/// phase switch moves the estimate by less than 75 cals.
///
/// Every seed is replayed twice, with and without the rebound, on the same
/// draws: the difference between the two estimates is what the water did.
/// A seed's "move" is the largest difference on any day.
///
/// Measured at ticket 18 (tuning / held-out):
/// - lose → maintain on day 42: mean 12 / 11, p95 28 / 22, under 75 for
///   99.5% / 99.9% of seeds (worst 81 / 83).
/// - lose → maintain on day 56: mean 8 / 8, p95 14 / 15, all under 75.
/// - lose → break (+1 kg) on day 42 → lose (−1 kg) on day 70: mean 15 / 14,
///   p95 46 / 34, under 75 for 99.5% / 100% (worst 90 / 75).
/// - The estimator not told about the switch: mean ~148, ~0% under 75.
/// The few seeds over 75 are the outlier rule's 3% line: a reading just
/// either side of it changes which weigh-ins a short post-switch window fits.
///
/// About a minute: 5,600 replays.
@Timeout(Duration(minutes: 5))
library;

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/services/energy/targets.dart';

import 'simulated_user.dart';

void main() {
  /// A loss phase, then maintenance from [day] with [rebound] kg of water.
  List<SimSwitch> toMaintain(int day, double rebound) =>
      [SimSwitch(day, GoalKind.maintain, reboundKg: rebound)];

  /// Phased: a break from day 42 (+[rebound]), losing again from day 70.
  List<SimSwitch> phased(double rebound) => [
        SimSwitch(42, GoalKind.maintain, reboundKg: rebound),
        SimSwitch(70, GoalKind.lose, reboundKg: -rebound),
      ];

  late Map<String, _Moves> results;

  setUpAll(() {
    results = {
      'day 42': _Moves.run(84, (r) => toMaintain(42, r)),
      'day 42 held out': _Moves.run(84, (r) => toMaintain(42, r),
          firstSeed: kHeldOutFirstSeed, seeds: kHeldOutSeeds),
      'day 56': _Moves.run(84, (r) => toMaintain(56, r)),
      'phased': _Moves.run(112, phased),
      'phased held out': _Moves.run(112, phased,
          firstSeed: kHeldOutFirstSeed, seeds: kHeldOutSeeds),
      'unaware': _Moves.run(84, (r) => toMaintain(42, r), knowsPhaseStarts: false),
    };
  });

  test('a +1 kg rebound moves the estimate by less than 75 cals', () {
    for (final name in ['day 42', 'day 42 held out', 'day 56', 'phased', 'phased held out']) {
      final m = results[name]!;
      expect(m.mean, lessThan(20), reason: '$name: $m');
      expect(m.quantile(0.95), lessThan(50), reason: '$name: $m');
      expect(m.under(75), greaterThanOrEqualTo(0.99), reason: '$name: $m');
    }
    expect(results['day 56']!.under(75), 1.0, reason: '${results['day 56']}');
  });

  test('without the phase start the rebound would move it by ~150', () {
    final m = results['unaware']!;
    expect(m.quantile(0.5), greaterThan(100), reason: '$m');
    expect(m.under(75), lessThan(0.05), reason: '$m');
  });

  test('calibration holds through a switch: truth within ±1.28 sd on '
      '75–85% of seed-days', () {
    for (final e in results.entries) {
      if (e.key == 'unaware') continue;
      expect(e.value.calibration, inInclusiveRange(0.75, 0.85),
          reason: '${e.key}: ${e.value}');
    }
  });
}

class _Moves {
  _Moves(this.moves, this.calibration);

  /// Every seed is a lose user who switches on [switches]'s days.
  factory _Moves.run(
    int days,
    List<SimSwitch> Function(double rebound) switches, {
    int firstSeed = 0,
    int seeds = kTuningSeeds,
    bool knowsPhaseStarts = true,
  }) {
    SimConfig config(double rebound) => SimConfig(
          days: days,
          goal: GoalKind.lose,
          switches: switches(rebound),
          knowsPhaseStarts: knowsPhaseStarts,
        );
    final moves = <double>[];
    var inBand = 0, seedDays = 0;
    for (var seed = firstSeed; seed < firstSeed + seeds; seed++) {
      final user = SimulatedUser.generate(seed, config(1));
      final withWater = user.estimate();
      final without = SimulatedUser.generate(seed, config(0)).estimate();
      var move = 0.0;
      for (var d = 0; d < withWater.length; d++) {
        final r = withWater[d];
        move = math.max(move, (r.tdee - without[d].tdee).abs());
        if ((r.tdee - user.loggedBasisTdee[d]).abs() <= 1.28 * r.tdeeSd) inBand++;
        seedDays++;
      }
      moves.add(move);
    }
    return _Moves(moves..sort(), inBand / seedDays);
  }

  /// Each seed's largest move, ascending.
  final List<double> moves;
  final double calibration;

  double get mean => moves.reduce((a, b) => a + b) / moves.length;
  double quantile(double p) => moves[((moves.length - 1) * p).round()];
  double under(double cals) => moves.where((m) => m < cals).length / moves.length;

  @override
  String toString() => '${moves.length} seeds · mean ${mean.round()} · '
      'median ${quantile(0.5).round()} · p95 ${quantile(0.95).round()} · '
      'max ${moves.last.round()} · under 75 '
      '${(under(75) * 100).toStringAsFixed(1)}% · calibration '
      '${(calibration * 100).toStringAsFixed(1)}%';
}
