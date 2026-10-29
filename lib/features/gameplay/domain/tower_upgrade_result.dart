import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_instance.dart';

/// Why an upgrade request was refused.
///
/// Returned instead of merely logged, so the UI can disable or explain the
/// button and tests can assert the exact rule that fired.
enum TowerUpgradeBlocker {
  /// The level is already won or lost.
  levelEnded,

  /// No build pad with the requested id exists on the map.
  unknownPad,

  /// The pad is empty: there is nothing to upgrade.
  padEmpty,

  /// The tower is already at its maximum level.
  maxLevel,

  /// The player does not have enough gold.
  insufficientGold,
}

/// Outcome of one upgrade request.
///
/// A refused request never changed gold or the tower: the session deducts only
/// after every rule passed, which makes upgrading transactional exactly like
/// building.
@immutable
class TowerUpgradeResult {
  const TowerUpgradeResult.upgraded(
    TowerInstance this.tower, {
    required this.goldSpent,
  }) : blocker = null;

  const TowerUpgradeResult.refused(
    TowerUpgradeBlocker this.blocker, {
    this.goldSpent = 0,
  }) : tower = null;

  /// The tower that was upgraded, or null when the request was refused.
  final TowerInstance? tower;

  /// The rule that refused the upgrade, or null on success.
  final TowerUpgradeBlocker? blocker;

  /// Gold deducted; only set on success.
  final int goldSpent;

  /// Whether the tower gained a level.
  bool get isUpgraded => tower != null;

  @override
  String toString() => isUpgraded
      ? 'TowerUpgradeResult(upgraded $tower, $goldSpent gold)'
      : 'TowerUpgradeResult(refused $blocker)';
}
