import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

import '../helpers/gameplay_harness.dart';

/// World-to-screen mapping for an 800x450 surface showing a 1280x720 world:
/// aspect ratios match, so there is no letterbox and the scale is 0.625.
const double _scale = 0.625;

Offset _screen(WorldPoint point) => Offset(point.x * _scale, point.y * _scale);

void _useSmallLandscape(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 450);
  addTearDown(tester.view.reset);
}

/// Taps [point] in world units and lets the gesture recogniser settle.
Future<void> _tapWorld(WidgetTester tester, WorldPoint point) async {
  await tester.tapAt(_screen(point));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('tapping a build pad selects it and shows its panel', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    await pumpGameplay(tester);

    expect(find.text('Build pad A'), findsNothing);

    await _tapWorld(tester, const WorldPoint(180, 360));

    expect(find.text('Build pad A'), findsOneWidget);
  });

  testWidgets('tapping another pad moves the selection', (tester) async {
    _useSmallLandscape(tester);
    await pumpGameplay(tester);

    await _tapWorld(tester, const WorldPoint(180, 360));
    expect(find.text('Build pad A'), findsOneWidget);

    await _tapWorld(tester, const WorldPoint(860, 380));

    expect(find.text('Build pad B'), findsOneWidget);
    expect(find.text('Build pad A'), findsNothing);
  });

  testWidgets('tapping the route selects nothing', (tester) async {
    _useSmallLandscape(tester);
    await pumpGameplay(tester);

    // On the first horizontal route segment.
    await _tapWorld(tester, const WorldPoint(150, 500));

    expect(find.textContaining('Build pad'), findsNothing);
  });

  testWidgets('tapping just outside a pad does not select it', (tester) async {
    _useSmallLandscape(tester);
    await pumpGameplay(tester);

    // Pad A has radius 34; this point is 6 world units beyond its edge.
    await _tapWorld(tester, const WorldPoint(180, 400));

    expect(find.textContaining('Build pad'), findsNothing);
  });

  testWidgets('tapping open ground clears an existing selection', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    await pumpGameplay(tester);

    await _tapWorld(tester, const WorldPoint(180, 360));
    expect(find.text('Build pad A'), findsOneWidget);

    await _tapWorld(tester, const WorldPoint(640, 640));

    expect(find.textContaining('Build pad'), findsNothing);
  });

  testWidgets('closing the pad panel clears the selection', (tester) async {
    _useSmallLandscape(tester);
    await pumpGameplay(tester);

    await _tapWorld(tester, const WorldPoint(180, 360));
    expect(find.text('Build pad A'), findsOneWidget);

    await tester.tap(find.byTooltip('Deselect pad'));
    await tester.pump();

    expect(find.textContaining('Build pad'), findsNothing);
  });
}
