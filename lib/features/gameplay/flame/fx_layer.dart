import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

/// The level's transient feedback: shot, impact, death, leak, build and
/// upgrade cues.
///
/// Pure presentation: the facts come from the simulation as [LevelEvent]s the
/// session published this frame, and this layer only decides how long they
/// linger and how they look. Nothing here can change gameplay, which is what
/// lets effects stay a cosmetic layer (ADR 0001).
///
/// Two constraints shape every drawing rule. Effects must never hide what they
/// describe: each cue is a thin translucent stroke, and [maxLiveEffects] bounds
/// how many can be alive at once so a burst of kills cannot paint the field
/// opaque. And [reducedMotion] must keep every cue readable without movement:
/// geometry freezes at the cue's first frame and only the fade animates.
class FxLayer extends PositionComponent {
  FxLayer({this.reducedMotion = false}) : super(anchor: Anchor.topLeft);

  /// Whether effects may animate their geometry.
  ///
  /// Mirrors the accessibility setting: when set, a cue holds its first frame's
  /// size and position and only fades out, so the information survives while
  /// the motion does not.
  bool reducedMotion;

  /// Most cues one frame may hold alive.
  ///
  /// Effects are short-lived, so this only bites when many enemies die
  /// together — exactly when an unbounded stack would blanket the enemies it
  /// describes. The oldest are dropped first: the cue the player just caused
  /// is the one worth keeping.
  static const int maxLiveEffects = 64;

  /// How long each cue lingers, in seconds of simulation time.
  static const Map<LevelEventKind, double> _durations = {
    LevelEventKind.shot: 0.12,
    LevelEventKind.hit: 0.18,
    LevelEventKind.defeated: 0.3,
    LevelEventKind.leaked: 0.45,
    LevelEventKind.built: 0.35,
    LevelEventKind.upgraded: 0.4,
  };

  final List<_Fx> _effects = [];

  /// Number of live effects, exposed for tests.
  int get activeCount => _effects.length;

  /// Live effects as read-only drawing state, for tests.
  List<FxView> get effects => List<FxView>.unmodifiable(
    _effects.map((effect) => effect.view(reducedMotion: reducedMotion)),
  );

  /// Drops every live effect.
  ///
  /// Used when the attempt restarts: an effect belongs to the run that produced
  /// it, so a hit flash must not outlive the enemies it described.
  void clear() => _effects.clear();

  /// Starts the effects for [events]; called once per frame after the
  /// simulation advanced and drained its event queue.
  void publish(List<LevelEvent> events) {
    for (final event in events) {
      final duration = _durations[event.kind]!;
      _effects.add(
        _Fx(
          kind: event.kind,
          position: event.position,
          radius: event.radius,
          remaining: duration,
          duration: duration,
        ),
      );
    }
    if (_effects.length > maxLiveEffects) {
      _effects.removeRange(0, _effects.length - maxLiveEffects);
    }
  }

  @override
  void update(double dt) {
    for (final effect in _effects) {
      effect.remaining -= dt;
    }
    _effects.removeWhere((effect) => effect.remaining <= 0);
  }

  @override
  void render(Canvas canvas) {
    for (final effect in _effects) {
      final view = effect.view(reducedMotion: reducedMotion);
      final center = view.center;

      switch (view.kind) {
        case LevelEventKind.shot:
          canvas.drawCircle(center, view.radius, _paint(_shot, view.alpha));

        case LevelEventKind.hit:
          canvas.drawCircle(center, view.radius, _paint(_hit, view.alpha));
          // A splash hit draws its real blast boundary: the ring is the radius
          // the damage rule used, so the player can see which enemies the
          // shell actually caught.
          if (view.blastRadius > 0) {
            canvas.drawCircle(
              center,
              view.blastRadius,
              _paint(_hit, 0.55 * view.alpha)..strokeWidth = 2.5,
            );
          }

        case LevelEventKind.defeated:
          canvas.drawCircle(
            center,
            view.radius,
            _paint(_defeated, view.alpha)..strokeWidth = 3,
          );
          canvas.drawCircle(
            center,
            6 * view.progress,
            Paint()..color = _defeated.withValues(alpha: 0.5 * view.alpha),
          );

        case LevelEventKind.leaked:
          // A double ring plus four radial ticks: a different silhouette from
          // the death ring, so "the core was hit" reads at a glance and in
          // greyscale rather than only by its colour.
          canvas
            ..drawCircle(center, view.radius, _paint(_leaked, view.alpha))
            ..drawCircle(
              center,
              view.radius - 6,
              _paint(_leaked, 0.7 * view.alpha)..strokeWidth = 1.5,
            );
          for (var i = 0; i < 4; i++) {
            final angle = i * math.pi / 2;
            final dx = math.cos(angle);
            final dy = math.sin(angle);
            canvas.drawLine(
              center + Offset(dx * (view.radius - 2), dy * (view.radius - 2)),
              center + Offset(dx * (view.radius + 6), dy * (view.radius + 6)),
              _paint(_leaked, view.alpha),
            );
          }

        case LevelEventKind.built:
          // A placement reticle closing in on the tower it just placed: ring
          // plus corner brackets, so "something was built here" needs no text.
          canvas.drawCircle(center, view.radius, _paint(_built, view.alpha));
          for (var i = 0; i < 4; i++) {
            final angle = math.pi / 4 + i * math.pi / 2;
            final dx = math.cos(angle);
            final dy = math.sin(angle);
            canvas.drawLine(
              center + Offset(dx * (view.radius - 4), dy * (view.radius - 4)),
              center + Offset(dx * (view.radius + 4), dy * (view.radius + 4)),
              _paint(_built, view.alpha),
            );
          }

        case LevelEventKind.upgraded:
          // A ring plus rising chevrons: "up" is the shape, so the cue survives
          // greyscale and colour-blindness alike.
          canvas.drawCircle(center, view.radius, _paint(_upgraded, view.alpha));
          for (var i = 0; i < 2; i++) {
            final y = center.dy - view.radius - 4 - view.rise - i * 7;
            final paint = _paint(_upgraded, view.alpha)..strokeWidth = 2;
            canvas
              ..drawLine(
                Offset(center.dx - 7, y + 5),
                Offset(center.dx, y),
                paint,
              )
              ..drawLine(
                Offset(center.dx, y),
                Offset(center.dx + 7, y + 5),
                paint,
              );
          }
      }
    }
  }

