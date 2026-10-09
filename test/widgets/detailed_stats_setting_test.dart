import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/detailed_stats_provider.dart';
import 'package:macrotracker/providers/goals_provider.dart';
import 'package:macrotracker/screens/accountdashboard.dart';
import 'package:macrotracker/services/storage_service.dart';

import '../helpers/test_app.dart';
import '../helpers/simple_copy_audit.dart';

void main() {
  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete(DetailedStatsProvider.storageKey);
  });
  tearDown(() => StorageService().delete(DetailedStatsProvider.storageKey));

  group('DetailedStatsProvider', () {
    test('is off by default', () {
      expect(DetailedStatsProvider().showDetailedStats, isFalse);
    });

    test('persists on the device and notifies once per change', () {
      final detail = DetailedStatsProvider();
      var notified = 0;
      detail.addListener(() => notified++);

      detail.showDetailedStats = true;
      detail.showDetailedStats = true;
      expect(notified, 1);
      expect(StorageService().get(DetailedStatsProvider.storageKey), isTrue);
      expect(DetailedStatsProvider().showDetailedStats, isTrue);

      detail.showDetailedStats = false;
      expect(notified, 2);
      expect(DetailedStatsProvider().showDetailedStats, isFalse);
    });
  });

  testWidgets('Settings: "Show detailed stats" switch turns it on and off',
      (tester) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final detail = DetailedStatsProvider();
    await tester.pumpWidget(testApp(const AccountDashboard(),
        goalsProvider: GoalsProvider(), detailedStatsProvider: detail));
    await pumpFrames(tester, seconds: 1);

    final recalculate = find.text('Recalculate Goals');
    await tester.scrollUntilVisible(recalculate, 200,
        scrollable: find.byType(Scrollable).first);
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Update your weight, activity and goal'), findsOneWidget);
    expect(find.text('Answer the body and goal questions again'), findsNothing);
    expectSimpleCopy(tester);

    final title = find.text('Show detailed stats');
    await tester.scrollUntilVisible(title, 200,
        scrollable: find.byType(Scrollable).first);
    await pumpFrames(tester, seconds: 1);
    expect(
        find.text('Extra numbers for the curious: ranges, confidence and how '
            'we calculate'),
        findsOneWidget);
    final toggle = find.descendant(
        of: find.ancestor(of: title, matching: find.byType(ListTile)),
        matching: find.byType(CupertinoSwitch));
    expect(tester.widget<CupertinoSwitch>(toggle).value, isFalse);

    await tester.tap(toggle);
    await pumpFrames(tester, seconds: 1);
    expect(detail.showDetailedStats, isTrue);
    expect(tester.widget<CupertinoSwitch>(toggle).value, isTrue);
    expect(StorageService().get(DetailedStatsProvider.storageKey), isTrue);

    await tester.tap(toggle);
    await pumpFrames(tester, seconds: 1);
    expect(detail.showDetailedStats, isFalse);
    expect(tester.takeException(), isNull);
  });
}
