import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/core/constants/app_info.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_phase.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';
import 'package:up_tower_defense/features/gameplay/flame/game.dart';
import 'package:up_tower_defense/features/gameplay/presentation/gameplay_screen.dart';
import 'package:up_tower_defense/features/level_select/presentation/level_select_screen.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

import '../helpers/gameplay_harness.dart' show waitForGameLayers;
import '../helpers/map_fixture.dart';
import '../helpers/pump_app.dart';
import '../helpers/pump_until.dart';

// One flow that spans four screens: campaign picker → level → result → the
// picker again with the next level open.
//
// Each screen is covered on its own elsewhere; what only this test proves is
// that they hand state to each other through the real provider chain — the
// result recorded by the gameplay screen is the same record the picker reads
// back to decide what is unlocked.

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
///
/// The clock is advanced by hand instead of by pumping time, so the run is
/// exact: a zero-duration pump leaves the Flame ticker at delta zero and the
/// only simulation time in the test is the time asked for here.
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

/// Waits until the map can hit-test taps.
///
/// The HUD is Flutter-side and appears before the game can hit-test taps, and
/// the layers still have their sprite files to decode — so a test that taps a
/// pad straight away would tap an unmeasured, unmounted map.
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
  testWidgets('winning a level opens the next one in the campaign', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 450);
    addTearDown(tester.view.reset);

    // This flow plays through a level; the first-level tutorial has its own
    // test, and its card would sit over the build pads on this surface.
    await pumpApp(
      tester,
      settings: GameSettings.defaults.copyWith(tutorialSeen: true),
    );

    // A fresh campaign holds only its first level.
    await tester.tap(find.text('Campaign'));
    await tester.pumpAndSettle();
    expect(find.text('Clear Test Meadow to unlock'), findsOneWidget);
    expect(find.text('Clear Second Meadow to unlock'), findsOneWidget);
    expect(find.text('Clear Third Meadow to unlock'), findsOneWidget);

    await tester.tap(find.text('Test Meadow'));
    await pumpUntilFound(tester, find.byType(GameplayScreen));
    await pumpUntilFound(
      tester,
      find.byType(GameWidget<UpTowerDefenseGame>),
    );
    await pumpUntilFound(tester, find.text('150 g'));
    await _warmUpMap(tester);

    final game = _gameOf(tester);
    expect(game.session.level.id, 'test_level');

    // Build through the real pad panel: two rangers leave 10 g behind.
    await _tapPad(tester, 'pad_a');
    expect(find.text('Build pad A'), findsOneWidget);
    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    await _tapPad(tester, 'pad_b');
    expect(find.text('Build pad B'), findsOneWidget);
    await tester.tap(find.text('Ranger Tower'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(game.session.towers, hasLength(2));
    expect(find.text('10 g'), findsOneWidget);

    // Deselect, so the pad panel cannot sit under the wave control.
    await tester.tap(find.byTooltip('Deselect pad'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Start wave'));
    await tester.pump();

    // Wave two starts on its own when the countdown runs out, so one wait
    // covers both waves and the transition between them.
    await _advanceUntil(tester, game, find.text('All waves cleared'));
    expect(find.text('Replay'), findsOneWidget);
    expect(game.session.phase, LevelPhase.victory);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameplayScreen)),
    );
    final progress = container.read(campaignProgressProvider);
    expect(progress.isCompleted('test_level'), isTrue);
    expect(progress.starsFor('test_level'), greaterThan(0));

    // Back through the result panel, then into the picker again.
    await tester.tap(find.text('Menu'));
    await tester.pumpAndSettle();
    expect(find.text(AppInfo.name), findsOneWidget);

    await tester.tap(find.text('Campaign'));
    await tester.pumpAndSettle();
    expect(find.text('Clear Second Meadow to unlock'), findsOneWidget);
    expect(find.text('Clear Third Meadow to unlock'), findsOneWidget);
    expect(find.textContaining('1 of 4 levels cleared'), findsOneWidget);

    // The picker reads the very record the gameplay screen wrote.
    final picked = ProviderScope.containerOf(
      tester.element(find.byType(LevelSelectScreen)),
    ).read(campaignProgressProvider);
    expect(picked.isCompleted('test_level'), isTrue);
    expect(picked.starsFor('test_level'), progress.starsFor('test_level'));

    // The next level is now open, and it starts as its own attempt.
    await tester.tap(find.text('Second Meadow'));
    await pumpUntilFound(tester, find.byType(GameWidget<UpTowerDefenseGame>));
    await pumpUntilFound(tester, find.text('150 g'));

    final nextGame = _gameOf(tester);
    expect(nextGame.session.level.id, 'test_level_2');
    expect(nextGame.session.towers, isEmpty);
  });
}
