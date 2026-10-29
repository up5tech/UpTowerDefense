import 'package:shared_preferences/shared_preferences.dart';

/// Raw local storage for the save payload.
///
/// Deliberately string-only: the repository decides what a payload means, so
/// storage never has to know about schema versions and a test can drive every
/// recovery path without platform storage.
abstract interface class SaveStore {
  /// The payload written most recently, or null when nothing was ever written.
  Future<String?> readCurrent();

  /// The payload that the most recent [write] replaced.
  Future<String?> readBackup();

  /// Replaces the current payload, after copying the old one to the backup.
  ///
  /// The previous payload is preserved first, so the newest save is never the
  /// only copy: a payload that turns out to be unreadable can still be recovered
  /// from the one it replaced.
  Future<void> write(String payload);

  /// Keeps a payload that could not be read, so it survives the next write.
  Future<void> preserve(String payload);
}

/// [SaveStore] backed by local key-value preferences.
///
/// Three keys, one job each: `save.current` is the live payload, `save.backup`
/// is the one it replaced, and `save.damaged` holds the last payload that
/// failed to decode. Nothing here leaves the device and no network access is
/// involved.
class PreferencesSaveStore implements SaveStore {
  PreferencesSaveStore(this._preferences);

  /// Opens the platform store shared with settings.
  static Future<PreferencesSaveStore> open() async {
    return PreferencesSaveStore(await SharedPreferences.getInstance());
  }

  static const String currentKey = 'save.current';
  static const String backupKey = 'save.backup';
  static const String damagedKey = 'save.damaged';

  final SharedPreferences _preferences;

  @override
  Future<String?> readCurrent() async => _readString(currentKey);

  @override
  Future<String?> readBackup() async => _readString(backupKey);

  @override
  Future<void> write(String payload) async {
    final previous = _readString(currentKey);
    if (previous != null) {
      await _preferences.setString(backupKey, previous);
    }
    await _preferences.setString(currentKey, payload);
  }

  @override
  Future<void> preserve(String payload) async {
    await _preferences.setString(damagedKey, payload);
  }

  /// Reads a value without trusting its stored type: anything that is not a
  /// String is unreadable here and lets the caller fall back to the backup.
  String? _readString(String key) {
    final value = _preferences.get(key);
    return value is String ? value : null;
  }
}
