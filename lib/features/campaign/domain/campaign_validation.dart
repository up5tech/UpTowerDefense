import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/validation_result.dart';

/// Checks an authored campaign before the level picker can show it.
///
/// The campaign is the only place that decides play order, so a mistake here
/// either hides a level or unlocks the campaign out of order. Every check is
/// reported at once, like the other content validators, so an author fixes one
/// file in one pass.
class CampaignValidator {
  const CampaignValidator();

  /// Validates [campaign] against the level ids the app actually ships.
  ///
  /// [knownLevelIds] comes from the level catalog, so a level that exists as a
  /// file but is missing from the campaign (or the reverse) is reported here
  /// rather than discovered by a player looking for a level that is not there.
  ValidationResult validate({
    required CampaignDefinition campaign,
    required Set<String> knownLevelIds,
  }) {
    final issues = <String>[];

    if (campaign.regions.isEmpty) {
      issues.add('campaign needs at least one region');
      return ValidationResult(issues);
    }

    final regionIds = <String>{};
    final levelIds = <String>{};

    for (
      var regionIndex = 0;
      regionIndex < campaign.regions.length;
      regionIndex++
    ) {
      final region = campaign.regions[regionIndex];
      final path = 'regions[$regionIndex]';

      if (region.id.trim().isEmpty) {
        issues.add('$path.id must not be empty');
      } else if (!regionIds.add(region.id)) {
        issues.add('region id "${region.id}" is duplicated');
      }
      if (region.displayName.trim().isEmpty) {
        issues.add('$path.displayName must not be empty');
      }
      if (region.levels.isEmpty) {
        issues.add('$path needs at least one level');
      }

      for (
        var levelIndex = 0;
        levelIndex < region.levels.length;
        levelIndex++
      ) {
        final level = region.levels[levelIndex];
        final levelPath = '$path.levels[$levelIndex]';
        if (level.id.trim().isEmpty) {
          issues.add('$levelPath.id must not be empty');
          continue;
        }
        if (level.displayName.trim().isEmpty) {
          issues.add('$levelPath.displayName must not be empty');
        }
        if (!levelIds.add(level.id)) {
          issues.add(
            'level "${level.id}" appears more than once in the campaign',
          );
        }
        if (!knownLevelIds.contains(level.id)) {
          issues.add('$levelPath references unknown level "${level.id}"');
        }
      }
    }

    return ValidationResult(issues);
  }
}
