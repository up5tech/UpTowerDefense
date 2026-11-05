import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/json_reader.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';

/// Decodes `assets/data/difficulties.json` into load-time profiles (D65).
///
/// The numbers live in data so a balance edit is a content change, but the set
/// of modes is closed by [Difficulty]: an unknown name is a format error, not a
/// new mode nobody wrote a route, a save key or a picker label for.
abstract final class DifficultyJsonDecoder {
  static List<DifficultyProfile> decode(String source) {
    final root = JsonReader.decodeObject(source);
    final profiles = JsonReader.requireList(root['profiles'], 'profiles');

    final decoded = <DifficultyProfile>[];
    final seen = <Difficulty>{};
    for (var index = 0; index < profiles.length; index++) {
      final path = 'profiles[$index]';
      final json = JsonReader.requireObject(profiles[index], path);
      final name = JsonReader.requireString(json, 'difficulty', parent: path);
      final difficulty = Difficulty.fromWireName(name);
      if (difficulty == null) {
        throw ContentFormatException(
          '$path.difficulty "$name" is not a known difficulty; expected one of '
          '${Difficulty.values.map((value) => value.wireName).join(', ')}',
        );
      }
      if (!seen.add(difficulty)) {
        throw ContentFormatException(
          '$path repeats difficulty "$name"; a mode is tuned in one place',
        );
      }

      final profile = DifficultyProfile(
        difficulty: difficulty,
        waveCountPercent: JsonReader.requireInt(
          json,
          'waveCountPercent',
          parent: path,
        ),
        startingGoldPercent: JsonReader.requireInt(
          json,
          'startingGoldPercent',
          parent: path,
        ),
      );
      // A zero or negative percentage would delete waves or hand the player a
      // negative purse; both are arithmetic that no level is tuned for.
      if (profile.waveCountPercent <= 0) {
        throw ContentFormatException(
          '$path.waveCountPercent must be positive, '
          'got ${profile.waveCountPercent}',
        );
      }
      if (profile.startingGoldPercent <= 0) {
        throw ContentFormatException(
          '$path.startingGoldPercent must be positive, '
          'got ${profile.startingGoldPercent}',
        );
      }
      decoded.add(profile);
    }

    return decoded;
  }
}
