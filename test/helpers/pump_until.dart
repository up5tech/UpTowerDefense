import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps frames until [finder] matches, then returns.
///
/// Needed for screens that host the Flame game loop, where `pumpAndSettle` would
/// never settle, and for asynchronous map loading. On timeout the failure lists
/// the visible text, which usually identifies the screen that was shown instead.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  int maxFrames = 60,
}) async {
  for (var frame = 0; frame < maxFrames; frame++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    await tester.pump(step);
  }

  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .where((text) => text.isNotEmpty)
      .toList();

  throw TestFailure(
    'Timed out after $maxFrames frames waiting for $finder.\n'
    'Visible text: $visibleText',
  );
}
