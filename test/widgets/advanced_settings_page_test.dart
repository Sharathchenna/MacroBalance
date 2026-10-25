import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/screens/onboarding/pages/advanced_settings_page.dart';
import 'package:macrotracker/services/macro_calculator_service.dart';

import '../helpers/test_app.dart';

void main() {
  setUp(setUpTestEnvironment);

  Widget page({
    bool showBodyFatInput = true,
    double? bodyFat,
    double? proteinRatio,
    ValueChanged<double>? onBodyFatChanged,
  }) =>
      testApp(Scaffold(
        body: AdvancedSettingsPage(
          showBodyFatInput: showBodyFatInput,
          bodyFatPercentage: bodyFat,
          proteinRatio: proteinRatio,
          defaultProteinRatio: 2.0,
          fatRatio: 0.25,
          gender: MacroCalculatorService.MALE,
          onShowBodyFatChanged: (_) {},
          onBodyFatChanged: onBodyFatChanged ?? (_) {},
          onProteinRatioChanged: (_) {},
          onFatRatioChanged: (_) {},
        ),
      ));

  testWidgets('body fat is not used until the user sets a reading', (tester) async {
    double? set;
    await tester.pumpWidget(page(onBodyFatChanged: (v) => set = v));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Set your %'), findsOneWidget);
    expect(find.textContaining('· recommended'), findsOneWidget);

    await tester.tap(find.text('From a scan'));
    await tester.pump();
    expect(find.text('Set your %'), findsOneWidget);
    expect(set, isNull);

    await tester.tap(find.byIcon(Icons.add_rounded).first);
    expect(set, 21);
  });

  testWidgets('a set reading is shown and used', (tester) async {
    await tester.pumpWidget(page(bodyFat: 18, proteinRatio: 2.2));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('18%'), findsOneWidget);
    expect(find.textContaining('2.2 g/kg'), findsOneWidget);
  });
}
