import 'dart:math' as math;

import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

/// A shipped campaign difficulty (D65).
///
/// The enum is the identity used by saves, routes and the picker; the numbers
/// that make each mode harder live in `assets/data/difficulties.json` so a
/// balance edit never touches code.
enum Difficulty {
  /// The authored campaign as it shipped in 1.0.
  normal('normal', 'Normal'),

  /// The same levels with more enemies and a thinner purse.
  hard('hard', 'Hard');

  const Difficulty(this.wireName, this.label);

  /// Name authored in JSON, in a save and in a route segment. The Dart enum
  /// name stays an implementation detail, so renaming a constant cannot rewrite
  /// stored data.
  final String wireName;

  /// Player-facing name, derived here so every screen spells it the same way.
  final String label;

  /// The difficulty authored as [name], or null for an unknown one.
  static Difficulty? fromWireName(String name) {
    for (final difficulty in values) {
      if (difficulty.wireName == name) {
        return difficulty;
      }
    }
    return null;
  }
}

/// One difficulty's load-time tuning: integer multipliers over wave group
/// counts and starting gold (D65).
///
/// Percentages rather than doubles because gold is an integer everywhere else in
/// the game: `gold × percent ~/ 100` cannot drift by a rounding error, and the
/// number a save records is exactly the number the player was given. Core health
/// is deliberately not here — it stays authored, so the star rule means the same
/// thing on both modes.
@immutable
class DifficultyProfile {
  const DifficultyProfile({
    required this.difficulty,
    this.waveCountPercent = 100,
    this.startingGoldPercent = 100,
  });

  /// The authored campaign, unchanged; what every non-campaign run uses.
  static const DifficultyProfile normal = DifficultyProfile(
    difficulty: Difficulty.normal,
  );

  /// Which mode this profile tunes.
  final Difficulty difficulty;

  /// Percentage applied to every wave group's enemy count; 100 is unchanged.
  ///
  /// A group never drops below one enemy: scaling a group to zero would silently
  /// delete content a level was tuned around.
  final int waveCountPercent;

  /// Percentage applied to the level's authored starting gold; 100 is
  /// unchanged.
  final int startingGoldPercent;

  /// Whether this profile leaves a level exactly as authored.
  bool get isNeutral => waveCountPercent == 100 && startingGoldPercent == 100;

  /// The level as this difficulty plays it.
  ///
  /// Everything the level *is* — map, core health, objectives, wave pacing — is
  /// carried over unchanged; only the amount of gold and the number of enemies
  /// move. The result is a new immutable definition, so nothing can scale a
  /// shared catalog by accident.
  LevelDefinition applyTo(LevelDefinition level) {
    if (isNeutral) {
      return level;
    }
    return LevelDefinition(
      id: level.id,
      displayName: level.displayName,
      mapId: level.mapId,
      coreHealth: level.coreHealth,
      startingGold: level.startingGold * startingGoldPercent ~/ 100,
      waves: [
        for (final wave in level.waves)
          WaveDefinition(id: wave.id, groups: _groupsOf(wave)),
      ],
      waveTransitionSeconds: level.waveTransitionSeconds,
      endless: level.endless,
      endlessCountGrowth: level.endlessCountGrowth,
      objectives: level.objectives,
    );
  }

  List<SpawnGroupDefinition> _groupsOf(WaveDefinition wave) {
    return [
      for (final group in wave.groups)
        SpawnGroupDefinition(
          enemyId: group.enemyId,
          count: math.max(1, group.count * waveCountPercent ~/ 100),
          spawnIntervalSeconds: group.spawnIntervalSeconds,
          initialDelaySeconds: group.initialDelaySeconds,
        ),
    ];
  }

  @override
  String toString() =>
      'DifficultyProfile(${difficulty.wireName}, waves $waveCountPercent%, '
      'gold $startingGoldPercent%)';
}
