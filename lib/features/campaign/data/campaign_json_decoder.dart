import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
// The campaign is content for the gameplay feature, so it reuses the same
// path-aware reader: a malformed campaign reports the same way a malformed
// level does, and there is only one JSON-reading implementation to fix.
import 'package:up_tower_defense/features/gameplay/data/json_reader.dart';

/// Decodes the authored campaign file into ordered regions and levels.
abstract final class CampaignJsonDecoder {
  static CampaignDefinition decode(String source) {
    final root = JsonReader.decodeObject(source);
    final regions = JsonReader.requireList(root['regions'], 'regions');

    return CampaignDefinition([
      for (var index = 0; index < regions.length; index++)
        _decodeRegion(regions[index], index),
    ]);
  }

  static CampaignRegion _decodeRegion(Object? value, int index) {
    final path = 'regions[$index]';
    final json = JsonReader.requireObject(value, path);
    final levels = JsonReader.requireList(json['levels'], '$path.levels');

    return CampaignRegion(
      id: JsonReader.requireString(json, 'id', parent: path),
      displayName: JsonReader.requireString(
        json,
        'displayName',
        parent: path,
      ),
      levels: [
        for (var level = 0; level < levels.length; level++)
          _decodeLevel(levels[level], '$path.levels[$level]'),
      ],
    );
  }

  static CampaignLevel _decodeLevel(Object? value, String path) {
    final json = JsonReader.requireObject(value, path);

    return CampaignLevel(
      id: JsonReader.requireString(json, 'id', parent: path),
      displayName: JsonReader.requireString(
        json,
        'displayName',
        parent: path,
      ),
    );
  }
}
