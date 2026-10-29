import 'package:up_tower_defense/features/settings/data/settings_store.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

/// Non-persistent [SettingsStore].
///
/// Used as the startup fallback when platform storage is unavailable, so the
/// app still launches and plays with default preferences, and as a test double
/// that lets tests assert what was written.
class InMemorySettingsStore implements SettingsStore {
  InMemorySettingsStore([this._settings = GameSettings.defaults]);

  GameSettings _settings;

  /// The most recently saved snapshot (defaults until something is saved).
  GameSettings get settings => _settings;

  @override
  Future<GameSettings> load() async => _settings;

  @override
  Future<void> save(GameSettings settings) async {
    _settings = settings;
  }
}
