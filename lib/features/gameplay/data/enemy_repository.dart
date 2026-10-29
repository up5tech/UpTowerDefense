import 'package:flutter/services.dart';
import 'package:up_tower_defense/features/gameplay/data/asset_loader.dart';
import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/content_load_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/domain/enemy_validation.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';

/// Loads and validates the bundled enemy catalog.
class EnemyRepository {
  EnemyRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Loads the catalog at [assetPath].
  ///
  /// Throws [ContentLoadException] when the file is missing, malformed, or any
  /// definition is invalid.
  Future<EnemyCatalog> load(String assetPath) async {
    final source = await readAssetText(_bundle, assetPath);

    final List<EnemyDefinition> definitions;
    try {
      definitions = EnemyJsonDecoder.decode(source);
    } on ContentFormatException catch (error) {
      throw ContentLoadException(assetPath, error.message);
    }

    final validation = const EnemyValidator().validate(definitions);
    if (!validation.isValid) {
      throw ContentLoadException(
        assetPath,
        'enemy catalog failed validation',
        issues: validation.issues,
      );
    }

    return EnemyCatalog(definitions);
  }
}
