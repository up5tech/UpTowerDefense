import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_state.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

/// The splitter's death rule (V2-2): two runners join the field at the parent's
/// exact route progress, each resolves once through the single path, and only
/// the parent pays its reward.
///
/// The direct tests drive `reportEnemyDefeated` — the same entry point combat
/// uses — so the spawn facts are asserted without depending on where a shot
/// happened to land. The running-level test then proves the combat path feeds
/// the same rule at every frame rate.
LevelSession _session() {
  const level = LevelDefinition(
    id: 'split_probe',
    displayName: 'Split Probe',
    mapId: 'test_map',
    coreHealth: 20,
    startingGold: 200,
    waves: [
      WaveDefinition(
        id: 'wave_1',
        groups: [
          SpawnGroupDefinition(
            enemyId: 'splitter',
            count: 1,
            spawnIntervalSeconds: 1,
            initialDelaySeconds: 0.5,
          ),
        ],
      ),
    ],
  );
  return LevelSession(
    level: level,
    map: testMap,
    enemyCatalog: mechanicEnemyCatalog,
    towerCatalog: testTowerCatalog,
  );
}

/// Advances until [done] holds, failing rather than looping forever when a rule
/// change makes the expected state unreachable.
void _advanceUntil(
  LevelSession session,
  bool Function() done,
  double dt,
) {
  var frames = 0;
  while (!done()) {
    session.advance(dt);
    frames += 1;
    if (frames > 3000) {
      fail('condition never became true within 3000 frames at dt $dt');
    }
  }
}

/// A session whose splitter is on the field, parked at [distance] so its death
/// position is authored rather than observed.
(LevelSession, EnemyState) _sceneWithSplitter(double distance, double dt) {
  final session = _session();
  session.startNextWave();
  _advanceUntil(session, () => session.enemies.isNotEmpty, dt);
  final enemy = session.enemies.single;
  enemy.distanceAlongRoute = distance;
  return (session, enemy);
}

void main() {
  group('the split rule', () {
    test('a splitter dies into two runners at its own route progress', () {
      final (session, parent) = _sceneWithSplitter(300, 1 / 60);

      session.reportEnemyDefeated(parent);

      expect(session.enemies, hasLength(2));
      for (final child in session.enemies) {
        expect(child.definition.id, 'runner');
        // Spawned mid-frame after the movement pass: the children start exactly
        // where the parent stood and skip that frame's step, so the distance
        // is the parent's to the unit, not a unit further along.
        expect(child.distanceAlongRoute, 300);
      }
      expect(session.kills, 1);
      expect(session.goldEarned, 16, reason: 'only the parent pays its reward');
    });

    test('the wave cannot complete while the children still live', () {
      final (session, parent) = _sceneWithSplitter(300, 1 / 60);

      session.reportEnemyDefeated(parent);

      // One-wave level: had the split not happened, this death would have been
      // the last enemy and the run a victory. The children keep it playing.
      expect(session.phase, LevelPhase.playing);
      expect(session.isWaveActive, isTrue);
    });

    test('a second resolution of the parent changes nothing', () {
      final (session, parent) = _sceneWithSplitter(300, 1 / 60);
      session.reportEnemyDefeated(parent);

      session.reportEnemyDefeated(parent);

      expect(session.enemies, hasLength(2));
      expect(session.kills, 1);
      expect(session.goldEarned, 16);
    });

    test('each child resolves once, pays once, and does not split again', () {
      final (session, parent) = _sceneWithSplitter(300, 1 / 60);
      session.reportEnemyDefeated(parent);
      final children = List.of(session.enemies);

      for (final child in children) {
        session.reportEnemyDefeated(child);
      }

      // 16 for the parent plus 8 per runner child: the whole family pays
      // exactly its authored rewards, once each.
      expect(session.enemies, isEmpty);
      expect(session.kills, 3);
      expect(session.goldEarned, 32);
      expect(session.phase, LevelPhase.victory);
    });
  });

  group('the split in a running level', () {
    /// A ranger on pad A kills the splitter; the moment it dies, two runners
    /// must be on the field at the parent's route position — at every frame
    /// rate, because the spawn rule is part of the resolution path, not of
    /// the frame that happened to land the killing blow.
    ///
    /// The splitter is re-pinned to route distance 180 each frame: at 68 u/s
    /// it would otherwise cross the ranger's 210-unit coverage in about five
    /// seconds, short of the ten hits its 170 health needs. Pinning makes the
    /// kill a function of the damage rule, and the children still spawn through
    /// the real combat path.
    test("children appear at the parent's position at every frame rate", () {
      for (final dt in const [1 / 60, 1 / 30, 1 / 10]) {
        final session = _session();
        expect(session.buildTower('pad_a', testRanger).isBuilt, isTrue);
        session.startNextWave();
        _advanceUntil(session, () => session.enemies.isNotEmpty, dt);
        final parent = session.enemies.single;

        var frames = 0;
        while (!(parent.resolved && session.enemies.length == 2)) {
          parent.distanceAlongRoute = 180;
          session.advance(dt);
          frames += 1;
          if (frames > 3000) {
            fail('the splitter never died at dt $dt');
          }
        }

        expect(session.enemies, hasLength(2), reason: 'dt $dt');
        expect(
          session.enemies.every(
            (enemy) => enemy.definition.id == 'runner',
          ),
          isTrue,
          reason: 'dt $dt',
        );
        for (final child in session.enemies) {
          expect(
            child.distanceAlongRoute,
            parent.distanceAlongRoute,
            reason:
                'the child must start where the parent died, with no free '
                'step (dt $dt)',
          );
        }
        expect(
          session.goldEarned,
          16,
          reason: 'only the parent has resolved, so only it has paid (dt $dt)',
        );
        expect(
          session.phase,
          LevelPhase.playing,
          reason: 'the wave is not over while the children walk (dt $dt)',
        );
      }
    });
  });
}
