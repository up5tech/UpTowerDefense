import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/json_reader.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_objective.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

/// Decodes authored level JSON, including its waves and spawn groups.
abstract final class LevelJsonDecoder {
  static LevelDefinition decode(String source) {
    final root = JsonReader.decodeObject(source);

    return LevelDefinition(
      id: JsonReader.requireString(root, 'id'),
      displayName: JsonReader.requireString(root, 'displayName'),
      mapId: JsonReader.requireString(root, 'mapId'),
      coreHealth: JsonReader.requireInt(root, 'coreHealth'),
      startingGold: JsonReader.requireInt(root, 'startingGold'),
      waveTransitionSeconds: JsonReader.optionalNumber(
        root,
        'waveTransitionSeconds',
        fallback: LevelDefinition.defaultWaveTransitionSeconds,
      ),
      waves: _decodeWaves(root['waves']),
      endless: JsonReader.optionalBool(root, 'endless'),
      endlessCountGrowth: JsonReader.optionalNumber(
        root,
        'endlessCountGrowth',
        fallback: LevelDefinition.defaultEndlessCountGrowth,
      ),
      objectives: _decodeObjectives(root['objectives']),
    );
  }

  /// Decodes the optional goal list, including the rule that a value belongs
  /// only to the kinds that need one (D68).
  static List<LevelObjective> _decodeObjectives(Object? value) {
    if (value == null) {
      return const [];
    }
    final objectives = JsonReader.requireList(value, 'objectives');
    return [
      for (var index = 0; index < objectives.length; index++)
        _decodeObjective(objectives[index], 'objectives[$index]'),
    ];
  }

  static LevelObjective _decodeObjective(Object? value, String path) {
    final json = JsonReader.requireObject(value, path);
    final name = JsonReader.requireString(json, 'kind', parent: path);
    final kind = LevelObjectiveKind.fromWireName(name);
    if (kind == null) {
      throw ContentFormatException(
        '$path.kind "$name" is not a known objective; expected one of '
        '${LevelObjectiveKind.values.map((kind) => kind.wireName).join(', ')}',
      );
    }

    switch (kind) {
      case LevelObjectiveKind.noLeaks:
        if (json.containsKey('value')) {
          throw ContentFormatException('$path.value is not used by "$name"');
        }
        return const LevelObjective.noLeaks();
      case LevelObjectiveKind.maxTowers:
        return LevelObjective.maxTowers(
          JsonReader.requireInt(json, 'value', parent: path),
        );
      case LevelObjectiveKind.deadlineSeconds:
        return LevelObjective.deadlineSeconds(
          JsonReader.requireInt(json, 'value', parent: path),
        );
      case LevelObjectiveKind.coreAbove:
        return LevelObjective.coreAbove(
          JsonReader.requireInt(json, 'value', parent: path),
        );
    }
  }

  static List<WaveDefinition> _decodeWaves(Object? value) {
    final waves = JsonReader.requireList(value, 'waves');
    return [
      for (var index = 0; index < waves.length; index++)
        _decodeWave(waves[index], index),
    ];
  }

  static WaveDefinition _decodeWave(Object? value, int index) {
    final path = 'waves[$index]';
    final json = JsonReader.requireObject(value, path);

    return WaveDefinition(
      id: JsonReader.requireString(json, 'id', parent: path),
      groups: _decodeGroups(json['groups'], path),
    );
  }

  static List<SpawnGroupDefinition> _decodeGroups(
    Object? value,
    String parent,
  ) {
    final groups = JsonReader.requireList(value, '$parent.groups');
    return [
      for (var index = 0; index < groups.length; index++)
        _decodeGroup(groups[index], '$parent.groups[$index]'),
    ];
  }

  static SpawnGroupDefinition _decodeGroup(Object? value, String path) {
    final json = JsonReader.requireObject(value, path);

    return SpawnGroupDefinition(
      enemyId: JsonReader.requireString(json, 'enemyId', parent: path),
      count: JsonReader.requireInt(json, 'count', parent: path),
      spawnIntervalSeconds: JsonReader.requireNumber(
        json,
        'spawnIntervalSeconds',
        parent: path,
      ),
      initialDelaySeconds: JsonReader.optionalNumber(
        json,
        'initialDelaySeconds',
        parent: path,
      ),
    );
  }
}
