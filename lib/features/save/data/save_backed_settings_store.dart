import 'package:up_tower_defense/features/save/data/save_repository.dart';
import 'package:up_tower_defense/features/settings/data/settings_store.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

/// [SettingsStore] that writes into the versioned save.
///
/// Preferences join the save in Phase 9 (D41): one document, one migration
/// path, one backup. The settings screen keeps talking to the same boundary it
/// always did, so nothing above this line changes when storage does.
class SaveBackedSettingsStore implements SettingsStore {
  SaveBackedSettingsStore(this._repository);

  final SaveRepository _repository;

  @override
  Future<GameSettings> load() async => _repository.document.settings;

  @override
  Future<void> save(GameSettings settings) {
    return _repository.saveSettings(settings);
  }
}
