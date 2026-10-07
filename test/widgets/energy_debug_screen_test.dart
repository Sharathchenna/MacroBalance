import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/energy_provider.dart';
import 'package:macrotracker/screens/energy/energy_debug_screen.dart';
import 'package:macrotracker/services/energy/body_composition.dart';
import 'package:macrotracker/services/energy/energy_estimator.dart';
import 'package:macrotracker/services/energy/trend_weight.dart';
import 'package:macrotracker/services/energy_sync_service.dart';

import '../helpers/test_app.dart';

void main() {
  setUp(() async {
    await setUpTestEnvironment();
    await EnergySyncService().clearLocalState();
  });

  for (final dark in [true, false]) {
    testWidgets('shows the latest estimate, state, window and rows (dark: $dark)',
        (tester) async {
      final start = DateTime(2026, 9, 7);
      DateTime day(int n) => DateTime(2026, 9, 7 + n);
      final energy = EnergyProvider(
        clock: () => DateTime(2026, 10, 7, 9),
        inBackground: false,
        debounce: Duration.zero,
      )..inputs = () => EstimatorInputs(
            learningStartedOn: start,
            formulaTdee: 2500,
            body: const BodyProfile(sex: Sex.male, heightCm: 180, age: 30),
            food: {for (var d = 0; d < 30; d++) day(d): const FoodDay(loggedCals: 2200)},
            weights: [for (var d = 0; d < 30; d++) WeightReading(day(d), 80 - 0.05 * d)],
          );
      await tester.runAsync(energy.refresh);

      await tester.pumpWidget(
          testApp(const EnergyDebugScreen(), energyProvider: energy, dark: dark));
      await tester.pump();

      final latest = energy.latest!;
      expect(find.text('Estimate for Tue 6 Oct'), findsOneWidget);
      expect(find.text(latest.state.code), findsWidgets);
      expect(find.text('Learning started'), findsOneWidget);
      expect(find.textContaining('Mon 7 Sep'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Rows (30)'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('Rows (30)'), findsOneWidget);
      expect(find.text('10-06'), findsOneWidget);
    });
  }

  testWidgets('before any estimate', (tester) async {
    await tester.pumpWidget(testApp(const EnergyDebugScreen(),
        energyProvider: EnergyProvider(inBackground: false)));
    await tester.pump();
    expect(find.text('No estimates yet'), findsOneWidget);
    expect(find.text('Rows (0)'), findsOneWidget);
  });
}
