import 'package:flutter/services.dart';
import 'package:up_tower_defense/features/campaign/data/campaign_json_decoder.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
import 'package:up_tower_defense/features/gameplay/data/asset_loader.dart';
import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/content_load_exception.dart';

/// Loads the authored campaign from the app bundle.
///
/// The campaign is loaded before a level id can be resolved, so a level the
/// campaign does not list can never be opened by accident.
class CampaignRepository {
  CampaignRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Loads and decodes the campaign at [assetPath].
  Future<CampaignDefinition> load(String assetPath) async {
    final source = await readAssetText(_bundle, assetPath);
    try {
      return CampaignJsonDecoder.decode(source);
    } on ContentFormatException catch (error) {
      throw ContentLoadException(assetPath, error.message);
    }
  }
}
