import 'package:flutter/services.dart';

/// Orientation policy for the shell.
///
/// Gameplay is landscape-only; menus accept portrait and landscape so the app
/// can still be opened comfortably in any device position. The policy is
/// applied per screen rather than in the platform manifests so a future
/// tablet layout can opt out without reconfiguring the native projects.
abstract final class AppOrientation {
  /// Allowed while a level is being played.
  static const List<DeviceOrientation> gameplay = <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// Allowed outside gameplay.
  static const List<DeviceOrientation> menu = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  /// Locks the device to landscape for gameplay.
  static Future<void> lockForGameplay() =>
      SystemChrome.setPreferredOrientations(gameplay);

  /// Restores the menu orientation policy.
  static Future<void> releaseForMenu() =>
      SystemChrome.setPreferredOrientations(menu);
}
