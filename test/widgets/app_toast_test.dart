import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/widgets/app_toast.dart';

void main() {
  Future<BuildContext> pumpApp(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        context = c;
        return const Scaffold();
      }),
    ));
    return context;
  }

  testWidgets('a toast shows near the top and leaves on its own', (tester) async {
    final context = await pumpApp(tester);
    AppToast.show('Added Oats to Breakfast', context: context);
    await tester.pumpAndSettle();

    final toast = find.text('Added Oats to Breakfast');
    expect(toast, findsOneWidget);
    expect(tester.getRect(toast).top, lessThan(tester.view.physicalSize.height /
        tester.view.devicePixelRatio / 4));

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(toast, findsNothing);
  });

  testWidgets('Undo runs and hides the toast', (tester) async {
    final context = await pumpApp(tester);
    var undone = false;
    AppToast.show('Removed Eggs',
        context: context, actionLabel: 'Undo', onAction: () => undone = true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(undone, isTrue);
    expect(find.text('Removed Eggs'), findsNothing);
  });

  testWidgets('swiping up dismisses it early', (tester) async {
    final context = await pumpApp(tester);
    AppToast.show('Added Toast to Lunch', context: context);
    await tester.pumpAndSettle();

    await tester.fling(find.text('Added Toast to Lunch'), const Offset(0, -100), 800);
    await tester.pumpAndSettle();
    expect(find.text('Added Toast to Lunch'), findsNothing);
  });

  testWidgets('a newer toast replaces the current one', (tester) async {
    final context = await pumpApp(tester);
    AppToast.show('First', context: context);
    await tester.pumpAndSettle();
    AppToast.show('Second', context: context);
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });
}
