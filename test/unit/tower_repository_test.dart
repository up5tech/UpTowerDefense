import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_load_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_repository.dart';

import '../helpers/stub_asset_bundle.dart';

String _towerJson({int buildCost = 70}) {
  return '''
{
  "towers": [
    {
      "id": "ranger",
      "displayName": "Ranger Tower",
      "role": "Fast single target",
      "description": "Cheap, quick shots.",
      "buildCost": $buildCost,
      "sellRefundRate": 0.6,
      "color": "#4FD1C5",
      "levels": [
        { "damage": 18, "range": 210, "fireCooldownSeconds": 0.7, "projectileSpeed": 600, "upgradeCost": 60 },
        { "damage": 27, "range": 225, "fireCooldownSeconds": 0.66, "projectileSpeed": 600 }
      ]
    }
  ]
}
''';
}

TowerRepository _repository(String towerJson) {
  return TowerRepository(
    bundle: StubAssetBundle({'assets/towers.json': towerJson}),
  );
}

void main() {
  test('loads and validates a tower catalog', () async {
    final catalog = await _repository(_towerJson()).load('assets/towers.json');

    expect(catalog.length, 1);
    expect(catalog['ranger']!.buildCost, 70);
    expect(catalog.contains('cannon'), isFalse);
  });

  test('orders towers by build cost, then id', () async {
    final catalog = await _repository('''
{
  "towers": [
    {
      "id": "frost",
      "displayName": "Frost Tower",
      "role": "Control",
      "description": "Slows enemies.",
      "buildCost": 90,
      "sellRefundRate": 0.6,
      "color": "#7FB8FF",
      "levels": [
        { "damage": 4, "range": 180, "fireCooldownSeconds": 1.2, "projectileSpeed": 420 }
      ]
    },
    {
      "id": "ranger",
      "displayName": "Ranger Tower",
      "role": "Fast single target",
      "description": "Cheap, quick shots.",
      "buildCost": 70,
      "sellRefundRate": 0.6,
      "color": "#4FD1C5",
      "levels": [
        { "damage": 18, "range": 210, "fireCooldownSeconds": 0.7, "projectileSpeed": 600 }
      ]
    }
  ]
}
''').load('assets/towers.json');

    expect(catalog.all.map((tower) => tower.id), ['ranger', 'frost']);
  });

  test('reports invalid definitions with every issue', () async {
    await expectLater(
      _repository(_towerJson(buildCost: 0)).load('assets/towers.json'),
      throwsA(
        isA<ContentLoadException>()
            .having((error) => error.message, 'message', contains('validation'))
            .having(
              (error) => error.issues.join(),
              'issues',
              contains('positive buildCost'),
            ),
      ),
    );
  });

  test('reports malformed JSON with the asset path', () async {
    await expectLater(
      _repository('{ "towers": [').load('assets/towers.json'),
      throwsA(
        isA<ContentLoadException>().having(
          (error) => error.assetPath,
          'assetPath',
          'assets/towers.json',
        ),
      ),
    );
  });

  test('reports a missing asset', () async {
    await expectLater(
      TowerRepository(
        bundle: StubAssetBundle({}),
      ).load('assets/towers.json'),
      throwsA(
        isA<ContentLoadException>().having(
          (error) => error.message,
          'message',
          contains('could not read the asset'),
        ),
      ),
    );
  });
}
