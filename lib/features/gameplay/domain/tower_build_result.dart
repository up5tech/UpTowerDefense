import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_instance.dart';

/// Why a build request was refused.
///
/// The reason is returned to the caller instead of merely logged, so the UI can
/// explain a disabled option and tests can assert the exact rule that fired.
enum TowerBuildBlocker {
  /// The level is already won or lost.
  levelEnded,

  /// No build pad with the requested id exists on the map.
  unknownPad,

  /// Another tower already occupies the pad.
  padOccupied,

  /// The player does not have enough gold.
  insufficientGold,
}

/// Outcome of one build request.
///
/// A failed request never changed gold or pad occupancy: the session deducts only
/// after every rule passed, which is what makes building transactional.
@immutable
class TowerBuildResult {
  const TowerBuildResult.built(TowerInstance this.tower)
    : blocker = null,
      missingGold = 0;

  const TowerBuildResult.refused(
    TowerBuildBlocker this.blocker, {
    this.missingGold = 0,
  }) : tower = null;

  /// The tower that was created, or null when the build was refused.
  final TowerInstance? tower;

  /// The rule that refused the build, or null on success.
  final TowerBuildBlocker? blocker;

  /// How much more gold the player needed; only set for
  /// [TowerBuildBlocker.insufficientGold].
  final int missingGold;

  /// Whether the tower now exists on the pad.
  bool get isBuilt => tower != null;

  @override
  String toString() => isBuilt
      ? 'TowerBuildResult(built $tower)'
      : 'TowerBuildResult(refused $blocker, missing $missingGold gold)';
}
