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

/// A map whose three pads all sit inside the beacon fixture's 500-unit aura:
/// A–B is 220, A–C is 440 and B–C is 220, so every pad covers every other.
///
/// [testMap] cannot host this test — its two pads are ~680 units apart, outside
/// the aura, which is exactly the negative case the last group reuses it for.
const MapDefinition _auraMap = MapDefinition(
  id: 'aura_map',
  displayName: 'Aura Map',
  worldWidth: 1280,
  worldHeight: 720,
  buildPadRadius: 34,
  route: [
    WorldPoint(0, 500),
    WorldPoint(300, 500),
    WorldPoint(300, 260),
    WorldPoint(700, 260),
    WorldPoint(700, 500),
    WorldPoint(1150, 500),
  ],
  core: WorldPoint(1150, 500),
  buildPads: [
    BuildPad(id: 'pad_a', label: 'A', position: WorldPoint(180, 360)),
    BuildPad(id: 'pad_b', label: 'B', position: WorldPoint(400, 360)),
    BuildPad(id: 'pad_c', label: 'C', position: WorldPoint(620, 360)),
  ],
);

/// One wave fielding a single stationary grunt, so a scene can park it at an
/// exact route distance and leave it there — the same trick the chain tests
/// use to make a shot's geometry authored rather than observed.
LevelSession _session({
  MapDefinition map = _auraMap,
  int startingGold = 300,
}) {
  final level = LevelDefinition(
    id: 'aura_probe',
    displayName: 'Aura Probe',
    mapId: map.id,
    coreHealth: 20,
    startingGold: startingGold,
    waves: const [
      WaveDefinition(
        id: 'wave_1',
        groups: [
          SpawnGroupDefinition(
            enemyId: 'stationary_grunt',
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
    map: map,
    enemyCatalog: stationaryEnemyCatalog,
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

/// The ranger fixture's range at level 1 and level 2, restated so an
/// expectation reads as the rule ("a fifth wider", "a fifth wider still").
const double _rangerRange = 210;
const double _rangerLevelTwoRange = 225;

/// The beacon fixture's authored aura bonus per level.
const double _auraL1 = 0.2;
const double _auraL2 = 0.3;

void main() {
  group('the aura accessor', () {
    test('a tower with no beacon keeps its base range', () {
      final session = _session();
      expect(session.buildTower('pad_a', testRanger).isBuilt, isTrue);

      final tower = session.towerAtPad('pad_a')!;
      expect(session.effectiveStatsFor(tower).range, _rangerRange);
    });

    test('a covering beacon widens range by its bonus', () {
      final session = _session();
      session.buildTower('pad_a', testRanger);
      session.buildTower('pad_b', testBeacon);

      final tower = session.towerAtPad('pad_a')!;
      expect(
        session.effectiveStatsFor(tower).range,
        _rangerRange * (1 + _auraL1),
      );
    });

    test('only the strongest covering aura applies, never the sum', () {
      final session = _session();
      session.buildTower('pad_a', testRanger);
      session.buildTower('pad_b', testBeacon); // aura 0.2
      session.buildTower('pad_c', testBeacon);
      // Level the C beacon up to its 0.3 aura: two beacons now cover pad A.
      expect(session.upgradeTowerAt('pad_c').isUpgraded, isTrue);

      final tower = session.towerAtPad('pad_a')!;
      // 0.3 wins outright: 1.3x, not the 1.5x a stacking rule would give.
      expect(
        session.effectiveStatsFor(tower).range,
        _rangerRange * (1 + _auraL2),
      );
    });

    test('the buff is derived per query, so selling the beacon removes it', () {
      final session = _session();
      session.buildTower('pad_a', testRanger);
      session.buildTower('pad_b', testBeacon);
      final tower = session.towerAtPad('pad_a')!;
      expect(
        session.effectiveStatsFor(tower).range,
        _rangerRange * (1 + _auraL1),
      );

      expect(session.sellTowerAt('pad_b').isSold, isTrue);
      expect(session.effectiveStatsFor(tower).range, _rangerRange);
    });

    test('a beacon never amplifies itself', () {
      final session = _session();
      session.buildTower('pad_b', testBeacon);

      // Its own 500-unit aura reaches pad A and C but not itself: the circle
      // keeps showing the coverage it projects, not a buffed version of it.
      final beacon = session.towerAtPad('pad_b')!;
      expect(session.effectiveStatsFor(beacon).range, 300);
    });

    test('the level argument answers for the next upgrade', () {
      final session = _session();
      session.buildTower('pad_a', testRanger);
      session.buildTower('pad_b', testBeacon);
      final tower = session.towerAtPad('pad_a')!;

      // The panel's "Next:" preview asks about level 2: 225 base, still buffed.
      expect(
        session.effectiveStatsFor(tower, level: 2).range,
        _rangerLevelTwoRange * (1 + _auraL1),
      );
    });

    test('a beacon beyond aura radius buffs nothing', () {
      // testMap's pads are ~680 units apart — outside the 500-unit aura — so
      // the same build that buffs on _auraMap must do nothing here.
      final session = _session(map: testMap, startingGold: 200);
      session.buildTower('pad_a', testRanger);
      session.buildTower('pad_b', testBeacon);

      final tower = session.towerAtPad('pad_a')!;
      expect(session.effectiveStatsFor(tower).range, _rangerRange);
    });
  });

  group('the buff in a running level', () {
    /// Route distance 640 parks the grunt at (400, 260): 242 units from pad
    /// A — outside the ranger's 210 base range, inside the beacon's 252.
    const double parkedDistance = 640;

    /// A session with the ranger on pad A, optionally the beacon on pad B,
    /// and its stationary target parked in the band between the two ranges.
    LevelSession scene({required bool beacon, required double dt}) {
      final session = _session();
      session.buildTower('pad_a', testRanger);
      if (beacon) {
        session.buildTower('pad_b', testBeacon);
      }
      session.startNextWave();
      _advanceUntil(session, () => session.enemies.isNotEmpty, dt);
      session.enemies.single.distanceAlongRoute = parkedDistance;
      return session;
    }

    test('an unbuffed ranger cannot reach the parked target', () {
      final session = scene(beacon: false, dt: 1 / 60);
      final enemy = session.enemies.single;

      for (var frame = 0; frame < 180; frame++) {
        session.advance(1 / 60);
      }

      expect(enemy.health, 100, reason: 'no shot may land outside base range');
      expect(
        _drain(session).where((event) => event.kind == LevelEventKind.hit),
        isEmpty,
      );
    });

    test('a buffed ranger fires at what its drawn circle shows', () {
      final session = scene(beacon: true, dt: 1 / 60);
      final enemy = session.enemies.single;

      _advanceUntil(session, () => enemy.health < 100, 1 / 60);

      // One ranger hit of 18: the beacon widened reach, not damage.
      expect(enemy.health, 82);
    });

    test('the widened shot resolves identically at every frame rate', () {
      for (final dt in const [1 / 60, 1 / 30, 1 / 10]) {
        final session = scene(beacon: true, dt: dt);
        final enemy = session.enemies.single;

        var frames = 0;
        while (enemy.health == 100) {
          session.advance(dt);
          frames += 1;
          if (frames > 600) {
            fail('no shot landed within ten simulated seconds at dt $dt');
          }
        }

        expect(
          enemy.health,
          82,
          reason: 'the aura must not depend on the step size (dt $dt)',
        );
      }
    });
  });
}
