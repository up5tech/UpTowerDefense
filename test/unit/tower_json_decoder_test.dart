import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_json_decoder.dart';

const String _validJson = '''
{
  "towers": [
    {
      "id": "cannon",
      "displayName": "Cannon Tower",
      "role": "Area damage",
      "description": "Explodes on impact.",
      "buildCost": 110,
      "sellRefundRate": 0.6,
      "color": "#E8A05C",
      "levels": [
        {
          "damage": 26,
          "range": 200,
          "fireCooldownSeconds": 1.6,
          "projectileSpeed": 380,
          "splashRadius": 70,
          "upgradeCost": 90
        },
        {
          "damage": 40,
          "range": 215,
          "fireCooldownSeconds": 1.5,
          "projectileSpeed": 380,
          "splashRadius": 78
        }
      ]
    }
  ]
}
''';

/// Frost-shaped JSON so slow parsing has a fixture of its own.
const String _frostJson = '''
{
  "towers": [
    {
      "id": "frost",
      "displayName": "Frost Tower",
      "role": "Control",
      "description": "Chills enemies.",
      "buildCost": 85,
      "sellRefundRate": 0.6,
      "color": "#7FB8FF",
      "levels": [
        {
          "damage": 4,
          "range": 190,
          "fireCooldownSeconds": 1.2,
          "projectileSpeed": 420,
          "slow": {
            "magnitude": 0.4,
            "durationSeconds": 2.5,
            "minSpeedRatio": 0.4,
            "damageAmp": 0.25
          },
          "upgradeCost": 65
        },
        {
          "damage": 6,
          "range": 205,
          "fireCooldownSeconds": 1.1,
          "projectileSpeed": 420,
          "slow": {
            "magnitude": 0.5,
            "durationSeconds": 3,
            "minSpeedRatio": 0.4
          }
        }
      ]
    }
  ]
}
''';

/// The same tower with no splash fields, to prove they are optional.
const String _singleTargetJson = '''
{
  "towers": [
    {
      "id": "ranger",
      "displayName": "Ranger Tower",
      "role": "Fast single target",
      "description": "Picks off the leader.",
      "buildCost": 70,
      "sellRefundRate": 0.6,
      "color": "#4FD1C5",
      "levels": [
        {
          "damage": 18,
          "range": 210,
          "fireCooldownSeconds": 0.7,
          "projectileSpeed": 600
        }
      ]
    }
  ]
}
''';

void main() {
  test('decodes a tower catalog with per-level stats', () {
    final towers = TowerJsonDecoder.decode(_validJson);

    expect(towers, hasLength(1));
    final cannon = towers.single;
    expect(cannon.id, 'cannon');
    expect(cannon.displayName, 'Cannon Tower');
    expect(cannon.role, 'Area damage');
    expect(cannon.description, 'Explodes on impact.');
    expect(cannon.buildCost, 110);
    expect(cannon.sellRefundRate, 0.6);
    expect(cannon.colorValue, 0xFFE8A05C);
    expect(cannon.maxLevel, 2);

    // Level 1 doubles as the base stats the build panel shows.
    expect(cannon.damage, 26);
    expect(cannon.range, 200);
    expect(cannon.fireCooldownSeconds, 1.6);
    expect(cannon.projectileSpeed, 380);

    expect(cannon.levelAt(1).splashRadius, 70);
    expect(cannon.levelAt(2).splashRadius, 78);
    expect(cannon.upgradeCostFor(1), 90);
    expect(cannon.upgradeCostFor(2), isNull);
    expect(cannon.refundForInvested(100), 60);
  });

  test('decodes slow specs per level', () {
    final frost = TowerJsonDecoder.decode(_frostJson).single;

    final slow = frost.levelAt(1).slow;
    expect(slow, isNotNull);
    expect(slow!.magnitude, 0.4);
    expect(slow.durationSeconds, 2.5);
    expect(slow.minSpeedRatio, 0.4);
    expect(slow.damageAmp, 0.25);
    expect(frost.levelAt(2).slow!.magnitude, 0.5);
    // The amplifier is optional: a level that omits it only slows.
    expect(frost.levelAt(2).slow!.damageAmp, 0);
    expect(frost.upgradeCostFor(1), 65);
    expect(frost.upgradeCostFor(2), isNull);
  });

  test('an omitted splash radius means a single-target hit', () {
    final ranger = TowerJsonDecoder.decode(_singleTargetJson).single;

    expect(ranger.levelAt(1).splashRadius, 0);
    expect(ranger.levelAt(1).slow, isNull);
  });

  test('requires an integer build cost', () {
    expect(
      () => TowerJsonDecoder.decode(
        _validJson.replaceFirst('"buildCost": 110', '"buildCost": 110.5'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('towers[0].buildCost must be an integer'),
        ),
      ),
    );
  });

  test('requires a levels list and points at it', () {
    expect(
      () => TowerJsonDecoder.decode(
        _validJson.replaceFirst('"levels"', '"tiers"'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('towers[0].levels must be a list'),
        ),
      ),
    );
  });

  test('names the offending level field', () {
    expect(
      () => TowerJsonDecoder.decode(
        _validJson.replaceFirst('"range": 200', '"radius": 200'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('towers[0].levels[0].range must be a number'),
        ),
      ),
    );
  });

  test('names a malformed slow field', () {
    expect(
      () => TowerJsonDecoder.decode(
        _frostJson.replaceFirst('"magnitude": 0.4', '"magnitude": "half"'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('towers[0].levels[0].slow.magnitude must be a number'),
        ),
      ),
    );
  });

  test('names a malformed damageAmp', () {
    expect(
      () => TowerJsonDecoder.decode(
        _frostJson.replaceFirst('"damageAmp": 0.25', '"damageAmp": "loud"'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('towers[0].levels[0].slow.damageAmp must be a number'),
        ),
      ),
    );
  });

  test('rejects malformed colours', () {
    expect(
      () => TowerJsonDecoder.decode(
        _validJson.replaceFirst('"#E8A05C"', '"#E8A05"'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('towers[0].color must be #RRGGBB or #AARRGGBB'),
        ),
      ),
    );
  });

  test('requires a towers list', () {
    expect(
      () => TowerJsonDecoder.decode('{}'),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('towers must be a list'),
        ),
      ),
    );
  });
}
