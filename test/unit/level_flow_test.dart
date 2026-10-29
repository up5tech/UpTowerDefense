import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

/// Level with the same map and catalog as the fixture, so a test can vary core
/// health, gold or the countdown without rebuilding the whole bundle.
LevelDefinition _level({
  int coreHealth = 5,
  int startingGold = 150,
  double waveTransitionSeconds = 5,
  List<WaveDefinition>? waves,
}) {
  return LevelDefinition(
    id: testLevel.id,
    displayName: testLevel.displayName,
    mapId: testLevel.mapId,
    coreHealth: coreHealth,
    startingGold: startingGold,
    waveTransitionSeconds: waveTransitionSeconds,
    waves: waves ?? testLevel.waves,
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

/// A single-wave level, for cases that need the level to end immediately.
const List<WaveDefinition> _oneWave = [
  WaveDefinition(
    id: 'wave_1',
    groups: [
      SpawnGroupDefinition(enemyId: 'grunt', count: 1, spawnIntervalSeconds: 1),
    ],
  ),
];

/// Advances in game-loop sized frames, the way the engine drives the session.
void _run(LevelSession session, double seconds) {
  const step = 1 / 60;
  for (var elapsed = 0.0; elapsed < seconds; elapsed += step) {
    session.advance(step);
  }
}

/// Clears the wave that is currently on the field.
void _killEveryone(LevelSession session) {
  for (final enemy in session.enemies.toList()) {
    session.reportEnemyDefeated(enemy);
  }
}

void main() {
  group('state machine', () {
    test('allows exactly the documented transitions', () {
      expect(
        LevelPhaseTransitions.isLegal(LevelPhase.ready, LevelPhase.playing),
        isTrue,
      );
      expect(
        LevelPhaseTransitions.isLegal(
          LevelPhase.playing,
          LevelPhase.waveTransition,
        ),
        isTrue,
      );
      expect(
        LevelPhaseTransitions.isLegal(
          LevelPhase.waveTransition,
          LevelPhase.playing,
        ),
        isTrue,
      );
      expect(
        LevelPhaseTransitions.isLegal(LevelPhase.playing, LevelPhase.victory),
        isTrue,
      );
      expect(
        LevelPhaseTransitions.isLegal(LevelPhase.playing, LevelPhase.defeat),
        isTrue,
      );

      // A level cannot end before it starts, a cleared field cannot lose, and a
      // finished level goes nowhere.
      expect(
        LevelPhaseTransitions.isLegal(LevelPhase.ready, LevelPhase.victory),
        isFalse,
      );
      expect(
        LevelPhaseTransitions.isLegal(
          LevelPhase.waveTransition,
          LevelPhase.victory,
        ),
        isFalse,
      );
      expect(
        LevelPhaseTransitions.isLegal(LevelPhase.victory, LevelPhase.playing),
        isFalse,
      );
      expect(
        LevelPhaseTransitions.isLegal(LevelPhase.defeat, LevelPhase.playing),
        isFalse,
      );
      // Repeating a phase is a no-op, never an edge.
      for (final phase in LevelPhase.values) {
        expect(LevelPhaseTransitions.isLegal(phase, phase), isFalse);
      }
    });

    test('terminal phases have no way out', () {
      expect(LevelPhaseTransitions.isTerminal(LevelPhase.victory), isTrue);
      expect(LevelPhaseTransitions.isTerminal(LevelPhase.defeat), isTrue);
      expect(LevelPhaseTransitions.nextFrom(LevelPhase.victory), isEmpty);
      expect(LevelPhaseTransitions.nextFrom(LevelPhase.defeat), isEmpty);
      expect(LevelPhaseTransitions.isTerminal(LevelPhase.playing), isFalse);
      expect(
        LevelPhaseTransitions.isTerminal(LevelPhase.waveTransition),
        isFalse,
      );
    });
  });

  group('wave transition', () {
    test('a cleared wave holds a countdown and then starts the next wave', () {
      final session = _session(_level());
      session.startNextWave();
      _run(session, 3);
      expect(session.enemies, hasLength(2));

      _killEveryone(session);

      expect(session.phase, LevelPhase.waveTransition);
      expect(session.isInWaveTransition, isTrue);
      expect(session.transitionRemainingSeconds, 5);
      // The next wave is already startable: that is "start early".
      expect(session.canStartNextWave, isTrue);

      // One frame of tolerance: the run helper advances in 1/60 steps, so the
      // countdown can be a single frame short of the requested time.
      _run(session, 2);
      expect(session.transitionRemainingSeconds, closeTo(3, 1 / 60));
      expect(session.phase, LevelPhase.waveTransition);

      // Crossing zero starts the next wave by itself.
      _run(session, 3.1);
      expect(session.phase, LevelPhase.playing);
      expect(session.transitionRemainingSeconds, 0);
      expect(session.startedWaves, 2);

      _run(session, 0.1);
      expect(session.enemies, hasLength(1));
    });

    test('starting early cuts the countdown short', () {
      final session = _session(_level());
      session.startNextWave();
      _run(session, 3);
      _killEveryone(session);
      expect(session.phase, LevelPhase.waveTransition);

      expect(session.startNextWave(), isTrue);

      expect(session.phase, LevelPhase.playing);
      expect(session.transitionRemainingSeconds, 0);
      expect(session.startedWaves, 2);

      _run(session, 0.1);
      expect(session.enemies, hasLength(1));
    });

    test('the countdown uses the level value, not a constant', () {
      final session = _session(_level(waveTransitionSeconds: 2));
      session.startNextWave();
      _run(session, 3);
      _killEveryone(session);

      expect(session.transitionRemainingSeconds, 2);

      _run(session, 2.1);
      expect(session.startedWaves, 2);
    });

    test('the countdown only moves when the session is advanced', () {
      final session = _session(_level());
      session.startNextWave();
      _run(session, 3);
      _killEveryone(session);

      // A paused level is simply never advanced: the countdown is simulation
      // time, so it cannot tick behind the player's back.
      expect(session.transitionRemainingSeconds, 5);
      _run(session, 1);
      expect(session.transitionRemainingSeconds, closeTo(4, 1 / 60));
    });
  });

  group('victory and defeat', () {
    test('victory cannot occur while a spawn is still pending', () {
      final session = _session(_level());
      session.startNextWave();
      _run(session, 0.6);

      // One grunt is on the field, the second is still queued.
      expect(session.enemies, hasLength(1));
      expect(session.pendingSpawns, 1);

      _killEveryone(session);

      expect(session.phase, LevelPhase.playing);
      expect(session.canStartNextWave, isFalse);
    });

    test('victory needs every wave started and the field empty', () {
      final session = _session(_level(waves: _oneWave));
      session.startNextWave();
      _run(session, 1);

      _killEveryone(session);

      expect(session.phase, LevelPhase.victory);
      expect(session.canStartNextWave, isFalse);
      expect(session.startNextWave(), isFalse);
    });

    test('a finished level ignores later frames and pays nothing more', () {
      final session = _session(_level(waves: _oneWave));
      session.startNextWave();
      _run(session, 1);
      _killEveryone(session);
      expect(session.phase, LevelPhase.victory);

      final elapsed = session.elapsed;
      final gold = session.gold;
      final kills = session.kills;
      session.drainEvents();

      // One late frame far larger than the loop's clamp: a host that outlives
      // the attempt must not move it.
      session.advance(10);

      expect(session.elapsed, elapsed);
      expect(session.gold, gold);
      expect(session.kills, kills);
      expect(session.phase, LevelPhase.victory);
      expect(session.drainEvents(), isEmpty);
    });

    test('defeat clears the field and ignores later frames', () {
      final session = _session(_level(coreHealth: 1));
      session.startNextWave();
      // Both grunts walk the whole route; the first leak ends the level.
      _run(session, 24);

      expect(session.phase, LevelPhase.defeat);
      expect(session.coreHealth, 0);
      expect(session.projectiles, isEmpty);
      expect(session.pendingSpawns, 0);
      expect(session.leaks, 1);

      final elapsed = session.elapsed;
      session.advance(5);

      expect(session.phase, LevelPhase.defeat);
      expect(session.elapsed, elapsed);
      expect(session.leaks, 1);
    });
  });

  group('run stats', () {
    test('kills and gold earned count once per defeated enemy', () {
      final session = _session(_level());
      session.startNextWave();
      _run(session, 3);

      final first = session.enemies.first;
      session.reportEnemyDefeated(first);

      expect(session.kills, 1);
      expect(session.goldEarned, 10);

      // Resolving the same enemy again is a no-op: the stats cannot double.
      session.reportEnemyDefeated(first);
      expect(session.kills, 1);
      expect(session.goldEarned, 10);
    });

    test('a leak costs core health and pays no gold', () {
      final session = _session(_level());
      session.startNextWave();
      // Stops short of the countdown expiring, so no second wave can pay out.
      _run(session, 24);

      expect(session.leaks, 2);
      expect(session.kills, 0);
      expect(session.goldEarned, 0);
      expect(session.gold, 150);
    });

    test('every leak publishes one fact at the core', () {
      final session = _session(_level());
      session.startNextWave();
      // Stops short of the countdown expiring, so both grunts leak exactly
      // once each.
      _run(session, 24);
      expect(session.leaks, 2);

      final leaked = session
          .drainEvents()
          .where((event) => event.kind == LevelEventKind.leaked)
          .toList();

      expect(leaked, hasLength(session.leaks));
      for (final event in leaked) {
        expect(event.position.x, testMap.core.x);
        expect(event.position.y, testMap.core.y);
      }
      expect(
        session.drainEvents().where((e) => e.kind == LevelEventKind.leaked),
        isEmpty,
      );
    });
  });

  group('restart', () {
    test('returns the attempt to its opening state', () {
      final session = _session(_level());
      session.buildTower('pad_a', testRanger);
      session.upgradeTowerAt('pad_a');
      session.startNextWave();
      _run(session, 3);
      _killEveryone(session);
      expect(session.phase, LevelPhase.waveTransition);

      session.restart();

      expect(session.phase, LevelPhase.ready);
      expect(session.elapsed, 0);
      expect(session.transitionRemainingSeconds, 0);
      expect(session.startedWaves, 0);
      expect(session.gold, 150);
      expect(session.coreHealth, 5);
      expect(session.leaks, 0);
      expect(session.kills, 0);
      expect(session.goldEarned, 0);
      expect(session.towers, isEmpty);
      expect(session.towerCount, 0);
      expect(session.isPadOccupied('pad_a'), isFalse);
      expect(session.enemies, isEmpty);
      expect(session.pendingSpawns, 0);
      expect(session.projectiles, isEmpty);
      expect(session.drainEvents(), isEmpty);
    });

    test('a restarted attempt is fully playable again', () {
      final session = _session(_level());
      session.startNextWave();
      _run(session, 3);
      _killEveryone(session);
      session.restart();

      expect(session.canStartNextWave, isTrue);
      expect(session.canBuildOn('pad_a', testRanger), isTrue);

      session.buildTower('pad_a', testRanger);
      session.startNextWave();
      _run(session, 0.6);

      expect(session.gold, 80);
      expect(session.towerCount, 1);
      expect(session.enemies, hasLength(1));
      expect(session.phase, LevelPhase.playing);
    });

    test('restarting a finished level clears the outcome', () {
      final session = _session(_level(waves: _oneWave));
      session.startNextWave();
      _run(session, 1);
      _killEveryone(session);
      expect(session.phase, LevelPhase.victory);

      session.restart();

      expect(session.phase, LevelPhase.ready);
      expect(session.canStartNextWave, isTrue);
    });
  });
}
