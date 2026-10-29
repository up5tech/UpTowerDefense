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
    if (stats.damage <= 0) {
      issues.add('$path needs positive damage, got ${stats.damage}');
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
}
