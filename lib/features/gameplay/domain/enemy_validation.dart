import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/validation_result.dart';

/// Checks enemy definitions before they can be spawned.
///
/// Runs on a list rather than a catalog so duplicate ids are still visible.
class EnemyValidator {
  const EnemyValidator();

  /// Validates [enemies]; returns every problem found.
  ValidationResult validate(List<EnemyDefinition> enemies) {
    final issues = <String>[];

    if (enemies.isEmpty) {
      issues.add('enemy catalog needs at least one enemy');
      return ValidationResult(issues);
    }

    final ids = <String>{};
    final byId = <String, EnemyDefinition>{
      for (final enemy in enemies)
        if (enemy.id.isNotEmpty) enemy.id: enemy,
    };
    for (final enemy in enemies) {
      final path = 'enemy "${enemy.id}"';
      if (enemy.id.trim().isEmpty) {
        issues.add('enemy ids must not be empty');
      } else if (!ids.add(enemy.id)) {
        issues.add('enemy id "${enemy.id}" is duplicated');
      }
      if (enemy.displayName.trim().isEmpty) {
        issues.add('$path needs a displayName');
      }
      if (enemy.maxHealth <= 0) {
        issues.add('$path needs positive maxHealth, got ${enemy.maxHealth}');
      }
      if (enemy.speed <= 0) {
        issues.add('$path needs positive speed, got ${enemy.speed}');
      }
      if (enemy.coreDamageOnLeak <= 0) {
        issues.add(
          '$path needs positive coreDamageOnLeak, '
          'got ${enemy.coreDamageOnLeak}',
        );
      }
      if (enemy.rewardGold < 0) {
        issues.add(
          '$path must not have a negative rewardGold, got ${enemy.rewardGold}',
        );
      }
      if (enemy.radius <= 0) {
        issues.add('$path needs positive radius, got ${enemy.radius}');
      }
      issues.addAll(_validateSurge(enemy, path));
      issues.addAll(_validateReduction(enemy, path));
      issues.addAll(_validateSplit(enemy, path, byId));
    }

    return ValidationResult(issues);
  }

  /// Checks the flat per-hit reduction: non-negative, and always smaller than
  /// the health it protects.
  ///
  /// The upper bound is the one that matters: a reduction at or above
  /// `maxHealth` floors every hit at zero, so the enemy can never be defeated
  /// at all and the level that fields it can never be won. That is a content
  /// mistake, not a difficulty knob, so it is rejected here rather than
  /// discovered by a stuck session.
  List<String> _validateReduction(EnemyDefinition enemy, String path) {
    if (enemy.flatDamageReduction < 0) {
      final message =
          '$path flatDamageReduction must not be negative, '
          'got ${enemy.flatDamageReduction}';
      return [message];
    }
    if (enemy.flatDamageReduction >= enemy.maxHealth) {
      final message =
          '$path flatDamageReduction must be below maxHealth '
          '(${enemy.maxHealth}), got ${enemy.flatDamageReduction} — a shield '
          'that big could never be penetrated';
      return [message];
    }
    return const [];
  }

  /// Checks a split: a real target, a positive count, and no way to split
  /// forever.
  ///
  /// The acyclicity rule is the load-bearing one. Children spawn at the
  /// parent's route progress through the same resolution path, so a splitter
  /// whose target splits (including itself) would spawn children that spawn
  /// children for as long as they keep dying — unbounded work inside one
  /// frame, and a wave that never empties. One level of splitting is the
  /// authored shape: a splitter's target must be an enemy that does not
  /// split.
  List<String> _validateSplit(
    EnemyDefinition enemy,
    String path,
    Map<String, EnemyDefinition> byId,
  ) {
    final split = enemy.splitInto;
    if (split == null) {
      return const [];
    }

    final issues = <String>[];
    if (split.count < 1) {
      issues.add(
        '$path.splitInto.count must be at least 1, got ${split.count}',
      );
    }
    if (split.enemyId == enemy.id) {
      issues.add('$path.splitInto must not spawn itself');
      return issues;
    }
    final target = byId[split.enemyId];
    if (target == null) {
      issues.add(
        '$path.splitInto.enemyId "${split.enemyId}" is not in the catalog',
      );
    } else if (target.splitInto != null) {
      issues.add(
        '$path.splitInto.enemyId "${split.enemyId}" splits too — a splitter '
        'may only split into an enemy that does not split',
      );
    }
    return issues;
  }

  /// Checks the boss surge's bounds and that only a boss may carry one.
  ///
  /// The constraints are D69's, checked here rather than in the decoder so a
  /// report lists every bad field of every enemy in one pass instead of stopping
  /// at the first.
  List<String> _validateSurge(EnemyDefinition enemy, String path) {
    final surge = enemy.speedSurge;
    if (surge == null) {
      return const [];
    }

    final issues = <String>[];
    if (!enemy.isBoss) {
      issues.add('$path has a speedSurge but is not a boss (isBoss: true)');
    }
    if (surge.healthRatio <= 0 || surge.healthRatio > 1) {
      issues.add(
        '$path needs speedSurgeHealthRatio in (0, 1], '
        'got ${surge.healthRatio}',
      );
    }
    if (surge.multiplier <= 1) {
      issues.add(
        '$path needs speedSurgeMultiplier above 1, got ${surge.multiplier}',
      );
    }
    if (surge.durationSeconds <= 0) {
      issues.add(
        '$path needs positive speedSurgeDurationSeconds, '
        'got ${surge.durationSeconds}',
      );
    }
    return issues;
  }
}
