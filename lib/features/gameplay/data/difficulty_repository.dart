import 'package:flutter/services.dart';
import 'package:up_tower_defense/features/gameplay/data/asset_loader.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/content_format_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/content_load_exception.dart';
import 'package:up_tower_defense/features/gameplay/data/difficulty_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';

/// Loads one profile per shipped difficulty.
///
/// The whole set is resolved at once, so a missing mode fails at load instead of
/// the moment a player taps Hard. Every mode [Difficulty] names must be authored;
/// the picker, the route and the save all assume it exists.
class DifficultyRepository {
  DifficultyRepository({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;

  /// Loads every profile, keyed by difficulty.
  Future<Map<Difficulty, DifficultyProfile>> load() async {
    final source = await readAssetText(_bundle, ContentCatalog.difficulties);

    final List<DifficultyProfile> profiles;
    try {
      profiles = DifficultyJsonDecoder.decode(source);
    } on ContentFormatException catch (error) {
      throw ContentLoadException(ContentCatalog.difficulties, error.message);
    }

    final byDifficulty = <Difficulty, DifficultyProfile>{
      for (final profile in profiles) profile.difficulty: profile,
    };
    final missing = [
      for (final difficulty in Difficulty.values)
        if (!byDifficulty.containsKey(difficulty)) difficulty.wireName,
    ];
    if (missing.isNotEmpty) {
      throw ContentLoadException(
        ContentCatalog.difficulties,
        'no profile authored for ${missing.join(', ')}',
      );
    }

    return Map<Difficulty, DifficultyProfile>.unmodifiable(byDifficulty);
  }
}
