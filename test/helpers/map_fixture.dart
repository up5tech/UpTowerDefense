import 'package:up_tower_defense/features/gameplay/domain/models/build_pad.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

/// Small, valid map used by widget and unit tests.
///
/// Same geometry as the shipped opening map so coordinate expectations stay
/// readable: a 1280x720 field, route along y=500 with a raised middle section,
/// and pads clear of the route.
const MapDefinition testMap = MapDefinition(
  id: 'test_map',
  displayName: 'Test Meadow',
  worldWidth: 1280,
  worldHeight: 720,
  buildPadRadius: 34,
  route: [
    WorldPoint(0, 500),
    WorldPoint(300, 500),
    WorldPoint(300, 260),
    WorldPoint(700, 260),
    WorldPoint(700, 500),
    WorldPoint(1150, 500),
  ],
  core: WorldPoint(1150, 500),
  buildPads: [
    BuildPad(id: 'pad_a', label: 'A', position: WorldPoint(180, 360)),
    BuildPad(id: 'pad_b', label: 'B', position: WorldPoint(860, 380)),
  ],
);
