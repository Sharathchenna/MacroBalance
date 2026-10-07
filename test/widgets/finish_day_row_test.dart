import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/dateProvider.dart';
import 'package:macrotracker/providers/day_status_provider.dart';
import 'package:macrotracker/screens/dashboard/components/finish_day_row.dart';
import 'package:macrotracker/services/day_status_sync_service.dart';
import 'package:macrotracker/services/energy/day_status.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:provider/provider.dart';

import '../helpers/test_app.dart';

void main() {
  setUp(() async {
    await setUpTestEnvironment();
    await StorageService().delete('food_day_status');
    await StorageService().delete('pending_day_status');
  });

  Future<DayStatusProvider> pump(WidgetTester tester) async {
    final status = DayStatusProvider();
    await tester.pumpWidget(testApp(
      ChangeNotifierProvider<DayStatusProvider>.value(
        value: status,
        child: const Scaffold(body: FinishDayRow()),
      ),
    ));
    return status;
  }

  testWidgets('tapping Finish day marks the day finished and survives a reload',
      (tester) async {
    final status = await pump(tester);
    expect(find.textContaining('Finish day', findRichText: true), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.byType(InkWell));
    });
    await tester.pump();

    final today = DateProvider().selectedDate;
    expect(status.statusFor(today), ExplicitDayStatus.complete);
    expect(find.text('Day finished'), findsOneWidget);
    // The cache has it for the next launch.
    expect(DayStatusProvider().isFinished(today), isTrue);
  });

  testWidgets('the menu can mark a day fasted or clear it', (tester) async {
    final status = await pump(tester);
    final today = DateProvider().selectedDate;
    await tester.runAsync(() => status.setStatus(today, ExplicitDayStatus.complete));
    await tester.pump();

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    expect(find.text('Not finished'), findsOneWidget);
    expect(find.text('Fasted (ate nothing)'), findsOneWidget);
    expect(find.text("Didn't log everything"), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Fasted (ate nothing)'));
    });
    await tester.pumpAndSettle();
    expect(status.statusFor(today), ExplicitDayStatus.fasting);

    await tester.tap(find.byType(InkWell));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('Not finished'));
    });
    await tester.pumpAndSettle();
    expect(status.isFinished(today), isFalse);
    expect(find.textContaining('Finish day', findRichText: true), findsOneWidget);
  });

  group('cloud merge', () {
    test('cloud rows replace the cache; pending changes win', () {
      final merged = DayStatusSyncService.mergeCloud([
        {'day': '2026-10-01', 'status': 'complete'},
        {'day': '2026-10-02', 'status': 'partial'},
      ], pending: {
        '2026-10-02': 'fasting',
        '2026-10-01': '',
        '2026-10-03': 'complete',
      });
      expect(merged, {'2026-10-02': 'fasting', '2026-10-03': 'complete'});
    });
  });
}
