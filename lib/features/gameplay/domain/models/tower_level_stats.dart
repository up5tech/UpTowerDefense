import 'package:meta/meta.dart';

/// How a Frost-style hit slows its victims.
///
/// Every knob is data rather than code, so a future tower can slow harder,
/// longer, or hurt what it chills without touching the rules layer.
@immutable
class SlowSpec {
  const SlowSpec({
    required this.magnitude,
    required this.durationSeconds,
    required this.minSpeedRatio,
    this.damageAmp = 0,
  });

  /// Fraction of base speed removed while slowed, in (0, 1].
  /// A 0.4 magnitude makes a target move at 60% of its base speed.
  final double magnitude;

  /// Simulation seconds the slow lasts; refreshed on every new hit.
  final double durationSeconds;

  /// Hard floor for the resulting speed as a fraction of base speed.
  ///
  /// This is the cap the design doc requires: no amount of slow ever takes an
  /// enemy below `speed * minSpeedRatio`, so a swarm of slow towers can never
  /// freeze a target in place.
  final double minSpeedRatio;

  /// Extra damage fraction the chilled target takes from every source while
  /// this slow is active, in [0, 1]; 0 means the chill only moves it.
  ///
  /// A 0.25 amplifier turns a 26-damage shell into 32.5 health removed from a
  /// chilled enemy. It exists so a control tower pays off through the damage
  /// its allies land instead of through its own negligible numbers, and it is
  /// read inside the single damage path, so shots and splash can never disagree
  /// about whether it applied.
  final double damageAmp;
}

/// The combat numbers of one tower level.
///
/// Immutable and shared: which instance is at which level lives in
/// `TowerInstance`. The first entry of a tower's `levels` list doubles as its
/// base stats, and each entry carries the cost of reaching the level *after*
/// it (null on the max level).
@immutable
class TowerLevelStats {
  const TowerLevelStats({
    required this.damage,
    required this.range,
    required this.fireCooldownSeconds,
    required this.projectileSpeed,
    this.splashRadius = 0,
    this.slow,
    this.upgradeCost,
  });

  /// Damage per hit; splash applies the same value with no falloff.
  final double damage;

  /// Attack radius in world units, measured from the pad centre.
  final double range;

  /// Simulation-time gap between two shots, in seconds.
  final double fireCooldownSeconds;

  /// Travel speed of a shot in world units per second.
  final double projectileSpeed;

  /// Blast radius in world units; 0 means the hit only touches its target.
  final double splashRadius;

  /// The slow this level's hits apply, or null for a tower that only damages.
  final SlowSpec? slow;

  /// Gold cost to reach the level after this one; null on the max level.
  final int? upgradeCost;

  @override
  String toString() =>
      'TowerLevelStats(dmg $damage, range $range, cd $fireCooldownSeconds)';
}
