import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';

/// Runtime state of one spawned enemy.
///
/// Mutable by design and owned by the level session: two enemies of the same
/// type never share a definition-level value, and a shared `EnemyDefinition` is
/// never mutated to represent one instance.
class EnemyState {
  EnemyState({
    required this.instanceId,
    required this.definition,
    this.distanceAlongRoute = 0,
    double? health,
  }) : health = health ?? definition.maxHealth;

  /// Identifier unique within one level attempt.
  final int instanceId;

  /// Immutable stats this instance uses.
  final EnemyDefinition definition;

  /// Progress along the route in world units; the authoritative position.
  double distanceAlongRoute;

  /// Current health; clamped at zero by the damage rules.
  double health;

  /// Whether this enemy has been resolved (defeated or leaked) and removed.
  bool resolved = false;

  /// Magnitude of the slow currently affecting this enemy, in (0, 1].
  /// Zero means not slowed.
  double slowMagnitude = 0;

  /// Simulation seconds left before the slow expires.
  double slowRemainingSeconds = 0;

  /// Speed floor of the active slow as a fraction of base speed; only
  /// meaningful while [slowMagnitude] is positive.
  double slowMinSpeedRatio = 1;

  /// Extra damage fraction of the active slow, in [0, 1]; zero when there is
  /// none.
  ///
  /// Refreshed together with the slow by the same strongest-wins rule, and
  /// only consulted while [isSlowed] — an expired chill stops amplifying
  /// before its stored numbers are cleared.
  double slowDamageAmp = 0;

  /// Whether a slow is currently affecting this enemy.
  bool get isSlowed => slowMagnitude > 0 && slowRemainingSeconds > 0;

  /// Whether the boss surge has already fired; it fires at most once a life.
  bool surgeSpent = false;

  /// Simulation seconds of speed surge left; zero when not surging.
  double surgeRemainingSeconds = 0;

  /// Whether the boss's one-shot speed burst is currently active.
  bool get isSurging => surgeRemainingSeconds > 0;

  /// Starts the definition's surge if it has one, has not fired, and health has
  /// fallen to the arming threshold.
  ///
  /// Returns whether it fired, so a caller (or a test) can tell "the boss just
  /// crossed half health" from "nothing happened" without reading three fields.
  bool tryStartSpeedSurge() {
    final surge = definition.speedSurge;
    if (surge == null || surgeSpent) {
      return false;
    }
    if (!surge.armsAt(health, definition.maxHealth)) {
      return false;
    }
    surgeSpent = true;
    surgeRemainingSeconds = surge.durationSeconds;
    return true;
  }

  /// Unmodified speed for this instant: the definition's speed, or that speed
  /// times the surge multiplier while the burst lasts. Slows are applied on top
  /// by [currentSpeed].
  double get _baseSpeed {
    final surge = definition.speedSurge;
    if (surge == null || !isSurging) {
      return definition.speed;
    }
    return definition.speed * surge.multiplier;
  }

  /// Movement speed right now, in world units per second.
  ///
  /// A slow removes the current base speed multiplied by [slowMagnitude] but
  /// never takes the result below the slow's configured floor, so stacking slow
  /// towers cannot freeze a target. The surge is part of that base, which means a
  /// chilled boss still accelerates when it turns — the chill throttles whatever
  /// speed it has rather than cancelling the authored escalation.
  double get currentSpeed {
    final base = _baseSpeed;
    if (!isSlowed) {
      return base;
    }
    final slowed = base * (1 - slowMagnitude);
    return slowed < base * slowMinSpeedRatio
        ? base * slowMinSpeedRatio
        : slowed;
  }

  @override
  String toString() =>
      'EnemyState#$instanceId(${definition.id} @ '
      '${distanceAlongRoute.toStringAsFixed(1)}u)';
}
