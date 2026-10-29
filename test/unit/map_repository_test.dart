import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_load_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/map_repository.dart';

import '../helpers/stub_asset_bundle.dart';

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
  test('loads and validates a map asset', () async {
    final repository = MapRepository(
      bundle: StubAssetBundle({'assets/data/maps/fixture.json': _validJson}),
    );

    final map = await repository.load('assets/data/maps/fixture.json');

    expect(map.id, 'fixture');
    expect(map.buildPads.single.id, 'pad_a');
  });

  test('missing assets report the asset path', () async {
    final repository = MapRepository(bundle: StubAssetBundle(const {}));

    await expectLater(
      repository.load('assets/data/maps/gone.json'),
      throwsA(
        isA<ContentLoadException>()
            .having(
              (error) => error.assetPath,
              'assetPath',
              'assets/data/maps/gone.json',
            )
            .having(
              (error) => error.message,
              'message',
              contains('could not read'),
            ),
      ),
    );
  });

  test('format errors surface the decoder message', () async {
    final repository = MapRepository(
      bundle: StubAssetBundle({'map.json': '{ not json'}),
    );

    await expectLater(
      repository.load('map.json'),
      throwsA(
        isA<ContentLoadException>().having(
          (error) => error.message,
          'message',
          contains('not valid JSON'),
        ),
      ),
    );
  });

  test('content problems are reported together with their details', () async {
    // Pad sits on the route, which validation forbids.
    final invalid = _validJson.replaceFirst('[180, 360]', '[150, 500]');
    final repository = MapRepository(
      bundle: StubAssetBundle({'map.json': invalid}),
    );

    await expectLater(
      repository.load('map.json'),
      throwsA(
        isA<ContentLoadException>()
            .having((error) => error.issues, 'issues', isNotEmpty)
            .having(
              (error) => error.issues.join('\n'),
              'issues',
              contains('overlaps the enemy route'),
            ),
      ),
    );
  });
}
