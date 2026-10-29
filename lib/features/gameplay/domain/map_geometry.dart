import 'package:up_tower_defense/features/gameplay/domain/geometry.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/build_pad.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

/// World-space questions about a map: what was tapped and what is reachable.
///
/// Kept free of rendering so selection behaviour can be unit tested at exact
/// coordinates instead of through simulated screen taps. The Flame layer calls
/// this with tap positions already converted into world units.
class MapGeometry {
  MapGeometry(this.map);

  final MapDefinition map;

  /// The build pad whose area contains [point], else null.
  ///
  /// When pads overlap (map validation forbids it) the closest centre wins, so
  /// selection never depends on list order.
  BuildPad? padAt(WorldPoint point) {
    BuildPad? closestPad;
    var closestDistance = double.infinity;

    for (final pad in map.buildPads) {
      final distance = pad.position.distanceTo(point);
      if (distance <= map.buildPadRadius && distance < closestDistance) {
        closestPad = pad;
        closestDistance = distance;
      }
    }

    return closestPad;
  }

  /// Whether [point] lies on any part of the enemy route.
  ///
  /// Nothing is buildable on the route; pads are validated to keep clear of it,
  /// and this check keeps the renderer honest about the same rule.
  bool isOnRoute(WorldPoint point, {double tolerance = 0}) {
    return distanceToRoute(point) <= tolerance;
  }

  /// Distance from [point] to the nearest route segment.
  double distanceToRoute(WorldPoint point) {
    return distanceToPolyline(point, map.route);
  }

  /// Whether [point] is inside the playfield, optionally inset by [margin].
  bool isInsideWorld(WorldPoint point, {double margin = 0}) {
    return point.x >= margin &&
        point.y >= margin &&
        point.x <= map.worldWidth - margin &&
        point.y <= map.worldHeight - margin;
  }

  /// Total length of the enemy route in world units.
  late final double routeLength = _computeRouteLength();

  /// Length of each route segment, computed once.
  ///
  /// `pointAtDistance` walks these for every lookup, and the walk used to
  /// re-derive each length with a square root on every call — a cost paid for
  /// every enemy by targeting, movement and splash alike. The values are the
  /// same expression evaluated once, so results stay bit-identical while the
  /// walk drops to plain subtractions.
  late final List<double> segmentLengths = [
    for (var i = 1; i < map.route.length; i++)
      map.route[i - 1].distanceTo(map.route[i]),
  ];

  /// The segment index an enemy standing at [distance] units along the route
  /// is placed on.
  ///
  /// Classified by the same sequential walk [pointAtDistance] performs, so a
  /// broad phase built on this can never disagree with the position it prunes:
  /// whatever point the walk returns for [distance] lies on this segment. A
  /// degenerate route (fewer than two waypoints) reports segment 0, where the
  /// position lookup clamps anyway.
  int segmentIndexAtDistance(double distance) {
    if (segmentLengths.isEmpty || distance <= 0) {
      return 0;
    }

    var remaining = distance;
    for (var i = 0; i < segmentLengths.length; i++) {
      final segmentLength = segmentLengths[i];
      if (remaining <= segmentLength) {
        return i;
      }
      remaining -= segmentLength;
    }
    return segmentLengths.length - 1;
  }

  /// Which route segments come within [radius] of [point], as a flag per
  /// segment.
  ///
  /// The broad phase behind splash damage: an enemy's position always lies on
  /// its own segment, so if the blast reaches the enemy, that segment's
  /// distance to [point] is at most the blast radius — every `false` here is a
  /// stretch of route the exact distance test can skip entirely. The exact
  /// test still decides every survivor, so this can only remove candidates the
  /// exact test would have rejected, never a real victim.
  List<bool> reachableSegments(WorldPoint point, double radius) {
    final route = map.route;
    if (route.length < 2) {
      // A route without segments gives positions nothing to lie on, so the
      // mask can only fall back to the exact test for every candidate.
      return const [true];
    }

    final reachable = List<bool>.filled(route.length - 1, false);
    for (var i = 0; i + 1 < route.length; i++) {
      reachable[i] = distanceToSegment(point, route[i], route[i + 1]) <= radius;
    }
    return reachable;
  }

  /// World position of an enemy [distance] units along the route.
  ///
  /// Positions are clamped to the route: before the first waypoint the entry is
  /// returned, past the end the last waypoint (the core). Route distance, not
  /// elapsed time, is the authoritative enemy position, so movement stays
  /// identical at any frame rate.
  WorldPoint pointAtDistance(double distance) {
    final route = map.route;
    if (route.isEmpty) {
      return const WorldPoint(0, 0);
    }
    if (distance <= 0 || route.length == 1) {
      return route.first;
    }

    var remaining = distance;
    for (var i = 1; i < route.length; i++) {
      final from = route[i - 1];
      final to = route[i];
      final segmentLength = segmentLengths[i - 1];
      if (segmentLength == 0) {
        continue;
      }
      if (remaining <= segmentLength) {
        final t = remaining / segmentLength;
        return WorldPoint(
          from.x + (to.x - from.x) * t,
          from.y + (to.y - from.y) * t,
        );
      }
      remaining -= segmentLength;
    }

    return route.last;
  }

  double _computeRouteLength() {
    var total = 0.0;
    for (var i = 1; i < map.route.length; i++) {
      total += map.route[i].distanceTo(map.route[i - 1]);
    }
    return total;
  }
}
