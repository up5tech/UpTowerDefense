import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';

/// How well one level attempt went.
///
/// The stars are the rating rule's output, not the raw run: keeping the derived
/// value next to the run numbers means the level picker can show a best result
/// without re-running the rule, while the summary screen still has the numbers
/// it needs to explain it.
@immutable
class LevelResult {
  const LevelResult({
    required this.levelId,
    required this.stars,
    required this.coreHealth,
    required this.maxCoreHealth,
    required this.wavesCleared,
    required this.totalWaves,
    this.difficulty = Difficulty.normal,
    this.objectivesMet = 0,
  });

  /// Level this result belongs to.
  final String levelId;

  /// 0 for a defeat, 1–3 for a completed level.
  ///
  /// Stored, never recomputed on load: a 1.0 result keeps the stars it earned
  /// even where today's goals would have scored it differently (D68).
  final int stars;

  /// Core health left at the end of the attempt.
  final int coreHealth;

  /// Core health the level started with.
  final int maxCoreHealth;

  /// Waves the player actually cleared.
  final int wavesCleared;

  /// Waves the level defines.
  final int totalWaves;

  /// Which mode this result was earned on (D65).
  final Difficulty difficulty;

  /// Goals this run met; 0 for a level that declares none and for every result
  /// saved before schema v4.
  final int objectivesMet;

  /// Key this result is stored under: level id, then difficulty.
  ///
  /// Normal keeps the bare level id, so a v3 save's keys stay verbatim through
  /// the upgrade; Hard appends a suffix, which is what stops a Hard replay from
  /// overwriting Normal stars, totals and the unlock message (D65).
  String get key => keyOf(levelId, difficulty);

  /// The storage key for [levelId] on [difficulty].
  static String keyOf(String levelId, Difficulty difficulty) =>
      difficulty == Difficulty.normal
      ? levelId
      : '$levelId#${difficulty.wireName}';

  /// Whether the level was completed at all.
  bool get isCompleted => stars > 0;

  /// Whether this result is better than [other].
  ///
  /// Stars first, then remaining core health: a three-star run is never replaced
  /// by a worse replay, and two equal-star runs keep the healthier one, so the
  /// best result only ever improves. Two modes never compare — they are stored
  /// under different keys.
  bool isBetterThan(LevelResult other) {
    if (stars != other.stars) {
      return stars > other.stars;
    }
    return coreHealth > other.coreHealth;
  }

  @override
  String toString() =>
      'LevelResult($levelId, ${difficulty.wireName}, $stars stars, '
      'core $coreHealth/$maxCoreHealth, $objectivesMet goals)';
}

/// What the player has achieved so far, keyed by level and difficulty.
///
/// The type is immutable and every change returns a new value so the provider
/// can publish a new state without callers holding a reference that mutates
/// behind them. Every reader takes a difficulty (Normal by default), so no
/// screen has to guess which mode a number came from.
@immutable
class CampaignProgress {
  const CampaignProgress({required this.results});

  /// A fresh campaign: nothing played.
  const CampaignProgress.empty() : results = const {};

  /// Best result per [`LevelResult.key`] — level id, and `#hard` for Hard.
  final Map<String, LevelResult> results;

  /// Best result for [levelId] on [difficulty], or null when it was never
  /// completed there.
  LevelResult? resultFor(
    String levelId, {
    Difficulty difficulty = Difficulty.normal,
  }) => results[LevelResult.keyOf(levelId, difficulty)];

  /// Stars earned on [levelId] on [difficulty], 0 when none.
  int starsFor(String levelId, {Difficulty difficulty = Difficulty.normal}) =>
      resultFor(levelId, difficulty: difficulty)?.stars ?? 0;

  /// Whether [levelId] has been completed at least once on [difficulty].
  bool isCompleted(
    String levelId, {
    Difficulty difficulty = Difficulty.normal,
  }) => starsFor(levelId, difficulty: difficulty) > 0;

  /// Stars earned across [levelIds] on one difficulty.
  int totalStars(
    Iterable<String> levelIds, {
    Difficulty difficulty = Difficulty.normal,
  }) {
    var total = 0;
    for (final levelId in levelIds) {
      total += starsFor(levelId, difficulty: difficulty);
    }
    return total;
  }

  /// Whether every level of [region] is cleared on [difficulty].
  bool isRegionCleared(
    CampaignRegion region, {
    Difficulty difficulty = Difficulty.normal,
  }) => region.levels.every(
    (level) => isCompleted(level.id, difficulty: difficulty),
  );

  /// Whether Hard is open at all (D65).
  ///
  /// One region cleared on Normal is enough: Hard is an optional second pass,
  /// never a gate in front of a first-time player, and clearing a region is the
  /// point where a player has learned its route and roster.
  bool isHardAvailable(CampaignDefinition campaign) =>
      campaign.regions.any(isRegionCleared);

  /// Whether [levelId] may be played on [difficulty].
  ///
  /// Normal runs the 1.0 rule along the flattened order: the first level is
  /// always open and every other level opens when the one before it is
  /// completed (D33). Hard keeps that chain per region and adds one gate: a
  /// region's first level only opens once the whole region is cleared on
  /// Normal, so Hard can never strand a player who has not seen the level.
  bool isUnlocked(
    CampaignDefinition campaign,
    String levelId, {
    Difficulty difficulty = Difficulty.normal,
  }) {
    final index = campaign.indexOf(levelId);
    if (index < 0) {
      return false;
    }
    if (difficulty != Difficulty.normal) {
      final region = campaign.regionOf(levelId);
      if (region == null || !isRegionCleared(region)) {
        return false;
      }
      if (region.levels.first.id == levelId) {
        return true;
      }
    }
    if (index == 0) {
      return true;
    }
    return isCompleted(
      campaign.levelIds[index - 1],
      difficulty: difficulty,
    );
  }

  /// The level "Play" should open on Normal: the first unlocked, unfinished
  /// level, or the last level when the campaign is complete.
  ///
  /// Returning the last level rather than null keeps Play working after the
  /// campaign ends — replaying the finale is more useful than an empty screen.
  String? resumeLevelId(CampaignDefinition campaign) {
    for (final levelId in campaign.levelIds) {
      if (!isCompleted(levelId)) {
        return levelId;
      }
    }
    return campaign.levelIds.isEmpty ? null : campaign.levelIds.last;
  }

  /// Records [result], keeping the better of it and any previous run of the
  /// same level and difficulty.
  ///
  /// A worse replay is ignored rather than stored, which is what makes "best
  /// result" a property of the data instead of a UI concern.
  CampaignProgress record(LevelResult result) {
    final previous = results[result.key];
    if (previous != null && !result.isBetterThan(previous)) {
      return this;
    }
    return CampaignProgress(
      results: Map<String, LevelResult>.unmodifiable({
        ...results,
        result.key: result,
      }),
    );
  }

  @override
  String toString() => 'CampaignProgress(${results.length} results)';
}
