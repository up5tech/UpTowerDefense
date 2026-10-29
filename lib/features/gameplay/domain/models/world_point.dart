import 'dart:math' as math;

import 'package:meta/meta.dart';

/// A point in the game-world coordinate system, measured in logical map units.
///
/// Deliberately independent of Flutter and Flame types so map rules can be
/// validated and hit-tested without an engine running. The Flame layer converts
/// these to `Vector2` and screen positions.
@immutable
class WorldPoint {
  const WorldPoint(this.x, this.y);

  /// Horizontal position in world units.
  final double x;

  /// Vertical position in world units.
  final double y;

  /// Straight-line distance to [other].
  double distanceTo(WorldPoint other) {
    final dx = x - other.x;
    final dy = y - other.y;
    return math.sqrt(dx * dx + dy * dy);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is WorldPoint && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'WorldPoint($x, $y)';
}
