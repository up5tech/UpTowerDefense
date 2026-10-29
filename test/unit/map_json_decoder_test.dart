import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/map_json_decoder.dart';

const String _validJson = '''
{
  "id": "fixture",
  "displayName": "Fixture Map",
  "world": [1280, 720],
  "buildPadRadius": 34,
  "route": [[0, 500], [300, 500]],
  "core": [300, 500],
  "buildPads": [
    { "id": "pad_a", "label": "A", "center": [180, 360] }
  ]
}
''';

void main() {
  test('decodes a complete map', () {
    final map = MapJsonDecoder.decode(_validJson);

    expect(map.id, 'fixture');
    expect(map.displayName, 'Fixture Map');
    expect(map.worldWidth, 1280);
    expect(map.worldHeight, 720);
    expect(map.buildPadRadius, 34);
    expect(map.route, hasLength(2));
    expect(map.core.x, 300);
    expect(map.core.y, 500);
    expect(map.buildPads.single.id, 'pad_a');
    expect(map.buildPads.single.label, 'A');
    expect(map.buildPads.single.position.x, 180);
  });

  test('reports malformed JSON', () {
    expect(
      () => MapJsonDecoder.decode('{'),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('not valid JSON'),
        ),
      ),
    );
  });

  test('requires an object at the root', () {
    expect(
      () => MapJsonDecoder.decode('[]'),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('root must be a JSON object'),
        ),
      ),
    );
  });

  test('names the missing field', () {
    expect(
      () => MapJsonDecoder.decode(
        _validJson.replaceFirst('"displayName"', '"name"'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('displayName must be a non-empty string'),
        ),
      ),
    );
  });

  test('rejects a non-list route', () {
    expect(
      () => MapJsonDecoder.decode(
        _validJson.replaceFirst('[[0, 500], [300, 500]]', '"nope"'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('route must be a list'),
        ),
      ),
    );
  });

  test('points the error at the offending waypoint', () {
    expect(
      () => MapJsonDecoder.decode(
        _validJson.replaceFirst('[[0, 500], [300, 500]]', '[[0, 500], [300]]'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('route[1] must be a [x, y] pair'),
        ),
      ),
    );
  });

  test('points the error at the offending pad field', () {
    expect(
      () => MapJsonDecoder.decode(
        _validJson.replaceFirst('"center": [180, 360]', '"x": 180, "y": 360'),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('buildPads[0].center must be a [x, y] pair'),
        ),
      ),
    );
  });

  test('rejects non-numeric coordinates', () {
    expect(
      () => MapJsonDecoder.decode(
        _validJson.replaceFirst(
          '"world": [1280, 720]',
          '"world": [1280, "720"]',
        ),
      ),
      throwsA(
        isA<ContentFormatException>().having(
          (error) => error.message,
          'message',
          contains('world must contain two numbers'),
        ),
      ),
    );
  });
}
