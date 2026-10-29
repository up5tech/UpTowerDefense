import 'dart:ui';

import 'package:flame/components.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';

/// Draws the shots currently in flight.
///
/// Like the other layers it reads the session instead of keeping its own
/// mirrored state, so a bullet is only ever drawn where the simulation says it
/// is (ADR 0001). The ball sprite is shared by every tower and tinted with the
/// shot's own colour: one asset, and the colour still says who fired it.
class ProjectileLayer extends PositionComponent {
  ProjectileLayer({required this.session}) : super(anchor: Anchor.topLeft);

  final LevelSession session;

  /// Visual radius in world units; the domain has no notion of it because a
  /// shot's collision uses the target's body radius instead.
  static const double radius = 5;

  /// Drawn size in world units; slightly larger than the bare collision circle
  /// so a shot reads at speed.
  static const double spriteSide = 2 * radius * 1.3;

  late final Sprite _sprite;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _sprite = await Sprite.load('projectile.png');
  }

  @override
  void render(Canvas canvas) {
    for (final projectile in session.projectiles) {
      final center = Offset(projectile.position.x, projectile.position.y);
      // Modulate tints the white ball with the firing tower's colour while
      // keeping the sprite's own shading.
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(
          Color(projectile.colorValue),
          BlendMode.modulate,
        );
      canvas.drawImageRect(
        _sprite.image,
        _sprite.src,
        Rect.fromCenter(center: center, width: spriteSide, height: spriteSide),
        paint,
      );
    }
  }
}
