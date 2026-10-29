import 'package:up_tower_defense/features/gameplay/domain/level_event.dart';

/// The vibration patterns a gameplay fact may request.
///
/// This stays independent of Flutter so event selection can be tested without
/// a device or platform channel.
enum HapticPattern {
  /// A light acknowledgement for a player build or upgrade.
  light,

  /// A stronger warning when an enemy damages the core.
  heavy,
}

/// Device feedback target for important gameplay facts.
abstract interface class HapticsSink {
  /// Requests [pattern] without delaying the simulation frame.
  void vibrate(HapticPattern pattern);
}

/// Maps published level facts to haptics when the player's setting allows it.
///
/// Frequent combat events are intentionally silent; only player construction
/// and core damage request feedback, and duplicate facts of a kind coalesce
/// within a frame.
class HapticsLayer {
  HapticsLayer({required this.enabled, this.sink});

  /// Whether this attempt may request haptics.
  final bool enabled;

  /// The platform adapter; null means silent (tests or unsupported hosts).
  final HapticsSink? sink;

  /// A deliberate mapping: avoid buzzing for every projectile or impact.
  static const Map<LevelEventKind, HapticPattern> patterns = {
    LevelEventKind.built: HapticPattern.light,
    LevelEventKind.upgraded: HapticPattern.light,
    LevelEventKind.leaked: HapticPattern.heavy,
  };

  /// Sends at most one haptic per mapped fact kind in this frame's batch.
  void handle(List<LevelEvent> events) {
    if (!enabled) {
      return;
    }
    final sink = this.sink;
    if (sink == null) {
      return;
    }
    final played = <LevelEventKind>{};
    for (final event in events) {
      final pattern = patterns[event.kind];
      if (pattern == null || !played.add(event.kind)) {
        continue;
      }
      sink.vibrate(pattern);
    }
  }
}
