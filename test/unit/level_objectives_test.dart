import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_objective.dart';
import 'package:up_tower_defense/features/gameplay/domain/objective_status.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

/// Objective scoring (D68): the four kinds, the peak-tower rule and the "a lost
/// goal is lost immediately" rule.
///
/// Domain only: no widget is pumped, so a goal that can only be judged through a
/// renderer would fail here before it could reach a player.
LevelDefinition _levelWith(
  List<LevelObjective> objectives, {
  int coreHealth = 5,
  int startingGold = 150,
}) {
  return LevelDefinition(
    id: 'objectives_level',
    displayName: 'Objectives Level',
    mapId: testMap.id,
    coreHealth: coreHealth,
    startingGold: startingGold,
    waves: testLevel.waves,
    objectives: objectives,
  );
}

LevelSession _session(
  List<LevelObjective> objectives, {
  int coreHealth = 5,
}) {
  return LevelSession(
    level: _levelWith(objectives, coreHealth: coreHealth),
    map: testMap,
    enemyCatalog: testEnemyCatalog,
    towerCatalog: testTowerCatalog,
  );
}

/// Runs [session] until it finishes, the way the engine would.
void _runToEnd(LevelSession session, {double dt = 1 / 60}) {
  session.startNextWave();
  for (var frame = 0; frame < 60 * 120; frame++) {
    session.advance(dt);
    if (LevelPhaseTransitions.isTerminal(session.phase)) {
      return;
    }
  }
  fail('the level never finished');
}

void main() {
  group('noLeaks', () {
    test('is met until an enemy reaches the core', () {
      final session = _session(const [LevelObjective.noLeaks()]);

      expect(session.objectivesMet, 1);
      expect(session.objectiveStatuses.single.isMet, isTrue);

      session.startNextWave();
      // Long enough for the opening grunt to cross the route and leak.
      for (var frame = 0; frame < 60 * 30 && session.leaks == 0; frame++) {
        session.advance(1 / 60);
      }

      expect(session.leaks, greaterThan(0));
      // Lost on the leak, not at the result screen.
      expect(session.objectiveStatuses.single.hasFailed, isTrue);
      expect(session.objectivesMet, 0);
    });
  });

  group('maxTowers', () {
    test('counts the peak, so selling cannot refund the goal', () {
      final session = _session(const [LevelObjective.maxTowers(1)]);
      final ranger = testTowerCatalog['ranger']!;

      expect(session.buildTower('pad_a', ranger).isBuilt, isTrue);
      expect(session.objectiveStatuses.single.isMet, isTrue);

      expect(session.buildTower('pad_b', ranger).isBuilt, isTrue);
      expect(session.peakTowerCount, 2);
      expect(session.objectiveStatuses.single.hasFailed, isTrue);

      // Selling drops the field to one tower but not the recorded peak: the
      // goal measures occupancy, not the end state.
      expect(session.sellTowerAt('pad_b').isSold, isTrue);
      expect(session.towerCount, 1);
      expect(session.peakTowerCount, 2);
      expect(session.objectiveStatuses.single.hasFailed, isTrue);
    });

    test('a restart forgets the peak with everything else', () {
      final session = _session(const [LevelObjective.maxTowers(1)]);
      final ranger = testTowerCatalog['ranger']!;
      session.buildTower('pad_a', ranger);
      session.buildTower('pad_b', ranger);

      session.restart();

      expect(session.peakTowerCount, 0);
      expect(session.objectiveStatuses.single.isMet, isTrue);
    });
  });

  group('deadlineSeconds', () {
    test('fails the moment play time passes it, before the level ends', () {
      final session = _session(const [LevelObjective.deadlineSeconds(3)]);

      session.startNextWave();
      for (var frame = 0; frame < 60 * 4; frame++) {
        session.advance(1 / 60);
      }

      expect(session.elapsed, greaterThan(3));
      expect(session.objectiveStatuses.single.hasFailed, isTrue);
      expect(session.phase, isNot(LevelPhase.victory));
    });

    test('is met by a victory inside it, at any frame rate', () {
      final outcomes = <String>[];
      for (final dt in const [1 / 60, 1 / 30, 0.2]) {
        final session = _session(const [LevelObjective.deadlineSeconds(120)]);
        _runToEnd(session, dt: dt);
        outcomes.add(
          '${session.phase} leaks ${session.leaks} '
          'core ${session.coreHealth} met ${session.objectivesMet}',
        );
      }

      expect(outcomes.toSet(), hasLength(1), reason: '$outcomes');
      expect(outcomes.first, contains('LevelPhase.victory'));
      expect(outcomes.first, contains('met 1'));
    });
  });

  group('coreAbove', () {
    test('is pending while it can still be met, then failed by a leak', () {
      final session = _session(const [LevelObjective.coreAbove(5)]);

      expect(
        session.objectiveStatuses.single.state,
        LevelObjectiveState.pending,
      );

      session.startNextWave();
      for (var frame = 0; frame < 60 * 30 && session.leaks == 0; frame++) {
        session.advance(1 / 60);
      }

      expect(session.coreHealth, lessThan(5));
      expect(session.objectiveStatuses.single.hasFailed, isTrue);
    });

    test('is met by a victory that keeps the health', () {
      // Nothing is built, so the three enemies leak one core point each: the
      // core survives and the level still ends in victory.
      final session = _session(const [LevelObjective.coreAbove(2)]);
      _runToEnd(session);

      expect(session.phase, LevelPhase.victory);
      expect(session.coreHealth, 2);
      expect(session.objectivesMet, 1);
    });
  });

  group('frame-rate independence', () {
    test('the whole goal list agrees at 1/60, 1/30 and a coarse step', () {
      final outcomes = <String>[];
      for (final dt in const [1 / 60, 1 / 30, 0.2]) {
        final session = _session(const [
          LevelObjective.noLeaks(),
          LevelObjective.maxTowers(1),
        ]);
        _runToEnd(session, dt: dt);
        outcomes.add(
          session.objectiveStatuses
              .map(
                (status) => '${status.objective.kind.wireName}=${status.state}',
              )
              .join(','),
        );
      }

      expect(outcomes.toSet(), hasLength(1), reason: '$outcomes');
    });
  });

  test('a level with no goals reports none', () {
    final session = LevelSession(
      level: testLevel,
      map: testMap,
      enemyCatalog: testEnemyCatalog,
      towerCatalog: testTowerCatalog,
    );

    expect(session.objectiveStatuses, isEmpty);
    expect(session.objectivesMet, 0);
  });
}
