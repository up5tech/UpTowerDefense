import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/speed_surge.dart';

/// Immutable stats for one enemy type.
///
/// Shared by every instance of the type: runtime health and route progress live
/// in `EnemyState`, never here.
@immutable
class EnemyDefinition {
  const EnemyDefinition({
    required this.id,
    required this.displayName,
    required this.maxHealth,
    required this.speed,
    required this.coreDamageOnLeak,
    required this.rewardGold,
    required this.radius,
    required this.colorValue,
    this.isBoss = false,
    this.speedSurge,
    this.flatDamageReduction = 0,
    this.splitInto,
  });

  /// Stable identifier used by waves and saves.
  final String id;

  /// Player-facing name, used by the codex.
  final String displayName;

  /// Health an instance starts with.
  final double maxHealth;

  /// Movement speed in world units per second.
  final double speed;

  /// Core health lost when this enemy reaches the end of the route.
  final int coreDamageOnLeak;

  /// Gold granted when this enemy is defeated. Leaking pays nothing, so a
  /// mistake costs health and income at the same time.
  final int rewardGold;

  /// Draw radius in world units; also the visual "weight" of the enemy.
  final double radius;

  /// Body colour as 0xAARRGGBB, so the domain stays free of Flutter types.
  final int colorValue;

  /// Whether this is a boss, which is what makes [speedSurge] legal content.
  ///
  /// A marker rather than an inferred fact: the surge fields must be rejected on
  /// the ordinary roster, and "is this a boss" cannot be read back out of the
  /// fields it is supposed to gate (D69).
  final bool isBoss;

  /// The one-shot speed burst this enemy gains when badly hurt, if any.
  final SpeedSurge? speedSurge;

  /// Health every single hit loses before it touches this enemy, in
  /// `[0, maxHealth)`; 0 means nothing is ignored.
  ///
  /// Flat rather than a percentage on purpose: a fixed shield makes many weak
  /// hits underperform while one heavy hit pays the same price for getting
  /// through, which is what gives splash and the Arc chain a job no tower
  /// currently has. It is subtracted inside the single damage path, after the
  /// chill amplifier, and floored at zero — a hit the shield absorbs removes
  /// nothing, it never heals.
  final double flatDamageReduction;

  /// What spawns where this enemy died, if it splits; null for the roster
  /// that does not.
  final SplitSpec? splitInto;

  @override
  String toString() =>
      'EnemyDefinition($id, hp $maxHealth, ${speed}u/s'
      '${speedSurge == null ? '' : ', $speedSurge'})';
}

/// Two children of the same type spawned at a splitter's death point.
///
/// Data rather than a rule: which enemy comes out and how many is authored
/// content, so a splitter can spawn grunts or runners without a code change,
/// and `EnemyValidator` keeps the graph acyclic (a splitter may only split
/// into an enemy that does not itself split).
@immutable
class SplitSpec {
  const SplitSpec({required this.enemyId, required this.count});

  /// Id of the enemy to spawn, resolved against the same catalog.
  final String enemyId;

  /// How many children appear at the parent's route progress; at least one.
  final int count;

  @override
  String toString() => 'SplitSpec($count x $enemyId)';
}

/// Lookup for every enemy type the loaded content can spawn.
@immutable
class EnemyCatalog {
  EnemyCatalog(Iterable<EnemyDefinition> definitions)
    : _byId = Map.unmodifiable({
        for (final definition in definitions) definition.id: definition,
      });

  final Map<String, EnemyDefinition> _byId;

  /// The definition with [id], or null when the catalog does not contain it.
  EnemyDefinition? operator [](String id) => _byId[id];

  /// Whether [id] resolves to a definition.
  bool contains(String id) => _byId.containsKey(id);

  /// All definitions, ordered by id for stable diagnostics and tests.
  List<EnemyDefinition> get all =>
      _byId.values.toList()..sort((a, b) => a.id.compareTo(b.id));

  /// Number of enemy types in the catalog.
  int get length => _byId.length;
}
