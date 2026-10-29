/// Static application identity used by the shell and menus.
///
/// Keep this free of Flutter imports so any layer can read it.
abstract final class AppInfo {
  /// Internal and display name until store naming is finalised in Phase 13.
  static const String name = 'UpTowerDefense';

  /// One-line positioning shown under the title on the main menu.
  static const String tagline = 'Defend the core. Climb the regions.';
}
