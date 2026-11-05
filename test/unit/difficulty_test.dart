import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/difficulty_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/data/difficulty_repository.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_objective.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

import '../helpers/content_fixtures.dart';

const LevelDefinition _level = LevelDefinition(
  id: 'scaling',
  displayName: 'Scaling',
  mapId: 'test_map',
  coreHealth: 20,
  startingGold: 165,
  waveTransitionSeconds: 4,
  objectives: [LevelObjective.noLeaks(), LevelObjective.maxTowers(2)],
  waves: [
    WaveDefinition(
      id: 'wave_1',
      groups: [
        SpawnGroupDefinition(
          enemyId: 'grunt',
          count: 4,
          spawnIntervalSeconds: 1,
          initialDelaySeconds: 2,
        ),
        SpawnGroupDefinition(
          enemyId: 'runner',
          count: 1,
          spawnIntervalSeconds: 1,
        ),
      ],
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('a profile scales a level without changing what it is', () {
    test('counts and gold move; core, goals and pacing stay authored', () {
      const hard = DifficultyProfile(
        difficulty: Difficulty.hard,
        waveCountPercent: 125,
        startingGoldPercent: 90,
      );

      final tuned = hard.applyTo(_level);

      expect(tuned.waves.single.groups[0].count, 5);
      expect(tuned.waves.single.groups[1].count, 1, reason: 'never below 1');
      // Integer arithmetic: 165 × 90 / 100 = 148, never 148.5.
      expect(tuned.startingGold, 148);
      expect(tuned.coreHealth, _level.coreHealth);
      expect(tuned.objectives, _level.objectives);
      expect(tuned.waveTransitionSeconds, _level.waveTransitionSeconds);
      expect(tuned.id, _level.id);
      expect(tuned.endless, isFalse);
    });

    test('a neutral profile returns the level untouched', () {
      expect(
        identical(DifficultyProfile.normal.applyTo(_level), _level),
        isTrue,
      );
      expect(DifficultyProfile.normal.isNeutral, isTrue);
    });

    test('scaling twice is not the same as scaling once', () {
      const hard = DifficultyProfile(
        difficulty: Difficulty.hard,
        waveCountPercent: 125,
        startingGoldPercent: 90,
      );

      final once = hard.applyTo(_level);
      final twice = hard.applyTo(once);

      // The point is only that a profile is applied exactly once, at load: a
      // second pass would compound a fourth enemy into the level.
      expect(
        twice.waves.single.groups[0].count,
        greaterThan(
          once.waves.single.groups[0].count,
        ),
      );
    });
  });

  group('decoding difficulties.json', () {
    test('reads every authored profile', () {
      final profiles = DifficultyJsonDecoder.decode(
        '{"profiles":['
        '{"difficulty":"normal","waveCountPercent":100,'
        '"startingGoldPercent":100},'
        '{"difficulty":"hard","waveCountPercent":125,'
        '"startingGoldPercent":90}]}',
      );

      expect(profiles, hasLength(2));
      expect(
        profiles
            .firstWhere((p) => p.difficulty == Difficulty.hard)
            .waveCountPercent,
        125,
      );
    });

    test('refuses an unknown mode, a repeat and a non-positive percentage', () {
      expect(
        () => DifficultyJsonDecoder.decode(
          '{"profiles":['
          '{"difficulty":"nightmare","waveCountPercent":100,'
          '"startingGoldPercent":100}]}',
        ),
        throwsA(isA<ContentFormatException>()),
      );
      expect(
        () => DifficultyJsonDecoder.decode(
          '{"profiles":['
          '{"difficulty":"normal","waveCountPercent":100,'
          '"startingGoldPercent":100},'
          '{"difficulty":"normal","waveCountPercent":110,'
          '"startingGoldPercent":100}]}',
        ),
        throwsA(isA<ContentFormatException>()),
      );
      expect(
        () => DifficultyJsonDecoder.decode(
          '{"profiles":['
          '{"difficulty":"hard","waveCountPercent":0,'
          '"startingGoldPercent":100}]}',
        ),
        throwsA(isA<ContentFormatException>()),
      );
    });
  });

  group('the shipped profiles', () {
    test('are loaded for every mode, and Hard is harder than Normal', () async {
      final profiles = await DifficultyRepository().load();

      expect(profiles.keys, containsAll(Difficulty.values));
      final normal = profiles[Difficulty.normal]!;
      final hard = profiles[Difficulty.hard]!;

      expect(normal.isNeutral, isTrue);
      expect(hard.waveCountPercent, greaterThan(normal.waveCountPercent));
      expect(
        hard.startingGoldPercent,
        lessThan(normal.startingGoldPercent),
        reason: 'Hard thins the purse as well as swelling the waves',
      );
    });

    test('never shrink a wave away by rounding a small group to zero', () {
      const hard = DifficultyProfile(
        difficulty: Difficulty.hard,
        waveCountPercent: 50,
      );

      expect(hard.applyTo(_level).waves.single.groups[1].count, 1);
    });
  });

  test('the fixture level is unchanged by the normal profile it runs on', () {
    expect(DifficultyProfile.normal.applyTo(testLevel).waves, testLevel.waves);
  });
}
