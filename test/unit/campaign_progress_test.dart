import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/campaign/domain/level_rating.dart';

import '../helpers/content_fixtures.dart';

/// Result for [levelId] with [stars], using a core that matches the stars.
LevelResult _result(
  String levelId, {
  int stars = 3,
  int coreHealth = 5,
  int maxCoreHealth = 5,
}) {
  return LevelResult(
    levelId: levelId,
    stars: stars,
    coreHealth: coreHealth,
    maxCoreHealth: maxCoreHealth,
    wavesCleared: 2,
    totalWaves: 2,
  );
}

void main() {
  group('rating', () {
    test('a defeat earns nothing however healthy the core is', () {
      expect(
        LevelRating.starsFor(
          victorious: false,
          coreHealth: 5,
          maxCoreHealth: 5,
        ),
        0,
      );
    });

    test('an untouched core is three stars', () {
      expect(
        LevelRating.starsFor(
          victorious: true,
          coreHealth: 20,
          maxCoreHealth: 20,
        ),
        3,
      );
    });

    test('half the core or more is two stars, less is one', () {
      expect(
        LevelRating.starsFor(
          victorious: true,
          coreHealth: 10,
          maxCoreHealth: 20,
        ),
        2,
      );
      expect(
        LevelRating.starsFor(
          victorious: true,
          coreHealth: 9,
          maxCoreHealth: 20,
        ),
        1,
      );
    });

    test('the rule list describes every star level', () {
      expect(LevelRating.rules, hasLength(LevelRating.maxStars));
    });
  });

  group('unlocking', () {
    test('only the first level is open on a fresh campaign', () {
      const progress = CampaignProgress.empty();

      expect(progress.isUnlocked(testCampaign, 'test_level'), isTrue);
      expect(progress.isUnlocked(testCampaign, 'test_level_2'), isFalse);
      expect(progress.isUnlocked(testCampaign, 'test_level_3'), isFalse);
      expect(progress.isUnlocked(testCampaign, 'test_level_4'), isFalse);
    });

    test('completing a level opens exactly the next one', () {
      final progress = const CampaignProgress.empty().record(
        _result('test_level'),
      );

      expect(progress.isUnlocked(testCampaign, 'test_level_2'), isTrue);
      expect(progress.isUnlocked(testCampaign, 'test_level_3'), isFalse);
    });

    test('the chain crosses a region boundary', () {
      final progress = const CampaignProgress.empty()
          .record(_result('test_level'))
          .record(_result('test_level_2'));

      // The first level of region two opens from the last level of region one:
      // the unlock rule runs along the flattened campaign order.
      expect(progress.isUnlocked(testCampaign, 'test_level_3'), isTrue);
      expect(progress.isUnlocked(testCampaign, 'test_level_4'), isFalse);
    });

    test('a level outside the campaign is never unlocked', () {
      const progress = CampaignProgress.empty();
      expect(progress.isUnlocked(testCampaign, 'not_a_level'), isFalse);
    });
  });

  group('resume', () {
    test('a fresh campaign resumes at the first level', () {
      expect(
        const CampaignProgress.empty().resumeLevelId(testCampaign),
        'test_level',
      );
    });

    test('resume follows the first unfinished level', () {
      final progress = const CampaignProgress.empty()
          .record(_result('test_level'))
          .record(_result('test_level_2'));

      expect(progress.resumeLevelId(testCampaign), 'test_level_3');
    });

    test('a finished campaign resumes at its finale', () {
      var progress = const CampaignProgress.empty();
      for (final levelId in testCampaign.levelIds) {
        progress = progress.record(_result(levelId));
      }

      expect(progress.resumeLevelId(testCampaign), 'test_level_4');
    });
  });

  group('best result', () {
    test('a worse replay never replaces a better result', () {
      final three = const CampaignProgress.empty().record(
        _result('test_level'),
      );
      final one = three.record(_result('test_level', stars: 1, coreHealth: 1));

      expect(one.starsFor('test_level'), 3);
      expect(identical(one, three), isTrue);
    });

    test('a better replay replaces the result', () {
      final one = const CampaignProgress.empty().record(
        _result('test_level', stars: 1, coreHealth: 1),
      );
      final three = one.record(_result('test_level'));

      expect(three.starsFor('test_level'), 3);
      expect(three.resultFor('test_level')!.coreHealth, 5);
    });

    test('equal stars keep the healthier run', () {
      final healthier = const CampaignProgress.empty().record(
        _result('test_level', stars: 2, coreHealth: 4),
      );
      final weaker = healthier.record(
        _result('test_level', stars: 2, coreHealth: 3),
      );

      expect(weaker.resultFor('test_level')!.coreHealth, 4);
      expect(identical(weaker, healthier), isTrue);
    });

    test('total stars add up across the campaign', () {
      final progress = const CampaignProgress.empty()
          .record(_result('test_level'))
          .record(_result('test_level_2', stars: 2, coreHealth: 3));

      expect(progress.totalStars(testCampaign.levelIds), 5);
    });
  });
}
