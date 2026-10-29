import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/save/data/in_memory_save_store.dart';
import 'package:up_tower_defense/features/save/data/save_backed_settings_store.dart';
import 'package:up_tower_defense/features/save/data/save_codec.dart';
import 'package:up_tower_defense/features/save/data/save_document.dart';
import 'package:up_tower_defense/features/save/data/save_repository.dart';
import 'package:up_tower_defense/features/save/data/save_store.dart';
import 'package:up_tower_defense/features/settings/data/in_memory_settings_store.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

/// Counts writes, so a test can prove when saves happen.
class _CountingStore implements SaveStore {
  _CountingStore(this.inner);

  final SaveStore inner;
  int writes = 0;

  @override
  Future<String?> readCurrent() => inner.readCurrent();

  @override
  Future<String?> readBackup() => inner.readBackup();

  @override
  Future<void> write(String payload) {
    writes++;
    return inner.write(payload);
  }

  @override
  Future<void> preserve(String payload) => inner.preserve(payload);
}

/// A store that always fails to write, standing in for a full or locked disk.
class _FailingStore implements SaveStore {
  @override
  Future<String?> readCurrent() async => null;

  @override
  Future<String?> readBackup() async => null;

  @override
  Future<void> write(String payload) async {
    throw StateError('disk full');
  }

  @override
  Future<void> preserve(String payload) async {}
}

LevelResult _result({String levelId = 'meadow_01', int stars = 3}) {
  return LevelResult(
    levelId: levelId,
    stars: stars,
    coreHealth: 6,
    maxCoreHealth: 10,
    wavesCleared: 4,
    totalWaves: 4,
  );
}

SaveDocument _document({int stars = 3, GameSettings? settings}) {
  return SaveDocument(
    progress: CampaignProgress(
      results: Map.unmodifiable(<String, LevelResult>{
        'meadow_01': _result(stars: stars),
      }),
    ),
    settings: settings ?? GameSettings.defaults,
  );
}

SaveRepository _repository(SaveStore store) {
  return SaveRepository(store: store, legacySettings: InMemorySettingsStore());
}

