import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/map_geometry.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

final double _routeLength = MapGeometry(testMap).routeLength;

LevelDefinition _level({
  required List<WaveDefinition> waves,
  int coreHealth = 5,
  int startingGold = 150,
}) {
  return LevelDefinition(
    id: 'session_test',
    displayName: 'Session Test',
    mapId: testMap.id,
    coreHealth: coreHealth,
    startingGold: startingGold,
    waves: waves,
  );
}

WaveDefinition _wave(
  String id, {
  int count = 1,
  double interval = 1,
  double delay = 0,
  String enemyId = 'grunt',
}) {
  return WaveDefinition(
    id: id,
    groups: [
      SpawnGroupDefinition(
        enemyId: enemyId,
        count: count,
        spawnIntervalSeconds: interval,
        initialDelaySeconds: delay,
      ),
    ],
  );
}

LevelSession _session(LevelDefinition level) {
  return LevelSession(
    level: level,
    map: testMap,
    enemyCatalog: testEnemyCatalog,
    towerCatalog: testTowerCatalog,
  );
}

/// Advances in game-loop sized frames, the way the engine drives the session.
void _run(LevelSession session, double seconds) {
  const step = 1 / 60;
  for (var elapsed = 0.0; elapsed < seconds; elapsed += step) {
    session.advance(step);
  }
}

