import 'dart:ui';

import 'package:flame/components.dart';
import 'package:up_tower_defense/features/gameplay/application/map_selection.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';

/// Draws the towers built on the map and the range of the selected one.
///
/// Towers are read from the session every frame, like enemies: the session owns
/// occupancy, so the renderer can never show a tower the simulation does not have
/// (ADR 0001). Drawing them in one component keeps per-tower widget bookkeeping
/// out of the hot path for the small counts a level has.
///
/// A tower's *identity* is its art: one sprite per definition id under
/// `assets/images/`, loaded once when the layer mounts. The pad base, the
/// selection ring and the level pips stay vector because they report state —
/// occupancy, selection, level — which changes while the art does not.
class TowerLayer extends PositionComponent {
  TowerLayer({required this.session, required this.selection})
    : super(anchor: Anchor.topLeft);

  final LevelSession session;
  final MapSelection selection;

  /// Body radius in world units; comfortably inside a 34-unit pad.
  static const double bodyRadius = 22;

  /// Drawn size of a tower sprite in world units.
  ///
  /// The sprites are cropped to their art and squared at copy time, so this is
  /// the art's largest extent: a tower overhangs its 58-unit base ring by a
  /// hair, which is what makes it read as standing *on* the pad.
  static const double spriteSide = 55;

  /// Sprite per tower definition id, loaded once in [onLoad].
  final Map<String, Sprite> _sprites = {};

  static final Paint _rangeFill = Paint()..color = const Color(0x1A8BF0D6);

  static final Paint _rangeStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..color = const Color(0x668BF0D6);

  static final Paint _baseFill = Paint()..color = const Color(0xFF10231C);

  static final Paint _baseRing = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..color = const Color(0xFF3E7052);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // One load per definition, before the first frame: a tower whose art is
    // missing fails the mount loudly instead of drawing nothing in silence.
    for (final definition in session.towerCatalog.all) {
      _sprites[definition.id] = await Sprite.load(
        'tower_${definition.id}.png',
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final selectedPadId = selection.value;

    // Ranges first, so a highlighted range never hides another tower's body.
    for (final tower in session.towers) {
      if (tower.padId != selectedPadId) {
        continue;
      }
      final pad = session.map.padById(tower.padId);
      if (pad == null) {
        continue;
      }
      final centre = Offset(pad.position.x, pad.position.y);
      // The current level's range, not the definition's base range: an upgraded
      // tower really does reach further, and the circle must not lie about it.
      final range = tower.stats.range;
      canvas
        ..drawCircle(centre, range, _rangeFill)
        ..drawCircle(centre, range, _rangeStroke);
    }

    for (final tower in session.towers) {
      final pad = session.map.padById(tower.padId);
      if (pad == null) {
        continue;
      }

      final centre = Offset(pad.position.x, pad.position.y);
      final isSelected = tower.padId == selectedPadId;

      canvas
        ..drawCircle(centre, bodyRadius + 7, _baseFill)
        ..drawCircle(centre, bodyRadius + 7, _baseRing);

      final sprite = _sprites[tower.definition.id]!;
      canvas.drawImageRect(
        sprite.image,
        sprite.src,
        Rect.fromCenter(center: centre, width: spriteSide, height: spriteSide),
        Paint(),
      );

      // The selection ring hugs the art rather than the collision radius, so
      // it frames what the player is looking at.
      if (isSelected) {
        canvas.drawCircle(
          centre,
          spriteSide / 2 + 2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = const Color(0xFFDDF3EA),
        );
      }

      _renderLevelPips(canvas, centre, tower.level);
    }
  }

  /// One pip per level under the tower, so a maxed-out tower reads at a glance
  /// without opening the panel. Count only — the panel owns the numbers.
  void _renderLevelPips(Canvas canvas, Offset centre, int level) {
    const pipGap = 9.0;
    const pipRadius = 2.5;
    final totalWidth = (level - 1) * pipGap;
    final startX = centre.dx - totalWidth / 2;
    final y = centre.dy + bodyRadius + 12;
    final pipPaint = Paint()..color = const Color(0xFFDDF3EA);

    for (var i = 0; i < level; i++) {
      canvas.drawCircle(Offset(startX + i * pipGap, y), pipRadius, pipPaint);
    }
  }
}
