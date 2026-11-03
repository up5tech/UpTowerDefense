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
    this.chainCount = 0,
    this.chainRadius = 0,
    this.chainFalloff = 1,
    this.auraRadius = 0,
    this.auraRangeBonus = 0,
  });

  /// Sentinel for [copyWith]: a plain `null` argument would otherwise be
  /// indistinguishable from "keep the field I already have".
  static const Object _keep = Object();

  /// Damage per hit; splash applies the same value with no falloff.
  final double damage;

  /// Attack radius in world units, measured from the pad centre.
  ///
  /// This is the tower's own reach. The reach it *fights* with may be larger
  /// when a Beacon's aura covers the pad — `LevelSession.effectiveStatsFor`
  /// folds that in, and every reader of range goes through it (D64).
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

  /// Number of enemies one shot arcs to after its primary hit; 0 = no chain.
  ///
  /// Each jump lands `chainFalloff` times further from the previous victim's
  /// damage, so a chain is worth something against a crowd and almost nothing
  /// against a lone target — the trade the Arc tower is built around.
  final int chainCount;

  /// Jump radius in world units: the farthest a chain may leap from the
  /// victim it is jumping *from*. Unused while [chainCount] is 0.
  final double chainRadius;

  /// Damage multiplier applied per jump, in (0, 1]. Unused while [chainCount]
  /// is 0. The n-th jump deals `damage × chainFalloffⁿ`.
  final double chainFalloff;

  /// Aura radius in world units, measured from the beacon's pad centre; 0 = no
  /// aura. Towers whose pad centre falls inside it fight with a widened range.
  final double auraRadius;

  /// Fraction of range the aura adds, in (0, 1); 0 = no aura. Effective range
  /// is `range × (1 + bonus)` with the *strongest* covering aura only, so two
  /// beacons never compound (D64).
  final double auraRangeBonus;

  /// Returns these stats with the given fields replaced.
  ///
  /// Added for the aura: a buffed range is a derived value that must never be
  /// written back into a shared definition, so the reader gets a copy instead
  /// (D64). [slow] and [upgradeCost] are nullable, so they take [_keep] (the
  /// default) to mean "unchanged" and a literal `null` to clear.
  TowerLevelStats copyWith({
    double? damage,
    double? range,
    double? fireCooldownSeconds,
    double? projectileSpeed,
    double? splashRadius,
    Object? slow = _keep,
    Object? upgradeCost = _keep,
    int? chainCount,
    double? chainRadius,
    double? chainFalloff,
    double? auraRadius,
    double? auraRangeBonus,
  }) {
    return TowerLevelStats(
      damage: damage ?? this.damage,
      range: range ?? this.range,
      fireCooldownSeconds: fireCooldownSeconds ?? this.fireCooldownSeconds,
      projectileSpeed: projectileSpeed ?? this.projectileSpeed,
      splashRadius: splashRadius ?? this.splashRadius,
      slow: identical(slow, _keep) ? this.slow : slow as SlowSpec?,
      upgradeCost: identical(upgradeCost, _keep)
          ? this.upgradeCost
          : upgradeCost as int?,
      chainCount: chainCount ?? this.chainCount,
      chainRadius: chainRadius ?? this.chainRadius,
      chainFalloff: chainFalloff ?? this.chainFalloff,
      auraRadius: auraRadius ?? this.auraRadius,
      auraRangeBonus: auraRangeBonus ?? this.auraRangeBonus,
    );
  }

  @override
  String toString() =>
      'TowerLevelStats(dmg $damage, range $range, cd $fireCooldownSeconds)';
}
