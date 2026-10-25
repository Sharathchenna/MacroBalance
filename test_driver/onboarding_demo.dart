// Debug-only: runs the real app and plays the new-user onboarding on its own,
// at a watchable pace, for screen recordings. Run with:
//   flutter run -t test_driver/onboarding_demo.dart \
//     --dart-define=DEMO_EMAIL=<name>@mbtest.ai --dart-define=DEMO_PASSWORD=<pw>
// Start from a fresh install (signed out). Taps are synthetic pointer events
// found by on-screen text, as in qa_remote.dart.
import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:macrotracker/main.dart' as app;

const _email = String.fromEnvironment('DEMO_EMAIL');
const _password = String.fromEnvironment('DEMO_PASSWORD');

Future<void> main() async {
  await app.main();
  unawaited(_Demo().run());
}

class _Demo {
  int _pointer = 5000;

  Future<void> wait(double seconds) =>
      Future<void>.delayed(Duration(milliseconds: (seconds * 1000).round()));

  // Epoch seconds, so the recording can be trimmed to the run.
  void log(String s) =>
      debugPrint('[demo] ${DateTime.now().millisecondsSinceEpoch / 1000} $s');

  Future<void> run() async {
    await waitFor('Build my plan', timeout: 900);
    await wait(5);
    await tap('Build my plan');
    await wait(8); // story 1 plays and moves on by itself
    await wait(4);
    await tap('Build my plan'); // story 2's button
    await wait(2);

    await tap('Lose fat');
    await wait(1.5);
    await tap('Continue');

    await wait(2);
    await drag('years', dx: -112, dy: 40); // age strip, two years up
    await wait(1.5);
    await tap('Continue');

    await wait(2);
    await drag('Swipe the ruler', dx: -150, dy: -65); // weight ruler
    await wait(1.5);
    await tap('Continue');

    await wait(1.5);
    await tap('Lightly active');
    await wait(1.5);
    await tap('Continue');

    await wait(3.5); // goal weight glides to the suggestion
    await tap('Continue');

    await wait(2);
    await tap('Faster');
    await wait(3); // the eased-pace note
    await tap('Steady');
    await wait(1.5);
    await tap('Continue');

    await wait(1.5);
    await tap('I hit a plateau');
    await wait(0.8);
    await tap('Weekends undo my week');
    await wait(1.5);
    await tap('Continue');

    await wait(5);
    await tap('Continue');
    await wait(4);
    await tap('Continue');

    await wait(4);
    await tap('Not now'); // Apple Health
    await wait(4);
    await tap('Not now'); // reminders

    await waitFor('Save my plan', timeout: 30);
    await wait(6);
    await scroll(400);
    await wait(2.5);
    await tap('Save my plan');

    await wait(3);
    await tap('Continue with email');
    await wait(1.5);
    await type('Your name', 'Demo');
    await type('Email', _email);
    await type('Create a password', _password);
    await wait(1);
    await tap('Create account');

    // Creating the account goes to the server; stop rather than tap on blind.
    if (!await waitFor('SOMEWHERE ELSE?', timeout: 180)) return log('stopped: no source page');
    await wait(2);
    await tap('Instagram');
    await wait(1.5);
    await tap('Continue');

    if (!await waitFor('Buy (test, free)', timeout: 180)) return log('stopped: no test paywall');
    await wait(3);
    await tap('Buy (test, free)');
    await wait(15);
    log('done');
  }

  // --- finding and touching things on screen ---

  Size get _screen {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return view.physicalSize / view.devicePixelRatio;
  }

  List<(String, Rect)> _texts() {
    final screen = Offset.zero & _screen;
    final result = <(String, Rect)>[];
    void visit(Element e) {
      final ro = e.renderObject;
      if (e.widget is RichText && ro is RenderBox && ro.attached && ro.hasSize) {
        final text = (e.widget as RichText).text.toPlainText();
        final rect = ro.localToGlobal(Offset.zero) & ro.size;
        if (text.trim().isNotEmpty && screen.contains(rect.center)) {
          result.add((text.replaceAll('\n', ' '), rect));
        }
      }
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return result;
  }

  Rect? _find(String text) {
    // Exact text first ("Continue", not "Continue with Google"); the last
    // match is the topmost route's.
    final texts = _texts();
    var hits = texts.where((t) => t.$1.trim() == text).toList();
    if (hits.isEmpty) hits = texts.where((t) => t.$1.contains(text)).toList();
    return hits.isEmpty ? null : hits.last.$2;
  }

  Future<bool> waitFor(String text, {double timeout = 20}) async {
    final end = DateTime.now().add(Duration(milliseconds: (timeout * 1000).round()));
    while (_find(text) == null && DateTime.now().isBefore(end)) {
      await wait(0.3);
    }
    final found = _find(text) != null;
    log(found ? 'saw "$text"' : 'timed out waiting for "$text"');
    return found;
  }

  Future<void> tap(String text) async {
    await waitFor(text, timeout: 8);
    final rect = _find(text);
    if (rect == null) return;
    final b = GestureBinding.instance;
    final id = _pointer++;
    b.handlePointerEvent(PointerDownEvent(pointer: id, position: rect.center));
    await wait(0.08);
    b.handlePointerEvent(PointerUpEvent(pointer: id, position: rect.center));
    log('tapped "$text"');
  }

  /// A slow finger drag starting [dy] below [anchor]'s text, held still at
  /// the end so it doesn't fling.
  Future<void> drag(String anchor, {required double dx, double dy = 0}) async {
    final rect = _find(anchor);
    if (rect == null) return log('no "$anchor" to drag from');
    final start = Offset(_screen.width / 2 + 40, rect.center.dy + dy);
    final b = GestureBinding.instance;
    final id = _pointer++;
    b.handlePointerEvent(PointerDownEvent(pointer: id, position: start));
    const steps = 30;
    for (var i = 1; i <= steps; i++) {
      await wait(0.03);
      b.handlePointerEvent(PointerMoveEvent(
          pointer: id, position: start + Offset(dx * i / steps, 0), delta: Offset(dx / steps, 0)));
    }
    await wait(0.3);
    b.handlePointerEvent(PointerUpEvent(pointer: id, position: start + Offset(dx, 0)));
    log('dragged from "$anchor" by $dx');
  }

  Future<void> scroll(double dy) async {
    ScrollableState? target;
    void visit(Element e) {
      if (e is StatefulElement && e.state is ScrollableState) {
        final s = e.state as ScrollableState;
        if (s.position.axis == Axis.vertical && s.position.maxScrollExtent > 0) target = s;
      }
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    final p = target?.position;
    if (p == null) return;
    await p.animateTo((p.pixels + dy).clamp(p.minScrollExtent, p.maxScrollExtent),
        duration: const Duration(milliseconds: 900), curve: Curves.easeInOut);
  }

  /// Taps the field showing [hint] and types [text] a character at a time.
  Future<void> type(String hint, String text) async {
    await tap(hint);
    await wait(0.6);
    EditableTextState? field;
    void visit(Element e) {
      if (e is StatefulElement && e.state is EditableTextState) {
        final s = e.state as EditableTextState;
        if (s.widget.focusNode.hasFocus) field = s;
      }
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    final f = field;
    if (f == null) return log('no focused field for "$hint"');
    for (var i = 1; i <= text.length; i++) {
      final value = text.substring(0, i);
      f.userUpdateTextEditingValue(
        TextEditingValue(text: value, selection: TextSelection.collapsed(offset: value.length)),
        SelectionChangedCause.keyboard,
      );
      await wait(0.05);
    }
    log('typed into "$hint"');
  }
}
