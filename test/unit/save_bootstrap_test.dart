import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/save/application/save_bootstrap.dart';
import 'package:up_tower_defense/features/save/data/save_backed_settings_store.dart';
import 'package:up_tower_defense/features/save/data/save_codec.dart';
import 'package:up_tower_defense/features/save/data/save_document.dart';
import 'package:up_tower_defense/features/save/data/save_repository.dart';
import 'package:up_tower_defense/features/save/data/save_store.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

SaveDocument _documentWithProgress() {
  return SaveDocument(
    progress: CampaignProgress(
      results: Map.unmodifiable(<String, LevelResult>{
        'meadow_01': const LevelResult(
          levelId: 'meadow_01',
          stars: 3,
          coreHealth: 7,
          maxCoreHealth: 10,
          wavesCleared: 4,
          totalWaves: 4,
        ),
      }),
    ),
    settings: GameSettings.defaults,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a stored save is loaded before the first frame', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PreferencesSaveStore.currentKey: SaveCodec.encode(
        _documentWithProgress(),
      ),
    });

    final bootstrap = await openSave();

    expect(bootstrap.report.origin, SaveOrigin.current);
    expect(bootstrap.report.problem, isNull);
    expect(bootstrap.document.progress.resultFor('meadow_01')!.stars, 3);

    // The settings screen writes through the same repository, so preferences
    // and progress stay in one document.
    final preferences = SaveBackedSettingsStore(bootstrap.repository);
    await preferences.save(GameSettings.defaults.copyWith(reducedMotion: true));

    expect(bootstrap.repository.document.settings.reducedMotion, isTrue);
    expect(
      bootstrap.repository.document.progress.resultFor('meadow_01'),
      isNotNull,
    );
  });

  test('storage that will not open still boots, and says why', () async {
    final bootstrap = await openSave(
      openPreferences: () async => throw StateError('storage unavailable'),
    );

    expect(bootstrap.report.origin, SaveOrigin.empty);
    expect(bootstrap.report.problem, contains('storage is unavailable'));
    expect(bootstrap.document.progress.results, isEmpty);

    // The session keeps working: writes land in memory for as long as it runs.
    await bootstrap.repository.saveSettings(
      GameSettings.defaults.copyWith(musicEnabled: false),
    );
    expect(bootstrap.repository.document.settings.musicEnabled, isFalse);
  });
}