void main() {
  test('starts ready with a full core and no enemies', () {
    final session = _session(_level(waves: [_wave('w1')]));

    expect(session.phase, LevelPhase.ready);
    expect(session.coreHealth, 5);
    expect(session.startedWaves, 0);
    expect(session.totalWaves, 1);
    expect(session.enemies, isEmpty);
    expect(session.canStartNextWave, isTrue);
  });

  test('spawns on the configured delay and cadence', () {
    final session = _session(
      _level(waves: [_wave('w1', count: 2, delay: 0.5)]),
    );

    expect(session.startNextWave(), isTrue);
    expect(session.startedWaves, 1);
    expect(session.enemies, isEmpty);
    expect(session.pendingSpawns, 2);

    session.advance(0.4);
    expect(session.enemies, isEmpty);

    session.advance(0.2);
    expect(session.enemies, hasLength(1));

    session.advance(1);
    expect(session.enemies, hasLength(2));
    expect(session.pendingSpawns, 0);
  });

  test('spawned enemies start at the exact progress of the frame', () {
    final session = _session(
      _level(waves: [_wave('w1', delay: 0.5)]),
    );

    session
      ..startNextWave()
      ..advance(0.6);

    // Spawned at 0.5s, so it has been walking for 0.1s at 80 units/s.
    expect(session.enemies.single.distanceAlongRoute, closeTo(8, 1e-9));
  });

  test('waves never overlap', () {
    final session = _session(
      _level(waves: [_wave('w1', count: 2), _wave('w2')]),
    );

    session
      ..startNextWave()
      ..advance(0.1);

    expect(session.enemies, isNotEmpty);
    expect(session.canStartNextWave, isFalse);
    expect(session.startNextWave(), isFalse);
    expect(session.startedWaves, 1);
  });

  test('leaks damage the core once per enemy and remove it', () {
    final session = _session(_level(waves: [_wave('w1')]));

    session.startNextWave();
    // Long enough to cross the whole route at 80 units/s, frame by frame.
    _run(session, _routeLength / 80 + 0.6);

    expect(session.enemies, isEmpty);
    expect(session.leaks, 1);
    expect(session.coreHealth, 4);

    _run(session, 10);

    expect(session.leaks, 1);
    expect(session.coreHealth, 4);
  });

  test('defeat happens once and freezes the level', () {
    final session = _session(
      _level(
        coreHealth: 2,
        waves: [_wave('w1', count: 3, interval: 0.2)],
      ),
    );

    session.startNextWave();
    for (var frame = 0; frame < 4000; frame++) {
      if (session.phase == LevelPhase.defeat) {
        break;
      }
      session.advance(1 / 60);
    }

    expect(session.phase, LevelPhase.defeat);
    expect(session.coreHealth, 0);
    expect(session.leaks, 2);
    final leaksAtDefeat = session.leaks;
    final enemiesAtDefeat = session.enemies.length;

    session
      ..advance(50)
      ..startNextWave();

    expect(session.leaks, leaksAtDefeat);
    expect(session.enemies, hasLength(enemiesAtDefeat));
    expect(session.phase, LevelPhase.defeat);
    expect(session.startedWaves, 1);
  });

  test('resolving every enemy completes the wave and then the level', () {
    final session = _session(
      _level(
        waves: [
          _wave('w1'),
          _wave('w2', enemyId: 'runner'),
        ],
      ),
    );

    session
      ..startNextWave()
      ..advance(0.1);
    expect(session.enemies, hasLength(1));

    session.reportEnemyDefeated(session.enemies.single);
    // A cleared wave with waves remaining holds the between-waves countdown
    // instead of pretending the level is still playing.
    expect(session.phase, LevelPhase.waveTransition);
    expect(session.transitionRemainingSeconds, greaterThan(0));
    expect(session.canStartNextWave, isTrue);

    // Starting early cuts the countdown short and resumes play.
    expect(session.startNextWave(), isTrue);
    expect(session.phase, LevelPhase.playing);
    expect(session.transitionRemainingSeconds, 0);
    session.advance(0.1);
    expect(session.enemies, hasLength(1));

    session.reportEnemyDefeated(session.enemies.single);

    expect(session.phase, LevelPhase.victory);
    expect(session.canStartNextWave, isFalse);
    expect(session.startNextWave(), isFalse);
  });

  test('a resolved enemy cannot be counted twice', () {
    final session = _session(_level(waves: [_wave('w1')]));

    session
      ..startNextWave()
      ..advance(0.1);
    final enemy = session.enemies.single;

    session
      ..reportEnemyDefeated(enemy)
      ..reportEnemyDefeated(enemy);

    expect(session.enemies, isEmpty);
    expect(session.phase, LevelPhase.victory);
  });

  test('ignores zero, negative and non-finite deltas', () {
    final session = _session(_level(waves: [_wave('w1')]));

    session
      ..startNextWave()
      ..advance(0)
      ..advance(-1)
      ..advance(double.nan)
      ..advance(double.infinity);

    expect(session.elapsed, 0);
    expect(session.enemies, isEmpty);
  });

  test('does nothing after a wave has not been started', () {
    final session = _session(_level(waves: [_wave('w1')]));

    session.advance(10);

    expect(session.elapsed, 0);
    expect(session.phase, LevelPhase.ready);
    expect(session.enemies, isEmpty);
  });

  group('frame-rate independence', () {
    double timeToFirstLeak(double step) {
      final session = _session(_level(waves: [_wave('w1')]))..startNextWave();
      var elapsed = 0.0;
      for (var frame = 0; frame < 100000; frame++) {
        if (session.leaks > 0) {
          return elapsed;
        }
        session.advance(step);
        elapsed += step;
      }
      fail('enemy never reached the core');
    }

    test('enemy arrival time is stable across frame rates', () {
      final sixty = timeToFirstLeak(1 / 60);
      final thirty = timeToFirstLeak(1 / 30);
      final coarse = timeToFirstLeak(0.25);

      expect((sixty - thirty).abs(), lessThan(0.02));
      expect((sixty - coarse).abs(), lessThan(0.26));
    });

    test('distance after the same elapsed time is identical', () {
      final fine = _session(_level(waves: [_wave('w1')]))..startNextWave();
      final coarse = _session(_level(waves: [_wave('w1')]))..startNextWave();

      for (var i = 0; i < 60; i++) {
        fine.advance(1 / 60);
      }
      for (var i = 0; i < 12; i++) {
        coarse.advance(1 / 12);
      }

      expect(
        fine.enemies.single.distanceAlongRoute,
        closeTo(coarse.enemies.single.distanceAlongRoute, 1e-6),
      );
    });
  });
}
