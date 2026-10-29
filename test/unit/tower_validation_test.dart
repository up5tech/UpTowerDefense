import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_level_stats.dart';
import 'package:up_tower_defense/features/gameplay/domain/tower_validation.dart';

import '../helpers/content_fixtures.dart';

TowerDefinition _tower({
  String id = 'ranger',
  String displayName = 'Ranger Tower',
  String role = 'Fast single target',
  String description = 'Quick shots.',
  int buildCost = 70,
  double sellRefundRate = 0.6,
  double range = 210,
  double fireCooldownSeconds = 0.7,
  double damage = 18,
  double projectileSpeed = 600,
  double? splashRadius,
  SlowSpec? slow,
  List<TowerLevelStats>? levels,
}) {
  return TowerDefinition(
    id: id,
    displayName: displayName,
    role: role,
    description: description,
    buildCost: buildCost,
    sellRefundRate: sellRefundRate,
    colorValue: 0xFF4FD1C5,
    levels:
        levels ??
        [
          TowerLevelStats(
            damage: damage,
            range: range,
            fireCooldownSeconds: fireCooldownSeconds,
            projectileSpeed: projectileSpeed,
            splashRadius: splashRadius ?? 0,
            slow: slow,
          ),
        ],
  );
}

List<String> _issues(List<TowerDefinition> towers) {
  return const TowerValidator().validate(towers).issues;
}

void main() {
  test('the fixture towers are valid', () {
    expect(_issues([testRanger, testCannon, testFrost]), isEmpty);
  });

  test('requires at least one tower', () {
    expect(_issues([]), contains(contains('at least one tower')));
  });

  test('rejects duplicate ids', () {
    expect(
      _issues([_tower(), _tower()]),
      contains(contains('tower id "ranger" is duplicated')),
    );
  });

  test('rejects blank ids, names, roles and descriptions', () {
    final issues = _issues([
      _tower(id: ' ', displayName: ' ', role: ' ', description: ' '),
    ]);

    expect(issues, contains(contains('ids must not be empty')));
    expect(issues, contains(contains('needs a displayName')));
    expect(issues, contains(contains('needs a role')));
    expect(issues, contains(contains('needs a description')));
  });

  test('rejects non-positive balance values and names them', () {
    final issues = _issues([
      _tower(
        buildCost: 0,
        range: 0,
        fireCooldownSeconds: 0,
        damage: 0,
        projectileSpeed: 0,
      ),
    ]);

    expect(issues, contains(contains('positive buildCost, got 0')));
    expect(issues, contains(contains('positive range, got 0.0')));
    expect(issues, contains(contains('positive fireCooldownSeconds, got 0.0')));
    expect(issues, contains(contains('positive damage, got 0.0')));
    expect(issues, contains(contains('positive projectileSpeed, got 0.0')));
  });

  test('rejects a refund rate outside 0..1', () {
    expect(
      _issues([_tower(sellRefundRate: 1.5)]),
      contains(contains('sellRefundRate must be between 0 and 1')),
    );
    expect(
      _issues([_tower(sellRefundRate: -0.1)]),
      contains(contains('sellRefundRate must be between 0 and 1')),
    );
  });

  test('requires at least one level', () {
    expect(_issues([_tower(levels: [])]), contains(contains('one level')));
  });

  test('requires an upgrade cost on every level except the last', () {
    final issues = _issues([
      _tower(
        levels: [
          const TowerLevelStats(
            damage: 18,
            range: 210,
            fireCooldownSeconds: 0.7,
            projectileSpeed: 600,
          ),
          const TowerLevelStats(
            damage: 27,
            range: 225,
            fireCooldownSeconds: 0.66,
            projectileSpeed: 600,
          ),
        ],
      ),
    ]);

    expect(
      issues,
      contains(contains('levels[0] needs an upgradeCost')),
    );
  });

  test('rejects an upgrade cost on the last level', () {
    final issues = _issues([
      _tower(
        levels: [
          const TowerLevelStats(
            damage: 18,
            range: 210,
            fireCooldownSeconds: 0.7,
            projectileSpeed: 600,
            upgradeCost: 60,
          ),
          const TowerLevelStats(
            damage: 27,
            range: 225,
            fireCooldownSeconds: 0.66,
            projectileSpeed: 600,
            upgradeCost: 90,
          ),
        ],
      ),
    ]);

    expect(issues, contains(contains('must be omitted on the last level')));
  });

  test('validates slow specs', () {
    final issues = _issues([
      _tower(
        slow: const SlowSpec(
          magnitude: 0,
          durationSeconds: -1,
          minSpeedRatio: 2,
        ),
      ),
    ]);

    expect(issues, contains(contains('slow.magnitude must be in (0, 1]')));
    expect(
      issues,
      contains(contains('slow.durationSeconds must be positive')),
    );
    expect(issues, contains(contains('slow.minSpeedRatio must be in (0, 1]')));
    expect(
      _issues([
        _tower(
          slow: const SlowSpec(
            magnitude: 0.4,
            durationSeconds: 1,
            minSpeedRatio: 0.4,
            damageAmp: 1.5,
          ),
        ),
      ]),
      contains(contains('slow.damageAmp must be in [0, 1]')),
    );
  });

  test('reports every problem at once', () {
    expect(
      _issues([_tower(buildCost: -5, range: -1)]),
      hasLength(greaterThanOrEqualTo(2)),
    );
  });
}
