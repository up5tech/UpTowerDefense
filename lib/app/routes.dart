import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';

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

  /// Today's daily challenge (D66): one seeded campaign level, played on
  /// Normal, whose result never touches campaign progress.
  static const String daily = '/daily';

  /// Progress: campaign totals, endless and daily bests, achievements.
  static const String progress = '/progress';

  /// Codex: what every tower and enemy does.
  static const String codex = '/codex';

  /// Local preferences.
  static const String settings = '/settings';

  /// Credits and licence information.
  static const String credits = '/credits';

  /// Gameplay for one campaign level on one difficulty.
  ///
  /// Level ids are stable content ids, so a level is addressable by name rather
  /// than by position — a deep link keeps working when the campaign is reordered.
  /// The difficulty is a path segment, not a query parameter: it is part of the
  /// route's identity, so switching mode remounts the screen and discards the
  /// game it built for the other mode (D65).
  static String gameplayFor(
    String levelId, {
    Difficulty difficulty = Difficulty.normal,
  }) => '$gameplay/$levelId/${difficulty.wireName}';
}
