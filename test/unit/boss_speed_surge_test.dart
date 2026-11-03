import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_state.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

/// One boss, one wave, one pad: enough for a ranger to hurt it and nothing else
/// on the field to confuse the measurements.
LevelSession _session() {
  const level = LevelDefinition(
    id: 'surge_probe',
    displayName: 'Surge Probe',
    mapId: 'test_map',
    coreHealth: 20,
    startingGold: 200,
    waves: [
      WaveDefinition(
        id: 'wave_1',
        groups: [
          SpawnGroupDefinition(
            enemyId: 'boss',
            count: 1,
            spawnIntervalSeconds: 1,
            initialDelaySeconds: 0.5,
          ),
        ],
      ),
    ],
  );

  final session = LevelSession(
    level: level,
    map: testMap,
    enemyCatalog: testBossCatalog,
    towerCatalog: testTowerCatalog,
  );
  // The damage has to come from the real combat path, so the pad is filled the
  // way the player would fill it.
  session.buildTower('pad_a', testRanger);
  return session;
}

/// Advances until [done] holds, failing rather than looping forever when a rule
/// change makes the expected event unreachable.
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

/// A session with its boss on the field, in a tower's range, and one hit away
/// from its arming threshold.
(LevelSession, EnemyState) _sessionWithArmedBoss(double dt) {
  final session = _session();
  session.startNextWave();
  _advanceUntil(session, () => session.enemies.isNotEmpty, dt);

  final boss = session.enemies.single;
  // Slightly above half of 600: the next ranger hit crosses the threshold.
  boss.health = 305;
  _advanceUntil(session, () => boss.isSurging, dt);
  return (session, boss);
}

void main() {
  group('EnemyState surge bookkeeping', () {
    EnemyState boss() => EnemyState(instanceId: 1, definition: testBoss);

    test('arms only at or below the health ratio', () {
      final above = boss()..health = testBoss.maxHealth * 0.5 + 1;
      expect(above.tryStartSpeedSurge(), isFalse);
      expect(above.isSurging, isFalse);

      final at = boss()..health = testBoss.maxHealth * 0.5;
      expect(at.tryStartSpeedSurge(), isTrue);
      expect(at.isSurging, isTrue);
      expect(at.surgeRemainingSeconds, 3);
    });

    test('never arms on a corpse', () {
      final dead = boss()..health = 0;
      expect(dead.tryStartSpeedSurge(), isFalse);
      expect(dead.isSurging, isFalse);
    });

    test('fires once, and a later call changes nothing', () {
      final subject = boss()..health = 100;
      expect(subject.tryStartSpeedSurge(), isTrue);
      subject.surgeRemainingSeconds = 0;

      // Still under the threshold, but the one burst is spent: a boss cannot
      // re-surge by being hit again.
      expect(subject.tryStartSpeedSurge(), isFalse);
      expect(subject.isSurging, isFalse);
    });

    test('multiplies the authored speed while it lasts', () {
      final subject = boss()..health = 100;
      expect(subject.currentSpeed, 40);
      subject.tryStartSpeedSurge();
      expect(subject.currentSpeed, 60);
      subject.surgeRemainingSeconds = 0;
      expect(subject.currentSpeed, 40);
    });

    test('a chill throttles the surge instead of cancelling it', () {
      final subject = boss()..health = 100;
      subject.tryStartSpeedSurge();
      subject
        ..slowMagnitude = 0.5
        ..slowRemainingSeconds = 1
        ..slowMinSpeedRatio = 0.4;

      // Half of the surged 60, which is above the 24 floor.
      expect(subject.currentSpeed, 30);
    });

    test('the slow floor follows the surged base, not the authored speed', () {
      final subject = boss()..health = 100;
      subject.tryStartSpeedSurge();
      subject
        ..slowMagnitude = 0.95
        ..slowRemainingSeconds = 1
        ..slowMinSpeedRatio = 0.4;

      // 5% of 60 would be 3; the floor is 40% of 60 = 24.
      expect(subject.currentSpeed, 24);
    });

    test('an enemy without a surge never reports one', () {
      final grunt = EnemyState(
        instanceId: 2,
        definition: testGrunt,
      )..health = 1;

      expect(grunt.tryStartSpeedSurge(), isFalse);
      expect(grunt.isSurging, isFalse);
      expect(grunt.currentSpeed, testGrunt.speed);
    });
  });

  group('the surge in a running level', () {
    test('starts on the hit that crosses the threshold', () {
      final (session, boss) = _sessionWithArmedBoss(1 / 60);

      expect(boss.isSurging, isTrue);
      expect(boss.surgeSpent, isTrue);
      expect(boss.currentSpeed, 60);
      // The crossing happened through damage, so the boss is still alive and
      // still short of half health.
      expect(boss.health, lessThanOrEqualTo(testBoss.maxHealth * 0.5));
      expect(session.enemies, contains(boss));
    });

    test('lasts three simulation seconds at every frame rate', () {
      for (final dt in const [1 / 60, 1 / 30, 1 / 10]) {
        final (session, boss) = _sessionWithArmedBoss(dt);
        final startDistance = boss.distanceAlongRoute;

        var frames = 0;
        while (boss.isSurging) {
          session.advance(dt);
          frames += 1;
          if (frames > 1000) {
            fail('surge never expired at dt $dt');
          }
        }

        expect(
          frames * dt,
          closeTo(3, dt),
          reason: 'the burst must last its authored 3s of simulation time',
        );
        // 1.5x of 40 u/s for 3 s, within a frame of when the window was cut.
        expect(
          boss.distanceAlongRoute - startDistance,
          closeTo(180, 60 * dt),
          reason: 'the boss did not actually move faster while surging',
        );
        expect(boss.currentSpeed, 40);
      }
    });

    test('a lethal blow never starts a surge nobody sees', () {
      final session = _session();
      session.startNextWave();
      _advanceUntil(session, () => session.enemies.isNotEmpty, 1 / 60);
      final boss = session.enemies.single;
      boss.health = 10;

      _advanceUntil(session, () => boss.resolved, 1 / 60);

      expect(boss.isSurging, isFalse);
      expect(boss.surgeSpent, isFalse);
      expect(session.kills, 1);
    });

    test('a paused level spends no surge time', () {
      final (session, boss) = _sessionWithArmedBoss(1 / 60);
      final before = boss.surgeRemainingSeconds;

      // Pause is a multiplier on the frame delta in the controller, so the
      // domain simply receives no time: nothing here may invent any.
      expect(boss.surgeRemainingSeconds, greaterThan(0));
      session.advance(0);
      expect(boss.surgeRemainingSeconds, before);
      expect(boss.isSurging, isTrue);
    });
  });
}
