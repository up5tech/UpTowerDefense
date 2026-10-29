import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/map_validation.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/build_pad.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';
import 'package:up_tower_defense/features/gameplay/domain/validation_result.dart';

import '../helpers/map_fixture.dart';

MapDefinition _variant({
  String? id,
  String? displayName,
  double? worldWidth,
  double? worldHeight,
  double? buildPadRadius,
  List<WorldPoint>? route,
  WorldPoint? core,
  List<BuildPad>? buildPads,
}) {
  return MapDefinition(
    id: id ?? testMap.id,
    displayName: displayName ?? testMap.displayName,
    worldWidth: worldWidth ?? testMap.worldWidth,
    worldHeight: worldHeight ?? testMap.worldHeight,
    buildPadRadius: buildPadRadius ?? testMap.buildPadRadius,
    route: route ?? testMap.route,
    core: core ?? testMap.core,
    buildPads: buildPads ?? testMap.buildPads,
  );
}

ValidationResult _validate(MapDefinition map) =>
    const MapValidator().validate(map);

void main() {
  test('the fixture map is valid', () {
    expect(_validate(testMap).isValid, isTrue);
  });

  test('reports every problem, not just the first', () {
    final result = _validate(
      _variant(
        id: ' ',
        buildPadRadius: 0,
        buildPads: const [
          BuildPad(id: 'dup', label: 'A', position: WorldPoint(5, 5)),
          BuildPad(id: 'dup', label: 'B', position: WorldPoint(6, 6)),
        ],
      ),
    );

    expect(result.isValid, isFalse);
    expect(result.issues.length, greaterThanOrEqualTo(4));
  });

  group('route', () {
    test('requires two waypoints', () {
      final result = _validate(
        _variant(
          route: const [WorldPoint(0, 500)],
          core: const WorldPoint(0, 500),
        ),
      );

      expect(
        result.issues,
        contains(contains('route needs at least two waypoints')),
      );
    });

    test('rejects zero-length steps', () {
      final result = _validate(
        _variant(
          route: const [
            WorldPoint(0, 500),
            WorldPoint(0, 500),
            WorldPoint(200, 500),
          ],
        ),
      );

      expect(result.issues, contains(contains('duplicates route[0]')));
    });

    test('rejects waypoints outside the world', () {
      final result = _validate(
        _variant(
          route: const [WorldPoint(-10, 500), WorldPoint(200, 500)],
          core: const WorldPoint(200, 500),
        ),
      );

      expect(result.issues, contains(contains('lies outside the world')));
    });
  });

  group('core', () {
    test('must sit on the final waypoint', () {
      final result = _validate(_variant(core: const WorldPoint(1100, 500)));

      expect(
        result.issues,
        contains(contains('must sit on the final waypoint')),
      );
    });

    test('must stay inside the world', () {
      final result = _validate(
        _variant(
          route: const [WorldPoint(0, 500), WorldPoint(1300, 500)],
          core: const WorldPoint(1300, 500),
        ),
      );

      expect(result.issues, contains(contains('core')));
    });
  });

  group('build pads', () {
    test('a pad on the route is rejected', () {
      final result = _validate(
        _variant(
          buildPads: const [
            BuildPad(
              id: 'on_route',
              label: 'X',
              position: WorldPoint(150, 500),
            ),
          ],
        ),
      );

      expect(result.issues, contains(contains('overlaps the enemy route')));
    });

    test('a pad near the map edge is rejected', () {
      final result = _validate(
        _variant(
          buildPads: const [
            BuildPad(id: 'edge', label: 'X', position: WorldPoint(10, 360)),
          ],
        ),
      );

      expect(result.issues, contains(contains('too close to the map edge')));
    });

    test('overlapping pads are rejected', () {
      final result = _validate(
        _variant(
          buildPads: const [
            BuildPad(id: 'one', label: '1', position: WorldPoint(180, 360)),
            BuildPad(id: 'two', label: '2', position: WorldPoint(200, 380)),
          ],
        ),
      );

      expect(result.issues, contains(contains('are too close')));
    });

    test('duplicate ids are rejected', () {
      final result = _validate(
        _variant(
          buildPads: const [
            BuildPad(id: 'pad', label: '1', position: WorldPoint(180, 360)),
            BuildPad(id: 'pad', label: '2', position: WorldPoint(860, 380)),
          ],
        ),
      );

      expect(result.issues, contains(contains('is duplicated')));
    });

    test('a missing label is rejected', () {
      final result = _validate(
        _variant(
          buildPads: const [
            BuildPad(id: 'pad', label: ' ', position: WorldPoint(180, 360)),
          ],
        ),
      );

      expect(result.issues, contains(contains('needs a label')));
    });

    test('at least one pad is required', () {
      final result = _validate(_variant(buildPads: const []));

      expect(result.issues, contains(contains('at least one build pad')));
    });
  });

  test('rejects non-positive world dimensions and pad radius', () {
    final result = _validate(
      _variant(worldWidth: 0, worldHeight: -1, buildPadRadius: 0),
    );

    expect(result.issues, contains(contains('positive dimensions')));
    expect(
      result.issues,
      contains(contains('buildPadRadius must be positive')),
    );
  });
}
