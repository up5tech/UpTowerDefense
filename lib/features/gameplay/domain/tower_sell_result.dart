import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';

/// Why a sell request was refused.
enum TowerSellBlocker {
  /// The level is already won or lost.
  levelEnded,

  /// No build pad with the requested id exists on the map.
  unknownPad,

  /// The pad is empty: there is nothing to sell.
  padEmpty,
}

/// Outcome of one sell request.
///
/// The refund is computed from the definition's policy and the gold actually
/// invested, so the player sees the same number the session pays — and a
/// refused sell leaves the tower exactly where it was.
@immutable
class TowerSellResult {
  const TowerSellResult.sold({
    required this.padId,
    required this.towerDefinition,
    required this.refundGold,
    required this.investedGold,
  }) : blocker = null;

  const TowerSellResult.refused(TowerSellBlocker this.blocker)
    : padId = null,
      towerDefinition = null,
      refundGold = 0,
      investedGold = 0;

  /// The pad that is free again after the sale.
  final String? padId;

  /// The definition of the tower that was sold, for its refund policy.
  final TowerDefinition? towerDefinition;

  /// Gold paid back for the sold tower.
  final int refundGold;

  /// Gold the tower had invested in total, before the refund.
  final int investedGold;

  /// The rule that refused the sell, or null on success.
  final TowerSellBlocker? blocker;

  /// Whether the tower was removed and the gold paid back.
  bool get isSold => padId != null;

  @override
  String toString() => isSold
      ? 'TowerSellResult(sold $padId, +$refundGold g of $investedGold)'
      : 'TowerSellResult(refused $blocker)';
}
