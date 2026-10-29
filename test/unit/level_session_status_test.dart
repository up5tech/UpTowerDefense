import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/build_pad.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_state.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/targeting_policy.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_level_stats.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

import '../helpers/content_fixtures.dart';

/// Map built for status-effect geometry: the route starts at the origin and
/// runs straight along y=0, and both pads sit 150 units above the entry, so a
/// 200-unit range covers the first enemies from the very first frame.
const MapDefinition _statusMap = MapDefinition(
  id: 'status_map',
  displayName: 'Status Map',
  worldWidth: 2000,
  worldHeight: 720,
  buildPadRadius: 34,
  route: [WorldPoint(0, 0), WorldPoint(2000, 0)],
  core: WorldPoint(2000, 0),
  buildPads: [
    BuildPad(id: 'pad_a', label: 'A', position: WorldPoint(0, 150)),
    BuildPad(id: 'pad_b', label: 'B', position: WorldPoint(60, 150)),
  ],
);

/// Durable walker: survives a cannon shell, so splash can be read off health
/// instead of off a death.
const EnemyDefinition _walker = EnemyDefinition(
  id: 'walker',
  displayName: 'Walker',
  maxHealth: 1000,
  speed: 100,
  coreDamageOnLeak: 1,
  rewardGold: 10,
  radius: 14,
  colorValue: 0xFFD96B5B,
);

/// Fast, fragile scout, used to stand clear of a blast.
const EnemyDefinition _scout = EnemyDefinition(
  id: 'scout',
  displayName: 'Scout',
  maxHealth: 100,
  speed: 400,
  coreDamageOnLeak: 1,
  rewardGold: 5,
  radius: 11,
  colorValue: 0xFFE0A34A,
);

/// Stationary anchor: a speed of zero freezes it on the route entry, which
/// makes the blast impact point exact instead of frame-dependent.
const EnemyDefinition _anchor = EnemyDefinition(
  id: 'anchor',
  displayName: 'Anchor',
  maxHealth: 1000,
  speed: 0,
  coreDamageOnLeak: 1,
  rewardGold: 10,
  radius: 14,
  colorValue: 0xFF9BA8B5,
);

/// Satellite that ends up just inside the 70-unit blast when the shell lands
/// on the frozen anchor.
const EnemyDefinition _nearSatellite = EnemyDefinition(
  id: 'near',
  displayName: 'Near Satellite',
  maxHealth: 100,
  speed: 160,
  coreDamageOnLeak: 1,
  rewardGold: 5,
  radius: 11,
  colorValue: 0xFF8BF0D6,
);

/// Satellite that ends up just outside the blast.
const EnemyDefinition _farSatellite = EnemyDefinition(
  id: 'far',
  displayName: 'Far Satellite',
  maxHealth: 100,
  speed: 220,
  coreDamageOnLeak: 1,
  rewardGold: 5,
  radius: 11,
  colorValue: 0xFFE0A34A,
);

/// Slow walker for the frost tests: stays inside tower range long enough to be
/// hit twice, then leaves before a third shot.
const EnemyDefinition _chillwalker = EnemyDefinition(
  id: 'chillwalker',
  displayName: 'Chillwalker',
  maxHealth: 1000,
  speed: 90,
  coreDamageOnLeak: 1,
  rewardGold: 10,
  radius: 14,
  colorValue: 0xFF7FB8FF,
);

final EnemyCatalog _walkerCatalog = EnemyCatalog(const [_walker, _scout]);
final EnemyCatalog _satelliteCatalog = EnemyCatalog(const [
  _anchor,
  _nearSatellite,
  _farSatellite,
]);
final EnemyCatalog _chillCatalog = EnemyCatalog(const [_chillwalker]);

