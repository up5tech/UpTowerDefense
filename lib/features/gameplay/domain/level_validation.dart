import 'dart:math' as math;

import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_objective.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/validation_result.dart';

/// Checks a level definition and everything it references before it is played.
///
/// Reference checks live here rather than in the JSON decoder so a typo in a wave
/// reports as content validation ("unknown enemy id") instead of a parse error,
/// and so every problem surfaces in one pass.
class LevelValidator {
  const LevelValidator();

  /// Validates [level] against the [map] it claims and the [enemies] catalog.
  ValidationResult validate({
    required LevelDefinition level,
    required MapDefinition map,
    required EnemyCatalog enemies,
  }) {
    final issues = <String>[];

    if (level.id.trim().isEmpty) {
      issues.add('id must not be empty');
    }
    if (level.displayName.trim().isEmpty) {
      issues.add('displayName must not be empty');
    }
    if (level.coreHealth <= 0) {
      issues.add('coreHealth must be positive, got ${level.coreHealth}');
    }
    if (level.startingGold < 0) {
      issues.add(
        'startingGold must not be negative, got ${level.startingGold}',
      );
    }
    if (level.waveTransitionSeconds <= 0) {
      issues.add(
        'waveTransitionSeconds must be positive, '
        'got ${level.waveTransitionSeconds}',
      );
    }
    if (level.mapId != map.id) {
      issues.add(
        'mapId "${level.mapId}" does not match the loaded map "${map.id}"',
      );
    }
    if (level.waves.isEmpty) {
      issues.add('level needs at least one wave');
      return ValidationResult(issues);
    }
    // The endless growth knob is a difficulty multiplier, so a negative value
    // would silently make later cycles *easier* than the template (D62).
    if (level.endless && level.endlessCountGrowth < 0) {
      issues.add(
        'endlessCountGrowth must not be negative, '
        'got ${level.endlessCountGrowth}',
      );
    }
    issues.addAll(_objectiveIssues(level, map));

    final waveIds = <String>{};
    for (var waveIndex = 0; waveIndex < level.waves.length; waveIndex++) {
      final wave = level.waves[waveIndex];
      if (wave.id.trim().isEmpty) {
        issues.add('waves[$waveIndex].id must not be empty');
      } else if (!waveIds.add(wave.id)) {
        issues.add('wave id "${wave.id}" is duplicated');
      }
      if (wave.groups.isEmpty) {
        issues.add('wave "${wave.id}" needs at least one spawn group');
      }

      for (var groupIndex = 0; groupIndex < wave.groups.length; groupIndex++) {
        final group = wave.groups[groupIndex];
        final path = 'waves[$waveIndex].groups[$groupIndex]';
        if (!enemies.contains(group.enemyId)) {
          issues.add('$path references unknown enemy "${group.enemyId}"');
        }
        if (group.count <= 0) {
          issues.add('$path.count must be positive, got ${group.count}');
        }
        if (group.spawnIntervalSeconds <= 0) {
          issues.add(
            '$path.spawnIntervalSeconds must be positive, '
            'got ${group.spawnIntervalSeconds}',
          );
        }
        if (group.initialDelaySeconds < 0) {
          issues.add(
            '$path.initialDelaySeconds must not be negative, '
            'got ${group.initialDelaySeconds}',
          );
        }
      }
    }

    return ValidationResult(issues);
  }

  /// Checks the optional goals a level declares (D68).
  ///
  /// The star rule is `1 + met`, so the shape of the list is a rule, not a
  /// style choice: a single goal would cap a level at two stars, which is why
  /// only 0 or 2 are accepted. Every threshold is checked against the content
  /// it has to be reachable in, so an impossible goal fails at load instead of
  /// silently costing a player a star.
  List<String> _objectiveIssues(LevelDefinition level, MapDefinition map) {
    final objectives = level.objectives;
    final issues = <String>[];

    if (level.endless && objectives.isNotEmpty) {
      issues.add(
        'an endless level cannot declare objectives: its run can only end in '
        'defeat',
      );
      return issues;
    }
    if (objectives.isNotEmpty && objectives.length != 2) {
      issues.add(
        'objectives must be declared 0 or exactly 2 (stars are 1 + met, so a '
        'single goal would cap the level at two stars), got '
        '${objectives.length}',
      );
    }

    final kinds = <LevelObjectiveKind>{};
    for (var index = 0; index < objectives.length; index++) {
      final objective = objectives[index];
      final path = 'objectives[$index]';
      if (!kinds.add(objective.kind)) {
        issues.add('$path repeats "${objective.kind.wireName}"');
      }

      final value = objective.value;
      switch (objective.kind) {
        case LevelObjectiveKind.noLeaks:
          break;
        case LevelObjectiveKind.maxTowers:
          if (value == null || value < 1) {
            issues.add('$path.value must be at least 1, got $value');
          } else if (value > map.buildPads.length) {
            issues.add(
              '$path asks for $value towers but the map has only '
              '${map.buildPads.length} pads',
            );
          }
        case LevelObjectiveKind.deadlineSeconds:
          if (value == null || value <= 0) {
            issues.add('$path.value must be positive, got $value');
          } else {
            final minimum = _minimumSpawnSeconds(level);
            if (value < minimum) {
              issues.add(
                '$path gives $value seconds but the level cannot finish '
                'spawning before ${minimum.toStringAsFixed(1)} seconds',
              );
            }
          }
        case LevelObjectiveKind.coreAbove:
          if (value == null || value < 1) {
            issues.add('$path.value must be at least 1, got $value');
          } else if (value >= level.coreHealth) {
            issues.add(
              '$path.value must stay below coreHealth (${level.coreHealth}) '
              'so it cannot restate noLeaks, got $value',
            );
          }
      }
    }

    return issues;
  }

  /// Shortest time in which the level can finish spawning its enemies.
  ///
  /// Waves never overlap, and every wave waits for its longest group, so this
  /// sum is a hard lower bound on any run's play time — the number a deadline
  /// has to clear to be reachable at all.
  double _minimumSpawnSeconds(LevelDefinition level) {
    var total = 0.0;
    for (final wave in level.waves) {
      var longest = 0.0;
      for (final group in wave.groups) {
        final span =
            group.initialDelaySeconds +
            math.max(0, group.count - 1) * group.spawnIntervalSeconds;
        if (span > longest) {
          longest = span;
        }
      }
      total += longest;
    }
    return total;
  }
}
