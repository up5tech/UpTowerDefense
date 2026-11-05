import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/domain/level_rating.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_objective.dart';
import 'package:up_tower_defense/features/gameplay/domain/objective_status.dart';

/// The star rule (D68): `1 + met` on a level with goals, the 1.0 core-health
/// ladder on a level without them, zero for a defeat.
LevelObjectiveStatus _status(
  LevelObjective objective,
  LevelObjectiveState state,
) {
  return LevelObjectiveStatus(objective: objective, state: state);
}

void main() {
  group('objectives', () {
    test('a victory is worth one star plus every goal met', () {
      for (var met = 0; met <= 2; met++) {
        expect(
          LevelRating.starsFor(
            victorious: true,
            coreHealth: 1,
            maxCoreHealth: 20,
            objectivesMet: met,
          ),
          met + 1,
          reason: 'core health must not affect a level that has goals',
        );
      }
    });

    test('a defeat is worth zero even with both goals met', () {
      expect(
        LevelRating.starsFor(
          victorious: false,
          coreHealth: 20,
          maxCoreHealth: 20,
          objectivesMet: 2,
        ),
        0,
      );
    });

    test('a bad count cannot exceed the maximum', () {
      expect(
        LevelRating.starsFor(
          victorious: true,
          coreHealth: 20,
          maxCoreHealth: 20,
          objectivesMet: 9,
        ),
        LevelRating.maxStars,
      );
    });

    test('starsForRun reads the same statuses the HUD publishes', () {
      final statuses = [
        _status(const LevelObjective.noLeaks(), LevelObjectiveState.met),
        _status(
          const LevelObjective.maxTowers(2),
          LevelObjectiveState.failed,
        ),
      ];

      expect(
        LevelRating.starsForRun(
          victorious: true,
          coreHealth: 9,
          maxCoreHealth: 20,
          objectives: statuses,
        ),
        2,
      );
    });
  });

  group('levels without goals', () {
    test('keep the core-health ladder', () {
      int stars(int coreHealth) => LevelRating.starsFor(
        victorious: true,
        coreHealth: coreHealth,
        maxCoreHealth: 20,
      );

      expect(stars(20), 3);
      expect(stars(10), 2);
      expect(stars(9), 1);
      expect(
        LevelRating.starsFor(
          victorious: false,
          coreHealth: 20,
          maxCoreHealth: 20,
        ),
        0,
      );
    });

    test('starsForRun falls back to it when the goal list is empty', () {
      expect(
        LevelRating.starsForRun(
          victorious: true,
          coreHealth: 20,
          maxCoreHealth: 20,
          objectives: const [],
        ),
        3,
      );
    });
  });
}
