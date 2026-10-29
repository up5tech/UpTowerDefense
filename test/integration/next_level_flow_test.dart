import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_phase.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';
import 'package:up_tower_defense/features/gameplay/flame/game.dart';
import 'package:up_tower_defense/features/gameplay/presentation/gameplay_screen.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

import '../helpers/gameplay_harness.dart' show waitForGameLayers;
import '../helpers/map_fixture.dart';
import '../helpers/pump_app.dart';
import '../helpers/pump_until.dart';

// One flow across two attempts: level → result → the next level.
//
// What only this test proves is that a victory hands the player the unlock it
// just granted — the panel names the level that opened (D58) and its "Next
// level" action lands in a fresh attempt of exactly that level, through the
// same provider chain the record and the unlock rule share.

/// World-to-screen mapping for an 800x450 surface showing a 1280x720 world:
/// aspect ratios match, so the scale is 0.625 with no letterbox.
const double _scale = 0.625;

Offset _screen(WorldPoint point) => Offset(point.x * _scale, point.y * _scale);

/// Taps a build pad through the map's hit testing, the way a player would.
Future<void> _tapPad(WidgetTester tester, String padId) async {
  final pad = testMap.padById(padId)!;
  await tester.tapAt(_screen(pad.position));
  await tester.pump(const Duration(milliseconds: 100));
}

/// Steps the simulation in 0.1 s frames until [finder] matches.
Future<void> _advanceUntil(
  WidgetTester tester,
  UpTowerDefenseGame game,
  Finder finder, {
  int maxSteps = 4000,
}) async {
  for (var step = 0; step < maxSteps; step++) {
    if (finder.evaluate().isNotEmpty) {
      return;
    }
    game.controller.advance(0.1);
    if (step % 5 == 0) {
      await tester.pump();
    }
  }
  await tester.pump();

  final visibleText = tester
      .widgetList<Text>(find.byType(Text))
      .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '')
      .where((text) => text.isNotEmpty)
      .toList();
  throw TestFailure(
    'Timed out after $maxSteps frames waiting for $finder.\n'
    'Visible text: $visibleText',
  );
}

/// Waits until the map can hit-test taps, the same two-step warm-up the
/// campaign flow uses (layers mount on a tick, sprites decode in async time).
Future<void> _warmUpMap(WidgetTester tester) async {
  await waitForGameLayers(tester, _gameOf(tester));
  for (var frame = 0; frame < 5; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The running game behind the gameplay screen, which the screen owns.
UpTowerDefenseGame _gameOf(WidgetTester tester) {
  final widget = tester.widget<GameWidget<UpTowerDefenseGame>>(
    find.byType(GameWidget<UpTowerDefenseGame>),
  );
  return widget.game!;
}

void main() {
  testWidgets('a victory names what it unlocked and opens the next level', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 450);
    addTearDown(tester.view.reset);

    await pumpApp(
      tester,
      settings: GameSettings.defaults.copyWith(tutorialSeen: true),
    );

    await tester.tap(find.text('Campaign'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Test Meadow'));
    await pumpUntilFound(tester, find.byType(GameplayScreen));
    await pumpUntilFound(
      tester,
      find.byType(GameWidget<UpTowerDefenseGame>),
    );
    await _warmUpMap(tester);

    // Two rangers clear the fixture's waves, the same build the campaign flow
    // uses — the panel under test only appears at the victory.
    final game = _gameOf(tester);
    await _tapPad(tester, 'pad_a');
    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));
    await _tapPad(tester, 'pad_b');
    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byTooltip('Deselect pad'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('Start wave'));
    await tester.pump();

    await _advanceUntil(tester, game, find.text('All waves cleared'));
    expect(game.session.phase, LevelPhase.victory);

    // The reward a victory grants is the unlock itself: the panel says which
    // level just opened and offers the one action that reaches it.
    expect(find.text('Unlocked: Second Meadow'), findsOneWidget);
    expect(find.text('Campaign complete!'), findsNothing);
    expect(find.text('Next level'), findsOneWidget);

    await tester.tap(find.text('Next level'));
    await pumpUntilFound(tester, find.byType(GameWidget<UpTowerDefenseGame>));
    await pumpUntilFound(tester, find.text('150 g'));

    // A fresh attempt of exactly that level: same route, new screen state —
    // the finished game never carries over (the per-level route key).
    final nextGame = _gameOf(tester);
    expect(nextGame.session.level.id, 'test_level_2');
    expect(nextGame.session.towers, isEmpty);
    expect(nextGame.session.phase, LevelPhase.ready);
    expect(find.text('All waves cleared'), findsNothing);
    expect(find.text('Unlocked: Second Meadow'), findsNothing);
  });
}