/// Three walkers trickling in, plus a scout that races past the blast.
const LevelDefinition _walkerLevel = LevelDefinition(
  id: 'walker_level',
  displayName: 'Walker Level',
  mapId: 'status_map',
  coreHealth: 20,
  startingGold: 150,
  waves: [
    WaveDefinition(
      id: 'wave_1',
      groups: [
        SpawnGroupDefinition(
          enemyId: 'walker',
          count: 3,
          spawnIntervalSeconds: 0.1,
        ),
        SpawnGroupDefinition(
          enemyId: 'scout',
          count: 1,
          spawnIntervalSeconds: 1,
        ),
      ],
    ),
  ],
);

/// One frozen anchor plus the two satellites, all entering at once.
const LevelDefinition _satelliteLevel = LevelDefinition(
  id: 'satellite_level',
  displayName: 'Satellite Level',
  mapId: 'status_map',
  coreHealth: 20,
  startingGold: 150,
  waves: [
    WaveDefinition(
      id: 'wave_1',
      groups: [
        SpawnGroupDefinition(
          enemyId: 'anchor',
          count: 1,
          spawnIntervalSeconds: 1,
        ),
        SpawnGroupDefinition(
          enemyId: 'near',
          count: 1,
          spawnIntervalSeconds: 1,
        ),
        SpawnGroupDefinition(enemyId: 'far', count: 1, spawnIntervalSeconds: 1),
      ],
    ),
  ],
);

/// A single chillwalker, for the frost towers to slow.
const LevelDefinition _frostLevel = LevelDefinition(
  id: 'frost_level',
  displayName: 'Frost Level',
  mapId: 'status_map',
  coreHealth: 20,
  startingGold: 200,
  waves: [
    WaveDefinition(
      id: 'wave_1',
      groups: [
        SpawnGroupDefinition(
          enemyId: 'chillwalker',
          count: 1,
          spawnIntervalSeconds: 1,
        ),
      ],
    ),
  ],
);

/// Frost fixture for the slow tests.
///
/// [cooldownSeconds] is a parameter so a test can let a tower fire once (long
/// cooldown) or twice (short cooldown) inside its observation window: the
/// refresh rules under test are about hit timing, not fire rate.
TowerDefinition _frostTower({
  required String id,
  required double magnitude,
  required double durationSeconds,
  double cooldownSeconds = 5,
  double damageAmp = 0,
}) {
  return TowerDefinition(
    id: id,
    displayName: 'Frost $id',
    role: 'Control',
    description: 'Test frost tower.',
    buildCost: 85,
    sellRefundRate: 0.6,
    colorValue: 0xFF7FB8FF,
    levels: [
      TowerLevelStats(
        damage: 4,
        range: 200,
        fireCooldownSeconds: cooldownSeconds,
        projectileSpeed: 420,
        slow: SlowSpec(
          magnitude: magnitude,
          durationSeconds: durationSeconds,
          minSpeedRatio: 0.4,
          damageAmp: damageAmp,
        ),
      ),
    ],
  );
}

LevelSession _session({
  required LevelDefinition level,
  required EnemyCatalog enemies,
  TowerCatalog? towers,
}) {
  return LevelSession(
    level: level,
    map: _statusMap,
    enemyCatalog: enemies,
    towerCatalog: towers ?? TowerCatalog(const [testCannon]),
  );
}

/// Advances in game-loop sized frames, the way the engine drives the session.
void _run(LevelSession session, double seconds) {
  const step = 1 / 60;
  for (var elapsed = 0.0; elapsed < seconds; elapsed += step) {
    session.advance(step);
  }
}

