import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/world_point.dart';

/// What happened in the level this frame, published by `LevelSession`.
///
/// The session owns the fact that a shot was fired, an enemy leaked or a pad
/// changed hands; the Flame layer consumes these events to draw effects and the
/// audio layer will consume them to play cues. This direction keeps rendering
/// free of gameplay rules while still letting feedback respond to real
/// simulation outcomes (ADR 0001).
enum LevelEventKind {
  /// A tower fired a shot.
  shot,

  /// A shot landed; `radius` carries its blast size when it splashes.
  hit,

  /// An enemy was defeated.
  defeated,

  /// An enemy reached the core, paying its leak damage.
  leaked,

  /// A tower was built on a pad.
  built,

  /// A tower on a pad gained a level.
  upgraded,
}

/// One level fact, positioned in world units.
///
/// [radius] carries the size of the fact when it has one — the blast radius of
/// a splash hit — so the renderer can draw the rule that was applied instead of
/// guessing at it. Every other event leaves it at zero.
@immutable
class LevelEvent {
  const LevelEvent(this.kind, this.position, {this.radius = 0});

  final LevelEventKind kind;
  final WorldPoint position;

  /// Blast radius in world units; zero when the event covers a single point.
  final double radius;

  @override
  String toString() =>
      'LevelEvent(${kind.name} @ $position${radius > 0 ? ', r $radius' : ''})';
}
