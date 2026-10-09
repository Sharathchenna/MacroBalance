import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Copy forbidden by the simple-mode plan, including accessibility labels.
final _bannedCopy = RegExp(
  r'\b(?:tdee|expenditure|trend weight|estimated|confident|data quality|phases?|energy density|glycogen|ignored)\b|[±σ%]',
  caseSensitive: false,
);

List<String> simpleModeCopy(WidgetTester tester) => [
      for (final text in tester.widgetList<Text>(find.byType(Text)))
        text.data ?? text.textSpan?.toPlainText() ?? '',
      for (final text in tester.widgetList<RichText>(find.byType(RichText)))
        text.text.toPlainText(),
      for (final semantics in tester.widgetList<Semantics>(find.byType(Semantics)))
        semantics.properties.label ?? '',
      for (final tooltip in tester.widgetList<Tooltip>(find.byType(Tooltip)))
        tooltip.message ?? tooltip.richMessage?.toPlainText() ?? '',
    ];

/// Explicitly allowed labels must match the entire string, never a substring.
/// For example, S5 asks for the plan-style label "In phases" under More options.
void expectSimpleCopy(WidgetTester tester, {Set<String> allow = const {}}) {
  for (final copy in simpleModeCopy(tester).toSet()) {
    if (allow.contains(copy)) continue;
    expect(_bannedCopy.hasMatch(copy), isFalse,
        reason: 'Simple mode contains detailed-stats copy: "$copy"');
  }
}
