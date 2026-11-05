import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';
import 'package:up_tower_defense/features/save/data/save_codec.dart';
import 'package:up_tower_defense/features/save/data/save_document.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

/// Save v4 (D65, D68): results keyed by level and difficulty, and the number of
/// goals each run met. Every pair of versions must still read, because losing
/// progress on update is worse than any missing feature.
LevelResult _result({
  String levelId = 'meadow_01',
  Difficulty difficulty = Difficulty.normal,
  int stars = 3,
  int objectivesMet = 2,
  int coreHealth = 8,
  int maxCoreHealth = 10,
  int wavesCleared = 4,
  int totalWaves = 4,
}) {
  return LevelResult(
    levelId: levelId,
    stars: stars,
    coreHealth: coreHealth,
    maxCoreHealth: maxCoreHealth,
    wavesCleared: wavesCleared,
    totalWaves: totalWaves,
    difficulty: difficulty,
    objectivesMet: objectivesMet,
  );
}

Map<String, Object?> _payload(SaveDocument document) =>
    jsonDecode(SaveCodec.encode(document)) as Map<String, Object?>;

Map<String, Object?> _storedResult(Map<String, Object?> payload, String key) =>
    (payload['results']! as Map<String, Object?>)[key]! as Map<String, Object?>;

void main() {
  group('round trip', () {
    test('a normal and a hard result on one level stay apart', () {
      final document = SaveDocument(
        progress: CampaignProgress(
          results: Map.unmodifiable(
            <String, LevelResult>{
              'meadow_01': _result(),
              'meadow_01#hard': _result(
                difficulty: Difficulty.hard,
                stars: 2,
                objectivesMet: 1,
                coreHealth: 4,
              ),
            },
          ),
        ),
        settings: GameSettings.defaults,
      );

      final decoded = SaveCodec.decode(SaveCodec.encode(document));

      expect(decoded.progress.results, hasLength(2));
      final normal = decoded.progress.resultFor('meadow_01')!;
      final hard = decoded.progress.resultFor(
        'meadow_01',
        difficulty: Difficulty.hard,
      )!;
      expect(normal.stars, 3);
      expect(normal.objectivesMet, 2);
      expect(normal.difficulty, Difficulty.normal);
      expect(hard.stars, 2);
      expect(hard.objectivesMet, 1);
      expect(hard.difficulty, Difficulty.hard);
    });

    test('the current payload declares the current schema and writes the v4 fields', () {
      final payload = _payload(
        SaveDocument(
          progress: CampaignProgress(
            results: Map.unmodifiable(<String, LevelResult>{
              'meadow_01': _result(),
            }),
          ),
          settings: GameSettings.defaults,
        ),
      );

      expect(SaveCodec.currentVersion, 5);
      expect(payload['schemaVersion'], SaveCodec.currentVersion);
      final stored = _storedResult(payload, 'meadow_01');
      expect(stored['levelId'], 'meadow_01');
      expect(stored['difficulty'], 'normal');
      expect(stored['objectivesMet'], 2);
    });
  });

  group('migration', () {
    test('a version 3 result reads as Normal with no goals recorded', () {
      const versionThree =
          '{"schemaVersion":3,"results":{'
          '"meadow_01":{"stars":3,"coreHealth":9,"maxCoreHealth":10,'
          '"wavesCleared":4,"totalWaves":4}},"endlessBest":0}';

      final decoded = SaveCodec.decode(versionThree);

      final result = decoded.progress.resultFor('meadow_01')!;
      // Stars are stored, never recomputed: a 1.0 three-star run keeps three.
      expect(result.stars, 3);
      expect(result.difficulty, Difficulty.normal);
      expect(result.objectivesMet, 0);
      // The key stayed the bare level id, so nothing moved slot.
      expect(decoded.progress.results.keys, ['meadow_01']);
    });

    test('a version 1 save still keeps its stars and settings', () {
      const legacy = GameSettings(
        musicEnabled: false,
        sfxEnabled: true,
        hapticsEnabled: false,
        reducedMotion: true,
        musicVolume: 0.3,
        sfxVolume: 0.8,
        tutorialSeen: true,
      );
      const versionOne =
          '{"schemaVersion":1,"results":{'
          '"meadow_02":{"stars":2,"coreHealth":5,"maxCoreHealth":10,'
          '"wavesCleared":3,"totalWaves":4}}}';

      final decoded = SaveCodec.decode(versionOne, legacySettings: legacy);

      expect(decoded.progress.starsFor('meadow_02'), 2);
      expect(
        decoded.progress.starsFor('meadow_02', difficulty: Difficulty.hard),
        0,
      );
      expect(decoded.settings, legacy);
    });
  });

  group('refusals', () {
    test('an unknown difficulty is refused, not defaulted', () {
      final payload = _payload(
        SaveDocument(
          progress: CampaignProgress(
            results: Map.unmodifiable(<String, LevelResult>{
              'meadow_01': _result(),
            }),
          ),
          settings: GameSettings.defaults,
        ),
      );
      _storedResult(payload, 'meadow_01')['difficulty'] = 'nightmare';

      expect(
        () => SaveCodec.decode(jsonEncode(payload)),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            contains('nightmare'),
          ),
        ),
      );
    });

    test('a key that disagrees with its own fields is refused', () {
      final payload = _payload(
        SaveDocument(
          progress: CampaignProgress(
            results: Map.unmodifiable(<String, LevelResult>{
              'meadow_01': _result(),
            }),
          ),
          settings: GameSettings.defaults,
        ),
      );
      // Stored as Normal under the key a Hard run would use.
      _storedResult(payload, 'meadow_01')['difficulty'] = 'hard';

      expect(
        () => SaveCodec.decode(jsonEncode(payload)),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            contains('meadow_01#hard'),
          ),
        ),
      );
    });

    test('a missing goal count is refused in v4', () {
      final payload = _payload(
        SaveDocument(
          progress: CampaignProgress(
            results: Map.unmodifiable(<String, LevelResult>{
              'meadow_01': _result(),
            }),
          ),
          settings: GameSettings.defaults,
        ),
      );
      _storedResult(payload, 'meadow_01').remove('objectivesMet');

      expect(
        () => SaveCodec.decode(jsonEncode(payload)),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            contains('objectivesMet'),
          ),
        ),
      );
    });

    test('a goal count above the pair a level can declare is refused', () {
      final payload = _payload(
        SaveDocument(
          progress: CampaignProgress(
            results: Map.unmodifiable(<String, LevelResult>{
              'meadow_01': _result(),
            }),
          ),
          settings: GameSettings.defaults,
        ),
      );
      _storedResult(payload, 'meadow_01')['objectivesMet'] = 3;

      expect(
        () => SaveCodec.decode(jsonEncode(payload)),
        throwsA(isA<SaveFormatException>()),
      );
    });
  });
}
