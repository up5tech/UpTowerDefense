/// Route paths for the application shell.
///
/// Declared apart from the router so screens can navigate without importing the
/// router that builds them.
abstract final class AppRoutes {
  /// Main menu, also the root of the navigation stack.
  static const String mainMenu = '/';

  /// Gameplay for the campaign's next unfinished level.
  static const String gameplay = '/play';

  /// Campaign level picker.
  static const String levelSelect = '/levels';

  /// The endless challenge: a run that composes waves forever.
  static const String endless = '/endless';

  /// Codex: what every tower and enemy does.
  static const String codex = '/codex';

  /// Local preferences.
  static const String settings = '/settings';

  /// Credits and licence information.
  static const String credits = '/credits';

  /// Gameplay for one campaign level.
  ///
  /// Level ids are stable content ids, so a level is addressable by name rather
  /// than by position — a deep link keeps working when the campaign is reordered.
  static String gameplayFor(String levelId) => '$gameplay/$levelId';
}
