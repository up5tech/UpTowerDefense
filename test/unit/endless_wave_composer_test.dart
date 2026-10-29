import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/endless_wave_composer.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/wave_definition.dart';

/// The template an endless level cycles through.
const List<WaveDefinition> _template = [
  WaveDefinition(
    id: 'wave_a',
    groups: [
      SpawnGroupDefinition(
        enemyId: 'grunt',
        count: 5,
        spawnIntervalSeconds: 1.4,
        initialDelaySeconds: 2.0,
      ),
    ],
  ),
  WaveDefinition(
    id: 'wave_b',
    groups: [
      SpawnGroupDefinition(
        enemyId: 'runner',
        count: 4,
        spawnIntervalSeconds: 1,
      ),
      SpawnGroupDefinition(
        enemyId: 'brute',
        count: 1,
        spawnIntervalSeconds: 3,
        initialDelaySeconds: 6,
      ),
    ],
  ),
];

void main() {
  const composer = EndlessWaveComposer();

  group('template cycling', () {
    test('waves inside the template are returned verbatim', () {
      for (var n = 1; n <= _template.length; n++) {
        final wave = composer.compose(
          template: _template,
          waveNumber: n,
          countGrowthPerCycle: 1.0,
        );

        expect(
          wave,
          same(_template[n - 1]),
          reason: 'wave $n must be the authored wave itself, untouched',
        );
      }
    });

    test('waves past the template cycle back through it', () {
      final wave3 = composer.compose(
        template: _template,
        waveNumber: 3,
        countGrowthPerCycle: 1.0,
      );
      final wave4 = composer.compose(
        template: _template,
        waveNumber: 4,
        countGrowthPerCycle: 1.0,
      );

      // Position in the cycle, with a cycle suffix so a debugged run can name
      // which pass an enemy came from.
      expect(wave3.id, 'wave_a_c1');
      expect(wave4.id, 'wave_b_c1');
      expect(wave3.groups.single.enemyId, 'grunt');
      expect(wave4.groups.first.enemyId, 'runner');
    });
  });

  group('growth', () {
    test('each completed cycle scales counts by 1 + growth × cycle', () {
      // Template count 5: cycle 1 at growth 1.0 → ×2, cycle 2 → ×3.
      final cycle1 = composer.compose(
        template: _template,
        waveNumber: 3,
        countGrowthPerCycle: 1.0,
      );
      final cycle2 = composer.compose(
        template: _template,
        waveNumber: 5,
        countGrowthPerCycle: 1.0,
      );

      expect(cycle1.groups.single.count, 10);
      expect(cycle2.groups.single.count, 15);
    });

    test('fractional growth rounds the count up, never down', () {
      final wave = composer.compose(
        template: _template,
        waveNumber: 3,
        countGrowthPerCycle: 0.5,
      );

      // 5 × 1.5 = 7.5 → 8: a scaled wave may never shrink its own group.
      expect(wave.groups.single.count, 8);
    });

    test('growth zero keeps the counts but still cycles the template', () {
      final wave = composer.compose(
        template: _template,
        waveNumber: 3,
        countGrowthPerCycle: 0,
      );

      expect(wave.groups.single.count, 5);
      expect(wave.id, 'wave_a_c1');
    });

    test('intervals, delays and enemy ids are copied verbatim', () {
      final wave = composer.compose(
        template: _template,
        waveNumber: 4,
        countGrowthPerCycle: 2.0,
      );

      expect(wave.groups, hasLength(2));
      expect(wave.groups[0].enemyId, 'runner');
      expect(wave.groups[0].spawnIntervalSeconds, 1);
      expect(wave.groups[1].enemyId, 'brute');
      expect(wave.groups[1].spawnIntervalSeconds, 3);
      expect(wave.groups[1].initialDelaySeconds, 6);
      // Only counts move: the codex's stats stay true forever (D62).
      expect(wave.groups[1].count, 3);
    });

    test('the same inputs compose the same wave', () {
      WaveDefinition compose() => composer.compose(
        template: _template,
        waveNumber: 7,
        countGrowthPerCycle: 1.5,
      );

      final a = compose();
      final b = compose();

      expect(a.id, b.id);
      expect(a.groups.single.count, b.groups.single.count);
      expect(a.enemyCount, b.enemyCount);
    });
  });
}
