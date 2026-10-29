import 'package:meta/meta.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';

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
  });

  /// Level this result belongs to.
  final String levelId;

  /// 0 for a defeat, 1–3 for a completed level.
  final int stars;

  /// Core health left at the end of the attempt.
  final int coreHealth;

  /// Core health the level started with.
  final int maxCoreHealth;

  /// Waves the player actually cleared.
  final int wavesCleared;

  /// Waves the level defines.
  final int totalWaves;

  /// Whether the level was completed at all.
  bool get isCompleted => stars > 0;

  /// Whether this result is better than [other].
  ///
  /// Stars first, then remaining core health: a three-star run is never replaced
  /// by a worse replay, and two equal-star runs keep the healthier one, so the
  /// best result only ever improves.
  bool isBetterThan(LevelResult other) {
    if (stars != other.stars) {
      return stars > other.stars;
    }
    return coreHealth > other.coreHealth;
  }

  @override
  String toString() =>
      'LevelResult($levelId, $stars stars, core $coreHealth/$maxCoreHealth)';
}

/// What the player has achieved so far, keyed by level id.
///
/// Phase 8 keeps this in memory; Phase 9 serialises it. The type is immutable
/// and every change returns a new value so the provider can publish a new state
/// without callers holding a reference that mutates behind them.
@immutable
class CampaignProgress {
  const CampaignProgress({required this.results});

  /// A fresh campaign: nothing played.
  const CampaignProgress.empty() : results = const {};

  /// Best result per level id.
  final Map<String, LevelResult> results;

  /// Best result for [levelId], or null when it was never completed.
  LevelResult? resultFor(String levelId) => results[levelId];

  /// Stars earned on [levelId], 0 when it was never completed.
  int starsFor(String levelId) => results[levelId]?.stars ?? 0;

  /// Whether [levelId] has been completed at least once.
  bool isCompleted(String levelId) => starsFor(levelId) > 0;

  /// Stars earned across the whole campaign.
  int totalStars(Iterable<String> levelIds) {
    var total = 0;
    for (final levelId in levelIds) {
      total += starsFor(levelId);
    }
    return total;
  }

  /// Whether [levelId] may be played.
  ///
  /// The first level of the campaign is always open, and every other level opens
  /// when the level before it in campaign order is completed. One rule, applied
  /// along one order, so a gap can never open in the campaign.
  bool isUnlocked(CampaignDefinition campaign, String levelId) {
    final index = campaign.indexOf(levelId);
    if (index < 0) {
      return false;
    }
    if (index == 0) {
      return true;
    }
    return isCompleted(campaign.levelIds[index - 1]);
  }

  /// The level "Play" should open: the first unlocked, unfinished level, or the
  /// last level when the campaign is complete.
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

  /// Records [result], keeping the better of it and any previous run.
  ///
  /// A worse replay is ignored rather than stored, which is what makes "best
  /// result" a property of the data instead of a UI concern.
  CampaignProgress record(LevelResult result) {
    final previous = results[result.levelId];
    if (previous != null && !result.isBetterThan(previous)) {
      return this;
    }
    return CampaignProgress(
      results: Map<String, LevelResult>.unmodifiable({
        ...results,
        result.levelId: result,
      }),
    );
  }

  @override
  String toString() => 'CampaignProgress(${results.length} results)';
}
