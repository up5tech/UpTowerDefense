import 'package:flutter/foundation.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/save/data/save_codec.dart';
import 'package:up_tower_defense/features/save/data/save_document.dart';
import 'package:up_tower_defense/features/save/data/save_store.dart';
import 'package:up_tower_defense/features/settings/data/settings_store.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

/// Where the loaded document came from.
enum SaveOrigin {
  /// Nothing was ever stored: a clean install.
  fresh,

  /// The current payload decoded.
  current,

  /// The current payload was unusable and an earlier copy was restored.
  backup,

  /// Nothing usable was found; the session runs on defaults.
  empty,
}

/// What one load found, for the status line the menu and Settings show.
@immutable
class SaveLoadReport {
  const SaveLoadReport({required this.origin, this.problem});

  /// A clean install: nothing stored, nothing wrong.
  const SaveLoadReport.fresh() : origin = SaveOrigin.fresh, problem = null;

  /// Where the document came from.
  final SaveOrigin origin;

  /// The reason the stored data could not be used, or null when it could.
  final String? problem;

  /// Whether the player should be told something went wrong.
  bool get isDegraded => problem != null;
}

/// Owns the one save document: loading it once, then serialising every write.
///
/// Two independent writers (progress and settings) share this object so their
/// updates can never interleave into a half-written document: each call takes
/// its half of the current document synchronously, encodes that snapshot, and
/// hands it to a single FIFO queue. Nothing here writes per frame — a write only
/// happens when a caller explicitly saves.
class SaveRepository {
  SaveRepository({required this.store, required this.legacySettings});

  /// Raw storage for the payload.
  final SaveStore store;

  /// Where preferences from a version 1 save are read during migration.
  final SettingsStore legacySettings;

  SaveDocument _document = const SaveDocument.empty();
  Future<void> _writes = Future<void>.value();

  /// The latest known document, available synchronously for the UI.
  SaveDocument get document => _document;

  /// Reads and validates the stored payload once, at startup.
  ///
  /// Recovery order: the current payload, then the backup. An unreadable
  /// payload is preserved before anything can write over it, so a damaged save
  /// is reported and kept rather than silently replaced.
  Future<SaveLoadReport> load() async {
    final legacy = await _legacySettings();

    final String? current;
    try {
      current = await store.readCurrent();
    } on Object catch (error) {
      return SaveLoadReport(
        origin: SaveOrigin.empty,
        problem: 'local storage is unavailable ($error)',
      );
    }

    String? problem;
    if (current != null) {
      try {
        _document = SaveCodec.decode(current, legacySettings: legacy);
        return const SaveLoadReport(origin: SaveOrigin.current);
      } on SaveFormatException catch (error) {
        problem = error.message;
        await _preserve(current);
      }
    }

    String? backup;
    try {
      backup = await store.readBackup();
    } on Object catch (error) {
      problem = _join(problem, 'the backup could not be read ($error)');
    }

    if (backup != null) {
      try {
        _document = SaveCodec.decode(backup, legacySettings: legacy);
        return SaveLoadReport(
          origin: SaveOrigin.backup,
          problem: problem ?? 'the newest save was missing',
        );
      } on SaveFormatException catch (error) {
        problem = _join(problem, error.message);
      }
    }

    if (current == null && backup == null && problem == null) {
      return const SaveLoadReport.fresh();
    }

    _document = const SaveDocument.empty();
    return SaveLoadReport(origin: SaveOrigin.empty, problem: problem);
  }

  /// Stores [progress] as the next document's campaign half.
  Future<void> saveProgress(CampaignProgress progress) {
    _document = _document.copyWith(progress: progress);
    return _write(_document);
  }

  /// Stores [settings] as the next document's preferences half.
  Future<void> saveSettings(GameSettings settings) {
    _document = _document.copyWith(settings: settings);
    return _write(_document);
  }

  /// Stores [waves] as the endless best, keeping progress and settings.
  ///
  /// Only the best run is worth a write, so callers pass the new record —
  /// the max-enforcement lives with the notifier that owns the score.
  Future<void> saveEndlessBest(int waves) {
    _document = _document.copyWith(endlessBest: waves);
    return _write(_document);
  }

  /// Encodes a snapshot now and appends it to the write queue.
  Future<void> _write(SaveDocument document) {
    final payload = SaveCodec.encode(document);
    final queued = _writes.then((_) => _storeWrite(payload));
    _writes = queued;
    return queued;
  }

  /// A failed write is logged, never thrown: a full disk or a locked store must
  /// keep the session running with the values already in memory.
  Future<void> _storeWrite(String payload) async {
    try {
      await store.write(payload);
    } on Object catch (error) {
      debugPrint('Failed to write the save: $error');
    }
  }

  Future<void> _preserve(String payload) async {
    try {
      await store.preserve(payload);
    } on Object catch (error) {
      debugPrint('Failed to keep the unreadable save: $error');
    }
  }

  /// Preferences a version 1 save kept outside the document, or the defaults
  /// when even that read fails — losing preferences must not block the load.
  Future<GameSettings> _legacySettings() async {
    try {
      return await legacySettings.load();
    } on Object catch (error) {
      debugPrint('Legacy preferences unreadable, using defaults: $error');
      return GameSettings.defaults;
    }
  }

  String _join(String? first, String second) =>
      first == null ? second : '$first; $second';
}
