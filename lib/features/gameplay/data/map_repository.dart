import 'package:flutter/services.dart';
import 'package:up_tower_defense/features/gameplay/data/asset_loader.dart';
import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/content_load_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/map_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/domain/map_validation.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';

/// Loads map definitions from bundled assets.
///
/// Maps are local files; nothing here touches the network. The bundle is
/// injectable so tests can serve fixtures without touching the real asset
/// bundle.
class MapRepository {
  MapRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Loads, decodes and validates the map at [assetPath].
  ///
  /// Throws [ContentLoadException] with a readable reason when the asset is
  /// missing, malformed, or fails validation.
  Future<MapDefinition> load(String assetPath) async {
    final source = await readAssetText(_bundle, assetPath);

    final MapDefinition map;
    try {
      map = MapJsonDecoder.decode(source);
    } on ContentFormatException catch (error) {
      throw ContentLoadException(assetPath, error.message);
    }

    final validation = const MapValidator().validate(map);
    if (!validation.isValid) {
      throw ContentLoadException(
        assetPath,
        'map "${map.id}" failed validation',
        issues: validation.issues,
      );
    }

    return map;
  }
}
