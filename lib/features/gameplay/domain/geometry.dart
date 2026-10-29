import 'dart:math' as math;

import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

/// Shortest distance from [point] to the segment from [a] to [b].
///
/// Used by hit testing and content validation, so it lives in plain Dart with
/// no engine dependency. A zero-length segment degrades to the distance to [a].
double distanceToSegment(WorldPoint point, WorldPoint a, WorldPoint b) {
  final abx = b.x - a.x;
  final aby = b.y - a.y;
  final lengthSquared = abx * abx + aby * aby;
  if (lengthSquared == 0) {
    return point.distanceTo(a);
  }

  final apx = point.x - a.x;
  final apy = point.y - a.y;
  final t = ((apx * abx + apy * aby) / lengthSquared).clamp(0.0, 1.0);
  final closest = WorldPoint(a.x + abx * t, a.y + aby * t);
  return point.distanceTo(closest);
}

/// Shortest distance from [point] to a polyline through [points].
///
/// Returns [double.infinity] for fewer than two points, because an incomplete
/// route has no segments to measure against.
double distanceToPolyline(WorldPoint point, List<WorldPoint> points) {
  if (points.length < 2) {
    return double.infinity;
  }

  var shortest = double.infinity;
  for (var i = 1; i < points.length; i++) {
    final distance = distanceToSegment(point, points[i - 1], points[i]);
    shortest = math.min(shortest, distance);
  }
  return shortest;
}
