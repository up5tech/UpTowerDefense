import 'dart:typed_data';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/text.dart';
import 'package:up_tower_defense/features/gameplay/application/map_selection.dart';
import 'package:up_tower_defense/features/gameplay/domain/map_geometry.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

/// Renders one map and turns taps into map selections.
///
/// The component owns no gameplay rules: hit testing comes from [MapGeometry],
/// and the selection it reports is a plain pad id. Tower placement, costs and
/// waves are added by later phases on top of this.
///
/// The ground and the road are real art — two CC0 tiles under `assets/images/`,
/// repeated as shaders so they stay locked to world units. Pads, the core and
/// the labels stay vector on purpose: they carry state (selection, health) and
/// positions the geometry owns, and a sprite would have to be re-cut for every
/// map instead of being measured from the definition.
class MapComponent extends PositionComponent with TapCallbacks {
  MapComponent({required this.map, required this.selection})
    : geometry = MapGeometry(map),
      super(
        size: Vector2(map.worldWidth, map.worldHeight),
        anchor: Anchor.topLeft,
      );

  /// The pack ships a bright field; the game lives in a dark one — the
  /// texture survives, the palette does not bend.
  static const Color _groundWash = Color(0xC412241C);
  static const Color _gridLine = Color(0xFF172E22);
  static const Color _routeEdge = Color(0xFF20392C);
  static const Color _padFill = Color(0xFF1B2C24);
  static const Color _padStroke = Color(0xFF37C2A0);
  static const Color _padSelectedFill = Color(0x5537C2A0);
  static const Color _padSelectedStroke = Color(0xFF8BF0D6);
  static const Color _coreFill = Color(0xFF1E3A2E);
  static const Color _coreRing = Color(0xFFE0A34A);

  /// Grid spacing in world units; purely visual scale reference.
  static const double _gridSpacing = 80;

  /// Visual radius of the core, independent of its gameplay health.
  static const double coreRadius = 40;

  final MapDefinition map;
  final MapSelection selection;
  final MapGeometry geometry;

  /// The two field tiles, loaded once before the first frame; a missing file
  /// fails the mount loudly instead of rendering a flat colour in silence.
  late final Image _groundTile;
  late final Image _routeTile;

  late final Paint _groundPaint;
  late final Paint _roadPaint;

  /// Identity for the tile shaders, column-major: world units map to image
  /// pixels one to one, so a 64-unit tile stays a 64-unit tile anywhere on the
  /// map.
  static final Float64List _tileMatrix = Float64List.fromList(<double>[
    1, 0, 0, 0, //
    0, 1, 0, 0, //
    0, 0, 1, 0, //
    0, 0, 0, 1,
  ]);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _groundTile = (await Sprite.load('map_grass.png')).image;
    _routeTile = (await Sprite.load('map_dirt.png')).image;
    _groundPaint = Paint()
      ..shader = ImageShader(
        _groundTile,
        TileMode.repeated,
        TileMode.repeated,
        _tileMatrix,
      );
    _roadPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 36
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = ImageShader(
        _routeTile,
        TileMode.repeated,
        TileMode.repeated,
        _tileMatrix,
      );
  }

  late final Path _routePath = Path()
    ..addPolygon(<Offset>[
      for (final point in map.route) Offset(point.x, point.y),
    ], false);

  late final TextPaint _padLabel = TextPaint(
    style: const TextStyle(
      color: Color(0xFFDDF3EA),
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  );

  late final TextPaint _padLabelSelected = TextPaint(
    style: const TextStyle(
      color: Color(0xFF06231B),
      fontSize: 20,
      fontWeight: FontWeight.w700,
    ),
  );

  /// Taps anywhere in the viewport reach this component, including the
  /// letterbox bars of an off-ratio screen; taps that miss every pad clear the
  /// selection.
  @override
  bool containsLocalPoint(Vector2 point) => true;

  @override
  void onTapDown(TapDownEvent event) {
    final tapped = WorldPoint(event.localPosition.x, event.localPosition.y);
    final pad = geometry.padAt(tapped);
    if (pad == null) {
      selection.clear();
      return;
    }
    selection.select(pad.id);
  }

  @override
  void render(Canvas canvas) {
    _renderGround(canvas);
    _renderRoute(canvas);
    _renderCore(canvas);
    _renderPads(canvas);
  }

  void _renderGround(Canvas canvas) {
    canvas
      ..drawRect(size.toRect(), _groundPaint)
      // The wash, not a tint on the shader: plain alpha keeps the tile's own
      // shading visible while pulling its hue back into the game's palette.
      ..drawRect(size.toRect(), Paint()..color = _groundWash);

    final gridPaint = Paint()
      ..color = _gridLine
      ..strokeWidth = 1;
    for (var x = _gridSpacing; x < size.x; x += _gridSpacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.y), gridPaint);
    }
    for (var y = _gridSpacing; y < size.y; y += _gridSpacing) {
      canvas.drawLine(Offset(0, y), Offset(size.x, y), gridPaint);
    }
  }

  void _renderRoute(Canvas canvas) {
    // The dark rim first: it separates the road from the field on any map
    // palette and keeps the route's exact silhouette readable.
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 46
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = _routeEdge;
    canvas
      ..drawPath(_routePath, edge)
      ..drawPath(_routePath, _roadPaint);
  }

  void _renderCore(Canvas canvas) {
    final centre = Offset(map.core.x, map.core.y);

    canvas.drawCircle(
      centre,
      coreRadius + 18,
      Paint()..color = const Color(0x22E0A34A),
    );
    canvas.drawCircle(centre, coreRadius, Paint()..color = _coreFill);
    canvas.drawCircle(
      centre,
      coreRadius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = _coreRing,
    );
    canvas.drawCircle(centre, coreRadius * 0.42, Paint()..color = _coreRing);
  }

  void _renderPads(Canvas canvas) {
    final selectedId = selection.value;
    final radius = map.buildPadRadius;

    for (final pad in map.buildPads) {
      final centre = Offset(pad.position.x, pad.position.y);
      final isSelected = pad.id == selectedId;

      if (isSelected) {
        canvas
          ..drawCircle(
            centre,
            radius + 10,
            Paint()..color = const Color(0x2E8BF0D6),
          )
          ..drawCircle(
            centre,
            radius + 10,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = _padSelectedStroke,
          );
      }

      canvas
        ..drawCircle(
          centre,
          radius,
          Paint()..color = isSelected ? _padSelectedFill : _padFill,
        )
        ..drawCircle(
          centre,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = isSelected ? 4 : 3
            ..color = isSelected ? _padSelectedStroke : _padStroke,
        );

      (isSelected ? _padLabelSelected : _padLabel).render(
        canvas,
        pad.label,
        Vector2(pad.position.x, pad.position.y),
        anchor: Anchor.center,
      );
    }
  }
}
