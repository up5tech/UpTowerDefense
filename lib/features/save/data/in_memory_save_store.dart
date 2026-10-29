import 'package:up_tower_defense/features/save/data/save_store.dart';

/// Non-persistent [SaveStore].
///
/// Used when platform storage cannot be opened, so the app still launches and
/// plays with a session-only save, and as a test double that lets a test assert
/// exactly what was written and when.
class InMemorySaveStore implements SaveStore {
  String? _current;
  String? _backup;
  String? _damaged;

  /// The payload last written, until something replaces it.
  String? get current => _current;

  /// The payload the last write replaced.
  String? get backup => _backup;

  /// The last payload kept because it could not be read.
  String? get damaged => _damaged;

  @override
  Future<String?> readCurrent() async => _current;

  @override
  Future<String?> readBackup() async => _backup;

  @override
  Future<void> write(String payload) async {
    if (_current != null) {
      _backup = _current;
    }
    _current = payload;
  }

  @override
  Future<void> preserve(String payload) async {
    _damaged = payload;
  }
}
