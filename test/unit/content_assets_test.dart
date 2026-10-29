import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/level_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/map_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_repository.dart';
import 'package:up_tower_defense/features/gameplay/domain/map_geometry.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_objective.dart';

/// Guards the content pipeline: every asset that ships must load, decode and pass
/// validation, so a broken file fails the build instead of the player.
Future<List<String>> _assetsUnder(AssetManifest manifest, String prefix) async {
  final assets =
      manifest
          .listAssets()
          .where((asset) => asset.startsWith(prefix) && asset.endsWith('.json'))
          .toList()
        ..sort();
  return assets;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every shipped map decodes and validates', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final mapAssets = await _assetsUnder(manifest, 'assets/data/maps/');

    expect(mapAssets, isNotEmpty);
    expect(
      mapAssets.toSet(),
      ContentCatalog.mapAssetsById.values.toSet(),
      reason: 'the catalog must list every shipped map',
    );

    final repository = MapRepository();
    for (final asset in mapAssets) {
      final map = await repository.load(asset);
      expect(map.route.length, greaterThanOrEqualTo(2), reason: asset);
      expect(map.buildPads, isNotEmpty, reason: asset);
    }
  });

  test('every shipped pad is within reach of the shortest tower', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final mapAssets = await _assetsUnder(manifest, 'assets/data/maps/');
    final towers = await TowerRepository().load(ContentCatalog.towers);

    // Measured against the *shortest* base range so the rule means "every
    // tower can fire from here", not "one tower happens to fit". A pad beyond
    // it is a trap: the player pays build gold for a tower that can never take
    // a shot (meadow's pad D shipped at 211 units against the ranger's 210).
    final shortestRange = towers.all
        .map((tower) => tower.baseStats.range)
        .reduce((a, b) => a < b ? a : b);

    for (final asset in mapAssets) {
      final map = await MapRepository().load(asset);
      final geometry = MapGeometry(map);
      for (final pad in map.buildPads) {
        final distance = geometry.distanceToRoute(pad.position);
        expect(
          distance,
          lessThanOrEqualTo(shortestRange),
          reason:
              '$asset -> pad "${pad.id}" sits '
              '${distance.toStringAsFixed(0)} units from the route, beyond '
              'the ${shortestRange.toStringAsFixed(0)}-unit range of the '
              'shortest tower',
        );
      }
    }
  });

  test('every shipped pad clears the top HUD strip', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final mapAssets = await _assetsUnder(manifest, 'assets/data/maps/');

    // The gameplay HUD is a Flutter overlay pinned to the top of the screen
    // (back button, level chip, gold/health/wave chips, pause, speed) and the
    // camera fits the map to the full screen height whenever the screen is at
    // least as wide as the world, so the strip the HUD covers is the same
    // *fraction* of the map as of the screen. On the smallest supported
    // landscape phone that is about a quarter: roughly 88 px of HUD — status
    // bar included — over a 360 px screen. Widgets are not a solid panel, but
    // a pad that lands behind one can neither be seen nor tapped, because the
    // chip absorbs the tap (ember's pad E shipped behind the level chip, which
    // is reported as "the text covers the tower spot").
    //
    // This rule lives here rather than in `MapValidator` the way the tower
    // reach rule does: it describes where the shipped HUD sits, which is a
    // presentation fact, while the synthetic profiling scenario is never
    // played and stays free to place pads wherever the geometry rules allow.
    const hudTopFraction = 0.25;

    for (final asset in mapAssets) {
      final map = await MapRepository().load(asset);
      final hudLine = map.worldHeight * hudTopFraction;
      for (final pad in map.buildPads) {
        final padTop = pad.position.y - map.buildPadRadius;
        expect(
          padTop,
          greaterThanOrEqualTo(hudLine),
          reason:
              '$asset -> pad "${pad.id}" is inside the top HUD strip '
              '(top edge ${padTop.toStringAsFixed(0)} units; the HUD reaches '
              '${hudLine.toStringAsFixed(0)} units on a '
              '${map.worldHeight.toStringAsFixed(0)}-unit-tall map)',
        );
      }
    }
  });

  test('the enemy catalog decodes and validates', () async {
    final catalog = await EnemyRepository().load(ContentCatalog.enemies);

    expect(catalog.length, greaterThanOrEqualTo(2));
    expect(catalog.contains('grunt'), isTrue);
    expect(catalog.contains('runner'), isTrue);
  });

  test('the tower catalog decodes and validates', () async {
    final catalog = await TowerRepository().load(ContentCatalog.towers);

    expect(catalog.length, greaterThanOrEqualTo(1));
    expect(catalog.contains('ranger'), isTrue);
    expect(catalog['ranger']!.buildCost, greaterThan(0));
  });

  test(
    'every shipped level resolves its map and every enemy reference',
    () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final levelAssets = await _assetsUnder(manifest, 'assets/data/levels/');

      expect(levelAssets, isNotEmpty);

      final repository = LevelRepository(
        mapRepository: MapRepository(),
        enemyRepository: EnemyRepository(),
        towerRepository: TowerRepository(),
      );

      for (final asset in levelAssets) {
        final bundle = await repository.load(asset);

        expect(bundle.level.waves, isNotEmpty, reason: asset);
        // Everything under levels/ is a campaign level (campaign_assets_test
        // pins the two lists together). An endless one could never reach
        // victory, so its unlock chain would soft-lock the campaign — the
        // endless run lives outside levels/ precisely to avoid that.
        expect(
          bundle.level.endless,
          isFalse,
          reason: '$asset is a campaign level and must not set "endless": true',
        );
        expect(bundle.map.id, bundle.level.mapId, reason: asset);
        expect(bundle.enemies.length, greaterThan(0), reason: asset);
        expect(bundle.towers.length, greaterThan(0), reason: asset);
        expect(
          bundle.towers.all.any(
            (tower) => tower.isAffordableWith(bundle.level.startingGold),
          ),
          isTrue,
          reason: '$asset starts with too little gold to build anything',
        );
        // Two goals per campaign level: stars are 1 + met, so this is what
        // keeps a 2- and 3-star ladder reachable (D68).
        expect(
          bundle.level.objectives,
          hasLength(2),
          reason: '$asset must declare exactly two objectives',
        );
        for (final objective in bundle.level.objectives) {
          if (objective.kind != LevelObjectiveKind.maxTowers) {
            continue;
          }
          final cheapest = bundle.towers.all
              .map((tower) => tower.buildCost)
              .reduce((a, b) => a < b ? a : b);
          expect(
            cheapest * objective.value!,
            lessThanOrEqualTo(bundle.level.startingGold),
            reason:
                '$asset asks for ${objective.value} towers but starts with '
                '${bundle.level.startingGold} gold, less than '
                '${cheapest * objective.value!} for the cheapest build',
          );
        }

        for (final wave in bundle.level.waves) {
          for (final group in wave.groups) {
            expect(
              bundle.enemies.contains(group.enemyId),
              isTrue,
              reason: '$asset -> ${wave.id} -> ${group.enemyId}',
            );
          }
        }
      }
    },
  );

  test('the endless level loads, validates and starts buildable', () async {
    final repository = LevelRepository(
      mapRepository: MapRepository(),
      enemyRepository: EnemyRepository(),
      towerRepository: TowerRepository(),
    );

    final bundle = await repository.load(ContentCatalog.endless);

    expect(bundle.level.endless, isTrue);
    expect(
      bundle.level.objectives,
      isEmpty,
      reason: 'an endless run can only end in defeat, so it has no goals',
    );
    expect(bundle.level.waves, isNotEmpty);
    expect(bundle.level.endlessCountGrowth, greaterThanOrEqualTo(0));
    expect(
      bundle.towers.all.any(
        (tower) => tower.isAffordableWith(bundle.level.startingGold),
      ),
      isTrue,
      reason: 'the endless level starts with too little gold to build',
    );
    for (final wave in bundle.level.waves) {
      for (final group in wave.groups) {
        expect(
          bundle.enemies.contains(group.enemyId),
          isTrue,
          reason: 'endless -> ${wave.id} -> ${group.enemyId}',
        );
      }
    }
  });
}
