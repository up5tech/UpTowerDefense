import 'package:flutter/services.dart';
import 'package:up_tower_defense/features/gameplay/flame/haptics_layer.dart';

/// Production [HapticsSink] using Flutter's built-in platform feedback API.
class FlutterHapticsSink implements HapticsSink {
  const FlutterHapticsSink();

  @override
  void vibrate(HapticPattern pattern) {
    // Feedback is cosmetic and must never interrupt a simulation frame.
    final feedback = switch (pattern) {
      HapticPattern.light => HapticFeedback.selectionClick(),
      HapticPattern.heavy => HapticFeedback.heavyImpact(),
    };
    feedback.ignore();
  }
}
