import 'package:up_tower_defense/features/gameplay/data/json_reader.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/build_pad.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

/// Decodes authored map JSON into a [MapDefinition].
///
/// This performs structural checks only (types, required fields, numbers);
/// gameplay rules such as route clearance live in `MapValidator` so both stay
/// separately testable.
abstract final class MapJsonDecoder {
  static MapDefinition decode(String source) {
    final root = JsonReader.decodeObject(source);
    final world = JsonReader.requirePoint(root['world'], 'world');

    return MapDefinition(
      id: JsonReader.requireString(root, 'id'),
      displayName: JsonReader.requireString(root, 'displayName'),
      worldWidth: world[0],
      worldHeight: world[1],
      buildPadRadius: JsonReader.requireNumber(root, 'buildPadRadius'),
      route: _decodeRoute(root['route']),
      core: JsonReader.requireWorldPoint(root['core'], 'core'),
      buildPads: _decodeBuildPads(root['buildPads']),
    );
  }

  static List<WorldPoint> _decodeRoute(Object? value) {
    final route = JsonReader.requireList(value, 'route');
    return [
      for (var index = 0; index < route.length; index++)
        JsonReader.requireWorldPoint(route[index], 'route[$index]'),
    ];
  }

  static List<BuildPad> _decodeBuildPads(Object? value) {
    final pads = JsonReader.requireList(value, 'buildPads');
    return [
      for (var index = 0; index < pads.length; index++)
        _decodeBuildPad(pads[index], index),
    ];
  }

  static BuildPad _decodeBuildPad(Object? value, int index) {
    final path = 'buildPads[$index]';
    final json = JsonReader.requireObject(value, path);

    return BuildPad(
      id: JsonReader.requireString(json, 'id', parent: path),
      label: JsonReader.requireString(json, 'label', parent: path),
      position: JsonReader.requireWorldPoint(json['center'], '$path.center'),
    );
  }
}
