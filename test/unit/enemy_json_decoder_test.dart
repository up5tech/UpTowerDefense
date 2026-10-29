import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_json_decoder.dart';

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
}
