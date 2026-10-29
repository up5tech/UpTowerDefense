import 'package:meta/meta.dart';

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

  @override
  String toString() => 'EnemyDefinition($id, hp $maxHealth, ${speed}u/s)';
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
