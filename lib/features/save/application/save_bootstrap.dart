import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_tower_defense/features/save/data/in_memory_save_store.dart';
import 'package:up_tower_defense/features/save/data/save_document.dart';
import 'package:up_tower_defense/features/save/data/save_repository.dart';
import 'package:up_tower_defense/features/save/data/save_store.dart';
import 'package:up_tower_defense/features/settings/data/in_memory_settings_store.dart';
import 'package:up_tower_defense/features/settings/data/settings_store.dart';

/// What opening the save hands to the provider scope.
typedef SaveBootstrap = ({
  SaveRepository repository,
  SaveDocument document,
  SaveLoadReport report,
});

/// Opens local storage and reads the save before the first frame.
///
/// Reading during bootstrap keeps the picker and the settings screen
/// synchronous and avoids a loading flash. Nothing here can block launch:
/// storage that will not open falls back to a session-only save and reports
/// why, so the player is told instead of silently losing progress.
///
/// [openPreferences] exists for tests, which cannot make the platform store
/// fail on demand.
Future<SaveBootstrap> openSave({
  Future<SharedPreferences> Function()? openPreferences,
}) async {
  final SaveStore store;
  final SettingsStore legacy;
  try {
    final preferences = await (openPreferences ?? _openPlatformStore)();
    store = PreferencesSaveStore(preferences);
    legacy = SharedPreferencesSettingsStore(preferences);
  } on Object catch (error) {
    debugPrint(
      'Save storage unavailable, continuing with a session save: $error',
    );
    final repository = SaveRepository(
      store: InMemorySaveStore(),
      legacySettings: InMemorySettingsStore(),
    );
    await repository.load();
    return (
      repository: repository,
      document: repository.document,
      report: SaveLoadReport(
        origin: SaveOrigin.empty,
        problem: 'save storage is unavailable ($error)',
      ),
    );
  }

  final repository = SaveRepository(store: store, legacySettings: legacy);
  final report = await repository.load();
  return (
    repository: repository,
    document: repository.document,
    report: report,
  );
}

Future<SharedPreferences> _openPlatformStore() =>
    SharedPreferences.getInstance();
