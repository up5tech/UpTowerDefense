import 'package:flutter/foundation.dart';

/// The build pad the player currently has selected, identified by pad id.
///
/// Selection is presentation-level state owned by one gameplay screen: it is
/// event-driven (a tap), not per-frame simulation state, so it stays out of the
/// domain layer and out of global providers. It is disposed with the screen.
class MapSelection extends ValueNotifier<String?> {
  MapSelection() : super(null);

  /// Selects [padId], or keeps it selected if it already is.
  void select(String padId) {
    if (value != padId) {
      value = padId;
    }
  }

  /// Clears the selection, for example when the player taps open ground.
  void clear() {
    if (value != null) {
      value = null;
    }
  }
}
