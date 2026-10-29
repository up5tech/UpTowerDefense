import 'package:meta/meta.dart';

/// One level entry in the campaign order.
///
/// The campaign carries the player-facing name so the level picker can render
/// the whole list without loading ten level bundles; `campaign_assets_test`
/// asserts the name matches the level file, so the two cannot drift.
@immutable
class CampaignLevel {
  const CampaignLevel({required this.id, required this.displayName});

  /// Level id; the level file is `assets/data/levels/<id>.json`.
  final String id;

  /// Name shown in the level picker.
  final String displayName;

  @override
  String toString() => 'CampaignLevel($id)';
}

/// One campaign region: a named, ordered group of levels.
///
/// A region is presentation and pacing only — it does not change the unlock
/// rule, which runs along the flattened campaign order. That keeps "what comes
/// next" in exactly one place.
@immutable
class CampaignRegion {
  CampaignRegion({
    required this.id,
    required this.displayName,
    required Iterable<CampaignLevel> levels,
  }) : levels = List.unmodifiable(levels);

  /// Stable region id, used by saves and by the level picker.
  final String id;

  /// Player-facing region name, for example `Meadow Gate`.
  final String displayName;

  /// Ordered levels in this region; never empty.
  final List<CampaignLevel> levels;

  @override
  String toString() => 'CampaignRegion($id, ${levels.length} levels)';
}

/// The authored campaign: ordered regions, each holding ordered levels.
///
/// The flattened [levelIds] order *is* the unlock order: a level is playable
/// once the level before it is completed. Keeping the order in one place means
/// the level picker, the unlock rule and the validator cannot disagree about
/// what "next" means.
@immutable
class CampaignDefinition {
  factory CampaignDefinition(Iterable<CampaignRegion> regions) {
    final list = List<CampaignRegion>.unmodifiable(regions);
    return CampaignDefinition._(
      list,
      List<String>.unmodifiable([
        for (final region in list)
          for (final level in region.levels) level.id,
      ]),
      {
        for (final region in list)
          for (final level in region.levels) level.id: level,
      },
    );
  }

  const CampaignDefinition._(this.regions, this.levelIds, this._levelsById);

  /// Regions in play order.
  final List<CampaignRegion> regions;

  /// Every level id in play order, across all regions.
  final List<String> levelIds;

  final Map<String, CampaignLevel> _levelsById;

  /// Total number of playable levels.
  int get levelCount => levelIds.length;

  /// Whether [levelId] belongs to the campaign.
  bool contains(String levelId) => _levelsById.containsKey(levelId);

  /// The campaign entry for [levelId], or null when it is not part of it.
  CampaignLevel? levelFor(String levelId) => _levelsById[levelId];

  /// Player-facing name for [levelId], or null when it is not in the campaign.
  String? displayNameOf(String levelId) => _levelsById[levelId]?.displayName;

  /// Position of [levelId] in the campaign, or -1 when it is not part of it.
  int indexOf(String levelId) => levelIds.indexOf(levelId);

  /// Level at [index], or null when the index is out of range.
  String? levelIdAt(int index) {
    if (index < 0 || index >= levelIds.length) {
      return null;
    }
    return levelIds[index];
  }

  /// The region holding [levelId], or null when it is not part of the campaign.
  CampaignRegion? regionOf(String levelId) {
    for (final region in regions) {
      for (final level in region.levels) {
        if (level.id == levelId) {
          return region;
        }
      }
    }
    return null;
  }

  /// First level of the campaign, or null for an empty campaign.
  String? get firstLevelId => levelIdAt(0);

  /// 1-based position of [levelId], used for the "Level 3" label.
  int ordinalOf(String levelId) => indexOf(levelId) + 1;

  @override
  String toString() =>
      'CampaignDefinition(${regions.length} regions, $levelCount levels)';
}
