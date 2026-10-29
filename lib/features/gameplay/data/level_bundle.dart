import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';

/// Everything one level needs, resolved and validated against each other.
///
/// Passing a bundle around (instead of three lookups) guarantees a session can
/// never start with a map or enemy set that the level does not reference.
@immutable
class LevelBundle {
  const LevelBundle({
    required this.level,
    required this.map,
    required this.enemies,
    required this.towers,
  });

  final LevelDefinition level;
  final MapDefinition map;
  final EnemyCatalog enemies;

  /// Towers the player may build during this level.
  final TowerCatalog towers;
}
