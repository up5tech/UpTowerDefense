import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_progress.dart';
import 'package:up_tower_defense/features/campaign/domain/level_rating.dart';
import 'package:up_tower_defense/features/gameplay/domain/daily_challenge.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';

/// The ten long-tail goals v2 ships (D67).
///
/// A closed enum rather than authored content: every one is derived from a fact
/// the save already stores, so nothing is tracked per frame and no achievement
/// can invent a rule the simulation does not resolve. The wire name is what a
/// save stores, so renaming a Dart constant never rewrites stored ids.
///
/// Campaign achievements read **Normal** only. Hard is a second pass that opens
/// after a region is cleared on Normal, so a Normal-only set can never lock a
/// player out of a goal, and the total a screen shows is always the total it
/// says it is (D65).
enum Achievement {
  /// Finish any campaign level.
  firstClear(
    'firstClear',
    'First clear',
    'Finish any campaign level',
  ),

  /// Finish a level without losing a core point.
  untouchedCore(
    'untouchedCore',
    'Untouched',
    'Finish a level with the core at full health',
  ),

  /// Earn the highest rating anywhere in the campaign.
  threeStars(
    'threeStars',
    'Three of three',
    'Earn three stars on any level',
  ),

  /// Clear every level of one region.
  regionCleared(
    'regionCleared',
    'Region cleared',
    'Clear every level of a region on Normal',
  ),

  /// Three-star every level of one region.
  regionThreeStarred(
    'regionThreeStarred',
    'Region mastered',
    'Three-star every level of a region on Normal',
  ),

  /// Clear the whole campaign.
  campaignCleared(
    'campaignCleared',
    'Campaign cleared',
    'Clear every campaign level on Normal',
  ),

  /// Three-star the whole campaign.
  campaignThreeStarred(
    'campaignThreeStarred',
    'Campaign mastered',
    'Three-star every campaign level on Normal',
  ),

  /// Reach the tenth wave of the endless challenge.
  endlessTen('endlessTen', 'Wave ten', 'Clear ten waves in one endless run'),

  /// Reach the twentieth wave of the endless challenge.
  endlessTwenty(
    'endlessTwenty',
    'Wave twenty',
    'Clear twenty waves in one endless run',
  ),

  /// Finish a daily challenge.
  dailyFinished(
    'dailyFinished',
    'Daily done',
    'Finish a daily challenge',
  );

  const Achievement(this.wireName, this.label, this.description);

  /// Stable id stored in the save.
  final String wireName;

  /// Short player-facing name.
  final String label;

  /// The fact that unlocks it, in one sentence.
  final String description;

  /// The achievement stored as [name], or null for an unknown id.
  static Achievement? fromWireName(String name) {
    for (final achievement in values) {
      if (achievement.wireName == name) {
        return achievement;
      }
    }
    return null;
  }
}

/// Derives the earned set from facts the save already holds (D67).
///
/// One pure function over stored state: the caller supplies the campaign, the
/// progress, the endless best and the daily records, and gets back every goal
/// the facts satisfy. Nothing here mutates, so evaluating twice is harmless and
/// the "unlock once" guarantee lives in the writer that stores the difference.
abstract final class AchievementEvaluator {
  static Set<Achievement> evaluate({
    required CampaignDefinition campaign,
    required CampaignProgress progress,
    required int endlessBest,
    required Map<int, DailyResult> dailyResults,
  }) {
    final earned = <Achievement>{};

    // Normal results drive every campaign achievement, so a Hard replay can
    // never change what the achievement list says.
    final results = [
      for (final result in progress.results.values)
        if (result.difficulty == Difficulty.normal) result,
    ];

    if (results.any((result) => result.isCompleted)) {
      earned.add(Achievement.firstClear);
    }
    if (results.any(
      (result) =>
          result.isCompleted && result.coreHealth >= result.maxCoreHealth,
    )) {
      earned.add(Achievement.untouchedCore);
    }
    if (results.any((result) => result.stars == LevelRating.maxStars)) {
      earned.add(Achievement.threeStars);
    }

    if (endlessBest >= 10) {
      earned.add(Achievement.endlessTen);
    }
    if (endlessBest >= 20) {
      earned.add(Achievement.endlessTwenty);
    }
    if (dailyResults.values.any((result) => result.stars > 0)) {
      earned.add(Achievement.dailyFinished);
    }

    if (campaign.levelIds.isEmpty) {
      return earned;
    }

    // Region facts are per region, not per level: clearing all five levels of
    // one region is a different achievement from clearing one level in each.
    for (final region in campaign.regions) {
      if (region.levels.every((level) => progress.isCompleted(level.id))) {
        earned.add(Achievement.regionCleared);
      }
      if (region.levels.every(
        (level) => progress.starsFor(level.id) == LevelRating.maxStars,
      )) {
        earned.add(Achievement.regionThreeStarred);
      }
    }

    if (campaign.levelIds.every(progress.isCompleted)) {
      earned.add(Achievement.campaignCleared);
    }
    if (campaign.levelIds.every(
      (levelId) => progress.starsFor(levelId) == LevelRating.maxStars,
    )) {
      earned.add(Achievement.campaignThreeStarred);
    }

    return earned;
  }
}

/// Stable, readable view of a set of achievements for the progress screen.
///
/// Sorted by declaration order so the list does not reshuffle as a player earns
/// one, which would make the screen feel like it moved under their eyes.
@immutable
class AchievementProgress {
  const AchievementProgress(this.earned);

  /// Which achievements the save holds.
  final Set<Achievement> earned;

  /// Every achievement, earned first in declaration order.
  List<Achievement> get ordered => [
    for (final achievement in Achievement.values)
      if (earned.contains(achievement)) achievement,
    for (final achievement in Achievement.values)
      if (!earned.contains(achievement)) achievement,
  ];

  /// How many are earned.
  int get count => earned.length;

  /// How many exist.
  int get total => Achievement.values.length;

  @override
  String toString() => 'AchievementProgress($count/$total)';
}
