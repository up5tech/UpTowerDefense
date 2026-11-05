import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';

import '../helpers/content_fixtures.dart';

/// Difficulty-keyed progress (D65).
///
/// `testCampaign` is two regions of two levels: one region is the smallest unit
/// Hard can open, and two levels per region prove the per-mode unlock chain.
LevelResult _result(
  String levelId, {
  Difficulty difficulty = Difficulty.normal,
  int stars = 2,
}) {
  return LevelResult(
    levelId: levelId,
    stars: stars,
    coreHealth: 10,
    maxCoreHealth: 10,
    wavesCleared: 2,
    totalWaves: 2,
    difficulty: difficulty,
    objectivesMet: stars - 1,
  );
}

CampaignProgress _cleared(String levelId, {int stars = 2}) =>
    const CampaignProgress.empty().record(_result(levelId, stars: stars));

CampaignProgress _clearRegion(
  CampaignProgress progress,
  List<String> levelIds, {
  Difficulty difficulty = Difficulty.normal,
}) {
  var next = progress;
  for (final levelId in levelIds) {
    next = next.record(_result(levelId, difficulty: difficulty));
  }
  return next;
}

void main() {
  test('a Hard run cannot overwrite the Normal result', () {
    final progress = const CampaignProgress.empty()
        .record(_result('test_level', stars: 3))
        .record(_result('test_level', difficulty: Difficulty.hard, stars: 1));

    expect(progress.starsFor('test_level'), 3);
    expect(progress.starsFor('test_level', difficulty: Difficulty.hard), 1);
    expect(
      progress.results.keys,
      containsAll(['test_level', 'test_level#hard']),
    );
  });

  test('best-result keeping runs per mode', () {
    final progress = const CampaignProgress.empty()
        .record(_result('test_level', stars: 3))
        .record(_result('test_level', difficulty: Difficulty.hard))
        .record(_result('test_level', difficulty: Difficulty.hard, stars: 1));

    expect(progress.starsFor('test_level', difficulty: Difficulty.hard), 2);
  });

  test('Hard is unavailable until a region is cleared on Normal', () {
    var progress = const CampaignProgress.empty();
    expect(progress.isHardAvailable(testCampaign), isFalse);

    progress = _cleared('test_level');
    expect(
      progress.isHardAvailable(testCampaign),
      isFalse,
      reason: 'one level is not a region',
    );

    progress = _clearRegion(progress, const ['test_level_2']);
    expect(progress.isHardAvailable(testCampaign), isTrue);
  });

  test('a cleared region opens its first level on Hard, not the next one', () {
    final progress = _clearRegion(
      const CampaignProgress.empty(),
      const ['test_level', 'test_level_2'],
    );

    // Region one is cleared on Normal, so its first level is open on Hard.
    expect(
      progress.isUnlocked(
        testCampaign,
        'test_level',
        difficulty: Difficulty.hard,
      ),
      isTrue,
    );
    // Its second level still follows the first *on Hard*.
    expect(
      progress.isUnlocked(
        testCampaign,
        'test_level_2',
        difficulty: Difficulty.hard,
      ),
      isFalse,
    );
    // Region two is uncleared on Normal, so Hard stays shut there.
    expect(
      progress.isUnlocked(
        testCampaign,
        'test_level_3',
        difficulty: Difficulty.hard,
      ),
      isFalse,
    );

    final withHard = progress.record(
      _result('test_level', difficulty: Difficulty.hard),
    );
    expect(
      withHard.isUnlocked(
        testCampaign,
        'test_level_2',
        difficulty: Difficulty.hard,
      ),
      isTrue,
    );
    expect(
      withHard.isUnlocked(
        testCampaign,
        'test_level_3',
        difficulty: Difficulty.hard,
      ),
      isFalse,
    );
  });

  test('clearing a region on Hard opens the next region on Hard', () {
    var progress = _clearRegion(
      const CampaignProgress.empty(),
      const ['test_level', 'test_level_2', 'test_level_3', 'test_level_4'],
    );
    progress = _clearRegion(progress, const [
      'test_level',
      'test_level_2',
      'test_level_3',
    ], difficulty: Difficulty.hard);

    expect(
      progress.isUnlocked(
        testCampaign,
        'test_level_4',
        difficulty: Difficulty.hard,
      ),
      isTrue,
    );
  });

  test('totals and resume read one mode at a time', () {
    final progress = const CampaignProgress.empty()
        .record(_result('test_level', stars: 3))
        .record(_result('test_level_2', stars: 3))
        .record(_result('test_level', difficulty: Difficulty.hard, stars: 1));

    expect(progress.totalStars(testCampaign.levelIds), 6);
    expect(
      progress.totalStars(testCampaign.levelIds, difficulty: Difficulty.hard),
      1,
    );
    // Play resumes on Normal, which is the campaign a first-timer reads.
    expect(progress.resumeLevelId(testCampaign), 'test_level_3');
  });
}
