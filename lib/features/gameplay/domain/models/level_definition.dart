import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_objective.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

/// Static definition of one playable level: which map, how much core health and
/// gold the attempt starts with, and which waves arrive in what order.
///
/// Completion rewards and star objectives join this model in later phases.
@immutable
class LevelDefinition {
  const LevelDefinition({
    required this.id,
    required this.displayName,
    required this.mapId,
    required this.coreHealth,
    required this.startingGold,
    required this.waves,
    this.waveTransitionSeconds = defaultWaveTransitionSeconds,
    this.endless = false,
    this.endlessCountGrowth = defaultEndlessCountGrowth,
    this.objectives = const [],
  });

  /// Countdown used when a level does not author its own.
  ///
  /// Long enough to spend a kill reward or pick a target priority, short enough
  /// that a player who is ready does not feel stalled; a level may shorten or
  /// lengthen it from data.
  static const double defaultWaveTransitionSeconds = 5;

  /// Stable level identifier.
  final String id;

  /// Player-facing name shown in the HUD and level select.
  final String displayName;

  /// Map this level plays on; must resolve in the map catalog.
  final String mapId;

  /// Core health the player starts with.
  final int coreHealth;

  /// Gold the player starts the attempt with, as an integer.
  final int startingGold;

  /// Ordered waves; at least one.
  final List<WaveDefinition> waves;

  /// Simulation seconds between a cleared wave and the next one starting on its
  /// own. The player may always start the next wave earlier.
  final double waveTransitionSeconds;

  /// Whether this level is the endless challenge: after the last authored wave
  /// the session composes the next one from [waves], forever, and the attempt
  /// can only end in defeat — never in victory (D62).
  final bool endless;

  /// How much a composed wave grows per full cycle through [waves].
  ///
  /// One cycle is one playthrough of the authored template: the wave after the
  /// last authored one is cycle 1, and every group's count gains
  /// `1 + endlessCountGrowth × cycle` (so 1.0 doubles the counts each cycle,
  /// triples them the next). Spawn intervals are untouched — difficulty climbs
  /// by volume of visible enemies, never by hidden stat changes the codex
  /// cannot show. Only meaningful when [endless].
  static const double defaultEndlessCountGrowth = 1.0;
  final double endlessCountGrowth;

  /// Optional goals beyond winning, authored as data (D68).
  ///
  /// Empty for fixtures, the synthetic profiling map and the endless run; a
  /// shipped campaign level declares exactly two, which the content gate pins.
  /// The star rule reads this list, so a level with none falls back to the
  /// core-health ladder it shipped with.
  final List<LevelObjective> objectives;

  @override
  String toString() => 'LevelDefinition($id on $mapId, ${waves.length} waves)';
}
