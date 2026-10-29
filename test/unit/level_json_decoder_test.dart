import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/level_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_objective.dart';

const String _validJson = '''
{
  "id": "level_01",
  "displayName": "Level One",
  "mapId": "meadow_gate",
  "coreHealth": 20,
  "startingGold": 150,
  "waves": [
    {
      "id": "wave_01",
      "groups": [
        {
          "enemyId": "grunt",
          "count": 6,
          "spawnIntervalSeconds": 1.2,
          "initialDelaySeconds": 1.0
        }
      ]
    }
  ]
}
''';

void main() {
  test('decodes a level with waves and spawn groups', () {
    final level = LevelJsonDecoder.decode(_validJson);

    expect(level.id, 'level_01');
    expect(level.displayName, 'Level One');
    expect(level.mapId, 'meadow_gate');
    expect(level.coreHealth, 20);
    expect(level.startingGold, 150);
    expect(level.waves, hasLength(1));

    final wave = level.waves.single;
    expect(wave.id, 'wave_01');
    expect(wave.enemyCount, 6);
    final group = wave.groups.single;
    expect(group.enemyId, 'grunt');
    expect(group.count, 6);
    expect(group.spawnIntervalSeconds, 1.2);
    expect(group.initialDelaySeconds, 1.0);
  });

  test('treats a missing initial delay as zero', () {
    final json = _validJson.replaceFirst(
      '"initialDelaySeconds": 1.0',
      '"unused": 0',
    );
    final level = LevelJsonDecoder.decode(json);

    expect(level.waves.single.groups.single.initialDelaySeconds, 0);
  });

  test('falls back to the default wave transition when none is authored', () {
    final level = LevelJsonDecoder.decode(_validJson);

    expect(
      level.waveTransitionSeconds,
      LevelDefinition.defaultWaveTransitionSeconds,
    );
  });

  test('decodes an authored wave transition', () {
    final level = LevelJsonDecoder.decode(
      _validJson.replaceFirst(
        '"startingGold": 150',
        '"startingGold": 150,\n  "waveTransitionSeconds": 2.5',
      ),
    );

    expect(level.waveTransitionSeconds, 2.5);
  });

  test('requires integer gold', () {
    expect(
      () => LevelJsonDecoder.decode(
        _validJson.replaceFirst('"startingGold": 150', '"startingGold": 150.5'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('startingGold must be an integer'),
        ),
      ),
    );
  });

  test('requires an integer core health', () {
    expect(
      () => LevelJsonDecoder.decode(
        _validJson.replaceFirst('"coreHealth": 20', '"coreHealth": 20.5'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('coreHealth must be an integer'),
        ),
      ),
    );
  });

  test('names the offending wave group field', () {
    expect(
      () => LevelJsonDecoder.decode(
        _validJson.replaceFirst('"enemyId": "grunt",', ''),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('waves[0].groups[0].enemyId must be a non-empty string'),
        ),
      ),
    );
  });

  test('decodes authored objectives and their values', () {
    final level = LevelJsonDecoder.decode(
      _validJson.replaceFirst(
        '"startingGold": 150',
        '"startingGold": 150,\n  "objectives": [\n'
            '    { "kind": "noLeaks" },\n'
            '    { "kind": "maxTowers", "value": 3 }\n  ]',
      ),
    );

    expect(level.objectives, hasLength(2));
    expect(level.objectives[0].kind, LevelObjectiveKind.noLeaks);
    expect(level.objectives[0].value, isNull);
    expect(level.objectives[1].kind, LevelObjectiveKind.maxTowers);
    expect(level.objectives[1].value, 3);
    expect(level.objectives[1].description, contains('3 towers'));
  });

  test('treats a missing objectives list as none', () {
    expect(LevelJsonDecoder.decode(_validJson).objectives, isEmpty);
  });

  test('rejects an unknown objective kind', () {
    final json = _validJson.replaceFirst(
      '"startingGold": 150',
      '"startingGold": 150,\n  "objectives": [\n'
          '    { "kind": "noFlyers" }\n  ]',
    );

    expect(
      () => LevelJsonDecoder.decode(json),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('objectives[0].kind "noFlyers" is not a known objective'),
        ),
      ),
    );
  });

  test('rejects a value on a goal that takes none', () {
    final json = _validJson.replaceFirst(
      '"startingGold": 150',
      '"startingGold": 150,\n  "objectives": [\n'
          '    { "kind": "noLeaks", "value": 2 }\n  ]',
    );

    expect(
      () => LevelJsonDecoder.decode(json),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('objectives[0].value is not used by "noLeaks"'),
        ),
      ),
    );
  });

  test('requires waves', () {
    expect(
      () => LevelJsonDecoder.decode(
        _validJson.replaceFirst(
          RegExp(r'"waves": \[[\s\S]*\]\n'),
          '"waves": 5',
        ),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('waves must be a list'),
        ),
      ),
    );
  });
}
