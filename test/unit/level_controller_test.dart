import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/application/level_controller.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/targeting_policy.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

LevelController _controller({int coreHealth = 5}) {
  return LevelController(
    session: LevelSession(
      level: LevelDefinition(
        id: testLevel.id,
        displayName: testLevel.displayName,
        mapId: testLevel.mapId,
        coreHealth: coreHealth,
        startingGold: testLevel.startingGold,
        waves: testLevel.waves,
      ),
      map: testMap,
      enemyCatalog: testEnemyCatalog,
      towerCatalog: testTowerCatalog,
    ),
  );
}

/// Feeds the controller small frames, the way the game loop does.
void _run(LevelController controller, double seconds) {
  const step = 0.1;
  for (var elapsed = 0.0; elapsed < seconds; elapsed += step) {
    controller.advance(step);
  }
}

void main() {
  test('publishes the initial snapshot', () {
    final controller = _controller();
    addTearDown(controller.dispose);

    expect(controller.hud.coreHealth, 5);
    expect(controller.hud.maxCoreHealth, 5);
    expect(controller.hud.gold, 150);
    expect(controller.hud.towerCount, 0);
    expect(controller.hud.startedWaves, 0);
    expect(controller.hud.totalWaves, 2);
    expect(controller.hud.activeEnemies, 0);
    expect(controller.hud.canStartWave, isTrue);
    expect(controller.hud.isDefeated, isFalse);
    expect(controller.hud.isVictorious, isFalse);
  });

  test('notifies only when the HUD snapshot changes', () {
    final controller = _controller();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller.advance(0.01);
    expect(notifications, 0);

    expect(controller.startNextWave(), isTrue);
    expect(notifications, 1);
    expect(controller.hud.startedWaves, 1);
    expect(controller.hud.canStartWave, isFalse);

    // Wave one spawns its first grunt 0.5s after the wave started.
    controller.advance(0.6);
    expect(notifications, 2);
    expect(controller.hud.activeEnemies, 1);

    // No further change until the enemy moves out or is resolved.
    controller.advance(0.1);
    expect(notifications, 2);
  });

  test('a build republishes the HUD with the new gold and tower count', () {
    final controller = _controller();
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    final result = controller.buildTower('pad_a', testRanger);

    expect(result.isBuilt, isTrue);
    expect(notifications, 1);
    expect(controller.hud.gold, 80);
    expect(controller.hud.towerCount, 1);

    // A refused build changes nothing, so the HUD must not rebuild.
    controller.buildTower('pad_a', testRanger);
    expect(notifications, 1);
    expect(controller.hud.gold, 80);
  });

  test('an upgrade republishes gold only when it succeeds', () {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller.buildTower('pad_a', testRanger);
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    final result = controller.upgradeTower('pad_a');

    expect(result.isUpgraded, isTrue);
    expect(result.goldSpent, 60);
    expect(notifications, 1);
    expect(controller.hud.gold, 20);

    // 20 gold cannot pay the 95-gold level-3 upgrade, and a refusal must not
    // republish: the panel's disabled state comes from the same check.
    final refused = controller.upgradeTower('pad_a');

    expect(refused.isUpgraded, isFalse);
    expect(notifications, 1);
    expect(controller.hud.gold, 20);
  });

  test('a sell republishes the refund and frees the pad', () {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller.buildTower('pad_a', testRanger);
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    final result = controller.sellTower('pad_a');

    expect(result.isSold, isTrue);
    expect(result.refundGold, 42);
    expect(notifications, 1);
    expect(controller.hud.gold, 122);
    expect(controller.hud.towerCount, 0);

    // Selling an empty pad changes nothing and must not republish.
    controller.sellTower('pad_a');
    expect(notifications, 1);
    expect(controller.hud.gold, 122);
  });

  test('a priority change notifies once and a refusal never does', () {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller.buildTower('pad_a', testRanger);
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    expect(
      controller.setTargetingPolicy('pad_a', TargetingPolicy.strongest),
      isTrue,
    );
    expect(notifications, 1);

    expect(
      controller.setTargetingPolicy('pad_b', TargetingPolicy.strongest),
      isFalse,
    );
    expect(notifications, 1);
  });

  test('reports defeat once the core falls', () {
    final controller = _controller(coreHealth: 1);
    addTearDown(controller.dispose);
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller.startNextWave();
    _run(controller, 25);

    expect(controller.hud.isDefeated, isTrue);
    expect(controller.hud.coreHealth, 0);
    expect(controller.hud.canStartWave, isFalse);
    expect(notifications, greaterThan(1));

    final settled = notifications;
    _run(controller, 5);
    expect(notifications, settled);
  });

  test('pause stops the clock and resume continues it', () {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller.startNextWave();
    _run(controller, 1);
    final elapsed = controller.session.elapsed;
    expect(elapsed, greaterThan(0));

    controller.pause();
    expect(controller.hud.isPaused, isTrue);
    expect(controller.advance(1), 0);
    _run(controller, 2);
    expect(controller.session.elapsed, elapsed);

    controller.resume();
    expect(controller.hud.isPaused, isFalse);
    _run(controller, 1);
    expect(controller.session.elapsed, greaterThan(elapsed));
  });

  test('speed doubles the delta that reaches the domain', () {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller.startNextWave();

    final start = controller.session.elapsed;
    expect(controller.advance(0.5), closeTo(0.5, 1e-9));
    final atOneX = controller.session.elapsed;
    expect(atOneX - start, closeTo(0.5, 1e-9));

    controller.toggleSpeed();
    expect(controller.hud.speed, 2);
    expect(controller.advance(0.5), closeTo(1, 1e-9));
    expect(controller.session.elapsed - atOneX, closeTo(1, 1e-9));

    controller.toggleSpeed();
    expect(controller.hud.speed, 1);
    expect(controller.advance(0.5), closeTo(0.5, 1e-9));
  });

  test('restart clears the pause and republishes an opening snapshot', () {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller.buildTower('pad_a', testRanger);
    controller.startNextWave();
    _run(controller, 2);
    controller.pause();
    expect(controller.hud.isPaused, isTrue);

    controller.restart();

    expect(controller.isPaused, isFalse);
    expect(controller.hud.isPaused, isFalse);
    expect(controller.hud.phase, LevelPhase.ready);
    expect(controller.hud.gold, 150);
    expect(controller.hud.towerCount, 0);
    expect(controller.hud.startedWaves, 0);
    expect(controller.hud.kills, 0);
    expect(controller.hud.leaks, 0);
    expect(controller.hud.goldEarned, 0);
    expect(controller.hud.transitionSecondsRemaining, 0);
  });

  test('the HUD publishes the countdown in whole seconds', () {
    final controller = _controller();
    addTearDown(controller.dispose);
    controller.startNextWave();
    _run(controller, 3);
    for (final enemy in controller.session.enemies.toList()) {
      controller.session.reportEnemyDefeated(enemy);
    }
    controller.advance(0);

    expect(controller.hud.isInWaveTransition, isTrue);
    expect(controller.hud.transitionSecondsRemaining, 5);
    expect(controller.hud.canStartWave, isTrue);

    // Crossing into the next second is what republishes: the countdown is not
    // per-frame state.
    controller.advance(1.2);
    expect(controller.hud.transitionSecondsRemaining, 4);
  });
}
