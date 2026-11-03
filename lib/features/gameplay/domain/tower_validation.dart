import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_level_stats.dart';
import 'package:up_tower_defense/features/gameplay/domain/validation_result.dart';

/// Checks tower definitions before the build panel can offer them.
///
/// Runs on a list rather than a catalog so duplicate ids are still visible, and
/// reports every problem at once so an author fixes a file in one pass.
class TowerValidator {
  const TowerValidator();

  /// Validates [towers]; reports every problem found.
  ValidationResult validate(List<TowerDefinition> towers) {
    final issues = <String>[];

    if (towers.isEmpty) {
      issues.add('tower catalog needs at least one tower');
      return ValidationResult(issues);
    }

    final ids = <String>{};
    for (final tower in towers) {
      final path = 'tower "${tower.id}"';
      if (tower.id.trim().isEmpty) {
        issues.add('tower ids must not be empty');
      } else if (!ids.add(tower.id)) {
        issues.add('tower id "${tower.id}" is duplicated');
      }
      if (tower.displayName.trim().isEmpty) {
        issues.add('$path needs a displayName');
      }
      if (tower.role.trim().isEmpty) {
        issues.add('$path needs a role');
      }
      if (tower.description.trim().isEmpty) {
        issues.add('$path needs a description');
      }
      if (tower.buildCost <= 0) {
        issues.add('$path needs a positive buildCost, got ${tower.buildCost}');
      }
      if (tower.sellRefundRate < 0 || tower.sellRefundRate > 1) {
        issues.add(
          '$path sellRefundRate must be between 0 and 1, '
          'got ${tower.sellRefundRate}',
        );
      }
      if (tower.levels.isEmpty) {
        issues.add('$path needs at least one level');
      } else {
        _validateLevels(tower, issues);
      }
    }

    return ValidationResult(issues);
  }

  void _validateLevels(TowerDefinition tower, List<String> issues) {
    final path = 'tower "${tower.id}"';

    for (var index = 0; index < tower.levels.length; index++) {
      _validateStats(tower.levels[index], '$path.levels[$index]', issues);
    }

    // Every level except the last promises the cost of reaching the next one,
    // or the upgrade button would appear with no price.
    for (var index = 0; index < tower.levels.length - 1; index++) {
      final cost = tower.levels[index].upgradeCost;
      if (cost == null) {
        issues.add(
          '$path.levels[$index] needs an upgradeCost '
          '(only the last level may omit it)',
        );
      } else if (cost <= 0) {
        issues.add(
          '$path.levels[$index].upgradeCost must be positive, got $cost',
        );
      }
    }
    final last = tower.levels.last;
    if (last.upgradeCost != null) {
      issues.add(
        '$path.levels[${tower.levels.length - 1}].upgradeCost must be '
        'omitted on the last level',
      );
    }
  }

  void _validateStats(
    TowerLevelStats stats,
    String path,
    List<String> issues,
  ) {
    // A support level deals no damage, but only if it actually projects
    // something: zero damage with no aura would be a tower that neither
    // fights nor buffs, which is an authoring mistake rather than a strategy.
    final projects = stats.auraRadius > 0;
    if (stats.damage <= 0 && !projects) {
      issues.add(
        '$path needs positive damage, got ${stats.damage} '
        '(only a level with an aura may deal none)',
      );
    }
    if (stats.range <= 0) {
      issues.add('$path needs positive range, got ${stats.range}');
    }
    if (stats.fireCooldownSeconds <= 0) {
      issues.add(
        '$path needs positive fireCooldownSeconds, '
        'got ${stats.fireCooldownSeconds}',
      );
    }
    if (stats.projectileSpeed <= 0) {
      issues.add(
        '$path needs positive projectileSpeed, got ${stats.projectileSpeed}',
      );
    }
    if (stats.splashRadius < 0) {
      issues.add('$path splashRadius must not be negative');
    }

    issues.addAll(_validateChain(stats, path));
    issues.addAll(_validateAura(stats, path));

    final slow = stats.slow;
    if (slow != null) {
      if (slow.magnitude <= 0 || slow.magnitude > 1) {
        issues.add(
          '$path.slow.magnitude must be in (0, 1], got ${slow.magnitude}',
        );
      }
      if (slow.durationSeconds <= 0) {
        issues.add(
          '$path.slow.durationSeconds must be positive, '
          'got ${slow.durationSeconds}',
        );
      }
      if (slow.minSpeedRatio <= 0 || slow.minSpeedRatio > 1) {
        issues.add(
          '$path.slow.minSpeedRatio must be in (0, 1], '
          'got ${slow.minSpeedRatio}',
        );
      }
      if (slow.damageAmp < 0 || slow.damageAmp > 1) {
        issues.add(
          '$path.slow.damageAmp must be in [0, 1], got ${slow.damageAmp}',
        );
      }
    }
  }

  /// Checks an Arc level's chain, which is all-or-nothing.
  ///
  /// `chainCount` is the switch: with jumps promised, the jump radius and the
  /// per-jump falloff must be usable values, and with no jumps the other two
  /// must be absent rather than silently dead. A falloff above 1 would make
  /// every jump stronger than the last — a chain that grows as it walks away
  /// from the shot — so it is capped at 1 here, not in the session.
  List<String> _validateChain(TowerLevelStats stats, String path) {
    if (stats.chainCount == 0) {
      final issues = <String>[];
      if (stats.chainRadius != 0) {
        issues.add('$path.chainRadius requires chainCount above 0');
      }
      if (stats.chainFalloff != 1) {
        issues.add(
          '$path.chainFalloff requires chainCount above 0, '
          'got ${stats.chainFalloff}',
        );
      }
      return issues;
    }

    final issues = <String>[];
    if (stats.chainCount < 1) {
      issues.add(
        '$path.chainCount must not be negative, got ${stats.chainCount}',
      );
    }
    if (stats.chainRadius <= 0) {
      issues.add(
        '$path.chainRadius must be positive with chainCount above 0, '
        'got ${stats.chainRadius}',
      );
    }
    if (stats.chainFalloff <= 0 || stats.chainFalloff > 1) {
      issues.add(
        '$path.chainFalloff must be in (0, 1], got ${stats.chainFalloff}',
      );
    }
    return issues;
  }

  /// Checks a Beacon level's aura, which is all-or-nothing for the same
  /// reason: a radius with no bonus, or a bonus with no radius, describes an
  /// aura the session would never apply.
  List<String> _validateAura(TowerLevelStats stats, String path) {
    if (stats.auraRadius == 0) {
      final issues = <String>[];
      if (stats.auraRangeBonus != 0) {
        issues.add('$path.auraRangeBonus requires auraRadius above 0');
      }
      return issues;
    }

    final issues = <String>[];
    if (stats.auraRadius < 0) {
      issues.add(
        '$path.auraRadius must not be negative, got ${stats.auraRadius}',
      );
    }
    if (stats.auraRangeBonus <= 0 || stats.auraRangeBonus > 1) {
      issues.add(
        '$path.auraRangeBonus must be in (0, 1], got ${stats.auraRangeBonus}',
      );
    }
    return issues;
  }
}
