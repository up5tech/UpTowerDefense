import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/map_geometry.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_state.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/targeting_policy.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';
import 'package:up_tower_defense/features/gameplay/domain/targeting_system.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

/// Pad A sits 120 units from the vertical route segment at x=300, so a 210-unit
/// range from its centre covers route distances from roughly 23 to 540.
const WorldPoint _origin = WorldPoint(180, 360);
const double _range = 210;

final MapGeometry _geometry = MapGeometry(testMap);

EnemyState _enemy(
  int instanceId,
  double distanceAlongRoute, {
  double? health,
}) {
  return EnemyState(
    instanceId: instanceId,
    definition: testGrunt,
    distanceAlongRoute: distanceAlongRoute,
    health: health,
  );
}

EnemyState? _acquire(
  List<EnemyState> enemies, [
  TargetingPolicy policy = TargetingPolicy.first,
]) {
  return const TargetingSystem().acquire(
    geometry: _geometry,
    origin: _origin,
    range: _range,
    enemies: enemies,
    policy: policy,
  );
}

void main() {
  group('First', () {
    test('picks the enemy furthest along the route', () {
      // 120 -> (120, 500): ~167 units away. 250 -> (250, 500): ~156 away, but
      // "First" is about route progress, not proximity to the tower.
      final leading = _enemy(1, 250);
      final trailing = _enemy(2, 120);

      expect(_acquire([trailing, leading]), same(leading));
      expect(_acquire([leading, trailing]), same(leading));
    });

    test('breaks ties on the same route distance by instance id', () {
      final first = _enemy(1, 200);
      final second = _enemy(2, 200);

      expect(_acquire([second, first]), same(first));
      expect(_acquire([first, second]), same(first));
    });
  });

  group('Strongest', () {
    test('picks the enemy with the most current health', () {
      final tough = _enemy(1, 120, health: 90);
      final weak = _enemy(2, 300, health: 30);

      expect(_acquire([weak, tough], TargetingPolicy.strongest), same(tough));
      expect(_acquire([tough, weak], TargetingPolicy.strongest), same(tough));
    });

    test('breaks health ties by instance id', () {
      final first = _enemy(1, 150, health: 50);
      final second = _enemy(2, 250, health: 50);

      expect(
        _acquire([second, first], TargetingPolicy.strongest),
        same(first),
      );
    });

    test('ignores route position entirely', () {
      // The leader is barely hurt; the trailer is nearly dead. Strongest must
      // still pick the healthy one even though First would do the opposite.
      final leader = _enemy(1, 400, health: 5);
      final fresh = _enemy(2, 100, health: 100);

      expect(
        _acquire([leader, fresh], TargetingPolicy.strongest),
        same(fresh),
      );
      // First is the default policy in this helper.
      expect(_acquire([leader, fresh]), same(leader));
    });
  });

  group('shared rules', () {
    test('returns nothing when every enemy is out of range', () {
      // Distance 0 is the route entry at (0, 500), ~228 units from pad A.
      expect(_acquire([_enemy(1, 0)]), isNull);
      expect(_acquire([_enemy(1, 0)], TargetingPolicy.strongest), isNull);
    });

    test('ignores enemies out of range even when they lead', () {
      // The entry (distance 0) is out of range; the second enemy at 120 is in.
      final inRange = _enemy(2, 120);

      expect(_acquire([_enemy(1, 0), inRange]), same(inRange));
      expect(
        _acquire([_enemy(1, 0), inRange], TargetingPolicy.strongest),
        same(inRange),
      );
    });

    test('never targets a resolved or dead enemy', () {
      final resolved = _enemy(1, 300)..resolved = true;
      final dead = _enemy(2, 280)..health = 0;
      final alive = _enemy(3, 120);

      expect(_acquire([resolved, dead, alive]), same(alive));
      expect(_acquire([resolved, dead]), isNull);
      expect(
        _acquire([resolved, dead, alive], TargetingPolicy.strongest),
        same(alive),
      );
      expect(_acquire([resolved, dead], TargetingPolicy.strongest), isNull);
    });
  });
}
