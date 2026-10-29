import 'package:up_tower_defense/features/gameplay/data/json_reader.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_level_stats.dart';

/// Decodes the tower catalog JSON into definitions.
abstract final class TowerJsonDecoder {
  static List<TowerDefinition> decode(String source) {
    final root = JsonReader.decodeObject(source);
    final towers = JsonReader.requireList(root['towers'], 'towers');

    return [
      for (var index = 0; index < towers.length; index++)
        _decodeTower(towers[index], index),
    ];
  }

  static TowerDefinition _decodeTower(Object? value, int index) {
    final path = 'towers[$index]';
    final json = JsonReader.requireObject(value, path);
    final levels = JsonReader.requireList(json['levels'], '$path.levels');

    return TowerDefinition(
      id: JsonReader.requireString(json, 'id', parent: path),
      displayName: JsonReader.requireString(json, 'displayName', parent: path),
      role: JsonReader.requireString(json, 'role', parent: path),
      description: JsonReader.requireString(json, 'description', parent: path),
      buildCost: JsonReader.requireInt(json, 'buildCost', parent: path),
      sellRefundRate: JsonReader.requireNumber(
        json,
        'sellRefundRate',
        parent: path,
      ),
      levels: [
        for (var level = 0; level < levels.length; level++)
          _decodeLevel(levels[level], '$path.levels[$level]'),
      ],
      colorValue: JsonReader.requireColor(json, 'color', parent: path),
    );
  }

  static TowerLevelStats _decodeLevel(Object? value, String path) {
    final json = JsonReader.requireObject(value, path);

    return TowerLevelStats(
      damage: JsonReader.requireNumber(json, 'damage', parent: path),
      range: JsonReader.requireNumber(json, 'range', parent: path),
      fireCooldownSeconds: JsonReader.requireNumber(
        json,
        'fireCooldownSeconds',
        parent: path,
      ),
      projectileSpeed: JsonReader.requireNumber(
        json,
        'projectileSpeed',
        parent: path,
      ),
      splashRadius: JsonReader.optionalNumber(
        json,
        'splashRadius',
        parent: path,
      ),
      slow: json['slow'] == null ? null : _decodeSlow(json['slow'], path),
      upgradeCost: json['upgradeCost'] == null
          ? null
          : JsonReader.requireInt(json, 'upgradeCost', parent: path),
    );
  }

  static SlowSpec _decodeSlow(Object? value, String parent) {
    final path = '$parent.slow';
    final json = JsonReader.requireObject(value, path);

    return SlowSpec(
      magnitude: JsonReader.requireNumber(json, 'magnitude', parent: path),
      durationSeconds: JsonReader.requireNumber(
        json,
        'durationSeconds',
        parent: path,
      ),
      minSpeedRatio: JsonReader.requireNumber(
        json,
        'minSpeedRatio',
        parent: path,
      ),
      damageAmp: JsonReader.optionalNumber(
        json,
        'damageAmp',
        parent: path,
      ),
    );
  }
}
