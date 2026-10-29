import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/targeting_policy.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_level_stats.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/tower_sell_result.dart';
import 'package:up_tower_defense/features/gameplay/domain/tower_upgrade_result.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

const String _padA = 'pad_a';
const String _padB = 'pad_b';

LevelSession _session({int startingGold = 150}) {
  return LevelSession(
    level: LevelDefinition(
      id: testLevel.id,
      displayName: testLevel.displayName,
      mapId: testLevel.mapId,
      coreHealth: testLevel.coreHealth,
      startingGold: startingGold,
      waves: testLevel.waves,
    ),
    map: testMap,
    enemyCatalog: testEnemyCatalog,
    towerCatalog: testTowerCatalog,
  );
}

/// Refund probe: 70 build + 26 upgrade is 96 invested, and 60% of 96 is 57.6,
/// so the refund must floor to 57.
const TowerDefinition _refundProbe = TowerDefinition(
  id: 'refund_probe',
  displayName: 'Refund Probe',
  role: 'Test',
  description: 'Invested gold that does not divide evenly by the refund rate.',
  buildCost: 70,
  sellRefundRate: 0.6,
  colorValue: 0xFF4FD1C5,
  levels: [
    TowerLevelStats(
      damage: 10,
      range: 100,
      fireCooldownSeconds: 1,
      projectileSpeed: 100,
      upgradeCost: 26,
    ),
    TowerLevelStats(
      damage: 12,
      range: 100,
      fireCooldownSeconds: 1,
      projectileSpeed: 100,
    ),
  ],
);

/// Rate probe: level 2 fires more than twice as fast as level 1, so charging
/// the cooldown from the wrong level cannot slip past a loose assertion.
const TowerDefinition _rateProbe = TowerDefinition(
  id: 'rate_probe',
  displayName: 'Rate Probe',
  role: 'Test',
  description: 'Fires much faster after a single upgrade.',
  buildCost: 50,
  sellRefundRate: 0.6,
  colorValue: 0xFF4FD1C5,
  levels: [
    TowerLevelStats(
      damage: 1,
      range: 400,
      fireCooldownSeconds: 1,
      projectileSpeed: 900,
      upgradeCost: 10,
    ),
    TowerLevelStats(
      damage: 1,
      range: 400,
      fireCooldownSeconds: 0.4,
      projectileSpeed: 900,
    ),
  ],
);

/// Tanky walker used to prove the strongest-policy tower picks by health.
const EnemyDefinition _tank = EnemyDefinition(
  id: 'tank',
  displayName: 'Tank',
  maxHealth: 400,
  speed: 80,
  coreDamageOnLeak: 1,
  rewardGold: 20,
  radius: 16,
  colorValue: 0xFF8A7F8D,
);

/// A grunt and a tank entering together: same route position, very different
/// health, so only the policy decides who gets shot.
const LevelDefinition _policyLevel = LevelDefinition(
  id: 'policy_test',
  displayName: 'Policy Test',
  mapId: 'test_map',
  coreHealth: 5,
  startingGold: 150,
  waves: [
    WaveDefinition(
      id: 'wave_1',
      groups: [
        SpawnGroupDefinition(
          enemyId: 'grunt',
          count: 1,
          spawnIntervalSeconds: 1,
        ),
        SpawnGroupDefinition(
          enemyId: 'tank',
          count: 1,
          spawnIntervalSeconds: 1,
        ),
      ],
    ),
  ],
);

LevelSession _policySession() {
  return LevelSession(
    level: _policyLevel,
    map: testMap,
    enemyCatalog: EnemyCatalog(const [testGrunt, _tank]),
    towerCatalog: testTowerCatalog,
  );
}

/// A session driven to victory: both waves spawned and fully resolved.
LevelSession _wonSession() {
  final session = _session();
  session.buildTower(_padA, testRanger);
  session.startNextWave();
  session.advance(2);
  for (final enemy in session.enemies.toList()) {
    session.reportEnemyDefeated(enemy);
  }
  session.startNextWave();
  session.advance(1.2);
  for (final enemy in session.enemies.toList()) {
    session.reportEnemyDefeated(enemy);
  }
  return session;
}

