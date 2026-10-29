import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

const double _step = 1 / 60;

const LevelDefinition _combatLevel = LevelDefinition(
  id: 'combat_test',
  displayName: 'Combat Test',
  mapId: 'test_map',
  coreHealth: 5,
  startingGold: 150,
  waves: [
    WaveDefinition(
      id: 'wave_1',
      groups: [
        SpawnGroupDefinition(
          enemyId: 'grunt',
          count: 2,
          spawnIntervalSeconds: 1,
          initialDelaySeconds: 0.5,
        ),
      ],
    ),
  ],
);

LevelSession _session() {
  return LevelSession(
    level: _combatLevel,
    map: testMap,
    enemyCatalog: testEnemyCatalog,
    towerCatalog: testTowerCatalog,
  );
}

/// Advances in game-loop sized frames, the way the engine drives the session.
void _run(LevelSession session, double seconds) {
  for (var elapsed = 0.0; elapsed < seconds; elapsed += _step) {
    session.advance(_step);
  }
}

/// Frames until [condition] holds, or fail after two simulated seconds.
void _runUntil(LevelSession session, bool Function() condition) {
  for (var i = 0; i < 120; i++) {
    if (condition()) {
      return;
    }
    session.advance(_step);
  }
  fail('condition never became true within two simulated seconds');
}

List<LevelEvent> _drain(LevelSession session) {
  final events = <LevelEvent>[];
  while (true) {
    final batch = session.drainEvents();
    if (batch.isEmpty) {
      return events;
    }
    events.addAll(batch);
  }
}

void main() {
  test('a built tower does not fire before a target is in range', () {
    final session = _session();
    session.buildTower('pad_a', testRanger);
    session.startNextWave();

    // The first grunt spawns at the route entry, ~228 units from pad A, so the
    // 210-unit tower must wait before taking the shot.
    _run(session, 0.2);

    expect(session.projectiles, isEmpty);
    expect(
      _drain(session).where((e) => e.kind == LevelEventKind.shot),
      isEmpty,
    );
  });

  test(
    'a tower fires repeatedly on its cooldown while enemies are in range',
    () {
      final session = _session();
      session.buildTower('pad_a', testRanger);
      session.startNextWave();

      _run(session, 3);

      final shots = _drain(
        session,
      ).where((e) => e.kind == LevelEventKind.shot).toList();
      // 0.7s cooldown into ~3s of enemy contact means several shots, and the
      // exact first shot happens the frame the enemy enters range.
      expect(shots.length, greaterThanOrEqualTo(3));
      expect(shots.length, lessThanOrEqualTo(6));
    },
  );

  test('a single-target hit reports no blast radius', () {
    final session = _session();
    session.buildTower('pad_a', testRanger);
    session.startNextWave();

    final hits = <LevelEvent>[];
    for (var i = 0; i < 300 && hits.isEmpty; i++) {
      session.advance(_step);
      hits.addAll(_drain(session).where((e) => e.kind == LevelEventKind.hit));
    }

    expect(hits, isNotEmpty);
    // No splash means no radius: the effect layer must not draw a blast ring
    // for a shot that only ever touches one enemy.
    expect(hits.first.radius, 0);
  });

  test('damage kills pay the reward exactly once and clear the wave', () {
    final session = _session();
    session.buildTower('pad_a', testRanger);
    session.startNextWave();

    _run(session, 15);

    final defeated = _drain(
      session,
    ).where((e) => e.kind == LevelEventKind.defeated).length;

    expect(session.enemies, isEmpty);
    expect(session.pendingSpawns, 0);
    expect(session.leaks, 0);
    expect(defeated, 2);
    // 150 starting - 70 build + 2 x 10 reward: no reward may be paid twice and
    // a kill must not be worth more than the definition says.
    expect(session.gold, 150 - 70 + 2 * 10);
    expect(session.phase, LevelPhase.victory);
  });

  test('a shot whose target dies expires without paying anything', () {
    final session = _session();
    session.buildTower('pad_a', testRanger);
    session.startNextWave();

    _runUntil(session, () => session.projectiles.isNotEmpty);
    final target = session.projectiles.single.target;

    // Kill it out from under the in-flight shot, as another tower would.
    session.reportEnemyDefeated(target);
    final goldAfterKill = session.gold;

    _run(session, 2);

    expect(session.projectiles.where((p) => p.target == target), isEmpty);
    expect(target.resolved, isTrue);
    expect(session.gold, goldAfterKill);
  });

  test('two kills reported in the same update each pay once', () {
    final session = _session();
    session.startNextWave();

    // Both wave-one grunts exist by 1.5s; resolve them in one update.
    _run(session, 2);
    expect(session.enemies, hasLength(2));

    final victims = List.of(session.enemies);
    session.reportEnemyDefeated(victims[0]);
    session.reportEnemyDefeated(victims[1]);

    expect(session.gold, 150 + 2 * 10);
    expect(session.enemies, isEmpty);

    // The session keeps running afterwards and pays nothing further.
    _run(session, 1);
    expect(session.gold, 150 + 2 * 10);
    expect(
      _drain(session).where((e) => e.kind == LevelEventKind.defeated).length,
      2,
    );
  });

  test('two towers clear the wave without double-paying rewards', () {
    final session = _session();
    expect(session.buildTower('pad_a', testRanger).isBuilt, isTrue);
    expect(session.buildTower('pad_b', testRanger).isBuilt, isTrue);

    session.startNextWave();
    _run(session, 15);

    expect(session.leaks, 0);
    expect(session.enemies, isEmpty);
    expect(session.gold, 150 - 2 * 70 + 2 * 10);
  });

  test('combat reaches the same outcome at different frame rates', () {
    List<int> run(double step) {
      final session = _session();
      session.buildTower('pad_a', testRanger);
      session.startNextWave();
      for (var elapsed = 0.0; elapsed < 12; elapsed += step) {
        session.advance(step);
      }
      return [session.gold, session.leaks, session.enemies.length];
    }

    final fine = run(1 / 60);
    final coarse = run(1 / 30);

    expect(coarse, fine);
  });

  test('a finished level freezes projectiles in flight', () {
    final session = _session();
    session.buildTower('pad_a', testRanger);
    session.startNextWave();

    _runUntil(session, () => session.projectiles.isNotEmpty);
    // Resolve the targeted enemy out from under the in-flight shot.
    final target = session.projectiles.single.target;
    session.reportEnemyDefeated(target);
    _runUntil(session, () => session.enemies.isNotEmpty);
    session.reportEnemyDefeated(session.enemies.first);

    _run(session, 1);
    expect(session.phase, LevelPhase.victory);
    expect(session.projectiles, isEmpty);
  });
}
