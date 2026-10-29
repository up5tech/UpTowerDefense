import 'package:up_tower_defense/features/gameplay/domain/map_geometry.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/validation_result.dart';

/// Checks authored map data against the rules the game relies on.
///
/// Rules (see `docs/CONTENT_AUTHORING.md`):
/// - positive world dimensions and pad radius;
/// - at least two route waypoints, no zero-length steps, all inside the world;
/// - the core sits on the final waypoint;
/// - unique, bounded, non-overlapping pads that keep clear of the route and
///   core.
class MapValidator {
  const MapValidator({
    this.routeClearance = 8,
    this.edgeClearance = 8,
    this.minSegmentLength = 1,
    this.padSpacing = 8,
    this.pointTolerance = 0.5,
  });

  /// Minimum gap between a pad edge and the route.
  final double routeClearance;

  /// Minimum gap between a pad edge and the map border.
  final double edgeClearance;

  /// Waypoints closer than this count as duplicates.
  final double minSegmentLength;

  /// Minimum gap between the edges of two pads.
  final double padSpacing;

  /// Distance the core may be away from the final waypoint.
  final double pointTolerance;

  ValidationResult validate(MapDefinition map) {
    final issues = <String>[];
    final geometry = MapGeometry(map);

    if (map.id.trim().isEmpty) {
      issues.add('id must not be empty');
    }
    if (map.displayName.trim().isEmpty) {
      issues.add('displayName must not be empty');
    }
    if (map.worldWidth <= 0 || map.worldHeight <= 0) {
      issues.add(
        'world must have positive dimensions, got '
        '${map.worldWidth}x${map.worldHeight}',
      );
    }
    if (map.buildPadRadius <= 0) {
      issues.add('buildPadRadius must be positive, got ${map.buildPadRadius}');
    }

    issues.addAll(_validateRoute(map, geometry));
    issues.addAll(_validateCore(map, geometry));
    issues.addAll(_validatePads(map, geometry));

    return ValidationResult(issues);
  }

  List<String> _validateRoute(MapDefinition map, MapGeometry geometry) {
    final issues = <String>[];

    if (map.route.length < 2) {
      issues.add('route needs at least two waypoints, got ${map.route.length}');
      return issues;
    }

    for (var i = 0; i < map.route.length; i++) {
      final point = map.route[i];
      if (!geometry.isInsideWorld(point)) {
        issues.add('route[$i] $point lies outside the world bounds');
      }
      if (i == 0) {
        continue;
      }
      final step = point.distanceTo(map.route[i - 1]);
      if (step < minSegmentLength) {
        issues.add(
          'route[$i] $point duplicates route[${i - 1}] '
          '(step $step, minimum $minSegmentLength)',
        );
      }
    }

    return issues;
  }

  List<String> _validateCore(MapDefinition map, MapGeometry geometry) {
    final issues = <String>[];

    if (map.route.isEmpty) {
      issues.add('core cannot be validated without a route');
      return issues;
    }
    if (!geometry.isInsideWorld(map.core)) {
      issues.add('core ${map.core} lies outside the world bounds');
    }
    final distance = map.core.distanceTo(map.route.last);
    if (distance > pointTolerance) {
      issues.add(
        'core ${map.core} must sit on the final waypoint ${map.route.last} '
        '(distance $distance, tolerance $pointTolerance)',
      );
    }

    return issues;
  }

  List<String> _validatePads(MapDefinition map, MapGeometry geometry) {
    final issues = <String>[];

    if (map.buildPads.isEmpty) {
      issues.add('map needs at least one build pad');
      return issues;
    }

    final seenIds = <String>{};
    final minimumWorldGap = map.buildPadRadius + edgeClearance;
    final minimumRouteGap = map.buildPadRadius + routeClearance;

    for (final pad in map.buildPads) {
      if (!seenIds.add(pad.id)) {
        issues.add('build pad id "${pad.id}" is duplicated');
      }
      if (pad.label.trim().isEmpty) {
        issues.add('build pad "${pad.id}" needs a label');
      }
      if (!geometry.isInsideWorld(pad.position, margin: minimumWorldGap)) {
        issues.add(
          'build pad "${pad.id}" is too close to the map edge '
          '(needs ${minimumWorldGap.toStringAsFixed(1)} of clearance)',
        );
      }

      final routeDistance = geometry.distanceToRoute(pad.position);
      if (routeDistance < minimumRouteGap) {
        issues.add(
          'build pad "${pad.id}" overlaps the enemy route '
          '(distance ${routeDistance.toStringAsFixed(1)}, '
          'needs ${minimumRouteGap.toStringAsFixed(1)})',
        );
      }

      final coreDistance = pad.position.distanceTo(map.core);
      if (coreDistance < minimumRouteGap) {
        issues.add(
          'build pad "${pad.id}" is too close to the core '
          '(distance ${coreDistance.toStringAsFixed(1)}, '
          'needs ${minimumRouteGap.toStringAsFixed(1)})',
        );
      }
    }

    final minimumPadDistance = map.buildPadRadius * 2 + padSpacing;
    for (var i = 0; i < map.buildPads.length; i++) {
      for (var j = i + 1; j < map.buildPads.length; j++) {
        final a = map.buildPads[i];
        final b = map.buildPads[j];
        final distance = a.position.distanceTo(b.position);
        if (distance < minimumPadDistance) {
          issues.add(
            'build pads "${a.id}" and "${b.id}" are too close '
            '(distance ${distance.toStringAsFixed(1)}, '
            'needs ${minimumPadDistance.toStringAsFixed(1)})',
          );
        }
      }
    }

    return issues;
  }
}
