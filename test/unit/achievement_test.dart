import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/domain/achievement.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/gameplay/domain/daily_challenge.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';

import '../helpers/content_fixtures.dart';

/// The ten achievements, derived only from facts the save stores (D67).
///
/// Every case names the fact and asserts both directions where it matters: a
/// one-star run must not count as untouched, and a Hard-only result must not
/// satisfy a campaign achievement that claims to read Normal.
LevelResult _result(
  String levelId, {
  int stars = 3,
  int coreHealth = 10,
  int maxCoreHealth = 10,
  Difficulty difficulty = Difficulty.normal,
}) {
  return LevelResult(
    levelId: levelId,
    stars: stars,
    coreHealth: coreHealth,
    maxCoreHealth: maxCoreHealth,
    wavesCleared: 2,
    totalWaves: 2,
    difficulty: difficulty,
    objectivesMet: stars == 0 ? 0 : stars - 1,
  );
}

CampaignProgress _progress(List<LevelResult> results) =>
    results.fold<CampaignProgress>(
      const CampaignProgress.empty(),
      (progress, result) => progress.record(result),
    );

DailyResult _daily({int stars = 2, int dateKey = 20261104}) {
  return DailyResult(
    dateKey: dateKey,
    levelId: 'test_level',
    stars: stars,
    coreHealth: 5,
    maxCoreHealth: 5,
    objectivesMet: stars == 0 ? 0 : stars - 1,
  );
}

Set<Achievement> _earned({
  CampaignProgress? progress,
  int endlessBest = 0,
  Map<int, DailyResult> dailies = const {},
  CampaignDefinition? campaign,
}) {
  return AchievementEvaluator.evaluate(
    campaign: campaign ?? testCampaign,
    progress: progress ?? const CampaignProgress.empty(),
    endlessBest: endlessBest,
    dailyResults: dailies,
  );
}

void main() {
  test('a fresh save has earned nothing', () {
    expect(_earned(), isEmpty);
  });

  group('campaign facts', () {
    test('finishing a level earns the first clear', () {
      expect(
        _earned(progress: _progress([_result('test_level', stars: 1)])),
        contains(Achievement.firstClear),
      );
    });

    test('an untouched core needs a finished run, not just a healthy one', () {
      final finished = _earned(
        progress: _progress([_result('test_level', stars: 2)]),
      );
      expect(finished, contains(Achievement.untouchedCore));

      // A defeat cannot carry the fact: stars 0 means the level did not finish.
      final defeated = _earned(
        progress: _progress([
          _result('test_level', stars: 0),
        ]),
      );
      expect(defeated, isEmpty);
    });

    test('a damaged core still earns the clear but not untouched', () {
      final earned = _earned(
        progress: _progress([
          _result('test_level', stars: 2, coreHealth: 4),
        ]),
      );

      expect(earned, contains(Achievement.firstClear));
      expect(earned, isNot(contains(Achievement.untouchedCore)));
      expect(earned, isNot(contains(Achievement.threeStars)));
    });

    test('three stars is its own fact', () {
      final earned = _earned(
        progress: _progress([
          _result('test_level', coreHealth: 4),
        ]),
      );

      expect(earned, contains(Achievement.threeStars));
      expect(earned, isNot(contains(Achievement.untouchedCore)));
    });

    test('a region is cleared only when every level in it is', () {
      final partial = _earned(
        progress: _progress([_result('test_level'), _result('test_level_3')]),
      );
      expect(partial, isNot(contains(Achievement.regionCleared)));

      final regionOne = _earned(
        progress: _progress([
          _result('test_level', stars: 2),
          _result('test_level_2', stars: 2),
        ]),
      );
      expect(regionOne, contains(Achievement.regionCleared));
      expect(regionOne, isNot(contains(Achievement.campaignCleared)));
      expect(regionOne, isNot(contains(Achievement.regionThreeStarred)));
    });

    test('three-starring a region is a separate fact from clearing it', () {
      final regionOne = _earned(
        progress: _progress([
          _result('test_level'),
          _result('test_level_2', stars: 2),
        ]),
      );
      expect(regionOne, contains(Achievement.regionCleared));
      expect(regionOne, isNot(contains(Achievement.regionThreeStarred)));

      final mastered = _earned(
        progress: _progress([
          _result('test_level'),
          _result('test_level_2'),
        ]),
      );
      expect(mastered, contains(Achievement.regionThreeStarred));
    });

    test('clearing and mastering the campaign are the last two', () {
      final cleared = _earned(
        progress: _progress([
          _result('test_level', stars: 2),
          _result('test_level_2', stars: 2),
          _result('test_level_3', stars: 2),
          _result('test_level_4', stars: 2),
        ]),
      );
      expect(cleared, contains(Achievement.campaignCleared));
      expect(cleared, isNot(contains(Achievement.campaignThreeStarred)));

      final mastered = _earned(
        progress: _progress([
          _result('test_level'),
          _result('test_level_2'),
          _result('test_level_3'),
          _result('test_level_4'),
        ]),
      );
      expect(mastered, contains(Achievement.campaignCleared));
      expect(mastered, contains(Achievement.campaignThreeStarred));
      expect(mastered, contains(Achievement.regionThreeStarred));
    });

    test('Hard results do not count towards the Normal achievements', () {
      final earned = _earned(
        progress: _progress([
          _result('test_level', difficulty: Difficulty.hard),
        ]),
      );

      expect(earned, isEmpty, reason: 'the list says it reads Normal');
    });
  });

  group('other modes', () {
    test('the endless best unlocks at ten and twenty waves', () {
      expect(_earned(endlessBest: 9), isEmpty);
      expect(_earned(endlessBest: 10), contains(Achievement.endlessTen));
      expect(
        _earned(endlessBest: 10),
        isNot(contains(Achievement.endlessTwenty)),
      );
      expect(
        _earned(endlessBest: 20),
        containsAll([Achievement.endlessTen, Achievement.endlessTwenty]),
      );
    });

    test('only a finished daily counts', () {
      expect(
        _earned(dailies: {20261104: _daily(stars: 0)}),
        isNot(contains(Achievement.dailyFinished)),
      );
      expect(
        _earned(dailies: {20261104: _daily()}),
        contains(Achievement.dailyFinished),
      );
    });
  });

  test('evaluating twice returns the same facts', () {
    final progress = _progress([
      _result('test_level'),
      _result('test_level_2', stars: 2, coreHealth: 6),
    ]);

    expect(
      _earned(progress: progress, endlessBest: 12),
      _earned(
        progress: progress,
        endlessBest: 12,
      ),
    );
  });

  test('the progress view lists earned achievements first', () {
    const view = AchievementProgress({
      Achievement.endlessTen,
      Achievement.firstClear,
    });

    expect(view.count, 2);
    expect(view.total, Achievement.values.length);
    expect(view.total, 10);
    expect(view.ordered.take(2), [
      Achievement.firstClear,
      Achievement.endlessTen,
    ]);
    // A locked achievement keeps declaration order after the earned ones.
    expect(view.ordered.last, Achievement.dailyFinished);
  });
}
