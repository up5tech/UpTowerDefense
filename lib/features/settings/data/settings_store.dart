import 'package:shared_preferences/shared_preferences.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

/// Persistence boundary for [GameSettings].
///
/// Kept narrow so the settings UI can be tested without touching platform
/// storage. The shipped app binds it to the versioned save (D41), while
/// [SharedPreferencesSettingsStore] remains the source a version 1 save is
/// migrated from — the widgets never learn which.
abstract interface class SettingsStore {
  /// Reads the stored settings, falling back to defaults for missing or
  /// unreadable values.
  Future<GameSettings> load();

  /// Persists a complete settings snapshot.
  Future<void> save(GameSettings settings);
}

/// [SettingsStore] backed by local key-value preferences.
///
/// Preferences live in the versioned save now, so this class is what a version
/// 1 save is migrated from and what a session falls back to when storage will
/// not open. Only non-sensitive values live here; nothing leaves the device and
/// no network access is involved.
class SharedPreferencesSettingsStore implements SettingsStore {
  SharedPreferencesSettingsStore(this._preferences);

  /// Opens the platform preference store.
  static Future<SharedPreferencesSettingsStore> open() async {
    return SharedPreferencesSettingsStore(
      await SharedPreferences.getInstance(),
    );
  }

  static const String musicEnabledKey = 'settings.musicEnabled';
  static const String sfxEnabledKey = 'settings.sfxEnabled';
  static const String musicVolumeKey = 'settings.musicVolume';
  static const String sfxVolumeKey = 'settings.sfxVolume';
  static const String hapticsEnabledKey = 'settings.hapticsEnabled';
  static const String reducedMotionKey = 'settings.reducedMotion';
  static const String tutorialSeenKey = 'settings.tutorialSeen';

  final SharedPreferences _preferences;

  @override
  Future<GameSettings> load() async {
    const defaults = GameSettings.defaults;
    return GameSettings(
      musicEnabled: _readBool(musicEnabledKey, defaults.musicEnabled),
      sfxEnabled: _readBool(sfxEnabledKey, defaults.sfxEnabled),
      musicVolume: _readDouble(musicVolumeKey, defaults.musicVolume),
      sfxVolume: _readDouble(sfxVolumeKey, defaults.sfxVolume),
      hapticsEnabled: _readBool(hapticsEnabledKey, defaults.hapticsEnabled),
      reducedMotion: _readBool(reducedMotionKey, defaults.reducedMotion),
      tutorialSeen: _readBool(tutorialSeenKey, defaults.tutorialSeen),
    );
  }

  @override
  Future<void> save(GameSettings settings) async {
    await Future.wait(<Future<bool>>[
      _preferences.setBool(musicEnabledKey, settings.musicEnabled),
      _preferences.setBool(sfxEnabledKey, settings.sfxEnabled),
      _preferences.setDouble(musicVolumeKey, settings.musicVolume),
      _preferences.setDouble(sfxVolumeKey, settings.sfxVolume),
      _preferences.setBool(hapticsEnabledKey, settings.hapticsEnabled),
      _preferences.setBool(reducedMotionKey, settings.reducedMotion),
      _preferences.setBool(tutorialSeenKey, settings.tutorialSeen),
    ]);
  }

  /// Reads a boolean without trusting the stored type; a corrupted or
  /// hand-edited value falls back to the default instead of crashing startup.
  bool _readBool(String key, bool fallback) {
    final value = _preferences.get(key);
    return value is bool ? value : fallback;
  }

  /// Same rule for volumes: anything that is not a number becomes the
  /// default, and an out-of-range number is clamped to the slider's span.
  double _readDouble(String key, double fallback) {
    final value = _preferences.get(key);
    return value is num ? value.toDouble().clamp(0.0, 1.0) : fallback;
  }
}
