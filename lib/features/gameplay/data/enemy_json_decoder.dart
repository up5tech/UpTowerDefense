import 'package:up_tower_defense/features/gameplay/data/json_reader.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/speed_surge.dart';

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
      isBoss: JsonReader.optionalBool(json, 'isBoss', parent: path),
      speedSurge: _decodeSpeedSurge(json, path),
      flatDamageReduction: JsonReader.optionalNumber(
        json,
        'flatDamageReduction',
        parent: path,
      ),
      splitInto: _decodeSplit(json, path),
    );
  }

  /// Decodes the split, which is all-or-nothing like the surge: both fields
  /// are required the moment `splitInto` appears, so a half-authored split
  /// names the missing key instead of quietly spawning one child, and whether
  /// the id resolves is `EnemyValidator`'s job, not the decoder's.
  static SplitSpec? _decodeSplit(Map<String, Object?> json, String path) {
    final raw = json['splitInto'];
    if (raw == null) {
      return null;
    }
    final splitPath = '$path.splitInto';
    final split = JsonReader.requireObject(raw, splitPath);
    return SplitSpec(
      enemyId: JsonReader.requireString(split, 'enemyId', parent: splitPath),
      count: JsonReader.requireInt(split, 'count', parent: splitPath),
    );
  }

  /// Decodes the boss surge, which is all-or-nothing.
  ///
  /// A partially authored surge is a mistake rather than a default: reading the
  /// missing key with `requireNumber` names the exact field that is absent,
  /// where a "use 1.5 if only the duration is given" fallback would ship a
  /// mechanic nobody wrote. Whether the fields are *legal* on this enemy is
  /// `EnemyValidator`'s job, not the decoder's.
  static SpeedSurge? _decodeSpeedSurge(
    Map<String, Object?> json,
    String path,
  ) {
    const keys = [
      'speedSurgeHealthRatio',
      'speedSurgeMultiplier',
      'speedSurgeDurationSeconds',
    ];
    if (!keys.any(json.containsKey)) {
      return null;
    }
    return SpeedSurge(
      healthRatio: JsonReader.requireNumber(
        json,
        'speedSurgeHealthRatio',
        parent: path,
      ),
      multiplier: JsonReader.requireNumber(
        json,
        'speedSurgeMultiplier',
        parent: path,
      ),
      durationSeconds: JsonReader.requireNumber(
        json,
        'speedSurgeDurationSeconds',
        parent: path,
      ),
    );
  }
}
