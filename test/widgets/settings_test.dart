import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/foodEntryProvider.dart';
import 'package:macrotracker/providers/weight_unit_provider.dart';
import 'package:macrotracker/screens/WeightTrackingScreen.dart';
import 'package:macrotracker/screens/accountdashboard.dart';
import 'package:macrotracker/screens/delete_account_screen.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';

void main() {
  late FoodEntryProvider provider;

  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('nutrition_goals');
    await StorageService().delete('weight_history');
    await StorageService().delete('unit_system');
    provider = FoodEntryProvider();
    await provider.ensureInitialized();
  });

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
  }

  group('Units setting', () {
    testWidgets('picking Imperial, then Metric, updates the unit and subtitle',
        (tester) async {
      phone(tester);
      final units = WeightUnitProvider()..setMetric(true);
      await tester.pumpWidget(testApp(const AccountDashboard(),
          foodEntryProvider: provider, weightUnitProvider: units));
      await pumpFrames(tester, seconds: 1);

      await tester.scrollUntilVisible(find.text('Units'), 200,
          scrollable: find.byType(Scrollable).first);
      await pumpFrames(tester, seconds: 1);
      expect(find.text('Metric (kg, g, cm)'), findsOneWidget);

      await tester.tap(find.text('Units'));
      await pumpFrames(tester, seconds: 1);
      expect(find.text('Select Unit System'), findsOneWidget);
      await tester.tap(find.text('Imperial (lb, oz, ft)').last);
      await pumpFrames(tester, seconds: 1);

      expect(units.isMetric, isFalse);
      expect(StorageService().get('unit_system'), 'imperial');
      expect(find.text('Select Unit System'), findsNothing);
      expect(find.text('Imperial (lb, oz, ft)'), findsOneWidget);

      await tester.tap(find.text('Units'));
      await pumpFrames(tester, seconds: 1);
      await tester.tap(find.text('Metric (kg, g, cm)').last);
      await pumpFrames(tester, seconds: 1);
      expect(units.isMetric, isTrue);
      expect(find.text('Metric (kg, g, cm)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Cancel leaves the unit unchanged', (tester) async {
      phone(tester);
      final units = WeightUnitProvider()..setMetric(false);
      await tester.pumpWidget(testApp(const AccountDashboard(),
          foodEntryProvider: provider, weightUnitProvider: units));
      await pumpFrames(tester, seconds: 1);
      await tester.scrollUntilVisible(find.text('Units'), 200,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Units'));
      await pumpFrames(tester, seconds: 1);
      await tester.tap(find.text('Cancel').last);
      await pumpFrames(tester, seconds: 1);
      expect(units.isMetric, isFalse);
      expect(find.text('Imperial (lb, oz, ft)'), findsOneWidget);
    });
  });

  group('Weight target', () {
    Future<void> pumpWeight(WidgetTester tester) async {
      phone(tester);
      await tester.pumpWidget(testApp(const WeightTrackingScreen(),
          foodEntryProvider: provider,
          weightUnitProvider: WeightUnitProvider()..setMetric(true)));
      await pumpFrames(tester, seconds: 2);
    }

    /// The value shown under a progress label such as "Target".
    Finder valueUnder(String label) => find.descendant(
        of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
        matching: find.byType(Text));

    testWidgets('with no goal weight, the target is the current weight', (tester) async {
      provider
        ..currentWeightKg = 82.4
        ..goalWeightKg = 0;
      await pumpWeight(tester);

      final texts = tester.widgetList<Text>(valueUnder('Target')).map((t) => t.data);
      expect(texts, ['Target', '82.4 kg']);
      expect(find.text('0.0 kg'), findsNothing);
      expect(find.text('To Go'), findsNothing);
    });

    testWidgets('with a goal weight, shows it and how far to go', (tester) async {
      provider
        ..currentWeightKg = 82.4
        ..goalWeightKg = 75;
      await pumpWeight(tester);

      expect(tester.widgetList<Text>(valueUnder('Target')).map((t) => t.data),
          ['Target', '75.0 kg']);
      expect(tester.widgetList<Text>(valueUnder('To Go')).map((t) => t.data),
          ['To Go', '7.4 kg']);
    });
  });

  group('Delete account', () {
    testWidgets('email users must enter their password', (tester) async {
      phone(tester);
      await tester.pumpWidget(
          testApp(const DeleteAccountScreen(), foodEntryProvider: provider));
      await pumpFrames(tester, seconds: 1);

      final form = tester.state<FormState>(find.byType(Form));
      expect(form.validate(), isFalse);
      await tester.pump();
      expect(find.text('Please enter your password'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'hunter22');
      expect(form.validate(), isTrue);
      await tester.pump();
      expect(find.text('Please enter your password'), findsNothing);
    });
  });
}
