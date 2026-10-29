import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/save/data/save_codec.dart';
import 'package:up_tower_defense/features/save/data/save_document.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

/// A completed run, so a round trip has real numbers to preserve.
LevelResult _result({
  String levelId = 'meadow_01',
  int stars = 3,
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
  );
}

void main() {
  group('round trip', () {
    test('progress and settings survive encode → decode', () {
      const settings = GameSettings(
        musicEnabled: false,
        sfxEnabled: true,
        hapticsEnabled: false,
        reducedMotion: true,
        musicVolume: 0.7,
        sfxVolume: 0.4,
        tutorialSeen: true,
      );
      final document = SaveDocument(
        progress: CampaignProgress(
          results: Map.unmodifiable(<String, LevelResult>{
            'meadow_01': _result(),
            'meadow_02': _result(
              levelId: 'meadow_02',
              stars: 2,
              coreHealth: 3,
              wavesCleared: 3,
            ),
          }),
        ),
        settings: settings,
      );

      final decoded = SaveCodec.decode(SaveCodec.encode(document));

      expect(decoded.progress.results.keys, ['meadow_01', 'meadow_02']);
      final first = decoded.progress.resultFor('meadow_01')!;
      expect(first.stars, 3);
      expect(first.coreHealth, 8);
      expect(first.maxCoreHealth, 10);
      expect(first.wavesCleared, 4);
      expect(first.totalWaves, 4);
      expect(decoded.progress.resultFor('meadow_02')!.stars, 2);
      expect(decoded.settings, settings);
    });

    test('a clean install encodes as an empty, readable document', () {
      final decoded = SaveCodec.decode(
        SaveCodec.encode(const SaveDocument.empty()),
      );

      expect(decoded.progress.results, isEmpty);
      expect(decoded.settings, GameSettings.defaults);
    });

    test('the payload declares the current schema version', () {
      final json = jsonDecode(
        SaveCodec.encode(const SaveDocument.empty()),
      ) as Map<String, Object?>;

      expect(json['schemaVersion'], SaveCodec.currentVersion);
      expect(json.containsKey('results'), isTrue);
      expect(json.containsKey('settings'), isTrue);
    });
  });

  group('migration', () {
    test('a version 1 save folds in the legacy preferences', () {
      const legacy = GameSettings(
        musicEnabled: false,
        sfxEnabled: false,
        hapticsEnabled: true,
        reducedMotion: true,
        musicVolume: 0.6,
        sfxVolume: 0.9,
        tutorialSeen: true,
      );
      const versionOne =
          '{"schemaVersion":1,"results":{'
          '"meadow_01":{"stars":3,"coreHealth":5,"maxCoreHealth":10,'
          '"wavesCleared":4,"totalWaves":4}}}';

      final decoded = SaveCodec.decode(versionOne, legacySettings: legacy);

      expect(decoded.progress.resultFor('meadow_01')!.stars, 3);
      // The preferences moved into the document instead of being reinterpreted.
      expect(decoded.settings, legacy);
    });

    test('a version 1 save without a legacy store still loads', () {
      const versionOne = '{"schemaVersion":1,"results":{}}';

      final decoded = SaveCodec.decode(versionOne);

      expect(decoded.progress.results, isEmpty);
      expect(decoded.settings, GameSettings.defaults);
    });
  });

  group('endless best (schema 3)', () {
    test('survives a round trip', () {
      final decoded = SaveCodec.decode(
        SaveCodec.encode(
          const SaveDocument(
            progress: CampaignProgress.empty(),
            settings: GameSettings.defaults,
            endlessBest: 17,
          ),
        ),
      );

      expect(decoded.endlessBest, 17);
    });

    test('a version 2 payload keeps its settings and reads a best of zero', () {
      // Built from a real v3 payload with the new key dropped, so the test
      // walks the exact path an installed pre-endless build takes when the
      // app updates over it.
      final json = jsonDecode(
        SaveCodec.encode(
          const SaveDocument(
            progress: CampaignProgress.empty(),
            settings: GameSettings(
              musicEnabled: false,
              sfxEnabled: true,
              hapticsEnabled: true,
              reducedMotion: false,
              musicVolume: 0.5,
              sfxVolume: 0.5,
              tutorialSeen: true,
            ),
            endlessBest: 9,
          ),
        ),
      ) as Map<String, Object?>;
      json
        ..['schemaVersion'] = 2
        ..remove('endlessBest');

      final decoded = SaveCodec.decode(jsonEncode(json));

      expect(
        decoded.settings,
        const GameSettings(
          musicEnabled: false,
          sfxEnabled: true,
          hapticsEnabled: true,
          reducedMotion: false,
          musicVolume: 0.5,
          sfxVolume: 0.5,
          tutorialSeen: true,
        ),
      );
      expect(decoded.endlessBest, 0);
    });

    test('a v3 payload without the key is refused, not repaired', () {
      final json = jsonDecode(
        SaveCodec.encode(const SaveDocument.empty()),
      ) as Map<String, Object?>;
      json.remove('endlessBest');

      expect(
        () => SaveCodec.decode(jsonEncode(json)),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            contains('endlessBest'),
          ),
        ),
      );
    });
  });

  group('refusals', () {
    test('malformed JSON is refused with the parser error', () {
      expect(
        () => SaveCodec.decode('{not json'),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            contains('not valid JSON'),
          ),
        ),
      );
    });

    test('a payload that is not an object is refused', () {
      expect(
        () => SaveCodec.decode('[1, 2, 3]'),
        throwsA(isA<SaveFormatException>()),
      );
    });

    test('a newer schema version is refused, never reinterpreted', () {
      final future = jsonEncode(<String, Object?>{
        'schemaVersion': SaveCodec.currentVersion + 1,
        'results': <String, Object?>{},
        'settings': <String, Object?>{},
      });

      expect(
        () => SaveCodec.decode(future),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('${SaveCodec.currentVersion + 1}'),
              contains('left untouched'),
            ),
          ),
        ),
      );
    });

    test('a missing schemaVersion is refused', () {
      expect(
        () => SaveCodec.decode('{"results":{}}'),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            contains('schemaVersion'),
          ),
        ),
      );
    });

    test('a missing results section is refused, not read as empty', () {
      // Reading it as "nothing played" would unlock nothing and then overwrite
      // the real campaign on the next write.
      expect(
        () => SaveCodec.decode('{"schemaVersion":2,"settings":{}}'),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            contains('results'),
          ),
        ),
      );
    });

    test('every problem in a stored result is reported at once', () {
      final broken = jsonEncode(<String, Object?>{
        'schemaVersion': 2,
        'results': <String, Object?>{
          'meadow_01': <String, Object?>{
            'stars': 9,
            'coreHealth': 12,
            'maxCoreHealth': 10,
            'wavesCleared': 5,
            'totalWaves': 4,
          },
        },
        'settings': <String, Object?>{},
      });

      expect(
        () => SaveCodec.decode(broken),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('meadow_01 stars is above 3'),
              contains('meadow_01 coreHealth exceeds maxCoreHealth'),
              contains('meadow_01 wavesCleared exceeds totalWaves'),
            ),
          ),
        ),
      );
    });

    test('a result that is not an object is refused', () {
      final broken = jsonEncode(<String, Object?>{
        'schemaVersion': 2,
        'results': <String, Object?>{'meadow_01': 'done'},
        'settings': <String, Object?>{},
      });

      expect(
        () => SaveCodec.decode(broken),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            contains('meadow_01 is not an object'),
          ),
        ),
      );
    });

    test('a settings section of the wrong type is refused', () {
      final broken = jsonEncode(<String, Object?>{
        'schemaVersion': 2,
        'results': <String, Object?>{},
        'settings': 'on',
      });

      expect(
        () => SaveCodec.decode(broken),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            contains('settings'),
          ),
        ),
      );
    });
  });

  group('preference fallbacks', () {
    test('a wrong toggle type falls back to its default', () {
      final payload = jsonEncode(<String, Object?>{
        'schemaVersion': 2,
        'results': <String, Object?>{},
        'settings': <String, Object?>{'musicEnabled': 'yes'},
      });

      final decoded = SaveCodec.decode(payload);

      expect(decoded.settings.musicEnabled, GameSettings.defaults.musicEnabled);
      expect(decoded.settings.sfxEnabled, GameSettings.defaults.sfxEnabled);
    });

    test('a missing settings section falls back to defaults', () {
      final payload = jsonEncode(<String, Object?>{
        'schemaVersion': 2,
        'results': <String, Object?>{},
      });

      expect(SaveCodec.decode(payload).settings, GameSettings.defaults);
    });

    test('a save written before the tutorial key reads as not seen', () {
      // The safe direction: an old save shows the card once instead of
      // silently losing it for a player who never saw it.
      final payload = jsonEncode(<String, Object?>{
        'schemaVersion': 2,
        'results': <String, Object?>{},
        'settings': <String, Object?>{
          'musicEnabled': false,
          'reducedMotion': true,
        },
      });

      final decoded = SaveCodec.decode(payload);

      expect(decoded.settings.tutorialSeen, isFalse);
      // The keys the old save did carry still decode.
      expect(decoded.settings.musicEnabled, isFalse);
      expect(decoded.settings.reducedMotion, isTrue);
    });
  });
}
