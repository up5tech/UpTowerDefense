import 'dart:convert';

import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/campaign/domain/level_rating.dart';
import 'package:up_tower_defense/features/save/data/save_document.dart';
import 'package:up_tower_defense/features/settings/domain/game_settings.dart';

/// Raised when a stored payload cannot be read as the shape this build knows.
///
/// The message lists every problem found, so a broken save is reported once in
/// full instead of one field at a time.
class SaveFormatException implements Exception {
  const SaveFormatException(this.message);

  final String message;

  @override
  String toString() => 'SaveFormatException: $message';
}

/// JSON encoding, validation and forward migration for [SaveDocument].
///
/// Pure Dart on purpose: decoding must be testable without a device, and the
/// data layer owns persisted shapes while the domain types stay ignorant of
/// them. Decoding never repairs or reinterprets — it either returns a document
/// or refuses with a [SaveFormatException], so an unreadable save can be kept
/// and reported rather than quietly overwritten.
abstract final class SaveCodec {
  /// The version this build writes.
  ///
  /// Version 3 added `endlessBest` beside progress and settings (D62).
  static const int currentVersion = 3;

  /// The oldest version this build still reads.
  ///
  /// Version 1 stored progress alone; preferences lived in their own legacy
  /// keys, which is why migrating forward takes the legacy preferences as an
  /// input.
  static const int firstVersion = 1;

  /// Version from which preferences live inside the document instead of the
  /// legacy settings store.
  static const int settingsInDocumentSince = 2;

  /// Writes [document] as the current schema version.
  static String encode(SaveDocument document) {
    return jsonEncode(<String, Object?>{
      'schemaVersion': currentVersion,
      'results': <String, Object?>{
        for (final entry in document.progress.results.entries)
          entry.key: _encodeResult(entry.value),
      },
      'settings': _encodeSettings(document.settings),
      'endlessBest': document.endlessBest,
    });
  }

  /// Reads a payload written by any version from [firstVersion] to
  /// [currentVersion].
  ///
  /// [legacySettings] supplies the preferences a version 1 save kept outside
  /// the document; newer saves ignore it.
  static SaveDocument decode(
    String raw, {
    GameSettings legacySettings = GameSettings.defaults,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw SaveFormatException(
        'the save is not valid JSON (${error.message})',
      );
    }
    if (decoded is! Map<String, Object?>) {
      throw const SaveFormatException('the save is not a JSON object');
    }

    final version = _readVersion(decoded);
    final progress = CampaignProgress(
      results: Map<String, LevelResult>.unmodifiable(
        _readResults(decoded['results']),
      ),
    );
    // Version 1 kept preferences in their own keys, so migrating forward folds
    // them in here; from version 2 on they come from the document itself.
    final settings = version < settingsInDocumentSince
        ? legacySettings
        : _readSettings(decoded['settings']);
    // The endless best only exists from version 3 on: an older payload has no
    // runs to remember, and inventing a number would be a repair, not a read.
    final endlessBest = version < endlessBestSince
        ? 0
        : _readEndlessBest(decoded['endlessBest']);

    return SaveDocument(
      progress: progress,
      settings: settings,
      endlessBest: endlessBest,
    );
  }

  /// Version from which `endlessBest` is part of the document.
  static const int endlessBestSince = 3;

  static int _readEndlessBest(Object? value) {
    if (value is! int || value < 0) {
      throw const SaveFormatException(
        'endlessBest is missing or is not a non-negative number; the data '
        'was left untouched instead of being reinterpreted',
      );
    }
    return value;
  }

  static int _readVersion(Map<String, Object?> json) {
    final raw = json['schemaVersion'];
    if (raw is! int) {
      throw const SaveFormatException(
        'schemaVersion is missing or is not a number',
      );
    }
    if (raw < firstVersion || raw > currentVersion) {
      throw SaveFormatException(
        'schemaVersion $raw is outside the range this build reads '
        '($firstVersion..$currentVersion); the data was left untouched instead '
        'of being reinterpreted',
      );
    }
    return raw;
  }

