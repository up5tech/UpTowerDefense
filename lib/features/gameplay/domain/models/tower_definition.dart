import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_level_stats.dart';

/// Immutable stats for one tower type.
///
/// Shared by every tower of the type: which pad it sits on, its current level
/// and its invested gold live in `TowerInstance`, never here.
///
/// Every number the player sees in the build panel and the tower panel comes
/// from this definition, so balancing never requires touching UI or combat
/// code. [levels] holds one entry per upgrade level; the first entry is also
/// the base stats, which the scalar getters expose for code that only cares
/// about a freshly built tower.
@immutable
class TowerDefinition {
  const TowerDefinition({
    required this.id,
    required this.displayName,
    required this.role,
    required this.description,
    required this.buildCost,
    required this.levels,
    required this.sellRefundRate,
    required this.colorValue,
  });

  /// Stable identifier used by builds and saves.
  final String id;

  /// Player-facing name, for example `Ranger Tower`.
  final String displayName;

  /// Short role line shown next to the name, for example `Fast single target`.
  final String role;

  /// One sentence describing what the tower is for.
  final String description;

  /// Gold deducted when the tower is built; integer to keep the economy exact.
  final int buildCost;

  /// Combat stats per level, index 0 = level 1. Never empty.
  final List<TowerLevelStats> levels;

  /// Share of invested gold returned when the tower is sold, in [0, 1].
  final double sellRefundRate;

  /// Body colour as 0xAARRGGBB, so the domain stays free of Flutter types.
  final int colorValue;

  /// Stats of the base (level 1) build.
  TowerLevelStats get baseStats => levels.first;

  double get damage => baseStats.damage;

  double get range => baseStats.range;

  double get fireCooldownSeconds => baseStats.fireCooldownSeconds;

  double get projectileSpeed => baseStats.projectileSpeed;

  /// Highest level this tower can reach; at least 1.
  int get maxLevel => levels.length;

  /// Stats for 1-based [level]; out-of-range values clamp to the nearest
  /// valid level, so bad runtime state degrades instead of crashing.
  TowerLevelStats levelAt(int level) {
    final index = (level - 1).clamp(0, levels.length - 1);
    return levels[index];
  }

  /// Gold cost to go from [level] to the next one, or null at the max level.
  int? upgradeCostFor(int level) {
    if (level < 1 || level >= levels.length) {
      return null;
    }
    return levels[level - 1].upgradeCost;
  }

  /// Gold returned for selling a tower that has [investedGold] gold in it.
  ///
  /// Floored to an integer: refunds never invent fractions of a gold piece.
  int refundForInvested(int investedGold) {
    return (investedGold * sellRefundRate).floor();
  }

  /// Whether [gold] is enough to build this tower.
  bool isAffordableWith(int gold) => gold >= buildCost;

  @override
  String toString() => 'TowerDefinition($id, ${buildCost}g, $maxLevel levels)';
}

/// Lookup for every tower type the player may build.
@immutable
class TowerCatalog {
  TowerCatalog(Iterable<TowerDefinition> definitions)
    : _byId = Map.unmodifiable({
        for (final definition in definitions) definition.id: definition,
      });

  final Map<String, TowerDefinition> _byId;

  /// The definition with [id], or null when the catalog does not contain it.
  TowerDefinition? operator [](String id) => _byId[id];

  /// Whether [id] resolves to a definition.
  bool contains(String id) => _byId.containsKey(id);

  /// All definitions ordered by build cost, then id, so the build panel lists
  /// the cheapest option first and the order never depends on file layout.
  List<TowerDefinition> get all {
    final definitions = _byId.values.toList();
    definitions.sort((a, b) {
      final byCost = a.buildCost.compareTo(b.buildCost);
      return byCost != 0 ? byCost : a.id.compareTo(b.id);
    });
    return definitions;
  }

  /// Number of tower types in the catalog.
  int get length => _byId.length;
}
