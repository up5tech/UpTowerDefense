import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_state.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

/// The bulwark's flat per-hit reduction (D73), exercised through the real
/// combat path: a shielded target, a ranger whose 18-damage hit lands as 12,
/// and a frost whose 4-damage hit the shield eats whole.
///
/// The shielded fixture moves at 60 u/s, so scenes re-pin it to the same route
/// distance every frame — the enemy never leaves the tower's coverage and the
/// number of hits a run produces is a function of the rule, not of timing.
LevelSession _session() {
  const level = LevelDefinition(
    id: 'shield_probe',
    displayName: 'Shield Probe',
    mapId: 'test_map',
    coreHealth: 20,
    startingGold: 200,
    waves: [
      WaveDefinition(
        id: 'wave_1',
        groups: [
          SpawnGroupDefinition(
            enemyId: 'shielded',
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
    towerCatalog: mechanicTowerCatalog,
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

/// Every event drained so far, batch or not.
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

/// Route distance 180 parks the shielded at (180, 500): 140 units from pad A,
/// inside both the ranger's 210 and the frost's 190 range.
const double _parkedDistance = 180;

/// A session with [tower] built on pad A and its shielded target on the field,
/// pinned to [_parkedDistance] for the whole run by re-writing it each frame —
/// the scene stays inside the tower's range at any frame rate.
(LevelSession, EnemyState) _scene(TowerDefinition tower, double dt) {
  final session = _session();
  expect(session.buildTower('pad_a', tower).isBuilt, isTrue);
  session.startNextWave();
  _advanceUntil(session, () => session.enemies.isNotEmpty, dt);
  final enemy = session.enemies.single;
  enemy.distanceAlongRoute = _parkedDistance;
  return (session, enemy);
}

/// Advances with the target re-pinned until [done] holds.
void _advancePinned(
  LevelSession session,
  EnemyState enemy,
  bool Function() done,
  double dt,
) {
  var frames = 0;
  while (!done()) {
    enemy.distanceAlongRoute = _parkedDistance;
    session.advance(dt);
    frames += 1;
    if (frames > 3000) {
      fail('condition never became true within 3000 frames at dt $dt');
    }
  }
}

void main() {
  group('the flat reduction in a running level', () {
    test('a ranger hit lands as damage minus the shield', () {
      final (session, enemy) = _scene(testRanger, 1 / 60);

      _advancePinned(session, enemy, () => enemy.health < 100, 1 / 60);

      // 18 - 6 = 12 through the shield, so 100 - 12 = 88.
      expect(enemy.health, 88);
    });

    test('the reduced hit resolves identically at every frame rate', () {
      for (final dt in const [1 / 60, 1 / 30, 1 / 10]) {
        final (session, enemy) = _scene(testRanger, dt);

        var frames = 0;
        while (enemy.health == 100) {
          enemy.distanceAlongRoute = _parkedDistance;
          session.advance(dt);
          frames += 1;
          if (frames > 600) {
            fail('no shot landed within ten simulated seconds at dt $dt');
          }
        }

        expect(
          enemy.health,
          88,
          reason: 'the shield must not depend on the step size (dt $dt)',
        );
      }
    });

    test('a hit the shield absorbs whole removes nothing and never heals', () {
      final (session, enemy) = _scene(testFrost, 1 / 60);

      var hits = 0;
      var frames = 0;
      while (hits < 3) {
        enemy.distanceAlongRoute = _parkedDistance;
        session.advance(1 / 60);
        hits += _drain(
          session,
        ).where((event) => event.kind == LevelEventKind.hit).length;
        frames += 1;
        if (frames > 3000) {
          fail('three shots never landed');
        }
      }

      // Frost hits for 4; the shield subtracts 6 and floors at zero, so three
      // landed shots moved the health bar by exactly nothing — while the chill
      // itself still applied, proving the hits were real.
      expect(enemy.health, 100);
      expect(enemy.isSlowed, isTrue);
    });

    test('the chill amplifier still pays for getting through the shield', () {
      final (session, enemy) = _scene(testRanger, 1 / 60);
      // A chilled bulwark: the same slow spec the frost fixture carries.
      enemy
        ..slowMagnitude = 0.4
        ..slowRemainingSeconds = 5
        ..slowMinSpeedRatio = 0.4
        ..slowDamageAmp = 0.25;

      _advancePinned(session, enemy, () => enemy.health < 100, 1 / 60);

      // 18 * 1.25 - 6 = 16.5, versus the 12 an unchilled hit lands: the
      // percentage is applied before the flat subtraction, so slowing a
      // shielded target is worth strictly more than on an unshielded one.
      expect(enemy.health, closeTo(100 - 16.5, 0.001));
    });

    test('the shielded enemy still resolves once and pays its reward once', () {
      final (session, enemy) = _scene(testRanger, 1 / 60);

      // 100 health at 12 per hit is nine shots; the pinned target cannot
      // leave the range, so the kill is a function of the damage rule alone.
      _advancePinned(session, enemy, () => enemy.resolved, 1 / 60);

      expect(session.kills, 1);
      expect(session.goldEarned, 12);
      expect(session.enemies, isEmpty);
    });
  });
}
