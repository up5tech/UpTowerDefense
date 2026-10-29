import 'package:up_tower_defense/features/gameplay/domain/models/enemy_state.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_level_stats.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

/// One shot in flight, owned by the level session.
///
/// Projectiles are simulation state rather than a rendering detail: whether a
/// shot lands is a gameplay fact that must behave identically at any frame
/// rate, so the position is advanced by `LevelSession` with the same delta as
/// the rest of the combat step (ADR 0001).
class ProjectileState {
  ProjectileState({
    required this.instanceId,
    required this.towerInstanceId,
    required this.position,
    required this.destination,
    required this.target,
    required this.speed,
    required this.damage,
    required this.splashRadius,
    required this.slow,
    required this.colorValue,
  });

  /// Identifier unique within one level attempt.
  final int instanceId;

  /// Tower that fired this shot, so effects can be attributed to it.
  final int towerInstanceId;

  /// Current world position.
  WorldPoint position;

  /// Where the shot is flying right now.
  ///
  /// Follows the live target every frame and freezes at its last known
  /// position once the target is resolved, so a shot whose target died still
  /// finishes its arc instead of chasing an entity that no longer exists.
  WorldPoint destination;

  /// The enemy this shot was fired at; checked for liveness every frame.
  final EnemyState target;

  /// Travel speed in world units per second, from the tower definition.
  final double speed;

  /// Damage dealt on a live hit, from the tower level that fired it.
  /// Splash applies the same value to every victim, with no falloff.
  final double damage;

  /// Blast radius in world units; 0 means the hit only touches its target.
  final double splashRadius;

  /// The slow this shot applies on hit, or null for a plain damage shot.
  /// Copied at fire time so an upgrade mid-flight cannot change a shot that
  /// the player already committed.
  final SlowSpec? slow;

  /// Body colour as 0xAARRGGBB, copied at fire time so the renderer needs no
  /// tower lookup to draw the shot.
  final int colorValue;

  @override
  String toString() =>
      'ProjectileState#$instanceId(from tower $towerInstanceId)';
}
