import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/domain/enemy_validation.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/speed_surge.dart';

/// [_validJson] with the boss marker and a surge appended to the first enemy.
String _bossJson({
  String ratio = '0.5',
  String multiplier = '1.5',
  String duration = '3',
  bool isBoss = true,
}) {
  final extra = StringBuffer();
  if (isBoss) {
    extra.write('\n      "isBoss": true,');
  }
  if (ratio.isNotEmpty) {
    extra.write('\n      "speedSurgeHealthRatio": $ratio,');
  }
  if (multiplier.isNotEmpty) {
    extra.write('\n      "speedSurgeMultiplier": $multiplier,');
  }
  if (duration.isNotEmpty) {
    extra.write('\n      "speedSurgeDurationSeconds": $duration,');
  }
  return _validJson.replaceFirst(
    '"radius": 14,',
    '"radius": 14,$extra',
  );
}

const String _validJson = '''
{
  "enemies": [
    {
      "id": "grunt",
      "displayName": "Grunt",
      "maxHealth": 100,
      "speed": 80,
      "coreDamageOnLeak": 1,
      "rewardGold": 10,
      "radius": 14,
      "color": "#D96B5B"
    }
  ]
}
''';

void main() {
  test('decodes an enemy catalog', () {
    final enemies = EnemyJsonDecoder.decode(_validJson);

    expect(enemies, hasLength(1));
    final grunt = enemies.single;
    expect(grunt.id, 'grunt');
    expect(grunt.displayName, 'Grunt');
    expect(grunt.maxHealth, 100);
    expect(grunt.speed, 80);
    expect(grunt.coreDamageOnLeak, 1);
    expect(grunt.rewardGold, 10);
    expect(grunt.radius, 14);
    // Six-digit colours gain a fully opaque alpha channel.
    expect(grunt.colorValue, 0xFFD96B5B);
  });

  test('accepts explicit alpha in colours', () {
    final enemies = EnemyJsonDecoder.decode(
      _validJson.replaceFirst('"#D96B5B"', '"#80D96B5B"'),
    );

    expect(enemies.single.colorValue, 0x80D96B5B);
  });

  test('rejects malformed colours', () {
    expect(
      () => EnemyJsonDecoder.decode(
        _validJson.replaceFirst('"#D96B5B"', '"#XYZXYZ"'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('hexadecimal colour'),
        ),
      ),
    );
  });

  test('names the missing enemy field', () {
    expect(
      () => EnemyJsonDecoder.decode(
        _validJson.replaceFirst('"maxHealth"', '"hp"'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('enemies[0].maxHealth must be a number'),
        ),
      ),
    );
  });

  test('requires integer counts such as core damage', () {
    expect(
      () => EnemyJsonDecoder.decode(
        _validJson.replaceFirst(
          '"coreDamageOnLeak": 1',
          '"coreDamageOnLeak": 1.5',
        ),
      ),
      throwsA(isA<ContentFormatException>()),
    );
  });

  test('requires an enemies list', () {
    expect(
      () => EnemyJsonDecoder.decode('{}'),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('enemies must be a list'),
        ),
      ),
    );
  });

  group('boss speed surge (D69)', () {
    test('decodes the boss marker and all three surge fields', () {
      final enemy = EnemyJsonDecoder.decode(_bossJson()).single;

      expect(enemy.isBoss, isTrue);
      expect(
        enemy.speedSurge,
        isA<SpeedSurge>()
            .having((surge) => surge.healthRatio, 'healthRatio', 0.5)
            .having((surge) => surge.multiplier, 'multiplier', 1.5)
            .having((surge) => surge.durationSeconds, 'durationSeconds', 3),
      );
    });

    test('an enemy without the fields has no surge at all', () {
      final enemy = EnemyJsonDecoder.decode(_validJson).single;

      expect(enemy.isBoss, isFalse);
      expect(enemy.speedSurge, isNull);
    });

    test('a partially authored surge names the missing field', () {
      expect(
        () => EnemyJsonDecoder.decode(_bossJson(multiplier: '')),
        throwsA(
          isA<ContentFormatException>().having(
            (error) => error.message,
            'message',
            contains('enemies[0].speedSurgeMultiplier must be a number'),
          ),
        ),
      );
    });

    test('rejects a non-boolean boss marker', () {
      expect(
        () => EnemyJsonDecoder.decode(
          _validJson.replaceFirst(
            '"radius": 14,',
            '"radius": 14, "isBoss": 1,',
          ),
        ),
        throwsA(
          isA<ContentFormatException>().having(
            (error) => error.message,
            'message',
            contains('enemies[0].isBoss must be a boolean'),
          ),
        ),
      );
    });

    test('the validator accepts the shipped shape', () {
      final enemies = EnemyJsonDecoder.decode(_bossJson());

      expect(const EnemyValidator().validate(enemies).issues, isEmpty);
    });

    test('the validator rejects a surge on an ordinary enemy', () {
      final enemies = EnemyJsonDecoder.decode(_bossJson(isBoss: false));

      final issues = const EnemyValidator().validate(enemies).issues;
      expect(issues, hasLength(1));
      expect(issues.single, contains('is not a boss'));
    });

    test('the validator bounds every surge field', () {
      const cases = <(String, String, String, String)>[
        (
          'ratio of zero',
          'speedSurgeHealthRatio',
          '"speedSurgeHealthRatio": 0.5',
          '"speedSurgeHealthRatio": 0',
        ),
        (
          'ratio above one',
          'speedSurgeHealthRatio',
          '"speedSurgeHealthRatio": 0.5',
          '"speedSurgeHealthRatio": 1.5',
        ),
        (
          'multiplier of one',
          'speedSurgeMultiplier',
          '"speedSurgeMultiplier": 1.5',
          '"speedSurgeMultiplier": 1',
        ),
        (
          'zero duration',
          'speedSurgeDurationSeconds',
          '"speedSurgeDurationSeconds": 3',
          '"speedSurgeDurationSeconds": 0',
        ),
      ];

      for (final (label, field, from, to) in cases) {
        final enemies = EnemyJsonDecoder.decode(
          _bossJson().replaceFirst(from, to),
        );
        final issues = const EnemyValidator().validate(enemies).issues;

        expect(issues, hasLength(1), reason: label);
        // Each bound names the field it rejected, so an author fixes the value
        // rather than hunting for which of three fields was wrong.
        expect(issues.single, contains(field), reason: label);
      }
    });
  });
}
