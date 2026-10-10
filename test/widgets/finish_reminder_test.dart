import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/providers/day_status_provider.dart';
import 'package:macrotracker/providers/finish_reminder_provider.dart';
import 'package:macrotracker/services/energy/day_status.dart';
import 'package:macrotracker/services/energy/finish_reminder.dart';
import 'package:macrotracker/services/finish_day_link.dart';
import 'package:macrotracker/services/storage_service.dart';
import 'package:macrotracker/widgets/finish_reminder_button.dart';

import '../helpers/test_app.dart';

/// A provider whose meal-reminder preference and cloud flag are fakes.
class _Reminder extends FinishReminderProvider {
  _Reminder(NoFinishReminders notifier, {this.meals = false, DateTime? now})
      : super(userId: 'u1', notifier: notifier, clock: () => now ?? DateTime(2026, 10, 9, 10));

  bool meals;
  final List<bool> flags = [];

  @override
  Future<bool> fetchMealReminders() async => meals;

  @override
  Future<void> writeFlag(bool on) async => flags.add(on);
}

void main() {
  late NoFinishReminders device;
  final events = <MethodCall>[];

  List<Map> capturedEvents(String name) => [
        for (final c in events)
          if ((c.arguments as Map)['eventName'] == name)
            Map.of((c.arguments as Map)['properties'] as Map),
      ];

  setUpAll(setUpTestEnvironment);
  setUp(() async {
    device = NoFinishReminders();
    events.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('posthog_flutter'), (call) async {
      if (call.method == 'capture') events.add(call);
      return null;
    });
    await StorageService().delete('finish_reminder:u1');
  });

  Future<void> pump(WidgetTester tester, FinishReminderProvider p) async {
    await tester.pumpWidget(testApp(
      const Scaffold(body: Center(child: FinishReminderButton(source: FinishReminderSource.checkin))),
      finishReminderProvider: p,
    ));
  }

  test('never on by default and nothing is scheduled', () async {
    final p = _Reminder(device);
    await p.refresh();
    expect(p.enabled, isFalse);
    expect(p.mode, FinishReminderMode.off);
    expect(device.pending, isEmpty);
  });

  testWidgets('tapping the button turns it on, schedules 21:00 and tracks the source', (tester) async {
    device.permitted = true;
    final p = _Reminder(device);
    await pump(tester, p);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('finish_reminder_button')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(p.enabled, isTrue);
    expect(device.pending.first, DateTime(2026, 10, 9, 21));
    expect(device.pending, hasLength(14));
    expect(find.text('Reminder set for 9:00 PM'), findsOneWidget);
    expect(p.flags, [true]);
    expect(
        capturedEvents('finish_reminder_enabled'),
        contains(predicate<Map>((m) => m['source'] == 'checkin')));
  });

  testWidgets('without notification permission it stays off and says where to allow it', (tester) async {
    device.permitted = false;
    final p = _Reminder(device);
    await pump(tester, p);
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('finish_reminder_button')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(p.enabled, isFalse);
    expect(device.pending, isEmpty);
    expect(find.byKey(const Key('finish_reminder_blocked')), findsOneWidget);
  });

  test('with meal reminders on it joins them: no separate notification', () async {
    device.permitted = true;
    final p = _Reminder(device, meals: true);
    expect(await p.enable(FinishReminderSource.settings), isTrue);
    expect(p.mode, FinishReminderMode.mergedIntoMeal);
    expect(device.pending, isEmpty);
    expect(p.flags, [true]);
    // Meal reminders off again: its own push comes back.
    p.meals = false;
    await p.refresh();
    expect(p.mode, FinishReminderMode.separate);
    expect(device.pending, hasLength(14));
  });

  test('time change reschedules; finishing today drops tonight', () async {
    device.permitted = true;
    final status = DayStatusProvider();
    final p = _Reminder(device)..attach(status);
    await p.enable(FinishReminderSource.dataQualityTip);
    await p.setMinutes(20 * 60 + 30);
    expect(device.pending.first, DateTime(2026, 10, 9, 20, 30));
    await status.setStatus(DateTime(2026, 10, 9), ExplicitDayStatus.complete);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(device.pending.first, DateTime(2026, 10, 10, 20, 30));
  });

  test('the choice survives a restart; disabling cancels and clears the flag', () async {
    device.permitted = true;
    final p = _Reminder(device);
    await p.enable(FinishReminderSource.settings);
    await p.setMinutes(22 * 60);
    final again = _Reminder(device);
    expect(again.enabled, isTrue);
    expect(again.minutes, 22 * 60);
    await again.disable();
    expect(device.pending, isEmpty);
    expect(again.flags.last, isFalse);
    expect(_Reminder(device).enabled, isFalse);
  });

  test('logout cancels the notifications', () async {
    device.permitted = true;
    final p = _Reminder(device);
    await p.enable(FinishReminderSource.settings);
    await p.clearUserData();
    expect(device.pending, isEmpty);
    expect(_Reminder(device).enabled, isFalse);
  });

  test('a tap on the reminder waits as a request until the shell takes it', () {
    FinishDayLink.take();
    FinishDayLink.request();
    expect(FinishDayLink.pending, isTrue);
    expect(FinishDayLink.take(), isTrue);
    expect(FinishDayLink.take(), isFalse);
  });
}
