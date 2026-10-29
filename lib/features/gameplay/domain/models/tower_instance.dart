import 'package:up_tower_defense/features/gameplay/domain/models/targeting_policy.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_level_stats.dart';

/// One tower built during a level attempt.
///
/// The pad is part of the identity: a level has at most one tower per pad, so
/// the pad id doubles as the occupancy key in `LevelSession`.
///
/// Definition stats stay immutable; everything here is per-tower runtime state
/// (level, invested gold, priority, cooldown) and is never written back into
/// the shared `TowerDefinition`, so the class deliberately is not `@immutable`.
class TowerInstance {
  TowerInstance({
    required this.instanceId,
    required this.padId,
    required this.definition,
    required int buildCost,
  }) : investedGold = buildCost;

  /// Identifier unique within one level attempt.
  final int instanceId;

  /// Build pad the tower occupies.
  final String padId;

  /// Immutable stats this tower uses.
  final TowerDefinition definition;

  /// Current level, 1-based; the shared stats come from [stats].
  int level = 1;

  /// Total gold spent on this tower (build plus every upgrade).
  ///
  /// The sell refund is a share of this number, so the accounting is exact no
  /// matter how the tower was improved.
  int investedGold;

  /// Which enemy this tower prefers while several are in range.
  TargetingPolicy targetingPolicy = TargetingPolicy.first;

  /// Seconds of simulation time until this tower may fire again.
  ///
  /// Starts at zero so a freshly built tower shoots as soon as a target is in
  /// range, and counts down only while the level is playing.
  double cooldownRemaining = 0;

  /// Stats for the current level.
  TowerLevelStats get stats => definition.levelAt(level);

  bool get isMaxLevel => level >= definition.maxLevel;

  /// Cost of the next upgrade, or null at the max level.
  int? get nextUpgradeCost => definition.upgradeCostFor(level);

  /// Whether [gold] can pay for the next upgrade right now.
  bool isUpgradeAffordableWith(int gold) {
    final cost = nextUpgradeCost;
    return cost != null && gold >= cost;
  }

  @override
  String toString() =>
      'TowerInstance#$instanceId(${definition.id} L$level on $padId)';
}
