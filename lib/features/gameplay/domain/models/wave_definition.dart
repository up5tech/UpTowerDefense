import 'package:meta/meta.dart';

/// One group of enemies spawned inside a wave.
@immutable
class SpawnGroupDefinition {
  const SpawnGroupDefinition({
    required this.enemyId,
    required this.count,
    required this.spawnIntervalSeconds,
    this.initialDelaySeconds = 0,
  });

  /// Enemy type to spawn; must exist in the enemy catalog.
  final String enemyId;

  /// How many enemies this group spawns.
  final int count;

  /// Simulation-time gap between consecutive spawns.
  final double spawnIntervalSeconds;

  /// Simulation-time delay before the first spawn of this group, measured from
  /// the moment the wave starts.
  final double initialDelaySeconds;

  @override
  String toString() =>
      'SpawnGroup($enemyId x$count every ${spawnIntervalSeconds}s '
      'after ${initialDelaySeconds}s)';
}

/// One wave: an ordered set of spawn groups.
@immutable
class WaveDefinition {
  const WaveDefinition({required this.id, required this.groups});

  /// Stable wave identifier, unique within its level.
  final String id;

  /// Groups spawned by this wave; at least one.
  final List<SpawnGroupDefinition> groups;

  /// Total enemies this wave will spawn.
  int get enemyCount => groups.fold(0, (total, group) => total + group.count);

  @override
  String toString() => 'WaveDefinition($id, ${groups.length} groups)';
}