/// Advances frame by frame until the next shot is fired and returns the
/// simulation time it happened at.
///
/// Shot timing is what the cooldown rule controls, so measuring the clock
/// instead of a count keeps the assertion exact rather than a range.
double _timeOfNextShot(LevelSession session) {
  for (var i = 0; i < 600; i++) {
    session.advance(1 / 60);
    final fired = session.drainEvents().any(
      (event) => event.kind == LevelEventKind.shot,
    );
    if (fired) {
      return session.elapsed;
    }
  }
  fail('no shot was fired within ten simulated seconds');
}

void main() {
  group('upgrades', () {
    test('an upgrade spends its cost and applies the next level stats', () {
      final session = _session();
      session.buildTower(_padA, testRanger);

      final result = session.upgradeTowerAt(_padA);

      expect(result.isUpgraded, isTrue);
      expect(result.blocker, isNull);
      expect(result.goldSpent, 60);
      final tower = session.towerAtPad(_padA)!;
      expect(tower.level, 2);
      expect(tower.stats.damage, 27);
      expect(tower.stats.range, 225);
      expect(tower.stats.fireCooldownSeconds, 0.66);
      expect(session.gold, 20);
    });

    test('an upgrade publishes one fact and a refusal publishes none', () {
      final session = _session();
      session.buildTower(_padA, testRanger);
      session.drainEvents();

      session.upgradeTowerAt(_padA);

      final upgraded = session
          .drainEvents()
          .where((event) => event.kind == LevelEventKind.upgraded)
          .toList();
      expect(upgraded, hasLength(1));
      expect(upgraded.single.position.x, 180);
      expect(upgraded.single.position.y, 360);

      // 20 gold is left and the next level costs more: refused, so no cue.
      expect(session.gold, 20);
      final refused = session.upgradeTowerAt(_padA);
      expect(refused.isUpgraded, isFalse);
      expect(
        session.drainEvents().where(
          (event) => event.kind == LevelEventKind.upgraded,
        ),
        isEmpty,
      );
    });

    test('invested gold accumulates across build and upgrades', () {
      final session = _session(startingGold: 400);
      session.buildTower(_padA, testRanger);
      session.upgradeTowerAt(_padA);

      expect(session.towerAtPad(_padA)!.investedGold, 130);

      session.upgradeTowerAt(_padA);
      final tower = session.towerAtPad(_padA)!;

      expect(tower.level, 3);
      expect(tower.isMaxLevel, isTrue);
      expect(tower.nextUpgradeCost, isNull);
      expect(tower.investedGold, 225);
      expect(session.gold, 175);
    });

    test('a max-level tower refuses further upgrades', () {
      final session = _session(startingGold: 400);
      session.buildTower(_padA, testRanger);
      session.upgradeTowerAt(_padA);
      session.upgradeTowerAt(_padA);

      final result = session.upgradeTowerAt(_padA);

      expect(result.isUpgraded, isFalse);
      expect(result.blocker, TowerUpgradeBlocker.maxLevel);
      expect(result.goldSpent, 0);
      expect(session.gold, 175);
      expect(session.towerAtPad(_padA)!.level, 3);
    });

    test('an unaffordable upgrade is refused and changes nothing', () {
      final session = _session(startingGold: 100);
      session.buildTower(_padA, testRanger);

      final result = session.upgradeTowerAt(_padA);

      expect(result.isUpgraded, isFalse);
      expect(result.blocker, TowerUpgradeBlocker.insufficientGold);
      expect(session.gold, 30);
      expect(session.towerAtPad(_padA)!.level, 1);
      expect(session.towerAtPad(_padA)!.investedGold, 70);
    });

    test('upgrade refusals name the exact rule', () {
      final session = _session();

      expect(
        session.upgradeTowerAt('pad_zzz').blocker,
        TowerUpgradeBlocker.unknownPad,
      );
      expect(
        session.upgradeTowerAt(_padB).blocker,
        TowerUpgradeBlocker.padEmpty,
      );

      session.buildTower(_padA, testRanger);
      expect(
        session.upgradeTowerAt('pad_zzz').blocker,
        TowerUpgradeBlocker.unknownPad,
      );
      expect(session.gold, 80);
      expect(session.towerAtPad(_padA)!.level, 1);
    });

    test('a finished level refuses every upgrade', () {
      final session = _wonSession();
      expect(session.phase, LevelPhase.victory);
      final gold = session.gold;

      final result = session.upgradeTowerAt(_padA);

      expect(result.blocker, TowerUpgradeBlocker.levelEnded);
      expect(session.gold, gold);
      expect(session.towerAtPad(_padA)!.level, 1);
    });

    test('canUpgradeAt agrees with upgradeTowerAt', () {
      final session = _session(startingGold: 100);
      session.buildTower(_padA, testRanger);

      expect(session.canUpgradeAt(_padA), isFalse);
      expect(session.upgradeTowerAt(_padA).isUpgraded, isFalse);

      session.gold = 60;
      expect(session.canUpgradeAt(_padA), isTrue);
      expect(session.upgradeTowerAt(_padA).isUpgraded, isTrue);

      expect(session.canUpgradeAt(_padA), isFalse);
      expect(session.canUpgradeAt(_padB), isFalse);
      expect(session.canUpgradeAt('pad_zzz'), isFalse);
    });

    test('an upgraded tower fires with its new stats', () {
      final session = _session();
      session.buildTower(_padA, testRanger);
      session.startNextWave();

      // The first shot carries the level-1 damage.
      for (var i = 0; i < 120 && session.projectiles.isEmpty; i++) {
        session.advance(1 / 60);
      }
      expect(session.projectiles.single.damage, 18);

      expect(session.upgradeTowerAt(_padA).isUpgraded, isTrue);

      // The next shot, after the cooldown, carries the level-2 damage.
      for (
        var i = 0;
        i < 240 && session.projectiles.every((p) => p.damage == 18);
        i++
      ) {
        session.advance(1 / 60);
      }
      expect(session.projectiles.last.damage, 27);
    });

    test('an upgraded tower fires on its new cooldown', () {
      final session = LevelSession(
        level: LevelDefinition(
          id: testLevel.id,
          displayName: testLevel.displayName,
          mapId: testLevel.mapId,
          coreHealth: testLevel.coreHealth,
          startingGold: 150,
          waves: testLevel.waves,
        ),
        map: testMap,
        enemyCatalog: testEnemyCatalog,
        towerCatalog: TowerCatalog(const [_rateProbe]),
      );
      session.buildTower(_padA, _rateProbe);
      session.startNextWave();

      // The first shot runs at the level-1 rate; upgrading afterwards must make
      // every later cooldown the level-2 value.
      _timeOfNextShot(session);
      expect(session.upgradeTowerAt(_padA).isUpgraded, isTrue);

      // The cooldown already charged before the upgrade still has to expire,
      // so the measured gap starts at the shot after it.
      _timeOfNextShot(session);
      final before = _timeOfNextShot(session);
      final after = _timeOfNextShot(session);

      // 0.4 s at 60 fps is 24 frames; the base 1.0 s rate would be 60.
      expect(after - before, closeTo(0.4, 0.02));
    });
  });

  group('selling', () {
    test('selling refunds the configured share of the build cost', () {
      final session = _session();
      session.buildTower(_padA, testRanger);

      final result = session.sellTowerAt(_padA);

      expect(result.isSold, isTrue);
      expect(result.blocker, isNull);
      expect(result.padId, _padA);
      expect(result.investedGold, 70);
      expect(result.refundGold, 42); // floor(70 * 0.6)
      expect(session.gold, 122);
      expect(session.towers, isEmpty);
      expect(session.towerAtPad(_padA), isNull);
      expect(session.isPadOccupied(_padA), isFalse);
    });

    test('the refund preview equals what the session pays', () {
      final session = _session();
      session.buildTower(_padA, testRanger);
      final tower = session.towerAtPad(_padA)!;
      session.upgradeTowerAt(_padA);

      // The panel shows definition.refundForInvested(investedGold) before the
      // player commits; the payout must be that exact number.
      final preview = tower.definition.refundForInvested(tower.investedGold);
      final result = session.sellTowerAt(_padA);

      expect(tower.investedGold, 130);
      expect(preview, 78);
      expect(result.refundGold, preview);
      expect(session.gold, 98);
    });

    test('the refund floors fractional gold', () {
      final session = LevelSession(
        level: LevelDefinition(
          id: testLevel.id,
          displayName: testLevel.displayName,
          mapId: testLevel.mapId,
          coreHealth: testLevel.coreHealth,
          startingGold: 150,
          waves: testLevel.waves,
        ),
        map: testMap,
        enemyCatalog: testEnemyCatalog,
        towerCatalog: TowerCatalog(const [_refundProbe]),
      );
      session.buildTower(_padA, _refundProbe);
      session.upgradeTowerAt(_padA);

      final result = session.sellTowerAt(_padA);

      // 60% of 96 invested is 57.6; refunds never invent fractions of gold.
      expect(result.investedGold, 96);
      expect(result.refundGold, 57);
      expect(session.gold, 111); // 150 - 96 + 57
    });

    test('sell refusals name the exact rule', () {
      final session = _session();

      expect(session.sellTowerAt(_padB).blocker, TowerSellBlocker.padEmpty);
      expect(
        session.sellTowerAt('pad_zzz').blocker,
        TowerSellBlocker.unknownPad,
      );

      session.buildTower(_padA, testRanger);
      expect(session.sellTowerAt(_padB).blocker, TowerSellBlocker.padEmpty);
      expect(session.gold, 80);
      expect(session.towerAtPad(_padA), isNotNull);
    });

    test('a finished level refuses every sell', () {
      final session = _wonSession();
      final gold = session.gold;

      final result = session.sellTowerAt(_padA);

      expect(result.blocker, TowerSellBlocker.levelEnded);
      expect(result.isSold, isFalse);
      expect(session.gold, gold);
      expect(session.towerAtPad(_padA), isNotNull);
    });

    test('selling frees the pad for an immediate rebuild', () {
      final session = _session();
      session.buildTower(_padA, testRanger);
      session.sellTowerAt(_padA);

      expect(session.canBuildOn(_padA, testRanger), isTrue);
      expect(session.buildTower(_padA, testRanger).isBuilt, isTrue);

      expect(session.towerCount, 1);
      expect(session.gold, 122 - 70);
    });

    test('canSellAt agrees with sellTowerAt', () {
      final session = _session();

      expect(session.canSellAt(_padA), isFalse);
      session.buildTower(_padA, testRanger);
      expect(session.canSellAt(_padA), isTrue);
      expect(session.canSellAt(_padB), isFalse);
      expect(session.canSellAt('pad_zzz'), isFalse);
    });
  });

  group('target priority', () {
    test('the policy can be set and changed on a built tower', () {
      final session = _session();
      session.buildTower(_padA, testRanger);

      expect(
        session.setTargetingPolicyAt(_padA, TargetingPolicy.strongest),
        isTrue,
      );
      expect(
        session.towerAtPad(_padA)!.targetingPolicy,
        TargetingPolicy.strongest,
      );

      expect(
        session.setTargetingPolicyAt(_padA, TargetingPolicy.first),
        isTrue,
      );
      expect(
        session.towerAtPad(_padA)!.targetingPolicy,
        TargetingPolicy.first,
      );
    });

    test('setting a policy on an empty pad fails', () {
      final session = _session();

      expect(
        session.setTargetingPolicyAt(_padA, TargetingPolicy.strongest),
        isFalse,
      );
      expect(
        session.setTargetingPolicyAt('pad_zzz', TargetingPolicy.strongest),
        isFalse,
      );
    });

    test('a strongest-policy tower shoots the toughest enemy in range', () {
      final session = _policySession();
      session.buildTower(_padA, testRanger);
      expect(
        session.setTargetingPolicyAt(_padA, TargetingPolicy.strongest),
        isTrue,
      );
      session.startNextWave();

      for (var i = 0; i < 120 && session.projectiles.isEmpty; i++) {
        session.advance(1 / 60);
      }

      // Both enemies walk in at the same speed from the same spawn point, so
      // only the policy separates them: the tank's 400 health wins.
      expect(session.projectiles.single.target.definition.id, 'tank');
    });
  });
}
