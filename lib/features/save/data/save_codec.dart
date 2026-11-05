import 'dart:convert';

import 'package:up_tower_defense/features/campaign/domain/achievement.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/campaign/domain/level_rating.dart';
import 'package:up_tower_defense/features/gameplay/domain/daily_challenge.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';
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
  /// Version 3 added `endlessBest` beside progress and settings (D62); version 4
  /// keys every result by level *and* difficulty and records how many goals the
  /// run met (D65, D68); version 5 adds earned achievements and the per-date
  /// daily records (D67, D66). Every change is additive, so every older save
  /// still loads with defaults.
  static const int currentVersion = 5;

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
        for (final result in document.progress.results.values)
          result.key: _encodeResult(result),
      },
      'settings': _encodeSettings(document.settings),
      'endlessBest': document.endlessBest,
      'achievements': [
        for (final achievement in document.achievements) achievement.wireName,
      ]..sort(),
      'dailyResults': <String, Object?>{
        for (final entry in document.dailyResults.entries)
          entry.key.toString(): _encodeDailyResult(entry.value),
      },
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
        _readResults(decoded['results'], version: version),
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
      // Achievements and dailies only exist from version 5 on: an older payload
      // has no such facts, and inventing them would be a repair, not a read.
      achievements: version < achievementsSince
          ? const <Achievement>{}
          : _readAchievements(decoded['achievements']),
      dailyResults: version < dailyResultsSince
          ? const <int, DailyResult>{}
          : _readDailyResults(decoded['dailyResults']),
    );
  }

  /// Version from which earned achievements are part of the document.
  static const int achievementsSince = 5;

  /// Version from which daily records are part of the document.
  static const int dailyResultsSince = 5;

  /// Reads the earned ids, refusing one this build cannot name.
  ///
  /// A v5 payload with an id outside [Achievement] is corrupt rather than
  /// newer — a newer build would have written a higher `schemaVersion` and been
  /// refused already — so it is reported instead of dropped.
  static Set<Achievement> _readAchievements(Object? value) {
    if (value is! List<Object?>) {
      throw const SaveFormatException(
        'achievements is missing or is not a list',
      );
    }

    final earned = <Achievement>{};
    final problems = <String>[];
    for (var index = 0; index < value.length; index++) {
      final raw = value[index];
      if (raw is! String) {
        problems.add('achievements[$index] is not a string');
        continue;
      }
      final achievement = Achievement.fromWireName(raw);
      if (achievement == null) {
        problems.add(
          'achievements[$index] "$raw" is not a known achievement',
        );
        continue;
      }
      earned.add(achievement);
    }

    if (problems.isNotEmpty) {
      throw SaveFormatException(problems.join('; '));
    }
    return Set<Achievement>.unmodifiable(earned);
  }

  /// Reads the per-date daily records.
  ///
  /// The stored date and the map key must agree: a result filed under the wrong
  /// day would silently replace another day's best, which is the one thing a
  /// daily record exists to keep apart (D66).
  static Map<int, DailyResult> _readDailyResults(Object? value) {
    if (value is! Map<String, Object?>) {
      throw const SaveFormatException(
        'dailyResults is missing or is not a JSON object',
      );
    }

    final results = <int, DailyResult>{};
    final problems = <String>[];
    for (final entry in value.entries) {
      final dateKey = int.tryParse(entry.key);
      if (dateKey == null || dateKey <= 0) {
        problems.add('dailyResults key "${entry.key}" is not a date');
        continue;
      }
      final raw = entry.value;
      if (raw is! Map<String, Object?>) {
        problems.add('${entry.key} is not an object');
        continue;
      }
      final json = raw;

      final storedDate = _readInt(
        json,
        'dateKey',
        label: '${entry.key} dateKey',
        problems: problems,
        min: 1,
      );
      if (storedDate != null && storedDate != dateKey) {
        problems.add('${entry.key} stores dateKey $storedDate');
        continue;
      }
      final levelId = json['levelId'];
      if (levelId is! String || levelId.isEmpty) {
        problems.add('${entry.key} levelId is missing or is empty');
      }
      final stars = _readInt(
        json,
        'stars',
        label: '${entry.key} stars',
        problems: problems,
        min: 0,
        max: LevelRating.maxStars,
      );
      final coreHealth = _readInt(
        json,
        'coreHealth',
        label: '${entry.key} coreHealth',
        problems: problems,
        min: 0,
      );
      final maxCoreHealth = _readInt(
        json,
        'maxCoreHealth',
        label: '${entry.key} maxCoreHealth',
        problems: problems,
        min: 1,
      );
      final objectivesMet = _readInt(
        json,
        'objectivesMet',
        label: '${entry.key} objectivesMet',
        problems: problems,
        min: 0,
        max: LevelRating.maxStars - 1,
      );
      if (coreHealth != null &&
          maxCoreHealth != null &&
          coreHealth > maxCoreHealth) {
        problems.add('${entry.key} coreHealth exceeds maxCoreHealth');
      }

      if (storedDate == null ||
          levelId is! String ||
          levelId.isEmpty ||
          stars == null ||
          coreHealth == null ||
          maxCoreHealth == null ||
          coreHealth > maxCoreHealth ||
          objectivesMet == null) {
        continue;
      }

      results[dateKey] = DailyResult(
        dateKey: dateKey,
        levelId: levelId,
        stars: stars,
        coreHealth: coreHealth,
        maxCoreHealth: maxCoreHealth,
        objectivesMet: objectivesMet,
      );
    }

    if (problems.isNotEmpty) {
      throw SaveFormatException(problems.join('; '));
    }
    return Map<int, DailyResult>.unmodifiable(results);
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

  /// Version from which a result carries its difficulty and goal count (D65).
  static const int difficultyInResultsSince = 4;

  static Map<String, LevelResult> _readResults(
    Object? value, {
    required int version,
  }) {
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

      // Before v4 a level had exactly one result and keys were bare level ids;
      // reading them as Normal keeps every stored key and star verbatim. A v4
      // key must agree with the fields inside it, or the payload is refused
      // rather than reinterpreted into the wrong mode's slot.
      final levelIdField = version < difficultyInResultsSince
          ? levelId
          : _readResultLevelId(
              json,
              label: '$levelId levelId',
              problems: problems,
            );
      final difficulty = version < difficultyInResultsSince
          ? Difficulty.normal
          : _readDifficulty(
              json,
              label: '$levelId difficulty',
              problems: problems,
            );
      final objectivesMet = version < difficultyInResultsSince
          ? 0
          : _readInt(
              json,
              'objectivesMet',
              label: '$levelId objectivesMet',
              problems: problems,
              min: 0,
              max: LevelRating.maxStars - 1,
            );

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

      if (levelIdField != null && difficulty != null) {
        final expected = LevelResult.keyOf(levelIdField, difficulty);
        if (expected != levelId) {
          problems.add(
            '$levelId is stored under the wrong key for '
            '"$levelIdField" on ${difficulty.wireName} (expected "$expected")',
          );
          usable = false;
        }
      }

      if (!usable ||
          levelIdField == null ||
          difficulty == null ||
          objectivesMet == null ||
          stars == null ||
          coreHealth == null ||
          maxCoreHealth == null ||
          wavesCleared == null ||
          totalWaves == null) {
        continue;
      }

      // The stored key is the canonical one, so the map and the result can
      // never disagree about which slot a run belongs to.
      final result = LevelResult(
        levelId: levelIdField,
        stars: stars,
        coreHealth: coreHealth,
        maxCoreHealth: maxCoreHealth,
        wavesCleared: wavesCleared,
        totalWaves: totalWaves,
        difficulty: difficulty,
        objectivesMet: objectivesMet,
      );
      results[result.key] = result;
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

  static String? _readResultLevelId(
    Map<String, Object?> json, {
    required String label,
    required List<String> problems,
  }) {
    final raw = json['levelId'];
    if (raw is! String || raw.isEmpty) {
      problems.add('$label is missing or is not a level id');
      return null;
    }
    return raw;
  }

  /// Reads a result's difficulty, which must name a shipped mode.
  static Difficulty? _readDifficulty(
    Map<String, Object?> json, {
    required String label,
    required List<String> problems,
  }) {
    final raw = json['difficulty'];
    if (raw is! String) {
      problems.add('$label is missing or is not a string');
      return null;
    }
    final difficulty = Difficulty.fromWireName(raw);
    if (difficulty == null) {
      problems.add(
        '$label "$raw" is not a known difficulty; expected one of '
        '${Difficulty.values.map((value) => value.wireName).join(', ')}',
      );
    }
    return difficulty;
  }

  static Map<String, Object> _encodeResult(LevelResult result) {
    return <String, Object>{
      'levelId': result.levelId,
      'difficulty': result.difficulty.wireName,
      'objectivesMet': result.objectivesMet,
      'stars': result.stars,
      'coreHealth': result.coreHealth,
      'maxCoreHealth': result.maxCoreHealth,
      'wavesCleared': result.wavesCleared,
      'totalWaves': result.totalWaves,
    };
  }

  static Map<String, Object> _encodeDailyResult(DailyResult result) {
    return <String, Object>{
      'dateKey': result.dateKey,
      'levelId': result.levelId,
      'stars': result.stars,
      'coreHealth': result.coreHealth,
      'maxCoreHealth': result.maxCoreHealth,
      'objectivesMet': result.objectivesMet,
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
