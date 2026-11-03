import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/build_pad.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

/// The arc fixture's authored numbers, restated so an expectation reads as a
/// rule ("the second jump is half again") instead of an arithmetic result.
const double _damage = 24;
const double _falloff = 0.5;

/// A map whose route turns in exact hundred-unit steps.
///
/// A parked enemy therefore stands on an exact waypoint, and two candidates
/// around the corner sit exactly a hundred units from it. The shared
/// [testMap] turns after three hundred units, which leaves a parked
/// candidate a hundred and one-eighth units off: close enough to look like a
/// tie and far enough to let rounding decide it.
const MapDefinition _tieMap = MapDefinition(
  id: 'chain_tie_map',
  displayName: 'Chain Tie Map',
  worldWidth: 800,
  worldHeight: 800,
  buildPadRadius: 34,
  route: [
    WorldPoint(0, 500),
    WorldPoint(100, 500),
    WorldPoint(200, 500),
    WorldPoint(300, 500),
    WorldPoint(300, 400),
    WorldPoint(600, 400),
  ],
  core: WorldPoint(600, 400),
  buildPads: [
    BuildPad(id: 'pad_a', label: 'A', position: WorldPoint(300, 650)),
  ],
);

/// A one-wave level of grunts on [testMap]; the wave size is the scenario's.
LevelSession _session({required int enemies}) {
  final level = LevelDefinition(
    id: 'chain_probe',
    displayName: 'Chain Probe',
    mapId: 'test_map',
    coreHealth: 20,
    startingGold: 200,
    waves: [
      WaveDefinition(
        id: 'wave_1',
        groups: [
          SpawnGroupDefinition(
            enemyId: 'grunt',
            count: enemies,
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
    enemyCatalog: testEnemyCatalog,
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

/// Every event drained so far this frame, batch or not.
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

/// Spawns one grunt per entry of [distances], parks them at those route
/// distances in spawn order, then builds the arc on pad A.
///
/// The shot's geometry is authored rather than observed: every grunt shares a
/// speed, so once the field is parked the spacing — and with it splash
/// membership and chain order — holds for the whole run at any frame rate.
LevelSession _scene(List<double> distances, double dt) {
  final session = _session(enemies: distances.length);
  session.startNextWave();
  _advanceUntil(
    session,
    () => session.enemies.length == distances.length,
    dt,
  );
  for (var index = 0; index < distances.length; index++) {
    session.enemies[index].distanceAlongRoute = distances[index];
  }
  expect(
    session.buildTower('pad_a', testArc).isBuilt,
    isTrue,
    reason: 'the arc must be on the field for the shot to happen',
  );
  return session;
}

/// Parks one stationary grunt per entry of [distances] on [_tieMap] and builds
/// the arc on pad A.
///
/// The field does not move, so the distance the chain measures is the one the
/// scene was built with and the tie stays exact. That is what makes the
/// tie-break test a test of the rule: on a moving field the two candidates
/// reach the corner's legs at slightly different float values, and rounding
/// decides the order before the rule ever gets a say.
LevelSession _tieScene(List<double> distances, double dt) {
  final level = LevelDefinition(
    id: 'chain_tie_probe',
    displayName: 'Chain Tie Probe',
    mapId: _tieMap.id,
    coreHealth: 20,
    startingGold: 200,
    waves: [
      WaveDefinition(
        id: 'wave_1',
        groups: [
          SpawnGroupDefinition(
            enemyId: 'stationary_grunt',
            count: distances.length,
            spawnIntervalSeconds: 1,
            initialDelaySeconds: 0.5,
          ),
        ],
      ),
    ],
  );
  final session = LevelSession(
    level: level,
    map: _tieMap,
    enemyCatalog: stationaryEnemyCatalog,
    towerCatalog: mechanicTowerCatalog,
  );
  session.startNextWave();
  _advanceUntil(
    session,
    () => session.enemies.length == distances.length,
    dt,
  );
  for (var index = 0; index < distances.length; index++) {
    session.enemies[index].distanceAlongRoute = distances[index];
  }
  expect(
    session.buildTower('pad_a', testArc).isBuilt,
    isTrue,
    reason: 'the arc must be on the field for the shot to happen',
  );
  return session;
}

/// Advances until a shot lands, then reports every enemy's health as it stood
/// after that shot's full resolution: primary, splash and chain all resolve
/// inside the one frame, so this is the whole shot's effect on the field.
Map<int, double> _healthAfterFirstHit(LevelSession session, double dt) {
  for (var frame = 0; frame < 600; frame++) {
    session.advance(dt);
    final hits = _drain(
      session,
    ).where((event) => event.kind == LevelEventKind.hit);
    if (hits.isNotEmpty) {
      return {
        for (final enemy in session.enemies) enemy.instanceId: enemy.health,
      };
    }
  }
  fail('no shot landed within ten simulated seconds at dt $dt');
}

void main() {
  group('a chain shot in a running level', () {
    test('damages each victim exactly once when the blast caught them', () {
      // 300 is the target; 270 and 250 sit inside the 60-unit blast, so the
      // whole field is already in the victim set before the chain looks.
      final session = _scene(const [270, 250, 300], 1 / 60);

      final health = _healthAfterFirstHit(session, 1 / 60);

      // One hit of 24 each: a chain that re-jumped a splash victim would show
      // 52 or 64 here, which is the double-damage this rule exists to prevent.
      expect(health, {0: 76, 1: 76, 2: 76});
    });

    test('walks the field in distance order with falloff per jump', () {
      // 300 is targeted; 200 is one jump away and outside the blast, 100 is
      // two jumps away — both outside splash radius, so only the chain can
      // reach them.
      final session = _scene(const [100, 200, 300], 1 / 60);

      final health = _healthAfterFirstHit(session, 1 / 60);

      expect(
        health,
        {
          0: 100 - _damage * _falloff * _falloff,
          1: 100 - _damage * _falloff,
          2: 100 - _damage,
        },
      );
    });

    test('breaks equal jump distances by the lower instance id', () {
      // The shot lands on the corner at 300: it leads the field inside the
      // tower's 220-unit range, because 400 sits a hundred units up the
      // vertical leg — 250 units from the tower — so it can only ever be a
      // jump candidate. 200 sits a hundred units before the corner on the
      // horizontal leg and 400 a hundred units after it on the vertical one,
      // so the two are exactly equidistant from the shot. 100 is two hundred
      // units out, beyond the 160-unit jump radius, so it waits for the
      // second jump.
      final session = _tieScene(const [200, 300, 100, 400], 1 / 60);

      final health = _healthAfterFirstHit(session, 1 / 60);

      // The tie at a hundred units goes to instance id 0, spawned before id 3,
      // so id 3 takes nothing at all: the order is a function of the field,
      // not of list position or of who fired. The chain then jumps on to id 2,
      // which is nearer to id 0 than the tie loser is.
      expect(
        health,
        {
          0: 100 - _damage * _falloff,
          1: 100 - _damage,
          2: 100 - _damage * _falloff * _falloff,
          3: 100,
        },
      );
    });

    test('resolves identically at every frame rate', () {
      for (final dt in const [1 / 60, 1 / 30, 1 / 10]) {
        final session = _scene(const [100, 200, 300], dt);

        final health = _healthAfterFirstHit(session, dt);

        expect(
          health,
          {
            0: 100 - _damage * _falloff * _falloff,
            1: 100 - _damage * _falloff,
            2: 100 - _damage,
          },
          reason: 'the chain must not depend on the step size (dt $dt)',
        );
      }
    });

    test('ends early when nobody is left in jump radius', () {
      // The lone target has no one to jump to: chainCount promises two jumps,
      // but a chain may only spend them on real victims.
      final session = _scene(const [300], 1 / 60);

      final health = _healthAfterFirstHit(session, 1 / 60);

      expect(health, {0: 100 - _damage});
      expect(session.enemies, hasLength(1));
    });
  });
}
