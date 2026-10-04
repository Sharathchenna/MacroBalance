import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/theme/app_theme.dart';

void main() {
  testWidgets('Undo snackbar shows above the nav bar and Undo fires', (tester) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    var undone = false;
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: messengerKey,
      theme: AppTheme.darkTheme,
      home: Scaffold(
        extendBody: true,
        body: Stack(children: [
          const Positioned.fill(child: SizedBox()),
          Positioned(
            bottom: 30, left: 70, right: 70,
            child: Container(key: const Key('nav'), height: 56, color: Colors.black),
          ),
        ]),
      ),
    ));
    messengerKey.currentState!.showSnackBar(SnackBar(
      content: const Text('Removed Toast'),
      action: SnackBarAction(label: 'Undo', onPressed: () => undone = true),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Removed Toast'), findsOneWidget);
    final snackBottom = tester.getRect(find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first).bottom;
    final navTop = tester.getRect(find.byKey(const Key('nav'))).top;
    expect(snackBottom, lessThanOrEqualTo(navTop));
    await tester.tap(find.text('Undo'));
    expect(undone, isTrue);
  });
}
