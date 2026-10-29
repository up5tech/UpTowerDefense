import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/map_geometry.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

import '../helpers/map_fixture.dart';

void main() {
  final geometry = MapGeometry(testMap);

  group('padAt', () {
    test('finds the pad under the tap', () {
      expect(geometry.padAt(const WorldPoint(180, 360))?.id, 'pad_a');
      expect(geometry.padAt(const WorldPoint(860, 380))?.id, 'pad_b');
    });

    test('accepts the pad edge and rejects a point just outside it', () {
      // Radius is 34.
      expect(geometry.padAt(const WorldPoint(214, 360))?.id, 'pad_a');
      expect(geometry.padAt(const WorldPoint(214.5, 360)), isNull);
    });

    test('rejects taps on the route and on open ground', () {
      expect(geometry.padAt(const WorldPoint(150, 500)), isNull);
      expect(geometry.padAt(const WorldPoint(640, 640)), isNull);
    });
  });

  group('route and bounds', () {
    test('reports points on the route', () {
      expect(geometry.isOnRoute(const WorldPoint(150, 500)), isTrue);
      expect(geometry.isOnRoute(const WorldPoint(300, 400)), isTrue);
      expect(geometry.isOnRoute(const WorldPoint(640, 640)), isFalse);
    });

    test('measures distance to the route', () {
      expect(geometry.distanceToRoute(const WorldPoint(180, 360)), 120);
      expect(geometry.distanceToRoute(const WorldPoint(860, 380)), 120);
    });

    test('honours the world bounds and an inset margin', () {
      expect(geometry.isInsideWorld(const WorldPoint(0, 0)), isTrue);
      expect(geometry.isInsideWorld(const WorldPoint(1280, 720)), isTrue);
      expect(geometry.isInsideWorld(const WorldPoint(-1, 0)), isFalse);
      expect(
        geometry.isInsideWorld(const WorldPoint(10, 10), margin: 20),
        isFalse,
      );
    });
  });

  group('route distance', () {
    test('adds up every segment', () {
      // 300 + 240 + 400 + 240 + 450.
      expect(geometry.routeLength, 1630);
    });

    test('maps a distance to a position on the first segment', () {
      expect(geometry.pointAtDistance(0), const WorldPoint(0, 500));
      expect(geometry.pointAtDistance(150), const WorldPoint(150, 500));
      expect(geometry.pointAtDistance(300), const WorldPoint(300, 500));
    });

    test('maps distances across corners to the exact waypoints', () {
      // 300 along the first leg, then 240 up the second.
      expect(geometry.pointAtDistance(420), const WorldPoint(300, 380));
      expect(geometry.pointAtDistance(540), const WorldPoint(300, 260));
      expect(geometry.pointAtDistance(1630), testMap.core);
    });

    test('clamps distances outside the route', () {
      expect(geometry.pointAtDistance(-50), const WorldPoint(0, 500));
      expect(geometry.pointAtDistance(99999), testMap.core);
    });
  });
}
