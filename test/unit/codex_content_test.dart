import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/codex/application/codex_providers.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/content_load_exception.dart';

import '../helpers/stub_asset_bundle.dart';

/// Minimal valid tower file: one single-level tower, so the codex provider's
/// own composition — two catalogs from one bundle — is what is under test, not
/// the decoders the repository tests already cover.
const String _towerJson = '''
{
  "towers": [
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
''';

const String _enemyJson = '''
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

ProviderContainer _container(Map<String, String> files) {
  final container = ProviderContainer(
    overrides: [
      codexBundleProvider.overrideWithValue(StubAssetBundle(files)),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test(
    'codex content loads both shared catalogs from the bundle seam',
    () async {
      final container = _container({
        ContentCatalog.towers: _towerJson,
        ContentCatalog.enemies: _enemyJson,
      });

      final content = await container.read(codexContentProvider.future);

      expect(content.towers.all.single.id, 'ranger');
      expect(content.towers.all.single.buildCost, 70);
      expect(content.enemies.all.single.id, 'grunt');
      expect(content.enemies.all.single.maxHealth, 100);
    },
  );

  test('a missing catalog fails at once instead of an empty codex', () async {
    final container = _container({
      ContentCatalog.towers: _towerJson,
      // No enemy file: silently rendering zero enemies would read as "this
      // game has none", which is exactly what the error message prevents.
    });

    await expectLater(
      container.read(codexContentProvider.future),
      throwsA(isA<ContentLoadException>()),
    );
  });
}
