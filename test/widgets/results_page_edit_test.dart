import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:macrotracker/AI/gemini.dart';
import 'package:macrotracker/camera/results_page.dart';
import 'package:macrotracker/models/ai_food_item.dart';

import '../helpers/test_app.dart';

AIFoodItem food(String name, double calories) => AIFoodItem(
      name: name,
      servingSizes: ['1 cup'],
      calories: [calories],
      protein: [10],
      carbohydrates: [20],
      fat: [8],
      fiber: [2],
    );

// A 1x1 transparent PNG.
final photo = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

class _Revision {
  _Revision(this.foods, this.note, this.focusFood);
  final List<AIFoodItem> foods;
  final String note;
  final String? focusFood;
  final result = Completer<List<AIFoodItem>>();
}

void main() {
  late List<_Revision> revisions;

  setUp(() async {
    await setUpTestEnvironment();
    revisions = [];
  });

  Future<void> pumpPage(WidgetTester tester, {Uint8List? withPhoto, String? note}) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(testApp(ResultsPage(
      foods: [food('Butter chicken', 490), food('Tofu stir-fry', 260)],
      meal: 'Lunch',
      photo: withPhoto,
      note: note,
      reviser: (photo, foods, note, {focusFood}) {
        final revision = _Revision(foods, note, focusFood);
        revisions.add(revision);
        return revision.result.future;
      },
    )));
    await pumpFrames(tester, seconds: 1);
  }

  testWidgets('without the photo there is nothing to edit', (tester) async {
    await pumpPage(tester);
    expect(find.text('Edit'), findsNothing);
  });

  testWidgets('shows the photo and the note from the camera', (tester) async {
    await pumpPage(tester, withPhoto: photo, note: 'Two rotis');
    expect(find.text('Lunch · 2 foods'), findsOneWidget);
    expect(find.text('“Two rotis”'), findsOneWidget);
  });

  testWidgets('a correction about one food replaces the list; Undo brings it back',
      (tester) async {
    await pumpPage(tester, withPhoto: photo);
    await tester.tap(find.text('Edit'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Done'), findsOneWidget);

    // In edit mode a card selects the food instead of opening it.
    await tester.tap(find.text('Tofu stir-fry'));
    await tester.pump();
    expect(find.text('About: Tofu stir-fry'), findsOneWidget);

    await tester.enterText(find.byType(TextField), "It's paneer, cooked in ghee");
    await tester.tap(find.byTooltip('Update foods'));
    await tester.pump();

    final revision = revisions.single;
    expect(revision.note, "It's paneer, cooked in ghee");
    expect(revision.focusFood, 'Tofu stir-fry');
    expect(revision.foods.map((f) => f.name), ['Butter chicken', 'Tofu stir-fry']);

    revision.result.complete([food('Butter chicken', 490), food('Paneer stir-fry', 410)]);
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Paneer stir-fry'), findsOneWidget);
    expect(find.text('Tofu stir-fry'), findsNothing);
    expect(find.text('About: Tofu stir-fry'), findsNothing);

    await tester.tap(find.byTooltip('Undo last change'));
    await pumpFrames(tester, seconds: 1);
    expect(find.text('Tofu stir-fry'), findsOneWidget);
    expect(find.text('Paneer stir-fry'), findsNothing);
    expect(find.byTooltip('Undo last change'), findsNothing);
    await pumpFrames(tester, seconds: 3);
  });

  testWidgets('with no food selected the correction is about the whole meal',
      (tester) async {
    await pumpPage(tester, withPhoto: photo);
    await tester.tap(find.text('Edit'));
    await pumpFrames(tester, seconds: 1);

    await tester.enterText(find.byType(TextField), "There's also raita");
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(revisions.single.focusFood, isNull);

    revisions.single.result.completeError(
        PhotoAnalysisException(PhotoAnalysisFailure.noConnection));
    await pumpFrames(tester, seconds: 1);
    // The list and the typed correction stay, so it can be sent again.
    expect(find.text('Butter chicken'), findsOneWidget);
    expect(find.text("There's also raita"), findsOneWidget);
    await pumpFrames(tester, seconds: 3);
  });
}