void main() {
  test('a clean install loads an empty document', () async {
    final repository = _repository(InMemorySaveStore());

    final report = await repository.load();

    expect(report.origin, SaveOrigin.fresh);
    expect(report.problem, isNull);
    expect(repository.document.progress.results, isEmpty);
  });

  test(
    'a saved document survives a fresh repository over the same store',
    () async {
      final store = InMemorySaveStore();
      const settings = GameSettings(
        musicEnabled: false,
        sfxEnabled: true,
        hapticsEnabled: false,
        reducedMotion: true,
        musicVolume: 0.35,
        sfxVolume: 0.85,
        tutorialSeen: true,
      );
      final written = _repository(store);
      await written.load();
      await written.saveProgress(_document().progress);
      await written.saveSettings(settings);

      // A new repository models the next launch: nothing comes from memory.
      final reloaded = _repository(store);
      final report = await reloaded.load();

      expect(report.origin, SaveOrigin.current);
      expect(report.problem, isNull);
      expect(reloaded.document.progress.resultFor('meadow_01')!.stars, 3);
      expect(reloaded.document.settings, settings);
    },
  );

  test('a version 1 save from the previous release upgrades on load', () async {
    const versionOne =
        '{"schemaVersion":1,"results":{'
        '"meadow_01":{"stars":3,"coreHealth":5,"maxCoreHealth":10,'
        '"wavesCleared":4,"totalWaves":4}}}';
    final store = InMemorySaveStore();
    await store.write(versionOne);
    const oldPreferences = GameSettings(
      musicEnabled: false,
      sfxEnabled: false,
      hapticsEnabled: true,
      reducedMotion: true,
      musicVolume: 0.6,
      sfxVolume: 0.9,
      tutorialSeen: true,
    );

    final upgraded = SaveRepository(
      store: store,
      legacySettings: InMemorySettingsStore(oldPreferences),
    );
    final report = await upgraded.load();

    expect(report.origin, SaveOrigin.current);
    expect(report.problem, isNull);
    expect(upgraded.document.progress.resultFor('meadow_01')!.stars, 3);
    // The v1 preferences moved into the document instead of being reinterpreted.
    expect(upgraded.document.settings, oldPreferences);

    // The first write re-encodes under the current schema, so the next launch
    // needs no legacy preference store at all — the upgrade is complete.
    await upgraded.saveSettings(oldPreferences);
    final relaunched = SaveRepository(
      store: store,
      legacySettings: InMemorySettingsStore(),
    );
    await relaunched.load();
    expect(relaunched.document.settings, oldPreferences);
    expect(relaunched.document.progress.resultFor('meadow_01')!.stars, 3);
  });

  test('the endless best persists beside progress and settings', () async {
    final store = InMemorySaveStore();
    final written = _repository(store);
    await written.load();
    await written.saveProgress(_document().progress);
    await written.saveEndlessBest(12);
    await written.saveSettings(
      const GameSettings(
        musicEnabled: false,
        sfxEnabled: true,
        hapticsEnabled: true,
        reducedMotion: true,
        musicVolume: 0.4,
        sfxVolume: 0.6,
        tutorialSeen: true,
      ),
    );

    final reloaded = _repository(store);
    await reloaded.load();

    expect(reloaded.document.endlessBest, 12);
    expect(reloaded.document.progress.resultFor('meadow_01'), isNotNull);
    expect(reloaded.document.settings.musicEnabled, isFalse);
  });

  test('progress and settings save without erasing each other', () async {
    final store = InMemorySaveStore();
    final repository = _repository(store);
    await repository.load();

    await repository.saveProgress(_document().progress);
    await repository.saveSettings(
      GameSettings.defaults.copyWith(
        reducedMotion: true,
      ),
    );

    final reloaded = _repository(store);
    await reloaded.load();

    expect(reloaded.document.progress.resultFor('meadow_01'), isNotNull);
    expect(reloaded.document.settings.reducedMotion, isTrue);
  });

  test('writes are queued in order, so a later save wins', () async {
    final store = InMemorySaveStore();
    final repository = _repository(store);
    await repository.load();

    // Two saves started back to back, as a result and a setting change in the
    // same frame would be.
    final first = repository.saveProgress(_document(stars: 1).progress);
    final second = repository.saveProgress(_document().progress);
    await Future.wait([first, second]);

    final reloaded = _repository(store);
    await reloaded.load();
    expect(reloaded.document.progress.resultFor('meadow_01')!.stars, 3);
  });

  group('recovery', () {
    test('an unreadable save is kept and the backup is restored', () async {
      final store = InMemorySaveStore();
      final good = SaveCodec.encode(_document());
      await store.write(good); // becomes the backup after the bad write below
      await store.write('{corrupt');

      final repository = _repository(store);
      final report = await repository.load();

      expect(report.origin, SaveOrigin.backup);
      expect(report.isDegraded, isTrue);
      expect(repository.document.progress.resultFor('meadow_01')!.stars, 3);
      // The data that could not be read is preserved for diagnosis, and
      // neither the backup nor the payload itself was touched by the load.
      expect(store.damaged, '{corrupt');
      expect(store.current, '{corrupt');
      expect(store.backup, good);
    });

    test('nothing usable still starts the session on defaults', () async {
      final store = InMemorySaveStore();
      await store.write('not json at all');

      final repository = _repository(store);
      final report = await repository.load();

      expect(report.origin, SaveOrigin.empty);
      expect(report.problem, isNotNull);
      expect(repository.document.progress.results, isEmpty);
      expect(repository.document.settings, GameSettings.defaults);
      expect(store.damaged, 'not json at all');
    });

    test('loading never writes over the data it could not read', () async {
      final store = _CountingStore(InMemorySaveStore());
      await store.inner.write('{"schemaVersion":2,"results":');

      final repository = _repository(store);
      await repository.load();

      expect(store.writes, 0, reason: 'a load must not touch storage');
      expect(await store.readCurrent(), '{"schemaVersion":2,"results":');
    });

    test('unavailable storage is reported instead of thrown', () async {
      final repository = _repository(_UnavailableStore());

      final report = await repository.load();

      expect(report.origin, SaveOrigin.empty);
      expect(report.problem, contains('storage is unavailable'));
      expect(repository.document.progress.results, isEmpty);
    });
  });

  test('preferences persist through the same document as progress', () async {
    final store = InMemorySaveStore();
    final repository = _repository(store);
    await repository.load();
    final preferences = SaveBackedSettingsStore(repository);

    await preferences.save(GameSettings.defaults.copyWith(musicEnabled: false));
    await repository.saveProgress(_document().progress);

    // Next launch: both halves come from one load of one document.
    final reloaded = _repository(store);
    await reloaded.load();
    final reloadedPreferences = SaveBackedSettingsStore(reloaded);
    expect((await reloadedPreferences.load()).musicEnabled, isFalse);
    expect(reloaded.document.progress.resultFor('meadow_01'), isNotNull);
  });

  test('a failed write never reaches the caller', () async {
    final repository = _repository(_FailingStore());
    await repository.load();

    await expectLater(
      repository.saveProgress(_document().progress),
      completes,
    );
    // The session keeps the value even though nothing reached storage.
    expect(repository.document.progress.resultFor('meadow_01'), isNotNull);
  });
}

/// A store whose reads throw, standing in for unavailable platform storage.
class _UnavailableStore implements SaveStore {
  @override
  Future<String?> readCurrent() async {
    throw StateError('storage unavailable');
  }

  @override
  Future<String?> readBackup() async => null;

  @override
  Future<void> write(String payload) async {}

  @override
  Future<void> preserve(String payload) async {}
}
