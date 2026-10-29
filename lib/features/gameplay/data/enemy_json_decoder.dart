import 'package:up_tower_defense/features/gameplay/data/json_reader.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';

/// Decodes the enemy catalog JSON into definitions.
abstract final class EnemyJsonDecoder {
  static List<EnemyDefinition> decode(String source) {
    final root = JsonReader.decodeObject(source);
    final enemies = JsonReader.requireList(root['enemies'], 'enemies');

    return [
      for (var index = 0; index < enemies.length; index++)
        _decodeEnemy(enemies[index], index),
    ];
  }

  static EnemyDefinition _decodeEnemy(Object? value, int index) {
    final path = 'enemies[$index]';
    final json = JsonReader.requireObject(value, path);

    return EnemyDefinition(
      id: JsonReader.requireString(json, 'id', parent: path),
      displayName: JsonReader.requireString(json, 'displayName', parent: path),
      maxHealth: JsonReader.requireNumber(json, 'maxHealth', parent: path),
      speed: JsonReader.requireNumber(json, 'speed', parent: path),
      coreDamageOnLeak: JsonReader.requireInt(
        json,
        'coreDamageOnLeak',
        parent: path,
      ),
      radius: JsonReader.requireNumber(json, 'radius', parent: path),
      rewardGold: JsonReader.requireInt(json, 'rewardGold', parent: path),
      colorValue: JsonReader.requireColor(json, 'color', parent: path),
    );
  }
}
