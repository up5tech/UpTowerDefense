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
    }

    return ValidationResult(issues);
  }
}
