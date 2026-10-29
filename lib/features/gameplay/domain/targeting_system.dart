import 'package:up_tower_defense/features/gameplay/domain/map_geometry.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_state.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/targeting_policy.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

/// Target acquisition for tower attacks.
///
/// Pure functions over the active enemy list, so the policy that decides *who*
/// gets shot is testable at exact coordinates without running a frame of the
/// game. Both MVP policies share one scan, so range and liveness rules can
/// never drift apart between them.
class TargetingSystem {
  const TargetingSystem();

  /// The enemy this tower should shoot, according to [policy].
  ///
  /// Returns null when nothing live is in range, so a tower never aims at
  /// something it cannot reach.
  EnemyState? acquire({
    required MapGeometry geometry,
    required WorldPoint origin,
    required double range,
    required List<EnemyState> enemies,
    required TargetingPolicy policy,
  }) {
    final inRange = _scan(geometry, origin, range, enemies);
    if (inRange.isEmpty) {
      return null;
    }

    switch (policy) {
      case TargetingPolicy.first:
        return _pick(inRange, (enemy) => -enemy.distanceAlongRoute);
      case TargetingPolicy.strongest:
        return _pick(inRange, (enemy) => -enemy.health);
    }
  }

  /// Every live enemy within [range] of [origin].
  List<EnemyState> _scan(
    MapGeometry geometry,
    WorldPoint origin,
    double range,
    List<EnemyState> enemies,
  ) {
    final result = <EnemyState>[];
    for (final enemy in enemies) {
      if (enemy.resolved || enemy.health <= 0) {
        continue;
      }
      final position = geometry.pointAtDistance(enemy.distanceAlongRoute);
      if (origin.distanceTo(position) <= range) {
        result.add(enemy);
      }
    }
    return result;
  }

  /// The enemy with the lowest [key] value; ties go to the lower instance id.
  ///
  /// Keys are negated values (furthest route distance, highest health), and
  /// the instance-id tie-break makes the choice independent of list order, so
  /// tests stay stable.
  EnemyState? _pick(
    List<EnemyState> candidates,
    double Function(EnemyState enemy) key,
  ) {
    EnemyState? best;
    var bestKey = 0.0;

    for (final enemy in candidates) {
      final value = key(enemy);
      if (best == null ||
          value < bestKey ||
          (value == bestKey && enemy.instanceId < best.instanceId)) {
        best = enemy;
        bestKey = value;
      }
    }

    return best;
  }
}
