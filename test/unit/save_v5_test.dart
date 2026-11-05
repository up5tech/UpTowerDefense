import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/domain/achievement.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/gameplay/domain/daily_challenge.dart';
import 'package:up_tower_defense/features/save/data/in_memory_save_store.dart';
import 'package:up_tower_defense/features/save/data/save_codec.dart';
import 'package:up_tower_defense/features/save/data/save_document.dart';
import 'package:up_tower_defense/features/save/data/save_repository.dart';
import 'package:up_tower_defense/features/settings/data/in_memory_settings_store.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

/// Save v5 (D67, D66): earned achievement ids and per-date daily records.
///
/// Every version pair has to keep reading, and a v5 field that cannot be read
/// has to refuse rather than be repaired — the same rules v4 followed.
LevelResult _result({String levelId = 'meadow_01', int stars = 3}) {
  return LevelResult(
    levelId: levelId,
    stars: stars,
    coreHealth: 8,
    maxCoreHealth: 10,
    wavesCleared: 4,
    totalWaves: 4,
    objectivesMet: stars - 1,
  );
}

DailyResult _daily({int dateKey = 20261104, int stars = 2}) {
  return DailyResult(
    dateKey: dateKey,
    levelId: 'hollow_04',
    stars: stars,
    coreHealth: 7,
    maxCoreHealth: 20,
    objectivesMet: stars - 1,
  );
}

SaveDocument _document() {
  return SaveDocument(
    progress: CampaignProgress(
      results: Map.unmodifiable(<String, LevelResult>{
        'meadow_01': _result(),
      }),
    ),
    settings: const GameSettings(
      musicEnabled: false,
      sfxEnabled: true,
      hapticsEnabled: true,
      reducedMotion: false,
      musicVolume: 0.5,
      sfxVolume: 0.5,
      tutorialSeen: true,
    ),
    endlessBest: 12,
    achievements: const {Achievement.firstClear, Achievement.threeStars},
    dailyResults: Map.unmodifiable(<int, DailyResult>{
      20261104: _daily(),
      20260101: _daily(dateKey: 20260101, stars: 3),
    }),
  );
}

Map<String, Object?> _payload(SaveDocument document) =>
    jsonDecode(SaveCodec.encode(document)) as Map<String, Object?>;

