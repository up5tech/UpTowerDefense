import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/gameplay_harness.dart';
import '../helpers/map_fixture.dart';

LevelBundle _bundleWithCoreHealth(int coreHealth) {
  return LevelBundle(
    level: LevelDefinition(
      id: testLevel.id,
      displayName: testLevel.displayName,
      mapId: testLevel.mapId,
      coreHealth: coreHealth,
      startingGold: testLevel.startingGold,
      waves: testLevel.waves,
    ),
    map: testMap,
    enemies: testEnemyCatalog,
    towers: testTowerCatalog,
  );
}

void main() {
  testWidgets('HUD shows core health, wave progress and the wave control', (
    tester,
  ) async {
    await pumpGameplay(tester);

    expect(find.text('Test Meadow'), findsOneWidget);
    expect(find.text('5/5'), findsOneWidget);
    expect(find.text('Wave 0/2'), findsOneWidget);
    expect(find.text('Start wave'), findsOneWidget);
  });

  testWidgets('starting a wave disables the control until it is cleared', (
    tester,
  ) async {
    await pumpGameplay(tester);

    await tester.tap(find.text('Start wave'));
    await tester.pump();

    expect(find.text('Wave 1/2'), findsOneWidget);
    expect(find.text('Wave in progress'), findsOneWidget);
    expect(find.text('Start wave'), findsNothing);
  });

  testWidgets('reaching zero core health shows the defeat state', (
    tester,
  ) async {
    final game = await pumpGameplay(tester, bundle: _bundleWithCoreHealth(1));

    await tester.tap(find.text('Start wave'));
    await tester.pump();

    // Run the simulation past the whole route in small steps, the way the game
    // loop feeds it: both wave-one grunts leak and drain the single hit point.
    for (var i = 0; i < 300; i++) {
      game.controller.advance(0.1);
    }
    await tester.pump();

    expect(find.text('Core destroyed'), findsOneWidget);
    // The result summary reports both the empty core and the cleared waves, so
    // the same "0/1" value appears twice — once per row.
    expect(find.text('0/1'), findsNWidgets(2));
    expect(find.text('Start wave'), findsNothing);
    expect(find.text('Wave in progress'), findsNothing);
  });

  testWidgets('clearing every wave shows the victory state', (tester) async {
    final game = await pumpGameplay(tester);

    await tester.tap(find.text('Start wave'));
    await tester.pump();

    for (var wave = 0; wave < 2; wave++) {
      // Spawn the wave's enemies, then resolve them as combat would.
      game.controller.advance(3);
      await tester.pump();
      for (final enemy in game.session.enemies.toList()) {
        game.session.reportEnemyDefeated(enemy);
      }
      game.controller.advance(0);
      await tester.pump();

      if (wave == 0) {
        // A cleared wave leaves a live countdown; tapping it starts the next
        // wave immediately instead of waiting for the timer.
        await tester.tap(find.byTooltip('Start wave 2 now'));
        await tester.pump();
      }
    }

    expect(find.text('All waves cleared'), findsOneWidget);
    expect(find.text('Start wave'), findsNothing);
  });

  testWidgets('combat rewards show up as gold in the HUD', (tester) async {
    final game = await pumpGameplay(tester);

    expect(find.text('150 g'), findsOneWidget);

    game.controller.buildTower('pad_a', testRanger);
    await tester.pump();
    expect(find.text('80 g'), findsOneWidget);

    await tester.tap(find.text('Start wave'));
    await tester.pump();

    // Drive real combat: the ranger kills both wave-one grunts for 10 gold
    // each, and only the simulation may report the new total. Twelve seconds
    // covers both kills while leaving the between-waves countdown running, so
    // the next wave cannot start and pay a third reward.
    for (var i = 0; i < 120; i++) {
      game.controller.advance(0.1);
    }
    await tester.pump();

    expect(game.session.leaks, 0);
    expect(game.session.kills, 2);
    expect(find.text('100 g'), findsOneWidget);
  });

  testWidgets('returning to the menu disposes the game', (tester) async {
    final game = await pumpGameplay(tester);

    await tester.tap(find.text('Start wave'));
    await tester.pump();
    game.controller.advance(2);
    await tester.pump();

    await tester.tap(find.byTooltip('Back to menu'));
    await tester.pumpAndSettle();

    expect(find.text('menu'), findsOneWidget);
    expect(game.disposed, isTrue);
  });
}
