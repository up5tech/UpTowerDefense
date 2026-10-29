import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_phase.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';
import 'package:up_tower_defense/features/gameplay/presentation/gameplay_screen.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/gameplay_harness.dart';
import '../helpers/map_fixture.dart';

/// One-wave level, so a test can reach victory without playing a second wave.
LevelBundle _oneWaveBundle() {
  return LevelBundle(
    level: LevelDefinition(
      id: testLevel.id,
      displayName: testLevel.displayName,
      mapId: testLevel.mapId,
      coreHealth: testLevel.coreHealth,
      startingGold: testLevel.startingGold,
      waves: const [
        WaveDefinition(
          id: 'wave_1',
          groups: [
            SpawnGroupDefinition(
              enemyId: 'grunt',
              count: 1,
              spawnIntervalSeconds: 1,
            ),
          ],
        ),
      ],
    ),
    map: testMap,
    enemies: testEnemyCatalog,
    towers: testTowerCatalog,
  );
}

void _useSmallLandscape(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 450);
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('the pause control freezes the engine and shows the overlay', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester);

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    expect(game.paused, isTrue);
    expect(game.controller.isPaused, isTrue);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump();

    expect(game.paused, isFalse);
    expect(game.controller.isPaused, isFalse);
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('a player pause survives backgrounding and resuming', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester);
    addTearDown(
      () => tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      ),
    );

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // The system resume must not override the player's explicit pause.
    expect(game.paused, isTrue);
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('the speed control switches between 1x and 2x', (tester) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester);

    expect(find.text('1x'), findsOneWidget);
    expect(game.controller.speed, 1);

    await tester.tap(find.text('1x'));
    await tester.pump();

    expect(find.text('2x'), findsOneWidget);
    expect(game.controller.speed, 2);
    expect(game.controller.hud.speed, 2);

    await tester.tap(find.text('2x'));
    await tester.pump();

    expect(find.text('1x'), findsOneWidget);
    expect(game.controller.speed, 1);
  });

  testWidgets('restart from the pause overlay clears the run and its effects', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester);

    game.controller.buildTower('pad_a', testRanger);
    game.controller.startNextWave();
    game.controller.advance(2);
    await tester.pump();
    expect(game.session.towerCount, 1);
    expect(game.session.startedWaves, 1);

    // Put an effect in the layer the way the game loop would, so the restart
    // has something stale to drop whatever the ticker produced meanwhile.
    game.fxLayer.publish(const [
      LevelEvent(LevelEventKind.hit, WorldPoint(0, 0), radius: 10),
    ]);
    expect(game.fxLayer.activeCount, greaterThan(0));

    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    await tester.tap(find.byTooltip('Restart level'));
    await tester.pump();

    expect(game.paused, isFalse);
    expect(game.controller.isPaused, isFalse);
    expect(game.fxLayer.activeCount, 0);
    expect(game.session.phase, LevelPhase.ready);
    expect(game.session.towerCount, 0);
    expect(game.session.startedWaves, 0);
    expect(game.session.gold, 150);
    expect(game.selection.value, isNull);
    expect(find.text('Paused'), findsNothing);
  });

  testWidgets('the result panel reports the run and replay restarts it', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester, bundle: _oneWaveBundle());

    await tester.tap(find.text('Start wave'));
    await tester.pump();
    game.controller.advance(1);
    await tester.pump();

    for (final enemy in game.session.enemies.toList()) {
      game.session.reportEnemyDefeated(enemy);
    }
    game.controller.advance(0);
    await tester.pump();

    expect(find.text('All waves cleared'), findsOneWidget);
    expect(find.text('Waves cleared'), findsOneWidget);
    // The fixture level is outside the shipped campaign, so the panel has
    // no next level to offer and no unlock message to print (D58).
    expect(find.text('Next level'), findsNothing);
    expect(find.textContaining('Unlocked:'), findsNothing);
    expect(find.text('1/1'), findsWidgets);
    expect(find.text('Enemies defeated'), findsOneWidget);
    expect(find.text('Leaks'), findsOneWidget);
    expect(find.text('Gold earned'), findsOneWidget);
    expect(find.text('10 g'), findsOneWidget);

    await tester.tap(find.text('Replay'));
    await tester.pump();

    expect(find.text('All waves cleared'), findsNothing);
    expect(game.session.phase, LevelPhase.ready);
    expect(game.session.gold, 150);
    expect(game.session.kills, 0);
    expect(find.text('Start wave'), findsOneWidget);
  });

  testWidgets('finishing a level records its campaign result exactly once', (
    tester,
  ) async {
    _useSmallLandscape(tester);
    final game = await pumpGameplay(tester, bundle: _oneWaveBundle());

    await tester.tap(find.text('Start wave'));
    await tester.pump();
    game.controller.advance(1);
    await tester.pump();

    for (final enemy in game.session.enemies.toList()) {
      game.session.reportEnemyDefeated(enemy);
    }
    game.controller.advance(0);
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GameplayScreen)),
    );
    final progress = container.read(campaignProgressProvider);

    expect(progress.isCompleted(testLevel.id), isTrue);
    // The core was never touched, so the run earns the full rating.
    expect(progress.starsFor(testLevel.id), 3);
    expect(progress.results, hasLength(1));

    // Later frames and a replay must not record a second result for the same
    // attempt: the recorder arms itself again only when the level restarts.
    game.controller.advance(5);
    await tester.pump();
    expect(container.read(campaignProgressProvider).results, hasLength(1));
  });
}
