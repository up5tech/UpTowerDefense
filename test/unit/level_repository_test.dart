import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_load_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/level_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/map_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_repository.dart';

import '../helpers/stub_asset_bundle.dart';

/// Levels reference the shipped map, enemy and tower catalogs through
/// `ContentCatalog`, so the production repositories are used and only the level
/// JSON is stubbed.
LevelRepository _repository(String levelJson) {
  return LevelRepository(
    mapRepository: MapRepository(),
    enemyRepository: EnemyRepository(),
    towerRepository: TowerRepository(),
    bundle: StubAssetBundle({'assets/level.json': levelJson}),
  );
}

String _levelJson({
  String mapId = 'meadow_gate',
  String enemyId = 'grunt',
  int coreHealth = 20,
  int startingGold = 150,
}) {
  return '''
{
  "id": "level_01",
  "displayName": "Level One",
  "mapId": "$mapId",
  "coreHealth": $coreHealth,
  "startingGold": $startingGold,
  "waves": [
    {
      "id": "wave_01",
      "groups": [
        { "enemyId": "$enemyId", "count": 2, "spawnIntervalSeconds": 1.0 }
      ]
    }
  ]
}
''';
}

void main() {
  // The shipped map and enemy catalogs are read through `rootBundle`; the
  // binding gives unit tests access to the same assets the app ships.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads a level with its map and enemies resolved', () async {
    final bundle = await _repository(_levelJson()).load('assets/level.json');

    expect(bundle.level.id, 'level_01');
    expect(bundle.map.id, 'meadow_gate');
    expect(bundle.enemies.contains('grunt'), isTrue);
    expect(bundle.towers.contains('ranger'), isTrue);
    expect(bundle.level.startingGold, 150);
    expect(bundle.level.waves.single.enemyCount, 2);
  });

  test('rejects a level whose map is not in the catalog', () async {
    await expectLater(
      _repository(_levelJson(mapId: 'no_such_map')).load('assets/level.json'),
      throwsA(
        isA<ContentLoadException>().having(
          (error) => error.message,
          'message',
          contains('unknown map "no_such_map"'),
        ),
      ),
    );
  });

  test('rejects a wave that references an unknown enemy', () async {
    await expectLater(
      _repository(_levelJson(enemyId: 'dragon')).load('assets/level.json'),
      throwsA(
        isA<ContentLoadException>()
            .having((error) => error.issues, 'issues', isNotEmpty)
            .having(
              (error) => error.issues.join('\n'),
              'issues',
              contains('unknown enemy "dragon"'),
            ),
      ),
    );
  });

  test('surfaces malformed level JSON', () async {
    await expectLater(
      _repository('{').load('assets/level.json'),
      throwsA(
        isA<ContentLoadException>().having(
          (error) => error.message,
          'message',
          contains('not valid JSON'),
        ),
      ),
    );
  });

  test('rejects invalid level values', () async {
    await expectLater(
      _repository(_levelJson(coreHealth: 0)).load('assets/level.json'),
      throwsA(
        isA<ContentLoadException>().having(
          (error) => error.issues.join('\n'),
          'issues',
          contains('coreHealth must be positive'),
        ),
      ),
    );
  });
}
