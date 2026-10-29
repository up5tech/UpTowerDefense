import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

/// The fixture level flagged as the endless challenge.
///
/// The authored waves are the template: past them the session composes wave
/// `N` from `template[(N - 1) % length]`, scaled by [growth] per cycle (D62).
LevelDefinition _endlessLevel({
  double growth = 2.0,
  int coreHealth = 100,
  List<WaveDefinition>? waves,
}) => LevelDefinition(
  id: 'endless_test',
  displayName: 'Endless Test',
  mapId: 'test_map',
  coreHealth: coreHealth,
  startingGold: 150,
  endless: true,
  endlessCountGrowth: growth,
  waves: waves ?? testLevel.waves,
);

LevelSession _session({
  double growth = 2.0,
  int coreHealth = 100,
}) => LevelSession(
  level: _endlessLevel(growth: growth, coreHealth: coreHealth),
  map: testMap,
  enemyCatalog: testEnemyCatalog,
  towerCatalog: testTowerCatalog,
);

/// Advances in engine-sized frames until the field and the spawn queue are
/// both empty — i.e. the wave is cleared.
void _clearField(LevelSession session) {
  const step = 1 / 60;
  var guard = 0;
  while (session.isWaveActive && guard < 60 * 300) {
    session.advance(step);
    for (final enemy in session.enemies.toList()) {
      session.reportEnemyDefeated(enemy);
    }
    guard++;
  }
  expect(
    session.isWaveActive,
    isFalse,
    reason: 'the field must actually clear for the wave to roll over',
  );
}

void main() {
  test(
    'an endless level starts ready with the template as its visible budget',
    () {
      final session = _session();

      expect(session.phase, LevelPhase.ready);
      expect(session.totalWaves, testLevel.waves.length);
      expect(session.startedWaves, 0);
      expect(session.canStartNextWave, isTrue);
      expect(session.startNextWave(), isTrue);
      expect(session.phase, LevelPhase.playing);
      expect(
        session.canStartNextWave,
        isFalse,
        reason: 'a running wave never overlaps the next one',
      );
      expect(session.startNextWave(), isFalse);
    },
  );

  test('clearing a wave rolls into the next, never into victory', () {
    final session = _session();

    for (var wave = 1; wave <= 4; wave++) {
      expect(
        session.startNextWave(),
        isTrue,
        reason: 'wave $wave must always be startable in an endless run',
      );
      expect(session.startedWaves, wave);

      _clearField(session);

      // Past the authored waves the run still refuses victory: only the
      // transition branch is legal for a cleared endless field (D62).
      expect(session.phase, LevelPhase.waveTransition);
      expect(session.phase, isNot(LevelPhase.victory));
      expect(session.canStartNextWave, isTrue);
    }
  });

  test('waves past the template scale their counts by the growth rate', () {
    // Template: wave_1 has 2 grunts, wave_2 has 1 runner.
    final session = _session();

    session.startNextWave();
    expect(session.pendingSpawns, 2, reason: 'template wave, verbatim');
    _clearField(session);

    session.startNextWave();
    expect(session.pendingSpawns, 1, reason: 'second template wave, verbatim');
    _clearField(session);

    // Cycle 1 of wave_1: 2 × (1 + 2.0) = 6.
    session.startNextWave();
    expect(session.pendingSpawns, 6);
    expect(session.phase, LevelPhase.playing);
    _clearField(session);

    // Cycle 1 of wave_2: 1 × (1 + 2.0) = 3 — intervals stay authored, only
    // volume grows, so the codex stays truthful.
    session.startNextWave();
    expect(session.pendingSpawns, 3);
  });

  test('growth zero cycles the template without inflating it', () {
    final session = _session(growth: 0);

    session.startNextWave();
    _clearField(session);
    session.startNextWave();
    _clearField(session);

    session.startNextWave(); // cycle 1 of wave_1 with no growth
    expect(session.pendingSpawns, 2);
  });

  test('an endless run still ends — when the core dies', () {
    final session = _session(coreHealth: 1);

    session.startNextWave();
    // Let the wave walk the route: one leak with core 1 ends the attempt.
    const step = 1 / 60;
    var guard = 0;
    while (session.phase != LevelPhase.defeat && guard < 60 * 300) {
      session.advance(step);
      guard++;
    }

    expect(session.phase, LevelPhase.defeat);
    expect(session.leaks, greaterThan(0));
    // A terminal phase holds no spawns and refuses a next wave, endless or not.
    expect(session.pendingSpawns, 0);
    expect(session.canStartNextWave, isFalse);
    expect(session.startNextWave(), isFalse);
  });

  test('restart forgets composed waves and returns to ready', () {
    final session = _session();

    session.startNextWave();
    _clearField(session);
    session.startNextWave();
    _clearField(session);
    session.startNextWave(); // past the template
    expect(session.startedWaves, 3);

    session.restart();

    expect(session.phase, LevelPhase.ready);
    expect(session.startedWaves, 0);
    expect(session.pendingSpawns, 0);
    expect(session.isWaveActive, isFalse);
    expect(session.gold, 150);
    expect(session.startNextWave(), isTrue);
    expect(session.pendingSpawns, 2, reason: 'back to the template verbatim');
  });
}
