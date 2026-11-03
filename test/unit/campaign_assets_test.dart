import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/campaign/data/campaign_repository.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_validation.dart';
import 'package:up_tower_defense/features/gameplay/application/content_providers.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/data/level_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/map_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_repository.dart';
import 'package:up_tower_defense/features/gameplay/domain/map_geometry.dart';

import '../helpers/save_overrides.dart';

/// Campaign gate: the shipped campaign must load, cover every level file, and
/// every level in it must be playable in the ways a validator can check.
///
/// It cannot prove a level is *winnable* — that needs balance playtesting — but
/// it does catch the failure modes that make a level impossible before a player
/// ever sees it: a dangling reference, a level nobody can reach, starting gold
/// that buys nothing, no time to build before the first enemy, or a route so
/// short that the fastest enemy arrives before the player can react.
Future<List<String>> _levelAssetsUnder(AssetManifest manifest) async {
  final assets =
      manifest
          .listAssets()
          .where((asset) => asset.startsWith('assets/data/levels/'))
          .where((asset) => asset.endsWith('.json'))
          .toList()
        ..sort();
  return assets;
}

String _levelIdOf(String asset) {
  final name = asset.split('/').last;
  return name.substring(0, name.length - '.json'.length);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CampaignDefinition campaign;
  late Map<String, LevelBundle> bundles;

  setUpAll(() async {
    campaign = await CampaignRepository().load(ContentCatalog.campaign);

    final repository = LevelRepository(
      mapRepository: MapRepository(),
      enemyRepository: EnemyRepository(),
      towerRepository: TowerRepository(),
    );
    bundles = {
      for (final levelId in campaign.levelIds)
        levelId: await repository.load(
          ContentCatalog.levelAssetFor(levelId),
        ),
    };
  });

  test('the campaign ships at least two regions of five levels', () {
    expect(campaign.regions.length, greaterThanOrEqualTo(2));
    expect(campaign.levelCount, greaterThanOrEqualTo(10));
    for (final region in campaign.regions) {
      expect(region.levels.length, greaterThanOrEqualTo(2));
    }
  });

  test('the campaign lists exactly the level files that ship', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final shipped = (await _levelAssetsUnder(manifest)).map(_levelIdOf).toSet();

    expect(
      campaign.levelIds.toSet(),
      shipped,
      reason:
          'every shipped level must be reachable from the campaign, and every '
          'campaign level must have a file',
    );
  });

  test('the campaign passes validation against the shipped levels', () async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final known = (await _levelAssetsUnder(manifest)).map(_levelIdOf).toSet();

    final validation = const CampaignValidator().validate(
      campaign: campaign,
      knownLevelIds: known,
    );

    expect(validation.issues, isEmpty);
  });

  test('every campaign level loads and keeps its campaign name', () {
    for (final levelId in campaign.levelIds) {
      final bundle = bundles[levelId];

      expect(bundle, isNotNull, reason: levelId);
      expect(bundle!.level.id, levelId);
      expect(
        campaign.displayNameOf(levelId),
        bundle.level.displayName,
        reason: '$levelId: the campaign name and the level file must agree',
      );
      expect(bundle.map.id, bundle.level.mapId, reason: levelId);
    }
  });

  test('every level can be played: gold, pads, time to build, time to react', () {
    for (final levelId in campaign.levelIds) {
      final bundle = bundles[levelId]!;
      final level = bundle.level;
      final geometry = MapGeometry(bundle.map);

      // Starting gold must buy something, or the first wave arrives unopposed.
      expect(
        bundle.towers.all.any(
          (tower) => tower.isAffordableWith(level.startingGold),
        ),
        isTrue,
        reason: '$levelId starts with ${level.startingGold} gold',
      );

      // At least two pads, so the opening is a choice rather than a rail.
      expect(
        bundle.map.buildPads.length,
        greaterThanOrEqualTo(2),
        reason: levelId,
      );

      // Time to place a tower before the first enemy appears.
      for (final group in level.waves.first.groups) {
        expect(
          group.initialDelaySeconds,
          greaterThanOrEqualTo(1),
          reason: '$levelId first wave has no build window',
        );
      }

      // Time to react once the fastest enemy of the level is on the route.
      final speeds = [
        for (final wave in level.waves)
          for (final group in wave.groups) bundle.enemies[group.enemyId]!.speed,
      ];
      final fastest = speeds.reduce(math.max);
      expect(
        geometry.routeLength / fastest,
        greaterThanOrEqualTo(8),
        reason: '$levelId: the fastest enemy crosses too quickly',
      );

      expect(level.waves.length, greaterThanOrEqualTo(3), reason: levelId);
    }
  });

  test('the enemy roster covers the threats every level leans on', () {
    final referenced = <String>{
      for (final bundle in bundles.values)
        for (final wave in bundle.level.waves)
          for (final group in wave.groups) group.enemyId,
    };

    expect(referenced, containsAll(['grunt', 'runner', 'brute', 'boss']));
  });

  test('the boss is never an ambush, and the campaign ends on one', () {
    bool fieldsBoss(String levelId) => bundles[levelId]!.level.waves.any(
      (wave) => wave.groups.any((group) => group.enemyId == 'boss'),
    );

    // The finale is the boss level: the campaign has to end on its escalation.
    final finale = campaign.levelIds.last;
    expect(
      fieldsBoss(finale),
      isTrue,
      reason: 'the last campaign level should be the boss level',
    );

    // Region 3 teaches the D69 speed surge before the finale relies on it, so a
    // boss may appear more than once — but never as a surprise. Two rules keep
    // that honest: the first region stays boss-free (a new player is still
    // learning what a wave is), and no region opens with one, because a boss on
    // arrival reads as a wall rather than as an escalation.
    final firstRegion = campaign.regions.first;
    for (final level in firstRegion.levels) {
      expect(
        fieldsBoss(level.id),
        isFalse,
        reason: '${level.id} is in the first region and must not field a boss',
      );
    }
    for (final region in campaign.regions) {
      final opening = region.levels.first;
      expect(
        fieldsBoss(opening.id),
        isFalse,
        reason: '${region.id} opens with a boss',
      );
    }

    // The teaching appearance sits directly before the finale: the player meets
    // the surge on its own, then meets it again with the rest of the finale.
    final penultimate = campaign.levelIds[campaign.levelCount - 2];
    expect(
      fieldsBoss(penultimate),
      isTrue,
      reason:
          '$penultimate should introduce the surging boss before $finale '
          'requires it (V2-1)',
    );
  });

  test('Play opens the first campaign level and then the next one', () async {
    final container = ProviderContainer(
      overrides: [isolatedSaveOverride()],
    );
    addTearDown(container.dispose);

    // The real provider chain: campaign → progress → level bundle, all from
    // shipped assets. This is the path the Play button takes on a fresh launch.
    final first = await container.read(levelToPlayProvider.future);
    expect(first.level.id, campaign.levelIds.first);

    container
        .read(campaignProgressProvider.notifier)
        .record(
          LevelResult(
            levelId: first.level.id,
            stars: 3,
            coreHealth: first.level.coreHealth,
            maxCoreHealth: first.level.coreHealth,
            wavesCleared: first.level.waves.length,
            totalWaves: first.level.waves.length,
          ),
        );

    // Finishing it moves Play on, without any extra bookkeeping in the menu.
    final second = await container.read(levelToPlayProvider.future);
    expect(second.level.id, campaign.levelIds[1]);
  });
}
