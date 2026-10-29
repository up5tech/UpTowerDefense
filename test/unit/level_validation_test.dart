import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_validation.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_objective.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

import '../helpers/content_fixtures.dart';
import '../helpers/map_fixture.dart';

LevelDefinition _level({
  String id = 'test_level',
  String displayName = 'Test Level',
  String mapId = 'test_map',
  int coreHealth = 20,
  int startingGold = 150,
  double waveTransitionSeconds = LevelDefinition.defaultWaveTransitionSeconds,
  List<WaveDefinition>? waves,
  List<LevelObjective> objectives = const [],
  bool endless = false,
}) {
  return LevelDefinition(
    id: id,
    displayName: displayName,
    mapId: mapId,
    coreHealth: coreHealth,
    startingGold: startingGold,
    waveTransitionSeconds: waveTransitionSeconds,
    waves: waves ?? testLevel.waves,
    objectives: objectives,
    endless: endless,
  );
}

List<String> _issues(LevelDefinition level) {
  return const LevelValidator()
      .validate(level: level, map: testMap, enemies: testEnemyCatalog)
      .issues;
}

void main() {
  test('the fixture level is valid', () {
    expect(_issues(testLevel), isEmpty);
  });

  test('requires a positive core health', () {
    expect(_issues(_level(coreHealth: 0)), contains(contains('coreHealth')));
  });

  test('rejects negative starting gold', () {
    expect(
      _issues(_level(startingGold: -1)),
      contains(contains('startingGold must not be negative')),
    );
  });

  test('requires a positive wave transition countdown', () {
    expect(
      _issues(_level(waveTransitionSeconds: 0)),
      contains(contains('waveTransitionSeconds must be positive')),
    );
    expect(
      _issues(_level(waveTransitionSeconds: -1)),
      contains(contains('waveTransitionSeconds must be positive')),
    );
  });

  test('requires matching map ids', () {
    expect(
      _issues(_level(mapId: 'somewhere_else')),
      contains(contains('does not match the loaded map')),
    );
  });

  test('requires at least one wave', () {
    expect(
      _issues(_level(waves: const [])),
      contains(contains('at least one wave')),
    );
  });

  test('accepts either no objectives or exactly two', () {
    expect(_issues(_level()), isEmpty);
    expect(
      _issues(
        _level(
          objectives: const [
            LevelObjective.noLeaks(),
            LevelObjective.maxTowers(2),
          ],
        ),
      ),
      isEmpty,
    );
    expect(
      _issues(_level(objectives: const [LevelObjective.noLeaks()])),
      contains(contains('0 or exactly 2')),
    );
    expect(
      _issues(
        _level(
          objectives: const [
            LevelObjective.noLeaks(),
            LevelObjective.maxTowers(2),
            LevelObjective.coreAbove(10),
          ],
        ),
      ),
      contains(contains('0 or exactly 2')),
    );
  });

  test('rejects the same objective twice', () {
    final issues = _issues(
      _level(
        objectives: const [
          LevelObjective.maxTowers(2),
          LevelObjective.maxTowers(3),
        ],
      ),
    );

    expect(issues, contains(contains('repeats "maxTowers"')));
  });

  test('rejects a tower limit the map cannot hold', () {
    final issues = _issues(
      _level(
        objectives: const [
          LevelObjective.maxTowers(99),
          LevelObjective.noLeaks(),
        ],
      ),
    );

    expect(
      issues,
      contains(contains('asks for 99 towers but the map has only')),
    );
  });

  test('rejects a non-positive threshold', () {
    final issues = _issues(
      _level(
        objectives: const [
          LevelObjective.maxTowers(0),
          LevelObjective.noLeaks(),
        ],
      ),
    );

    expect(issues, contains(contains('must be at least 1')));
  });

  test('rejects a deadline shorter than the spawn schedule', () {
    final issues = _issues(
      _level(
        objectives: const [
          LevelObjective.deadlineSeconds(1),
          LevelObjective.noLeaks(),
        ],
      ),
    );

    expect(issues, contains(contains('cannot finish spawning before')));
  });

  test('rejects a core floor that restates noLeaks', () {
    final issues = _issues(
      _level(
        objectives: const [
          LevelObjective.coreAbove(20),
          LevelObjective.maxTowers(2),
        ],
      ),
    );

    expect(issues, contains(contains('must stay below coreHealth')));
  });

  test('rejects objectives on an endless level', () {
    final issues = _issues(
      _level(
        endless: true,
        objectives: const [
          LevelObjective.noLeaks(),
          LevelObjective.maxTowers(2),
        ],
      ),
    );

    expect(issues, contains(contains('endless level cannot declare')));
  });

  test('rejects duplicate wave ids', () {
    final issues = _issues(
      _level(
        waves: const [
          WaveDefinition(
            id: 'wave',
            groups: [
              SpawnGroupDefinition(
                enemyId: 'grunt',
                count: 1,
                spawnIntervalSeconds: 1,
              ),
            ],
          ),
          WaveDefinition(
            id: 'wave',
            groups: [
              SpawnGroupDefinition(
                enemyId: 'grunt',
                count: 1,
                spawnIntervalSeconds: 1,
              ),
            ],
          ),
        ],
      ),
    );

    expect(issues, contains(contains('is duplicated')));
  });

  test('rejects unknown enemy references', () {
    expect(
      _issues(
        _level(
          waves: const [
            WaveDefinition(
              id: 'wave',
              groups: [
                SpawnGroupDefinition(
                  enemyId: 'dragon',
                  count: 1,
                  spawnIntervalSeconds: 1,
                ),
              ],
            ),
          ],
        ),
      ),
      contains(contains('unknown enemy "dragon"')),
    );
  });

  test('rejects empty waves and invalid group values', () {
    final issues = _issues(
      _level(
        waves: const [
          WaveDefinition(id: 'empty', groups: []),
          WaveDefinition(
            id: 'bad',
            groups: [
              SpawnGroupDefinition(
                enemyId: 'grunt',
                count: 0,
                spawnIntervalSeconds: 0,
                initialDelaySeconds: -1,
              ),
            ],
          ),
        ],
      ),
    );

    expect(issues, contains(contains('at least one spawn group')));
    expect(issues, contains(contains('count must be positive')));
    expect(issues, contains(contains('spawnIntervalSeconds must be positive')));
    expect(
      issues,
      contains(contains('initialDelaySeconds must not be negative')),
    );
  });
}