void main() {
  group('round trip', () {
    test('achievements and dailies survive encode → decode', () {
      final decoded = SaveCodec.decode(SaveCodec.encode(_document()));

      expect(decoded.achievements, {
        Achievement.firstClear,
        Achievement.threeStars,
      });
      expect(decoded.dailyResults.keys, containsAll([20261104, 20260101]));
      expect(decoded.dailyResults[20260101]!.stars, 3);
      expect(decoded.dailyResults[20261104]!.levelId, 'hollow_04');
      expect(decoded.endlessBest, 12);
      expect(decoded.progress.starsFor('meadow_01'), 3);
    });

    test('the payload declares schema 5 and stores ids, not prose', () {
      final payload = _payload(_document());

      expect(SaveCodec.currentVersion, 5);
      expect(payload['schemaVersion'], 5);
      expect(payload['achievements'], ['firstClear', 'threeStars']);
      final daily =
          (payload['dailyResults']! as Map<String, Object?>)['20261104']!
              as Map<String, Object?>;
      expect(daily['levelId'], 'hollow_04');
      expect(daily['stars'], 2);
    });

    test('a clean install writes empty collections, not nulls', () {
      final payload = _payload(const SaveDocument.empty());

      expect(payload['achievements'], isEmpty);
      expect(payload['dailyResults'], isEmpty);
    });
  });

  group('migration', () {
    test('a v4 save loads with no achievements and no dailies', () {
      final json = _payload(_document())
        ..['schemaVersion'] = 4
        ..remove('achievements')
        ..remove('dailyResults');

      final decoded = SaveCodec.decode(jsonEncode(json));

      expect(decoded.achievements, isEmpty);
      expect(decoded.dailyResults, isEmpty);
      // Everything v4 stored is untouched by the upgrade.
      expect(decoded.endlessBest, 12);
      expect(decoded.progress.starsFor('meadow_01'), 3);
      expect(decoded.settings.musicEnabled, isFalse);
    });

    test('a v1 save still loads and keeps its stars', () {
      const versionOne =
          '{"schemaVersion":1,"results":{'
          '"meadow_01":{"stars":3,"coreHealth":5,"maxCoreHealth":10,'
          '"wavesCleared":4,"totalWaves":4}}}';

      final decoded = SaveCodec.decode(versionOne);

      expect(decoded.progress.starsFor('meadow_01'), 3);
      expect(decoded.achievements, isEmpty);
      expect(decoded.dailyResults, isEmpty);
    });
  });

  group('refusals', () {
    test('an unknown achievement id is refused', () {
      final json = _payload(_document());
      json['achievements'] = ['firstClear', 'perfectRun'];

      expect(
        () => SaveCodec.decode(jsonEncode(json)),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            contains('perfectRun'),
          ),
        ),
      );
    });

    test('a daily filed under the wrong date is refused', () {
      final json = _payload(_document());
      final dailies = json['dailyResults']! as Map<String, Object?>;
      final moved = dailies.remove('20261104')!;
      dailies['20261105'] = moved;

      expect(
        () => SaveCodec.decode(jsonEncode(json)),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            contains('20261105'),
          ),
        ),
      );
    });

    test('a v5 payload missing the achievement list is refused', () {
      final json = _payload(const SaveDocument.empty())..remove('achievements');

      expect(
        () => SaveCodec.decode(jsonEncode(json)),
        throwsA(
          isA<SaveFormatException>().having(
            (error) => error.message,
            'message',
            contains('achievements'),
          ),
        ),
      );
    });
  });

  group('repository upgrade pairs', () {
    test(
      'a v4 save gains achievements and dailies without losing anything',
      () async {
        final store = InMemorySaveStore();
        final v4 = _payload(_document())
          ..['schemaVersion'] = 4
          ..remove('achievements')
          ..remove('dailyResults');
        await store.write(jsonEncode(v4));

        final repository = SaveRepository(
          store: store,
          legacySettings: InMemorySettingsStore(),
        );
        final report = await repository.load();
        expect(report.origin, SaveOrigin.current);

        await repository.saveAchievements(const {Achievement.dailyFinished});
        await repository.saveDailyResults(
          Map.unmodifiable(<int, DailyResult>{
            20261104: _daily(stars: 3),
          }),
        );

        final relaunched = SaveRepository(
          store: store,
          legacySettings: InMemorySettingsStore(),
        );
        await relaunched.load();

        expect(relaunched.document.achievements, {Achievement.dailyFinished});
        expect(relaunched.document.dailyResults[20261104]!.stars, 3);
        expect(relaunched.document.endlessBest, 12);
        expect(relaunched.document.progress.starsFor('meadow_01'), 3);
        expect(relaunched.document.settings.sfxEnabled, isTrue);
      },
    );

    test('achievements and dailies save without erasing progress', () async {
      final store = InMemorySaveStore();
      final repository = SaveRepository(
        store: store,
        legacySettings: InMemorySettingsStore(),
      );
      await repository.load();

      await repository.saveProgress(_document().progress);
      await repository.saveAchievements(const {Achievement.firstClear});
      await repository.saveDailyResults(
        Map.unmodifiable(<int, DailyResult>{
          20261104: _daily(),
        }),
      );
      await repository.saveSettings(
        GameSettings.defaults.copyWith(
          reducedMotion: true,
        ),
      );

      final reloaded = SaveRepository(
        store: store,
        legacySettings: InMemorySettingsStore(),
      );
      await reloaded.load();

      expect(reloaded.document.progress.starsFor('meadow_01'), 3);
      expect(reloaded.document.achievements, {Achievement.firstClear});
      expect(reloaded.document.dailyResults.keys, [20261104]);
      expect(reloaded.document.settings.reducedMotion, isTrue);
    });
  });
}
