import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

/// A predefined spot where the player may build a tower.
///
/// Pads are authored in map data, never derived from the route, so tower
/// placement can never block or reshape enemy pathing.
@immutable
class BuildPad {
  const BuildPad({
    required this.id,
    required this.label,
    required this.position,
  });

  /// Stable identifier used by saves, selection and (later) tower instances.
  final String id;

  /// Short player-facing label, for example `A`.
  final String label;

  /// Centre of the pad in world coordinates.
  final WorldPoint position;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is BuildPad &&
        other.id == id &&
        other.label == label &&
        other.position == position;
  }

  @override
  int get hashCode => Object.hash(id, label, position);

  @override
  String toString() => 'BuildPad($id, $label, $position)';
}
