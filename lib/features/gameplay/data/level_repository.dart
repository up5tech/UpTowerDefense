import 'package:flutter/services.dart';
import 'package:up_tower_defense/features/gameplay/data/asset_loader.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/content_load_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/data/level_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/data/map_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_repository.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_validation.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';

/// Loads a level together with the map and enemy catalog it references.
class LevelRepository {
  LevelRepository({
    required this.mapRepository,
    required this.enemyRepository,
    required this.towerRepository,
    AssetBundle? bundle,
  }) : _bundle = bundle ?? rootBundle;

  /// Catalog the level's `mapId` is resolved against.
  final MapRepository mapRepository;

  /// Catalog the level's waves are resolved against.
  final EnemyRepository enemyRepository;

  /// Catalog the player builds from during the level.
  final TowerRepository towerRepository;

  final AssetBundle _bundle;

  /// Loads, decodes and validates the level at [assetPath].
  ///
  /// A level whose `mapId` is not in the catalog, or whose waves reference an
  /// unknown enemy, fails here instead of at spawn time.
  Future<LevelBundle> load(String assetPath) async {
    final source = await readAssetText(_bundle, assetPath);

    final LevelDefinition level;
    try {
      level = LevelJsonDecoder.decode(source);
    } on ContentFormatException catch (error) {
      throw ContentLoadException(assetPath, error.message);
    }

    final mapAsset = ContentCatalog.mapAssetFor(level.mapId);
    if (mapAsset == null) {
      throw ContentLoadException(
        assetPath,
        'level references unknown map "${level.mapId}"',
      );
    }

    final map = await mapRepository.load(mapAsset);
    final enemies = await enemyRepository.load(ContentCatalog.enemies);
    final towers = await towerRepository.load(ContentCatalog.towers);

    final validation = const LevelValidator().validate(
      level: level,
      map: map,
      enemies: enemies,
    );
    if (!validation.isValid) {
      throw ContentLoadException(
        assetPath,
        'level "${level.id}" failed validation',
        issues: validation.issues,
      );
    }

    return LevelBundle(
      level: level,
      map: map,
      enemies: enemies,
      towers: towers,
    );
  }
}
