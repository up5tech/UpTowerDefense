import 'package:up_tower_defense/features/gameplay/domain/objective_status.dart';

/// The campaign's star rating for one finished attempt (D68, superseding D35).
///
/// A campaign level declares two goals, so a victory is worth `1 + met` stars:
/// three for both goals, two for one, one for finishing at all, and zero for a
/// defeat. A level with no goals (the endless run, the synthetic profiling map
/// and every test fixture) keeps the 1.0 core-health ladder, which is the only
/// rating those levels have ever shown.
abstract final class LevelRating {
  /// Highest rating a level can earn.
  static const int maxStars = 3;

  /// Stars for a finished attempt.
  ///
  /// [objectivesMet] is the number of goals the run satisfied, or null when the
  /// level declares none — the one signal that separates "one goal met" from
  /// "this level has no goals", so the two ladders cannot be confused.
  ///
  /// A defeat always rates zero however much health the core still has, because
  /// the attempt did not finish the job; stars are stored, never recomputed on
  /// load, so a 1.0 three-star run keeps its three stars.
  static int starsFor({
    required bool victorious,
    required int coreHealth,
    required int maxCoreHealth,
    int? objectivesMet,
  }) {
    if (!victorious) {
      return 0;
    }
    final met = objectivesMet;
    if (met != null) {
      // Clamped rather than trusted: goals are authored in pairs, and a bad
      // count must still produce a star value the save format can store.
      return (1 + met).clamp(1, maxStars);
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

  /// Stars for a run, judged from its goal statuses.
  ///
  /// The one entry point the HUD, the result panel and the recorder all call,
  /// so the number on screen is the number that is saved. A level with no goals
  /// falls back to [rules] — the 1.0 core-health ladder — because there is no
  /// `1 + met` to compute on the endless run or a fixture.
  static int starsForRun({
    required bool victorious,
    required int coreHealth,
    required int maxCoreHealth,
    required List<LevelObjectiveStatus> objectives,
  }) {
    return starsFor(
      victorious: victorious,
      coreHealth: coreHealth,
      maxCoreHealth: maxCoreHealth,
      objectivesMet: objectives.isEmpty
          ? null
          : LevelObjectives.metCount(objectives),
    );
  }

  /// The goal-based rule as one player-facing line.
  ///
  /// Kept beside the rule itself so the explanation cannot drift from the maths;
  /// the level picker and the result panel both read it.
  static const String objectiveRule =
      'Finish for 1 star, plus 1 for each goal you meet';

  /// The core-health ladder, used only by levels that declare no goals.
  ///
  /// Retained from 1.0 because the endless run and the fixtures still rate by
  /// it; campaign levels never read these lines any more.
  static const List<String> rules = [
    'Finish the level',
    'Finish with at least half the core intact',
    'Finish without losing a single core point',
  ];
}
