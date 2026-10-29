import 'package:flutter/services.dart';
import 'package:up_tower_defense/features/gameplay/data/asset_loader.dart';
import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/content_load_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/tower_validation.dart';

/// Loads and validates the bundled tower catalog.
class TowerRepository {
  TowerRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Loads the catalog at [assetPath].
  ///
  /// Throws [ContentLoadException] when the file is missing, malformed, or any
  /// definition is invalid.
  Future<TowerCatalog> load(String assetPath) async {
    final source = await readAssetText(_bundle, assetPath);

    final List<TowerDefinition> definitions;
    try {
      definitions = TowerJsonDecoder.decode(source);
    } on ContentFormatException catch (error) {
      throw ContentLoadException(assetPath, error.message);
    }

    final validation = const TowerValidator().validate(definitions);
    if (!validation.isValid) {
      throw ContentLoadException(
        assetPath,
        'tower catalog failed validation',
        issues: validation.issues,
      );
    }

    return TowerCatalog(definitions);
  }
}
