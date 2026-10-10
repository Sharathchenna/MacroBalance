// Debug-only remote control for the QA entrypoint. The host writes commands,
// one per line, to <Documents>/qa_cmd.txt (found with
// `xcrun simctl get_app_container booted app.macrobalance.com data`); results
// land in qa_out.txt. Commands: tap <text>, tapi <n> <text>, tapxy <x> <y>,
// scroll <dy>, top, back, dump.
import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class QARemote {
  QARemote._(this.dir);
  final Directory dir;
  static int _pointer = 1000;

  static void start(Directory dir) {
    final remote = QARemote._(dir);
    Timer.periodic(const Duration(milliseconds: 300), (_) => remote._poll());
  }

  bool _busy = false;

  Future<void> _poll() async {
    if (_busy) return;
    final cmd = File('${dir.path}/qa_cmd.txt');
    if (!cmd.existsSync()) return;
    _busy = true;
    final lines = cmd.readAsLinesSync();
    cmd.deleteSync();
    final out = StringBuffer();
    for (final line in lines.where((l) => l.trim().isNotEmpty)) {
      try {
        out.writeln(await _run(line.trim()));
      } catch (e) {
        out.writeln('ERR $line: $e');
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    File('${dir.path}/qa_out.txt').writeAsStringSync(out.toString());
    _busy = false;
  }

  Future<String> _run(String line) async {
    final space = line.indexOf(' ');
    final op = space < 0 ? line : line.substring(0, space);
    final arg = space < 0 ? '' : line.substring(space + 1);
    switch (op) {
      case 'tap':
        return _tapText(arg, -1);
      case 'tapi':
        final sp = arg.indexOf(' ');
        return _tapText(arg.substring(sp + 1), int.parse(arg.substring(0, sp)));
      case 'tapxy':
        final p = arg.split(' ').map(double.parse).toList();
        _tap(Offset(p[0], p[1]));
        return 'tapped $arg';
      case 'scroll':
        return _scroll(double.parse(arg));
      case 'top':
        return _scroll(-1e9);
      case 'back':
        final nav = _navigators().lastOrNull;
        if (nav == null) return 'no navigator';
        await nav.maybePop();
        return 'back';
      case 'dump':
        return _visibleTexts().map((t) => '${t.$1} @ ${t.$2}').join('\n');
    }
    return 'unknown $op';
  }

  void _tap(Offset p) {
    final b = GestureBinding.instance;
    final id = _pointer++;
    b.handlePointerEvent(PointerDownEvent(pointer: id, position: p));
    b.handlePointerEvent(PointerUpEvent(pointer: id, position: p));
  }

  String _tapText(String text, int index) {
    final hits = _visibleTexts().where((t) => t.$1.contains(text)).toList();
    if (hits.isEmpty) return 'not found: $text';
    final hit = index < 0 ? hits.last : hits[index];
    _tap(hit.$2);
    return 'tapped "${hit.$1}" at ${hit.$2}';
  }

  Size get _screen {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    return view.physicalSize / view.devicePixelRatio;
  }

  List<(String, Offset)> _visibleTexts() {
    final screen = Offset.zero & _screen;
    final result = <(String, Offset)>[];
    void visit(Element e) {
      final ro = e.renderObject;
      if (e.widget is RichText && ro is RenderBox && ro.attached && ro.hasSize) {
        final text = (e.widget as RichText).text.toPlainText();
        final rect = ro.localToGlobal(Offset.zero) & ro.size;
        if (text.trim().isNotEmpty && screen.contains(rect.center)) {
          result.add((text.replaceAll('\n', ' '), rect.center));
        }
      }
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return result;
  }

  List<NavigatorState> _navigators() {
    final navs = <NavigatorState>[];
    void visit(Element e) {
      if (e is StatefulElement && e.state is NavigatorState) {
        navs.add(e.state as NavigatorState);
      }
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    return navs;
  }

  String _scroll(double dy) {
    final screen = Offset.zero & _screen;
    ScrollableState? target;
    void visit(Element e) {
      if (e is StatefulElement && e.state is ScrollableState) {
        final s = e.state as ScrollableState;
        final ro = e.renderObject;
        if (s.position.axis == Axis.vertical &&
            s.position.maxScrollExtent > 0 &&
            ro is RenderBox &&
            ro.attached &&
            screen.overlaps(ro.localToGlobal(Offset.zero) & ro.size)) {
          target = s;
        }
      }
      e.visitChildren(visit);
    }

    WidgetsBinding.instance.rootElement?.visitChildren(visit);
    final s = target;
    if (s == null) return 'no scrollable';
    final p = s.position;
    p.jumpTo((p.pixels + dy).clamp(p.minScrollExtent, p.maxScrollExtent));
    return 'scrolled to ${p.pixels.round()} / ${p.maxScrollExtent.round()}';
  }
}
