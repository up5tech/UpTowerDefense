import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/geometry.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

void main() {
  group('distanceToSegment', () {
    const a = WorldPoint(0, 0);
    const b = WorldPoint(100, 0);

    test('measures perpendicular distance beside the segment', () {
      expect(distanceToSegment(const WorldPoint(50, 30), a, b), 30);
    });

    test('clamps beyond the ends to the endpoints', () {
      expect(distanceToSegment(const WorldPoint(-40, 0), a, b), 40);
      expect(distanceToSegment(const WorldPoint(130, 0), a, b), 30);
    });

    test('returns distance to the point when the segment is degenerate', () {
      expect(distanceToSegment(const WorldPoint(3, 4), a, a), 5);
    });

    test('handles diagonal segments', () {
      final distance = distanceToSegment(
        const WorldPoint(0, 10),
        const WorldPoint(0, 0),
        const WorldPoint(10, 10),
      );
      expect(distance, closeTo(7.0710678, 1e-6));
    });
  });

  group('distanceToPolyline', () {
    const route = [
      WorldPoint(0, 100),
      WorldPoint(100, 100),
      WorldPoint(100, 0),
    ];

    test('uses the nearest segment of the polyline', () {
      expect(distanceToPolyline(const WorldPoint(40, 60), route), 40);
      expect(distanceToPolyline(const WorldPoint(130, 40), route), 30);
    });

    test('is infinite without two usable points', () {
      expect(
        distanceToPolyline(const WorldPoint(0, 0), [const WorldPoint(0, 0)]),
        double.infinity,
      );
    });
  });
}
