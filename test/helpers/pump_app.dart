import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/app/app.dart';
import 'package:up_tower_defense/app/audio/music_controller.dart';
import 'package:up_tower_defense/features/campaign/application/campaign_providers.dart';
import 'package:up_tower_defense/features/codex/application/codex_providers.dart';
import 'package:up_tower_defense/features/codex/data/codex_content.dart';
import 'package:up_tower_defense/features/credits/application/credits_providers.dart';
import 'package:up_tower_defense/features/credits/data/attribution_repository.dart';
import 'package:up_tower_defense/features/gameplay/application/content_providers.dart';
import 'package:up_tower_defense/features/save/application/save_providers.dart';
import 'package:up_tower_defense/features/save/data/in_memory_save_store.dart';
import 'package:up_tower_defense/features/save/data/save_repository.dart';
import 'package:up_tower_defense/features/save/data/save_store.dart';
import 'package:up_tower_defense/features/settings/application/settings_providers.dart';
import 'package:up_tower_defense/features/settings/data/in_memory_settings_store.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

import 'attribution_fixture.dart';
import 'content_fixtures.dart';
import 'recording_music_sink.dart';
import 'stub_asset_bundle.dart';

/// Boots the real shell with an isolated provider container.
///
/// Every test gets its own router, settings store, save and campaign progress,
/// so navigation stacks, stored preferences and progress never leak between
/// cases. Pass [saveStore] to give a case the same storage twice — that is how
/// a relaunch is simulated.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  InMemorySettingsStore? store,
  GameSettings? settings,
  SaveStore? saveStore,
  MusicSink? musicSink,
}) async {
  final settingsStore = store ?? InMemorySettingsStore();

  // The real load path, with the same store instance a later pump can reuse.
  final repository = SaveRepository(
    store: saveStore ?? InMemorySaveStore(),
    legacySettings: settingsStore,
  );
  final report = await repository.load();
  final save = repository.document;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsStoreProvider.overrideWithValue(settingsStore),
        // An explicit `settings` argument wins, so a case can pin preferences
        // independently of what the save holds.
        initialSettingsProvider.overrideWithValue(
          settings ?? save.settings,
        ),
        saveRepositoryProvider.overrideWithValue(repository),
        initialSaveProvider.overrideWithValue(save),
        saveStatusProvider.overrideWithValue(report),
        // Widget tests use fixture content instead of reading real assets, so
        // they stay synchronous; shipped content is covered by the content and
        // campaign tests.
        levelToPlayProvider.overrideWith((ref) => testBundle),
        endlessBundleProvider.overrideWith((ref) async => testBundle),
        campaignProvider.overrideWith((ref) => testCampaign),
        levelBundleProvider.overrideWith(
          (ref, levelId) => bundleForLevel(levelId),
        ),
        // The credits screen reads the attribution document from the bundle;
        // tests serve a fixture with the same shape, never the real file.
        attributionBundleProvider.overrideWithValue(
          StubAssetBundle({kAttributionAssetKey: attributionMarkdown}),
        ),
        // The codex reads the two shared catalogs; fixtures keep widget tests
        // off the real assets, like every other content override here.
        codexContentProvider.overrideWith(
          (ref) async => CodexContent(
            towers: fullTowerCatalog,
            enemies: testEnemyCatalog,
          ),
        ),
      ],
      // The shell owns a background loop now; the default fake keeps every
      // widget test silent while a case can pass its own recorder.
      child: UpTowerDefenseApp(musicSink: musicSink ?? RecordingMusicSink()),
    ),
  );
  await tester.pumpAndSettle();

  return ProviderScope.containerOf(
    tester.element(find.byType(UpTowerDefenseApp)),
  );
}
