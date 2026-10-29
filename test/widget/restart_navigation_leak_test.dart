import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_phase.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';
import 'package:up_tower_defense/features/gameplay/flame/game.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/gameplay_harness.dart';
import '../helpers/pump_app.dart';
import '../helpers/pump_until.dart';

/// Phase 12 AC 3: level restart and repeated navigation must not accumulate
/// stale components or timers.
///
/// A leak here is invisible on screen — a `TimerComponent` nobody cancelled or
/// a layer child left behind still draws the same field — so each loop below
/// asserts an exact *snapshot* rather than "nothing looks wrong": the whole
/// recursive component count, the session's idle state and the widget element
/// count after cycle N must equal the ones recorded after cycle 1. Anything the
/// game carries over from a previous attempt grows one of those numbers and
/// fails the run.

/// Total components in [roots] and every descendant.
///
/// Flame runs timers, tweens and animations as components, so this count is
/// also the timer count: a stale timer is a stale component.
int _countComponents(Iterable<Component> roots) {
  var count = 0;

  void walk(Component component) {
    count += 1;
    for (final child in component.children) {
      walk(child);
    }
  }

  for (final root in roots) {
    walk(root);
  }
  return count;
}

/// One comparable picture of an idle game: what it draws (recursively) and
/// what its session holds after a restart.
Map<String, Object?> _gameSnapshot(UpTowerDefenseGame game) {
  final session = game.session;
  return {
    'world children': game.world.children.length,
    'components': _countComponents(game.world.children),
    'effects': game.fxLayer.activeCount,
    'phase': session.phase,
    'gold': session.gold,
    'core health': session.coreHealth,
    'towers': session.towerCount,
    'enemies': session.enemies.length,
    'projectiles': session.projectiles.length,
    'pending spawns': session.pendingSpawns,
    'started waves': session.startedWaves,
    'kills': session.kills,
    'leaks': session.leaks,
    'gold earned': session.goldEarned,
  };
}

/// Seeds an identical mid-run state, then restarts through the pause overlay
/// exactly as a player would.
///
/// The seed goes through the controller (not the engine ticker) so every cycle
/// starts from byte-identical state — an engine-driven seed would spawn timing
/// dependent enemies and turn the snapshot into a coin flip.
Future<void> _seedAndRestart(
  WidgetTester tester,
  UpTowerDefenseGame game,
) async {
  game.controller.buildTower('pad_a', testRanger);
  game.controller.buildTower('pad_b', testRanger);
  expect(game.controller.startNextWave(), isTrue);
  game.controller.advance(2);
  game.fxLayer.publish(const [
    LevelEvent(LevelEventKind.hit, WorldPoint(0, 0), radius: 10),
  ]);
  expect(game.session.towerCount, 2);
  expect(game.session.startedWaves, 1);
  expect(game.fxLayer.activeCount, greaterThan(0));

  await tester.tap(find.byTooltip('Pause'));
  await tester.pump();
  await tester.tap(find.byTooltip('Restart level'));
  await tester.pump();

  // The loop runs a few idle frames after every restart, the way play would:
  // a leak that only shows up while the engine ticks is caught here too.
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('ten restarts leave the game exactly where the first one did', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 450);
    addTearDown(tester.view.reset);

    final game = await pumpGameplay(tester);

    await _seedAndRestart(tester, game);
    final baseline = _gameSnapshot(game);
    expect(
      baseline['towers'],
      0,
      reason:
          'the restart must clear the seeded towers before it can be '
          'compared against',
    );
    expect(baseline['effects'], 0);

    const cycles = 9;
    for (var cycle = 2; cycle <= cycles + 1; cycle++) {
      await _seedAndRestart(tester, game);
      expect(
        _gameSnapshot(game),
        baseline,
        reason:
            'restart #$cycle drifted from the first restart — the attempt '
            'is carrying state (components, effects or session fields) across '
            'a restart',
      );
    }
  });

  testWidgets('entering and leaving gameplay ten times accumulates nothing', (
    tester,
  ) async {
    await pumpApp(tester);
    final menuBaseline = tester.allElements.length;
    expect(find.text('Play'), findsOneWidget);

    final games = <UpTowerDefenseGame>[];
    Map<String, Object?>? fieldBaseline;

    const cycles = 10;
    for (var cycle = 1; cycle <= cycles; cycle++) {
      await tester.tap(find.text('Play'));
      await tester.pump();

      // The map title appears first; the layers then finish mounting their
      // sprites in real async time, so wait for the layers before counting.
      await pumpUntilFound(tester, find.text('Test Meadow'));
      final game = tester
          .widget<GameWidget<UpTowerDefenseGame>>(
            find.byType(GameWidget<UpTowerDefenseGame>),
          )
          .game!;
      await waitForGameLayers(tester, game);
      await tester.pump(const Duration(milliseconds: 200));
      games.add(game);

      final field = _gameSnapshot(game);
      if (fieldBaseline == null) {
        fieldBaseline = field;
        expect(
          field['phase'],
          LevelPhase.ready,
          reason:
              'a freshly opened level must start idle; otherwise the '
              'cycles below would compare different starting states',
        );
      } else {
        expect(
          field,
          fieldBaseline,
          reason:
              'cycle $cycle opened a level that differs from the first '
              'one — a previous session leaked components or state into it',
        );
      }

      await tester.tap(find.byTooltip('Back to menu'));
      await tester.pumpAndSettle();

      expect(find.text('Play'), findsOneWidget, reason: 'cycle $cycle');
      expect(
        find.byType(GameWidget<UpTowerDefenseGame>),
        findsNothing,
        reason: 'cycle $cycle left a game widget mounted at the menu',
      );
      expect(
        game.disposed,
        isTrue,
        reason: 'cycle $cycle navigated away without disposing its game',
      );
      expect(
        tester.allElements.length,
        menuBaseline,
        reason:
            'cycle $cycle left stale elements behind at the menu — a '
            'grown element tree is how leaked overlays and timers show up',
      );
    }

    expect(games, hasLength(cycles));
    expect(games.where((game) => !game.disposed), isEmpty);
  });
}
