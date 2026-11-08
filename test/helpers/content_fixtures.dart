import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/speed_surge.dart';
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

/// A grunt that never moves, so a test can pin a geometry a moving field
/// would blur.
///
/// The chain's tie-break compares squared distances for exact equality, so a
/// drifting field can turn an intended tie into two slightly different
/// numbers and let rounding decide the order instead of the rule. A
/// stationary enemy keeps the measured distance exact for the whole run.
const EnemyDefinition testStationaryGrunt = EnemyDefinition(
  id: 'stationary_grunt',
  displayName: 'Stationary Grunt',
  maxHealth: 100,
  speed: 0,
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

/// Boss fixture for the D69 speed surge: tough enough to survive the crossing of
/// its threshold, slow enough to watch it move, and armed at half health.
const EnemyDefinition testBoss = EnemyDefinition(
  id: 'boss',
  displayName: 'Warden',
  maxHealth: 600,
  speed: 40,
  coreDamageOnLeak: 6,
  rewardGold: 140,
  radius: 24,
  colorValue: 0xFFA45CD6,
  isBoss: true,
  speedSurge: SpeedSurge(
    healthRatio: 0.5,
    multiplier: 1.5,
    durationSeconds: 3,
  ),
);

/// Enemy catalog matching [testGrunt] and [testRunner].
final EnemyCatalog testEnemyCatalog = EnemyCatalog(const [
  testGrunt,
  testRunner,
]);

/// Catalog for surge tests: the boss beside the plain grunt, so a level can be
/// climbed with damage that is not the boss.
final EnemyCatalog testBossCatalog = EnemyCatalog(const [testBoss, testGrunt]);

/// Catalog for the chain tie-break test: one enemy type, and it never moves.
final EnemyCatalog stationaryEnemyCatalog = EnemyCatalog(const [
  testStationaryGrunt,
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

/// Arc-like tower fixture: chain jumps with falloff behind a small blast, so
/// the chain walk, the splash exclusion and their interaction all have one
/// fixture to share.
const TowerDefinition testArc = TowerDefinition(
  id: 'arc',
  displayName: 'Arc Tower',
  role: 'Chain damage',
  description: 'Shots that jump between enemies.',
  buildCost: 95,
  sellRefundRate: 0.6,
  colorValue: 0xFFFFD166,
  levels: [
    TowerLevelStats(
      damage: 24,
      range: 220,
      fireCooldownSeconds: 0.9,
      projectileSpeed: 600,
      splashRadius: 60,
      chainCount: 2,
      chainRadius: 160,
      chainFalloff: 0.5,
    ),
  ],
);

/// Beacon fixture: a support level that projects range instead of shooting,
/// with two levels so the upgrade preview has a next level to ask for.
const TowerDefinition testBeacon = TowerDefinition(
  id: 'beacon',
  displayName: 'Beacon Tower',
  role: 'Range support',
  description: 'Widens the range of nearby towers.',
  buildCost: 70,
  sellRefundRate: 0.6,
  colorValue: 0xFFE46DD4,
  levels: [
    TowerLevelStats(
      damage: 0,
      range: 300,
      fireCooldownSeconds: 1,
      projectileSpeed: 600,
      auraRadius: 500,
      auraRangeBonus: 0.2,
      upgradeCost: 70,
    ),
    TowerLevelStats(
      damage: 0,
      range: 340,
      fireCooldownSeconds: 1,
      projectileSpeed: 600,
      auraRadius: 500,
      auraRangeBonus: 0.3,
    ),
  ],
);

/// Shielded fixture for the flat per-hit reduction (D80): six off every hit,
/// comfortably below its own health so the level stays winnable.
const EnemyDefinition testShielded = EnemyDefinition(
  id: 'shielded',
  displayName: 'Shielded',
  maxHealth: 100,
  speed: 60,
  coreDamageOnLeak: 1,
  rewardGold: 12,
  radius: 14,
  colorValue: 0xFF5C7A99,
  flatDamageReduction: 6,
);

/// Splitter fixture: dies into two runners at its own route progress, and the
/// runner it spawns must not itself split.
const EnemyDefinition testSplitter = EnemyDefinition(
  id: 'splitter',
  displayName: 'Splitter',
  maxHealth: 170,
  speed: 68,
  coreDamageOnLeak: 1,
  rewardGold: 16,
  radius: 15,
  colorValue: 0xFF7BC950,
  splitInto: SplitSpec(enemyId: 'runner', count: 2),
);

/// Tower catalog matching [testRanger].
///
/// Cannon and frost stay out of the default catalog so widget tests keep a
/// single build option; combat tests inject them explicitly and roster tests
/// use [fullTowerCatalog].
final TowerCatalog testTowerCatalog = TowerCatalog(const [testRanger]);

/// The V2-2 mechanic roster: the ranger beside the arc, the beacon and the
/// frost, so one session can field a support tower and the shooter it buffs —
/// or a shield test with a hit small enough for the shield to eat.
final TowerCatalog mechanicTowerCatalog = TowerCatalog(const [
  testRanger,
  testFrost,
  testArc,
  testBeacon,
]);

/// The V2-2 enemy fixtures: the shield, the splitter and the runner its split
/// spawns.
final EnemyCatalog mechanicEnemyCatalog = EnemyCatalog(const [
  testShielded,
  testSplitter,
  testRunner,
]);

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