/// Runs until every shell fired so far has landed.
///
/// Advances before checking, because the towers fire on the first frame: a
/// check-first loop would stop before the wave has even spawned.
void _runUntilShellsLanded(LevelSession session) {
  var sawShot = false;
  for (var i = 0; i < 240; i++) {
    session.advance(1 / 60);
    if (session.projectiles.isNotEmpty) {
      sawShot = true;
    } else if (sawShot) {
      return;
    }
  }
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
  group('slow maths on EnemyState', () {
    test('a mild slow removes exactly its magnitude', () {
      final enemy = EnemyState(instanceId: 0, definition: _chillwalker)
        ..slowMagnitude = 0.5
        ..slowMinSpeedRatio = 0.4
        ..slowRemainingSeconds = 1;

      expect(enemy.currentSpeed, 45); // 90 * (1 - 0.5)
    });

    test('a strong slow never takes speed below the configured floor', () {
      final enemy = EnemyState(instanceId: 0, definition: _chillwalker)
        ..slowMagnitude = 0.8
        ..slowMinSpeedRatio = 0.4
        ..slowRemainingSeconds = 1;

      // Uncapped this would be 18; the floor holds it at 40% of base speed.
      expect(enemy.currentSpeed, 36);
    });

    test('an expired slow no longer applies', () {
      final enemy = EnemyState(instanceId: 0, definition: _chillwalker)
        ..slowMagnitude = 0.8
        ..slowMinSpeedRatio = 0.4
        ..slowRemainingSeconds = 0;

      expect(enemy.isSlowed, isFalse);
      expect(enemy.currentSpeed, 90);
    });
  });

  group('cannon splash', () {
    test('splash damages every enemy inside the radius and nothing outside', () {
      final session = _session(level: _walkerLevel, enemies: _walkerCatalog);
      expect(session.buildTower('pad_a', testCannon).isBuilt, isTrue);
      // Strongest keeps the shell on a walker (1000 hp) rather than the scout
      // (100 hp), so the impact lands in the middle of the walker group.
      session.setTargetingPolicyAt('pad_a', TargetingPolicy.strongest);
      session.startNextWave();

      _run(session, 0.6);

      for (final enemy in session.enemies) {
        if (enemy.definition.id == 'scout') {
          // The scout is far past the impact when the shell lands: outside the
          // 70-unit blast, so it must not lose a single point.
          expect(enemy.health, 100);
        } else {
          // Exactly one 26-damage shell each, with no falloff by distance.
          expect(enemy.health, 974);
        }
      }
      expect(session.enemies, hasLength(4));
      // 150 - 110 build; nothing died, so no reward was paid.
      expect(session.gold, 40);

      final events = _drain(session);
      expect(events.where((e) => e.kind == LevelEventKind.shot), hasLength(1));
      final hit = events.singleWhere((e) => e.kind == LevelEventKind.hit);
      expect(hit, isNotNull);
      // The fact carries the blast the damage rule used, so the effect ring
      // drawn from it is the same circle the victims were chosen by.
      expect(hit.radius, 70);
    });

    test('the blast boundary is inclusive and damage never falls off', () {
      final session = _session(
        level: _satelliteLevel,
        enemies: _satelliteCatalog,
      );
      expect(session.buildTower('pad_a', testCannon).isBuilt, isTrue);
      session.setTargetingPolicyAt('pad_a', TargetingPolicy.strongest);
      session.startNextWave();

      _run(session, 0.6);

      // The anchor is frozen on the entry, so the shell lands exactly on the
      // route start. By landing time the near satellite sits ~61 units out
      // (inside 70) and the far one ~84 units out (outside 70).
      final byId = {
        for (final enemy in session.enemies) enemy.definition.id: enemy,
      };
      expect(byId['anchor']!.health, 974);
      expect(byId['near']!.health, 74);
      expect(byId['far']!.health, 100);
      expect(session.gold, 40);
    });
  });

  group('frost slow', () {
    test('a weaker slow hit is ignored and never refreshes the timer', () {
      final towers = TowerCatalog([
        _frostTower(id: 'strong', magnitude: 0.8, durationSeconds: 3),
        _frostTower(id: 'weak', magnitude: 0.4, durationSeconds: 10),
      ]);
      final session = _session(
        level: _frostLevel,
        enemies: _chillCatalog,
        towers: towers,
      );
      session
        ..buildTower('pad_a', towers['strong']!)
        ..buildTower('pad_b', towers['weak']!)
        ..startNextWave();

      _runUntilShellsLanded(session);

      final enemy = session.enemies.single;
      // One slow per enemy: the magnitude is the strongest hit, never a sum.
      expect(enemy.slowMagnitude, 0.8);
      expect(enemy.isSlowed, isTrue);
      // The floor caps the slow at 40% of base speed, not the raw 20%.
      expect(enemy.currentSpeed, 36);
      // The strong hit's own three seconds, not the weak hit's ten.
      expect(enemy.slowRemainingSeconds, greaterThan(2.3));

      // Well past the strong slow's expiry the enemy must be back to full
      // speed: the weak hit neither replaced the magnitude nor bought time.
      _run(session, 3.4);
      expect(enemy.isSlowed, isFalse);
      expect(enemy.currentSpeed, 90);
    });

    test('an expired strong chill does not block a weaker hit', () {
      final towers = TowerCatalog([
        _frostTower(id: 'weak', magnitude: 0.4, durationSeconds: 10),
      ]);
      final session = _session(
        level: _frostLevel,
        enemies: _chillCatalog,
        towers: towers,
      );
      session
        ..buildTower('pad_a', towers['weak']!)
        ..startNextWave();

      for (var i = 0; i < 300 && session.enemies.isEmpty; i++) {
        session.advance(1 / 60);
      }
      final enemy = session.enemies.single;
      // A stronger chill that already ran out: the stored magnitude is the
      // same as a live one's, but no timer is left. The rule gates on the
      // *active* slow, so this must not stand in the way of the weak hit.
      enemy
        ..slowMagnitude = 0.8
        ..slowMinSpeedRatio = 0.4
        ..slowDamageAmp = 0.35
        ..slowRemainingSeconds = 0;

      _runUntilShellsLanded(session);

      expect(enemy.isSlowed, isTrue);
      expect(enemy.slowMagnitude, 0.4);
      expect(enemy.slowRemainingSeconds, greaterThan(0));
      expect(enemy.currentSpeed, 54); // 90 × (1 − 0.4), above the 36 floor
    });

    test('a stronger slow hit replaces the magnitude and the duration', () {
      final towers = TowerCatalog([
        _frostTower(id: 'weak', magnitude: 0.4, durationSeconds: 2),
        _frostTower(id: 'strong', magnitude: 0.8, durationSeconds: 10),
      ]);
      final session = _session(
        level: _frostLevel,
        enemies: _chillCatalog,
        towers: towers,
      );
      session
        ..buildTower('pad_a', towers['weak']!)
        ..buildTower('pad_b', towers['strong']!)
        ..startNextWave();

      _runUntilShellsLanded(session);

      final enemy = session.enemies.single;
      expect(enemy.slowMagnitude, 0.8);
      expect(enemy.currentSpeed, 36);

      // The strong hit's ten seconds are what is left, whichever tower's shell
      // landed first; the weak hit's two seconds can never win.
      _run(session, 4.1);
      expect(enemy.isSlowed, isTrue);
      expect(enemy.slowMagnitude, 0.8);
      expect(enemy.slowRemainingSeconds, greaterThan(5));
    });

    test('a new hit buys the full duration again', () {
      final towers = TowerCatalog([
        _frostTower(
          id: 'refresh',
          magnitude: 0.5,
          durationSeconds: 3,
          cooldownSeconds: 1.5,
        ),
      ]);
      final session = _session(
        level: _frostLevel,
        enemies: _chillCatalog,
        towers: towers,
      );
      session
        ..buildTower('pad_a', towers['refresh']!)
        ..startNextWave();

      for (var i = 0; i < 180; i++) {
        session.advance(1 / 60);
        if (session.enemies.isNotEmpty && session.enemies.single.isSlowed) {
          break;
        }
      }
      final enemy = session.enemies.single;
      expect(enemy.isSlowed, isTrue);

      // The tower fires again while the walker is still in range; the second
      // hit must restart the full three seconds. A fresh hit is the only thing
      // that can make the remaining time jump back up, so that jump is the
      // signal to stop at.
      var previous = enemy.slowRemainingSeconds;
      var refreshed = false;
      for (var i = 0; i < 240 && !refreshed; i++) {
        session.advance(1 / 60);
        final now = enemy.slowRemainingSeconds;
        refreshed = now > previous;
        previous = now;
      }
      expect(refreshed, isTrue);
      expect(enemy.slowRemainingSeconds, greaterThan(2.5));

      // Past the first hit's expiry the slow is still running, and it does end
      // afterwards: effects expire in simulation time like everything else.
      _run(session, 2.1);
      expect(enemy.isSlowed, isTrue);
      _run(session, 1.4);
      expect(enemy.isSlowed, isFalse);
      expect(enemy.currentSpeed, 90);
    });
  });

  group('chill damage amplifier', () {
    test('a chill hit carries its amplifier onto the target', () {
      final towers = TowerCatalog([
        _frostTower(
          id: 'amp',
          magnitude: 0.4,
          durationSeconds: 3,
          damageAmp: 0.25,
        ),
      ]);
      final session = _session(
        level: _frostLevel,
        enemies: _chillCatalog,
        towers: towers,
      );
      session
        ..buildTower('pad_a', towers['amp']!)
        ..startNextWave();

      _runUntilShellsLanded(session);

      final enemy = session.enemies.single;
      expect(enemy.isSlowed, isTrue);
      expect(enemy.slowDamageAmp, 0.25);

      // The amplifier belongs to the chill: when the slow expires, the stored
      // number stops being read even though nothing clears it.
      _run(session, 3.4);
      expect(enemy.isSlowed, isFalse);
      expect(enemy.currentSpeed, 90);
    });

    test('damage on a chilled target is amplified by the slow\u2019s amp', () {
      final session = _session(level: _walkerLevel, enemies: _walkerCatalog);
      expect(session.buildTower('pad_a', testCannon).isBuilt, isTrue);
      session.setTargetingPolicyAt('pad_a', TargetingPolicy.strongest);
      session.startNextWave();

      for (var i = 0; i < 300 && session.enemies.isEmpty; i++) {
        session.advance(1 / 60);
      }
      expect(session.enemies, isNotEmpty);
      for (final enemy in session.enemies) {
        enemy
          ..slowMagnitude = 0.4
          ..slowMinSpeedRatio = 0.4
          ..slowDamageAmp = 0.25
          ..slowRemainingSeconds = 5;
      }
      _run(session, 0.6);

      // One 26-damage shell plus the chill's 25%: 1000 health -> 967.5.
      final walker = session.enemies.firstWhere(
        (enemy) => enemy.definition.id == 'walker',
      );
      expect(walker.health, 967.5);
    });

    test('an expired chill stops amplifying, even with its magnitude stored', () {
      final session = _session(level: _walkerLevel, enemies: _walkerCatalog);
      expect(session.buildTower('pad_a', testCannon).isBuilt, isTrue);
      session.setTargetingPolicyAt('pad_a', TargetingPolicy.strongest);
      session.startNextWave();

      for (var i = 0; i < 300 && session.enemies.isEmpty; i++) {
        session.advance(1 / 60);
      }
      expect(session.enemies, isNotEmpty);
      for (final enemy in session.enemies) {
        enemy
          ..slowMagnitude = 0.4
          ..slowMinSpeedRatio = 0.4
          ..slowDamageAmp = 0.25
          ..slowRemainingSeconds = 0;
      }
      _run(session, 0.6);

      // The stored magnitude and amp are identical to the case above; only the
      // remaining time differs, so the shell must deal the plain 26.
      final walker = session.enemies.firstWhere(
        (enemy) => enemy.definition.id == 'walker',
      );
      expect(walker.health, 974);
    });
  });
}
