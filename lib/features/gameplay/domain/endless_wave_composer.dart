import 'dart:math' as math;

import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

/// Generates the waves an endless level runs past its authored template.
///
/// Pure and deterministic: the same (template, wave number, growth) always
/// yields the same wave, so a run is reproducible and every rule here is
/// unit-testable without a session (D62).
///
/// The rules:
///   * waves cycle through the template — wave N is the template wave at
///     index `(N - 1) % template.length`, so the authored pacing returns
///     regularly instead of a flat soup of enemies;
///   * each completed cycle scales every group's count by
///     `1 + countGrowthPerCycle × cycle`, rounded up and floored at 1 — volume
///     is the difficulty knob, because spawn intervals and enemy stats stay
///     exactly what the codex and the template say;
///   * intervals, delays and enemy ids are copied verbatim: composing a wave
///     may never invent content the catalog does not know.
class EndlessWaveComposer {
  const EndlessWaveComposer();

  /// The wave to spawn for [waveNumber] (1-based) beyond which point the
  /// template has been entered again.
  ///
  /// `waveNumber` inside the template range returns the authored wave itself,
  /// so the caller needs no special case for the early waves.
  WaveDefinition compose({
    required List<WaveDefinition> template,
    required int waveNumber,
    required double countGrowthPerCycle,
  }) {
    assert(template.isNotEmpty, 'an endless level needs an authored template');
    assert(waveNumber >= 1, 'waves are numbered from 1');

    final index = (waveNumber - 1) % template.length;
    final cycle = (waveNumber - 1) ~/ template.length;
    final source = template[index];
    if (cycle == 0) {
      return source;
    }

    final multiplier = 1 + countGrowthPerCycle * cycle;
    return WaveDefinition(
      // The id stays unique per wave: debugging a run should be able to name
      // which cycle of the template an enemy came from.
      id: '${source.id}_c$cycle',
      groups: [
        for (final group in source.groups)
          SpawnGroupDefinition(
            enemyId: group.enemyId,
            count: math.max(1, (group.count * multiplier).ceil()),
            spawnIntervalSeconds: group.spawnIntervalSeconds,
            initialDelaySeconds: group.initialDelaySeconds,
          ),
      ],
    );
  }
}
