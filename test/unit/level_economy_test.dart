import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/tower_build_result.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

const String _padA = 'pad_a';
const String _padB = 'pad_b';

LevelSession _session({int startingGold = 150}) {
  return LevelSession(
    level: LevelDefinition(
      id: testLevel.id,
      displayName: testLevel.displayName,
      mapId: testLevel.mapId,
      coreHealth: testLevel.coreHealth,
      startingGold: startingGold,
      waves: testLevel.waves,
    ),
    map: testMap,
    enemyCatalog: testEnemyCatalog,
    towerCatalog: testTowerCatalog,
  );
}

void main() {
  test('starts with the level gold and no towers', () {
    final session = _session();

    expect(session.gold, 150);
    expect(session.towers, isEmpty);
    expect(session.towerAtPad(_padA), isNull);
  });

  test('builds a tower, deducts its cost and occupies the pad', () {
    final session = _session();

    final result = session.buildTower(_padA, testRanger);

    expect(result.isBuilt, isTrue);
    expect(result.blocker, isNull);
    expect(result.tower!.definition, same(testRanger));
    expect(result.tower!.padId, _padA);
    expect(session.gold, 80);
    expect(session.towers, hasLength(1));
    expect(session.towerAtPad(_padA)!.instanceId, result.tower!.instanceId);
    expect(session.isPadOccupied(_padA), isTrue);
  });

  test('a pad holds exactly one tower and a refused build costs nothing', () {
    final session = _session();
    session.buildTower(_padA, testRanger);

    final again = session.buildTower(_padA, testRanger);

    expect(again.isBuilt, isFalse);
    expect(again.blocker, TowerBuildBlocker.padOccupied);
    expect(session.gold, 80);
    expect(session.towers, hasLength(1));
  });

  test('a build publishes one placement fact and a refusal publishes none', () {
    final session = _session();
    session.drainEvents();

    session.buildTower(_padA, testRanger);

    final built = session
        .drainEvents()
        .where((event) => event.kind == LevelEventKind.built)
        .toList();
    expect(built, hasLength(1));
    // The cue sits on the pad that changed hands, in world units.
    expect(built.single.position.x, 180);
    expect(built.single.position.y, 360);

    // A refused build changed nothing, so it publishes nothing: no cue and no
    // fact for the audio layer to answer with.
    session.buildTower(_padA, testRanger);
    expect(
      session.drainEvents().where(
        (event) => event.kind == LevelEventKind.built,
      ),
      isEmpty,
    );
  });

  test('rejects an unknown pad without spending gold', () {
    final session = _session();

    final result = session.buildTower('pad_zzz', testRanger);

    expect(result.blocker, TowerBuildBlocker.unknownPad);
    expect(session.gold, 150);
    expect(session.towers, isEmpty);
  });

  test('rejects a build it cannot afford and reports the missing gold', () {
    final session = _session(startingGold: 50);

    final result = session.buildTower(_padA, testRanger);

    expect(result.isBuilt, isFalse);
    expect(result.blocker, TowerBuildBlocker.insufficientGold);
    expect(result.missingGold, 20);
    expect(session.gold, 50);
    expect(session.towerAtPad(_padA), isNull);
  });

  test('building two pads spends twice and keeps both towers', () {
    final session = _session();

    session
      ..buildTower(_padA, testRanger)
      ..buildTower(_padB, testRanger);

    expect(session.gold, 10);
    expect(session.towers.map((tower) => tower.padId), [_padA, _padB]);
    expect(session.towers.map((tower) => tower.instanceId), [0, 1]);
  });

  test('canBuildOn agrees with buildTower', () {
    final session = _session(startingGold: 50);

    expect(session.canBuildOn(_padA, testRanger), isFalse);
    expect(session.buildTower(_padA, testRanger).isBuilt, isFalse);

    session.gold = 70;
    expect(session.canBuildOn(_padA, testRanger), isTrue);
    expect(session.buildTower(_padA, testRanger).isBuilt, isTrue);

    expect(session.canBuildOn(_padA, testRanger), isFalse);
    expect(session.canBuildOn('pad_zzz', testRanger), isFalse);
  });

  test('a defeated level refuses every build', () {
    final session = LevelSession(
      level: LevelDefinition(
        id: 'defeat_test',
        displayName: 'Defeat Test',
        mapId: testMap.id,
        coreHealth: 1,
        startingGold: 500,
        waves: testLevel.waves,
      ),
      map: testMap,
      enemyCatalog: testEnemyCatalog,
      towerCatalog: testTowerCatalog,
    );

    session.startNextWave();
    for (var i = 0; i < 3000 && session.phase != LevelPhase.defeat; i++) {
      session.advance(1 / 60);
    }
    expect(session.phase, LevelPhase.defeat);

    final result = session.buildTower(_padA, testRanger);

    expect(result.blocker, TowerBuildBlocker.levelEnded);
    expect(session.gold, 500);
    expect(session.towers, isEmpty);
    expect(session.canBuildOn(_padA, testRanger), isFalse);
  });

  test('a won level refuses every build', () {
    final session = _session();

    session.startNextWave();
    session.advance(2);
    for (final enemy in session.enemies.toList()) {
      session.reportEnemyDefeated(enemy);
    }
    session
      ..startNextWave()
      ..advance(1.1);
    for (final enemy in session.enemies.toList()) {
      session.reportEnemyDefeated(enemy);
    }
    expect(session.phase, LevelPhase.victory);

    final result = session.buildTower(_padA, testRanger);

    expect(result.blocker, TowerBuildBlocker.levelEnded);
    expect(session.towers, isEmpty);
  });

  test('a kill pays the enemy reward exactly once', () {
    final session = _session();

    session
      ..startNextWave()
      ..advance(1);
    final enemy = session.enemies.first;

    session.reportEnemyDefeated(enemy);
    expect(session.gold, 160);

    session.reportEnemyDefeated(enemy);
    expect(session.gold, 160);
  });

  test('a leaked enemy pays nothing', () {
    final session = _session();

    session.startNextWave();
    for (var i = 0; i < 3000 && session.leaks == 0; i++) {
      session.advance(1 / 60);
    }

    expect(session.leaks, 1);
    expect(session.gold, 150);
  });

  test('kill rewards accumulate as integer gold and fund a second tower', () {
    final session = _session();
    session.buildTower(_padA, testRanger);
    expect(session.gold, 80);

    // Wave one: two grunts at 10 gold each.
    session.startNextWave();
    session.advance(2);
    for (final enemy in session.enemies.toList()) {
      session.reportEnemyDefeated(enemy);
    }
    expect(session.gold, 100);

    // The earned gold now covers a second tower while the level is still live.
    expect(session.canBuildOn(_padB, testRanger), isTrue);
    expect(session.buildTower(_padB, testRanger).isBuilt, isTrue);
    expect(session.gold, 30);

    // Wave two: one runner at 8 gold.
    session.startNextWave();
    session.advance(1.1);
    for (final enemy in session.enemies.toList()) {
      session.reportEnemyDefeated(enemy);
    }

    expect(session.gold, 38);
  });
}
