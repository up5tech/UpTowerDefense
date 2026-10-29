import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_level_stats.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

import 'map_fixture.dart';

/// Grunt-like enemy used by session and HUD tests.
const EnemyDefinition testGrunt = EnemyDefinition(
  id: 'grunt',
  displayName: 'Grunt',
  maxHealth: 100,
  speed: 80,
  coreDamageOnLeak: 1,
  rewardGold: 10,
  radius: 14,
  colorValue: 0xFFD96B5B,
);

/// Faster, lighter enemy so multi-group waves are meaningful in tests.
const EnemyDefinition testRunner = EnemyDefinition(
  id: 'runner',
  displayName: 'Runner',
  maxHealth: 60,
  speed: 140,
  coreDamageOnLeak: 1,
  rewardGold: 8,
  radius: 11,
  colorValue: 0xFFE0A34A,
);

/// Enemy catalog matching [testGrunt] and [testRunner].
final EnemyCatalog testEnemyCatalog = EnemyCatalog(const [
  testGrunt,
  testRunner,
]);

/// Ranger-like tower used by build and HUD tests.
const TowerDefinition testRanger = TowerDefinition(
  id: 'ranger',
  displayName: 'Ranger Tower',
  role: 'Fast single target',
  description: 'Quick shots that pick off the leading enemy.',
  buildCost: 70,
  sellRefundRate: 0.6,
  colorValue: 0xFF4FD1C5,
  levels: [
    TowerLevelStats(
      damage: 18,
      range: 210,
      fireCooldownSeconds: 0.7,
      projectileSpeed: 600,
      upgradeCost: 60,
    ),
    TowerLevelStats(
      damage: 27,
      range: 225,
      fireCooldownSeconds: 0.66,
      projectileSpeed: 600,
      upgradeCost: 95,
    ),
    TowerLevelStats(
      damage: 40,
      range: 245,
      fireCooldownSeconds: 0.6,
      projectileSpeed: 600,
    ),
  ],
);

/// Splash tower fixture: two levels so upgrade tests can reach the max.
const TowerDefinition testCannon = TowerDefinition(
  id: 'cannon',
  displayName: 'Cannon Tower',
  role: 'Area damage',
  description: 'Shells that explode on impact.',
  buildCost: 110,
  sellRefundRate: 0.6,
  colorValue: 0xFFE8A05C,
  levels: [
    TowerLevelStats(
      damage: 26,
      range: 200,
      fireCooldownSeconds: 1.6,
      projectileSpeed: 380,
      splashRadius: 70,
      upgradeCost: 90,
    ),
    TowerLevelStats(
      damage: 40,
      range: 215,
      fireCooldownSeconds: 1.5,
      projectileSpeed: 380,
      splashRadius: 78,
    ),
  ],
);

/// Slow tower fixture: applies a capped slow instead of meaningful damage.
const TowerDefinition testFrost = TowerDefinition(
  id: 'frost',
  displayName: 'Frost Tower',
  role: 'Control',
  description: 'Chills enemies so other towers hit more often.',
  buildCost: 85,
  sellRefundRate: 0.6,
  colorValue: 0xFF7FB8FF,
  levels: [
    TowerLevelStats(
      damage: 4,
      range: 190,
      fireCooldownSeconds: 1.2,
      projectileSpeed: 420,
      slow: SlowSpec(
        magnitude: 0.4,
        durationSeconds: 2.5,
        minSpeedRatio: 0.4,
        damageAmp: 0.25,
      ),
      upgradeCost: 65,
    ),
    TowerLevelStats(
      damage: 6,
      range: 205,
      fireCooldownSeconds: 1.1,
      projectileSpeed: 420,
      slow: SlowSpec(
        magnitude: 0.5,
        durationSeconds: 3,
        minSpeedRatio: 0.4,
      ),
    ),
  ],
);

/// Tower catalog matching [testRanger].
///
/// Cannon and frost stay out of the default catalog so widget tests keep a
/// single build option; combat tests inject them explicitly and roster tests
/// use [fullTowerCatalog].
final TowerCatalog testTowerCatalog = TowerCatalog(const [testRanger]);

/// The full Phase 6 roster, ordered like the shipped catalog.
///
/// Used by widget tests that exercise the build panel with every tower and the
/// tower panel's splash/slow chips.
final TowerCatalog fullTowerCatalog = TowerCatalog(const [
  testRanger,
  testFrost,
  testCannon,
]);

/// Two-wave level on [testMap]; short enough to simulate quickly in tests.
const LevelDefinition testLevel = LevelDefinition(
  id: 'test_level',
  displayName: 'Test Meadow',
  mapId: 'test_map',
  coreHealth: 5,
  startingGold: 150,
  waves: [
    WaveDefinition(
      id: 'wave_1',
      groups: [
        SpawnGroupDefinition(
          enemyId: 'grunt',
          count: 2,
          spawnIntervalSeconds: 1,
          initialDelaySeconds: 0.5,
        ),
      ],
    ),
    WaveDefinition(
      id: 'wave_2',
      groups: [
        SpawnGroupDefinition(
          enemyId: 'runner',
          count: 1,
          spawnIntervalSeconds: 1,
        ),
      ],
    ),
  ],
);

/// Everything a gameplay screen needs for the fixture content.
final LevelBundle testBundle = LevelBundle(
  level: testLevel,
  map: testMap,
  enemies: testEnemyCatalog,
  towers: testTowerCatalog,
);

/// Four-level campaign fixture: two regions of two levels, in play order.
///
/// Small enough to read in a test, long enough to prove the unlock chain crosses
/// a region boundary.
final CampaignDefinition testCampaign = CampaignDefinition([
  CampaignRegion(
    id: 'region_one',
    displayName: 'Region One',
    levels: const [
      CampaignLevel(id: 'test_level', displayName: 'Test Meadow'),
      CampaignLevel(id: 'test_level_2', displayName: 'Second Meadow'),
    ],
  ),
  CampaignRegion(
    id: 'region_two',
    displayName: 'Region Two',
    levels: const [
      CampaignLevel(id: 'test_level_3', displayName: 'Third Meadow'),
      CampaignLevel(id: 'test_level_4', displayName: 'Fourth Meadow'),
    ],
  ),
]);

/// A bundle for [levelId] built from the fixture level.
///
/// The level keeps the requested id so campaign progress recorded by the screen
/// lands on the level the player actually opened, not on the fixture's default.
LevelBundle bundleForLevel(String levelId) {
  return LevelBundle(
    level: LevelDefinition(
      id: levelId,
      displayName: testLevel.displayName,
      mapId: testLevel.mapId,
      coreHealth: testLevel.coreHealth,
      startingGold: testLevel.startingGold,
      waves: testLevel.waves,
    ),
    map: testMap,
    enemies: testEnemyCatalog,
    towers: testTowerCatalog,
  );
}

/// [testBundle] with the full tower roster, for tests that build cannon or
/// frost towers through the real screen.
final LevelBundle rosterBundle = LevelBundle(
  level: testLevel,
  map: testMap,
  enemies: testEnemyCatalog,
  towers: fullTowerCatalog,
);