  static Map<String, LevelResult> _readResults(Object? value) {
    // Absent results would silently become an empty campaign and overwrite the
    // real one on the next write, so a missing section is a refusal, not an
    // empty level list.
    if (value is! Map<String, Object?>) {
      throw const SaveFormatException(
        'results is missing or is not a JSON object',
      );
    }

    final results = <String, LevelResult>{};
    final problems = <String>[];
    for (final entry in value.entries) {
      final levelId = entry.key;
      if (levelId.isEmpty) {
        problems.add('a result has an empty level id');
        continue;
      }
      final rawResult = entry.value;
      if (rawResult is! Map<String, Object?>) {
        problems.add('$levelId is not an object');
        continue;
      }
      final json = rawResult;

      final stars = _readInt(
        json,
        'stars',
        label: '$levelId stars',
        problems: problems,
        min: 0,
        max: LevelRating.maxStars,
      );
      final coreHealth = _readInt(
        json,
        'coreHealth',
        label: '$levelId coreHealth',
        problems: problems,
        min: 0,
      );
      final maxCoreHealth = _readInt(
        json,
        'maxCoreHealth',
        label: '$levelId maxCoreHealth',
        problems: problems,
        min: 1,
      );
      final wavesCleared = _readInt(
        json,
        'wavesCleared',
        label: '$levelId wavesCleared',
        problems: problems,
        min: 0,
      );
      final totalWaves = _readInt(
        json,
        'totalWaves',
        label: '$levelId totalWaves',
        problems: problems,
        min: 1,
      );

      // The cross-field checks run even when a field is unreadable, so one
      // broken result reports all of its problems instead of only the first.
      var usable = true;
      if (coreHealth != null &&
          maxCoreHealth != null &&
          coreHealth > maxCoreHealth) {
        problems.add('$levelId coreHealth exceeds maxCoreHealth');
        usable = false;
      }
      if (wavesCleared != null &&
          totalWaves != null &&
          wavesCleared > totalWaves) {
        problems.add('$levelId wavesCleared exceeds totalWaves');
        usable = false;
      }

      if (!usable ||
          stars == null ||
          coreHealth == null ||
          maxCoreHealth == null ||
          wavesCleared == null ||
          totalWaves == null) {
        continue;
      }

      results[levelId] = LevelResult(
        levelId: levelId,
        stars: stars,
        coreHealth: coreHealth,
        maxCoreHealth: maxCoreHealth,
        wavesCleared: wavesCleared,
        totalWaves: totalWaves,
      );
    }

    if (problems.isNotEmpty) {
      throw SaveFormatException(problems.join('; '));
    }
    return results;
  }

  /// Reads the preferences section, falling back field by field.
  ///
  /// Preferences are the one part that degrades instead of refusing: a wrong
  /// toggle type has always defaulted rather than blocked launch, and losing one
  /// is far cheaper than losing progress. A section of the wrong type is still a
  /// refusal, because it means the payload is not this format at all.
  static GameSettings _readSettings(Object? value) {
    if (value == null) {
      return GameSettings.defaults;
    }
    if (value is! Map<String, Object?>) {
      throw const SaveFormatException('settings is not a JSON object');
    }

    bool read(String key, {required bool fallback}) {
      final raw = value[key];
      return raw is bool ? raw : fallback;
    }

    const defaults = GameSettings.defaults;

    double readVolume(String key, {required double fallback}) {
      final raw = value[key];
      // A save written before the sliders simply has no volume keys, and a
      // hand-edited number outside the slider's range is clamped rather than
      // refused — the switch beside it already defaults on unreadable types.
      if (raw is num) {
        return raw.toDouble().clamp(0.0, 1.0);
      }
      return fallback;
    }

    return GameSettings(
      musicEnabled: read('musicEnabled', fallback: defaults.musicEnabled),
      sfxEnabled: read('sfxEnabled', fallback: defaults.sfxEnabled),
      musicVolume: readVolume('musicVolume', fallback: defaults.musicVolume),
      sfxVolume: readVolume('sfxVolume', fallback: defaults.sfxVolume),
      hapticsEnabled: read('hapticsEnabled', fallback: defaults.hapticsEnabled),
      reducedMotion: read('reducedMotion', fallback: defaults.reducedMotion),
      // Saves written before the tutorial existed simply have no key, so they
      // read as "not seen" and the card shows once — the safe direction.
      tutorialSeen: read('tutorialSeen', fallback: defaults.tutorialSeen),
    );
  }

  static int? _readInt(
    Map<String, Object?> json,
    String key, {
    required String label,
    required List<String> problems,
    int? min,
    int? max,
  }) {
    final raw = json[key];
    if (raw is! int) {
      problems.add('$label is missing or is not a whole number');
      return null;
    }
    if (min != null && raw < min) {
      problems.add('$label is below $min');
      return null;
    }
    if (max != null && raw > max) {
      problems.add('$label is above $max');
      return null;
    }
    return raw;
  }

  static Map<String, Object> _encodeResult(LevelResult result) {
    return <String, Object>{
      'stars': result.stars,
      'coreHealth': result.coreHealth,
      'maxCoreHealth': result.maxCoreHealth,
      'wavesCleared': result.wavesCleared,
      'totalWaves': result.totalWaves,
    };
  }

  static Map<String, Object> _encodeSettings(GameSettings settings) {
    return <String, Object>{
      'musicEnabled': settings.musicEnabled,
      'sfxEnabled': settings.sfxEnabled,
      'musicVolume': settings.musicVolume,
      'sfxVolume': settings.sfxVolume,
      'hapticsEnabled': settings.hapticsEnabled,
      'reducedMotion': settings.reducedMotion,
      'tutorialSeen': settings.tutorialSeen,
    };
  }
}