  static Paint _paint(Color color, double alpha) {
    return Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color.withValues(alpha: alpha.clamp(0.0, 1.0));
  }
}

const Color _shot = Color(0xFF8BF0D6);
const Color _hit = Color(0xFFFFB86B);
const Color _defeated = Color(0xFFFFFFFF);
const Color _leaked = Color(0xFFE05C4A);
const Color _built = Color(0xFF9BE8C6);
const Color _upgraded = Color(0xFFF0D68B);

/// One live effect's drawing state.
///
/// Exposed so tests can assert the rules every cue obeys — geometry that grows
/// or closes, geometry that freezes under reduced motion, and a fade either
/// way — without needing a canvas to look at.
@immutable
class FxView {
  const FxView({
    required this.kind,
    required this.center,
    required this.radius,
    required this.blastRadius,
    required this.rise,
    required this.alpha,
    required this.progress,
  });

  final LevelEventKind kind;

  /// Cue centre in world units.
  final Offset center;

  /// Radius of the cue's main ring, in world units.
  final double radius;

  /// Splash boundary as drawn; zero for point cues.
  final double blastRadius;

  /// Upward offset the chevrons have risen since birth; zero under reduced
  /// motion, and zero for cues that do not rise.
  final double rise;

  /// Opacity the cue is drawn at, 0..1.
  final double alpha;

  /// 1 at birth, 0 at death; the fade always runs, motion or not.
  final double progress;
}

/// One effect instance and its remaining lifetime.
class _Fx {
  _Fx({
    required this.kind,
    required this.position,
    required this.radius,
    required this.remaining,
    required this.duration,
  });

  final LevelEventKind kind;
  final WorldPoint position;

  /// Blast radius carried by the event; zero for point effects.
  final double radius;

  final double duration;
  double remaining;

  /// The state this effect should be drawn at right now.
  ///
  /// [reducedMotion] freezes geometry at the cue's first frame (progress 1)
  /// while the fade keeps running, so the setting removes motion without
  /// removing information.
  FxView view({required bool reducedMotion}) {
    final progress = (remaining / duration).clamp(0.0, 1.0);
    final frozen = reducedMotion ? 1.0 : progress;
    final grown = 1.0 - frozen;

    final radius = switch (kind) {
      // Shrinking rings: 18 → 8 for a shot, 14 → 6 for an impact.
      LevelEventKind.shot => 18 - 10 * frozen,
      LevelEventKind.hit => 14 - 8 * frozen,
      LevelEventKind.defeated => 32 - 22 * frozen,
      // The core impact expands, so it reads as something that just happened.
      LevelEventKind.leaked => 14 + 26 * grown,
      // The reticle closes from pad size onto the tower it placed.
      LevelEventKind.built => 34 - 10 * grown,
      LevelEventKind.upgraded => 12 + 12 * grown,
    };

    final alpha = switch (kind) {
      LevelEventKind.shot => 0.65 * progress,
      LevelEventKind.hit => 0.8 * progress,
      LevelEventKind.defeated => 0.9 * progress,
      LevelEventKind.leaked => 0.95 * progress,
      LevelEventKind.built => 0.8 * progress,
      LevelEventKind.upgraded => 0.9 * progress,
    };

    return FxView(
      kind: kind,
      center: Offset(position.x, position.y),
      radius: radius,
      blastRadius: radius > 0 && this.radius > 0
          ? this.radius * (1 - 0.25 * grown)
          : 0,
      rise: kind == LevelEventKind.upgraded ? 8 * grown : 0,
      alpha: alpha,
      progress: progress,
    );
  }
}
