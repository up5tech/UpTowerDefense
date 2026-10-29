import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';

/// Draws the enemies of the running session.
///
/// Enemies are read from the session every frame instead of being mirrored into
/// components, so there is exactly one source of truth for their position and
/// health. Enemies are few (tens), so a single component rendering them is
/// cheaper than one component per enemy with lifecycle bookkeeping.
///
/// Identity comes from art: one sprite per enemy definition id under
/// `assets/images/`, sized from the definition's own radius and rotated to
/// face along the route. The health bar, the slow mark and their positions
/// stay vector — they report state that changes frame by frame.
class EnemyLayer extends PositionComponent {
  EnemyLayer({required this.session}) : super(anchor: Anchor.topLeft);

  final LevelSession session;

  /// How much larger than its collision body the art is drawn, so an enemy
  /// reads at a glance without changing the body the simulation fights with.
  static const double spriteScale = 1.15;

  /// Sprite per enemy definition id, loaded once in [onLoad].
  final Map<String, Sprite> _sprites = {};

  static const double _barWidth = 30;
  static const double _barHeight = 4.5;
  static const double _barGap = 12;
  static const Radius _barRadius = Radius.circular(_barHeight / 2);

  static final Paint _barBackground = Paint()..color = const Color(0xFF0B0F14);
  static final Paint _barFill = Paint()..color = const Color(0xFFE05C4A);

  static final Paint _slowMark = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xCC9ED8FF);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // One load per definition, before the first frame: an enemy whose art is
    // missing fails the mount loudly instead of drawing nothing in silence.
    for (final definition in session.enemyCatalog.all) {
      _sprites[definition.id] = await Sprite.load(
        'enemy_${definition.id}.png',
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final geometry = session.geometry;

    for (final enemy in session.enemies) {
      final point = geometry.pointAtDistance(enemy.distanceAlongRoute);
      final center = Offset(point.x, point.y);
      final radius = enemy.definition.radius;
      final side = 2 * radius * spriteScale;
      final sprite = _sprites[enemy.definition.id]!;

      // Rotated around its own centre: the art faces up, the heading points
      // down-route, so the difference is the turn.
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(_heading(enemy.distanceAlongRoute))
        ..drawImageRect(
          sprite.image,
          sprite.src,
          Rect.fromCenter(center: Offset.zero, width: side, height: side),
          Paint(),
        )
        ..restore();

      if (enemy.isSlowed) {
        _renderSlowMark(canvas, center, radius);
      }

      final healthRatio = (enemy.health / enemy.definition.maxHealth).clamp(
        0.0,
        1.0,
      );
      final barLeft = center.dx - _barWidth / 2;
      final barTop = center.dy - radius - _barGap;

      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(barLeft, barTop, _barWidth, _barHeight),
            _barRadius,
          ),
          _barBackground,
        )
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              barLeft,
              barTop,
              _barWidth * healthRatio,
              _barHeight,
            ),
            _barRadius,
          ),
          _barFill,
        );
    }
  }

  /// Rotation from the route heading, in radians.
  ///
  /// Sampled a few units ahead on the same polyline the enemies walk, so the
  /// facing is the rule's geometry rather than a guess — and an enemy at the
  /// core, with nowhere left to look, keeps the neutral orientation.
  double _heading(double distanceAlongRoute) {
    const lookAhead = 4.0;
    final from = session.geometry.pointAtDistance(distanceAlongRoute);
    final to = session.geometry.pointAtDistance(distanceAlongRoute + lookAhead);
    final dx = to.x - from.x;
    final dy = to.y - from.y;
    if (dx == 0 && dy == 0) {
      return 0;
    }
    return math.atan2(dy, dx) + math.pi / 2;
  }

  /// Marks a slowed enemy with a frost ring plus three ticks.
  ///
  /// A tint alone would convey the status by colour only, which the design
  /// rules forbid; the ring and ticks read as "chilled" in a screenshot and for
  /// a colour-blind player. Drawn inside the health bar's gap so neither
  /// overlaps.
  void _renderSlowMark(Canvas canvas, Offset center, double radius) {
    final ring = radius + 3;
    canvas.drawCircle(center, ring, _slowMark);

    for (var i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + i * 2 * math.pi / 3;
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      canvas.drawLine(
        center + Offset(dx * (ring - 3), dy * (ring - 3)),
        center + Offset(dx * (ring + 3), dy * (ring + 3)),
        _slowMark,
      );
    }
  }
}
