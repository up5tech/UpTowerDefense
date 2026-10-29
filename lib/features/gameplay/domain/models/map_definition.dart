import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/build_pad.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

/// Static definition of one playable arena.
///
/// Immutable: a running level never mutates its map. Runtime state (occupied
/// pads, selected pad, towers) belongs to the level session, not here.
///
/// Maps are authored as JSON and validated before use; see
/// `docs/CONTENT_AUTHORING.md`.
@immutable
class MapDefinition {
  const MapDefinition({
    required this.id,
    required this.displayName,
    required this.worldWidth,
    required this.worldHeight,
    required this.buildPadRadius,
    required this.route,
    required this.core,
    required this.buildPads,
  });

  /// Stable map identifier.
  final String id;

  /// Player-facing map name.
  final String displayName;

  /// Width of the playfield in world units.
  final double worldWidth;

  /// Height of the playfield in world units.
  final double worldHeight;

  /// Radius of every build pad on this map, in world units.
  final double buildPadRadius;

  /// Ordered enemy route; the final waypoint is the core.
  final List<WorldPoint> route;

  /// Protected core, reached by the last waypoint of [route].
  final WorldPoint core;

  /// Valid, predefined tower spots.
  final List<BuildPad> buildPads;

  /// The pad with [id], or null when no pad matches.
  BuildPad? padById(String id) {
    for (final pad in buildPads) {
      if (pad.id == id) {
        return pad;
      }
    }
    return null;
  }

  @override
  String toString() =>
      'MapDefinition($id, ${route.length} waypoints, '
      '${buildPads.length} pads)';
}
