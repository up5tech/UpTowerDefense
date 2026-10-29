/// The campaign's star rating for one finished attempt.
///
/// Three stars is "the core was never touched", two is "the core held at least
/// half", one is "you finished", zero is a defeat. The rule is deliberately
/// about one number the player can see at all times — core health — so it can be
/// explained in a single sentence and tested without a level.
abstract final class LevelRating {
  /// Highest rating a level can earn.
  static const int maxStars = 3;

  /// Stars for a finished attempt.
  ///
  /// [coreHealth] is the health left when the level ended; a defeat always rates
  /// zero however much health the core still has, because the attempt did not
  /// finish the job.
  static int starsFor({
    required bool victorious,
    required int coreHealth,
    required int maxCoreHealth,
  }) {
    if (!victorious) {
      return 0;
    }
    if (maxCoreHealth <= 0) {
      return 1;
    }
    if (coreHealth >= maxCoreHealth) {
      return maxStars;
    }
    if (coreHealth * 2 >= maxCoreHealth) {
      return 2;
    }
    return 1;
  }

  /// The rating rule as player-facing lines, in star order.
  ///
  /// Kept beside the rule itself so the explanation cannot drift from the maths;
  /// the level picker and the result panel both read this.
  static const List<String> rules = [
    'Finish the level',
    'Finish with at least half the core intact',
    'Finish without losing a single core point',
  ];
}
