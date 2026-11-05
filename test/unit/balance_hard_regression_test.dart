import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/difficulty_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/data/level_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/map_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_repository.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';

/// Hard-mode balance gate (D65).
///
/// Hard is one load-time profile over wave counts and starting gold, so it has
/// to be measured, not assumed: the probe runs the same four naive plans that
/// pin Normal, on the same levels, and its numbers are pinned here. Two claims
/// are checked:
///
/// 1. **Hard is harder.** Every pinned Hard row is at or below its Normal
///    counterpart on core health — the profile may not make a level easier by
///    accident, which a count multiplier applied to the wrong field would do.
/// 2. **No level is unwinnable.** Each of the fifteen levels is won by at least
///    one plan. A mode where a level can only be lost is not difficulty, it is
///    a dead end (V2-3's exit gate).
///
/// The policy mirrors `tool/balance_probe.dart` exactly, including the capped
/// starter plan for the opening levels. When Hard's percentages change, re-run
/// `dart run tool/balance_probe.dart --difficulty=hard` and update this table in
/// the same change — never to silence a surprise.
const double _dt = 1 / 60;
const double _timeLimit = 900;

/// The probe's plans, copied from `tool/balance_probe.dart`. Level-keyed entries
/// win over map-keyed ones, exactly as the probe resolves them.
const Map<String, Map<String, List<(String, String)>>> _probePlans = {
  'capped starter': {
    'meadow_01': [('pad_a', 'ranger'), ('pad_c', 'ranger')],
    'meadow_02': [('pad_a', 'ranger'), ('pad_c', 'ranger')],
    'meadow_03': [('pad_a', 'ranger'), ('pad_c', 'ranger')],
  },
  'rangers only': {
    'meadow_gate': [
      ('pad_a', 'ranger'),
      ('pad_c', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_f', 'ranger'),
    ],
    'ember_pass': [
      ('pad_a', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_c', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_f', 'ranger'),
    ],
    'hollow_court': [
      ('pad_a', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_c', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_f', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_g', 'ranger'),
    ],
  },
  'cannon crossfire': {
    'meadow_gate': [
      ('pad_a', 'ranger'),
      ('pad_c', 'cannon'),
      ('pad_e', 'cannon'),
      ('pad_b', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_f', 'ranger'),
    ],
    'ember_pass': [
      ('pad_a', 'ranger'),
      ('pad_b', 'cannon'),
      ('pad_c', 'cannon'),
      ('pad_d', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_f', 'ranger'),
    ],
    'hollow_court': [
      ('pad_a', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_c', 'cannon'),
      ('pad_e', 'cannon'),
      ('pad_f', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_g', 'ranger'),
    ],
  },
  'frost control': {
    'meadow_gate': [
      ('pad_a', 'ranger'),
      ('pad_c', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_f', 'frost'),
    ],
    'ember_pass': [
      ('pad_a', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_c', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_f', 'frost'),
    ],
    'hollow_court': [
      ('pad_a', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_c', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_f', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_g', 'frost'),
    ],
  },
  'no-frost control': {
    'meadow_gate': [
      ('pad_a', 'ranger'),
      ('pad_f', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_c', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_d', 'ranger'),
    ],
    'ember_pass': [
      ('pad_a', 'ranger'),
      ('pad_f', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_c', 'ranger'),
    ],
    'hollow_court': [
      ('pad_a', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_c', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_f', 'ranger'),
      ('pad_g', 'ranger'),
    ],
  },
};

/// Probe-measured Hard outcomes per strategy: `(victory, coreHealth, leaks)`.
///
/// Measured 2026-11-04 with the profile at 125% wave counts and 90% starting
/// gold, under the four full-build plans plus the capped opening plan. Nine
/// rows lose — hollow_03, hollow_04 and hollow_05 under every plan but
/// `cannon crossfire` — and they are pinned as losses on purpose: the probe's
/// plans are naive (fill every pad with one tower), and Hard is where a player
/// has to adapt. What must not happen is a level nobody can win, which the
/// last test checks.
const Map<String, Map<String, (bool, int, int)>> _pinnedHardOutcomes = {
  'meadow_01': {
    'rangers only': (true, 20, 0),
    'cannon crossfire': (true, 16, 4),
    'frost control': (true, 20, 0),
    'capped starter': (true, 20, 0),
    'no-frost control': (true, 20, 0),
  },
  'meadow_02': {
    'rangers only': (true, 19, 1),
    'cannon crossfire': (true, 15, 5),
    'frost control': (true, 19, 1),
    'capped starter': (true, 19, 1),
    'no-frost control': (true, 20, 0),
  },
  'meadow_03': {
    'rangers only': (true, 16, 2),
    'cannon crossfire': (true, 18, 0),
    'frost control': (true, 16, 2),
    'capped starter': (true, 16, 2),
    'no-frost control': (true, 18, 0),
  },
  'meadow_04': {
    'rangers only': (true, 18, 0),
    'cannon crossfire': (true, 18, 0),
    'frost control': (true, 18, 0),
    'no-frost control': (true, 18, 0),
  },
  'meadow_05': {
    'rangers only': (true, 14, 1),
    'cannon crossfire': (true, 14, 1),
    'frost control': (true, 14, 1),
    'no-frost control': (true, 16, 0),
  },
  'ember_01': {
    'rangers only': (true, 16, 0),
    'cannon crossfire': (true, 16, 0),
    'frost control': (true, 16, 0),
    'no-frost control': (true, 16, 0),
  },
  'ember_02': {
    'rangers only': (true, 15, 0),
    'cannon crossfire': (true, 14, 1),
    'frost control': (true, 15, 0),
    'no-frost control': (true, 15, 0),
  },
  'ember_03': {
    'rangers only': (true, 9, 3),
    'cannon crossfire': (true, 7, 4),
    'frost control': (true, 9, 3),
    'no-frost control': (true, 11, 2),
  },
  'ember_04': {
    'rangers only': (true, 4, 4),
    'cannon crossfire': (true, 12, 0),
    'frost control': (true, 2, 5),
    'no-frost control': (true, 6, 3),
  },
  'ember_05': {
    'rangers only': (true, 8, 2),
    'cannon crossfire': (true, 12, 0),
    'frost control': (true, 12, 0),
    'no-frost control': (true, 8, 2),
  },
  'hollow_01': {
    'rangers only': (true, 14, 3),
    'cannon crossfire': (true, 20, 0),
    'frost control': (true, 14, 3),
    'no-frost control': (true, 14, 3),
  },
  'hollow_02': {
    'rangers only': (true, 14, 3),
    'cannon crossfire': (true, 20, 0),
    'frost control': (true, 14, 3),
    'no-frost control': (true, 13, 4),
  },
  'hollow_03': {
    'rangers only': (false, 0, 18),
    'cannon crossfire': (true, 20, 0),
    'frost control': (false, 0, 18),
    'no-frost control': (false, 0, 19),
  },
  'hollow_04': {
    'rangers only': (false, 0, 20),
    'cannon crossfire': (true, 20, 0),
    'frost control': (false, 0, 20),
    'no-frost control': (false, 0, 20),
  },
  'hollow_05': {
    'rangers only': (false, 0, 7),
    'cannon crossfire': (true, 14, 0),
    'frost control': (false, 0, 7),
    'no-frost control': (false, 0, 7),
  },
};

/// The same levels' Normal outcomes, for the "Hard is never easier" check.
/// Kept here as only the one number that check needs: core health under the
/// plan that wins the level on both modes.
const Map<String, int> _normalCoreBest = {
  'meadow_01': 20,
  'meadow_02': 20,
  'meadow_03': 18,
  'meadow_04': 18,
  'meadow_05': 16,
  'ember_01': 16,
  'ember_02': 15,
  'ember_03': 13,
  'ember_04': 12,
  'ember_05': 12,
  'hollow_01': 20,
  'hollow_02': 20,
  'hollow_03': 20,
  'hollow_04': 20,
  'hollow_05': 14,
};

class _Outcome {
  const _Outcome({
    required this.victory,
    required this.coreHealth,
    required this.leaks,
  });

  final bool victory;
  final int coreHealth;
  final int leaks;
}

List<(String, String)> _plan(String strategy, String levelId, String mapId) =>
    _probePlans[strategy]![levelId] ?? _probePlans[strategy]![mapId]!;

_Outcome _run(LevelBundle bundle, List<(String, String)> plan) {
  final session = LevelSession(
    level: bundle.level,
    map: bundle.map,
    enemyCatalog: bundle.enemies,
    towerCatalog: bundle.towers,
  );

  while (session.elapsed < _timeLimit) {
    _act(session, plan);
    if (session.canStartNextWave) {
      session.startNextWave();
    }
    session.advance(_dt);
    if (session.phase == LevelPhase.victory ||
        session.phase == LevelPhase.defeat) {
      break;
    }
  }

  return _Outcome(
    victory: session.phase == LevelPhase.victory,
    coreHealth: session.coreHealth,
    leaks: session.leaks,
  );
}

void _act(LevelSession session, List<(String, String)> plan) {
  if (session.towerCount < plan.length) {
    final (padId, towerId) = plan[session.towerCount];
    final definition = session.towerCatalog[towerId];
    if (definition != null && session.canBuildOn(padId, definition)) {
      session.buildTower(padId, definition);
    }
    return;
  }

  final upgradeOrder = [
    for (final (padId, towerId) in plan)
      if (towerId == 'ranger') padId,
    for (final (padId, towerId) in plan)
      if (towerId != 'ranger') padId,
  ];
  for (final padId in upgradeOrder) {
    if (session.canUpgradeAt(padId)) {
      session.upgradeTowerAt(padId);
      return;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late final LevelRepository repository;
  late final Map<Difficulty, DifficultyProfile> profiles;

  setUpAll(() async {
    repository = LevelRepository(
      mapRepository: MapRepository(),
      enemyRepository: EnemyRepository(),
      towerRepository: TowerRepository(),
    );
    profiles = await DifficultyRepository().load();
  });

  Future<LevelBundle> load(
    String levelId, {
    Difficulty difficulty = Difficulty.hard,
  }) {
    return repository.load(
      ContentCatalog.levelAssetFor(levelId),
      profile: profiles[difficulty]!,
    );
  }

  test('every pinned row matches the probe on Hard', () async {
    for (final entry in _pinnedHardOutcomes.entries) {
      final levelId = entry.key;
      final bundle = await load(levelId);

      expect(bundle.difficulty, Difficulty.hard, reason: levelId);

      for (final strategy in entry.value.entries) {
        final (victory, coreHealth, leaks) = strategy.value;
        final outcome = _run(
          bundle,
          _plan(strategy.key, levelId, bundle.map.id),
        );
        final where = '$levelId / Hard / ${strategy.key}';

        expect(
          outcome.victory,
          victory,
          reason:
              '$where flipped a win to a loss (or back). Re-run '
              '`dart run tool/balance_probe.dart --difficulty=hard` and update '
              'the pinned table deliberately if the change is intended.',
        );
        expect(
          outcome.coreHealth,
          coreHealth,
          reason:
              '$where: core health moved. Re-run the Hard probe, review the '
              'whole campaign table, and update this pin in the same change as '
              'the data.',
        );
        expect(
          outcome.leaks,
          leaks,
          reason:
              '$where: leak count moved. Re-run the Hard probe and update this '
              'pin alongside the data that moved it.',
        );
      }
    }
  });

  test('no level is unwinnable on Hard, and Hard is never kinder', () async {
    for (final entry in _pinnedHardOutcomes.entries) {
      final levelId = entry.key;
      final wins = entry.value.values.where((row) => row.$1);

      expect(
        wins,
        isNotEmpty,
        reason:
            '$levelId cannot be won on Hard under any pinned plan. Hard is a '
            'second pass, not a dead end — retune the profile or the level.',
      );

      final bestHardCore = wins
          .map((row) => row.$2)
          .reduce(
            (a, b) => a > b ? a : b,
          );
      final bestNormalCore = _normalCoreBest[levelId]!;
      expect(
        bestHardCore,
        lessThanOrEqualTo(bestNormalCore),
        reason:
            '$levelId leaves more core on Hard ($bestHardCore) than on Normal '
            '($bestNormalCore): the profile is making the level easier.',
      );
    }
  });

  test('the Hard profile is the one the game loads', () async {
    final bundle = await load('meadow_01');
    final normal = await load('meadow_01', difficulty: Difficulty.normal);

    final hardWaves = bundle.level.waves
        .expand((wave) => wave.groups)
        .fold(0, (total, group) => total + group.count);
    final normalWaves = normal.level.waves
        .expand((wave) => wave.groups)
        .fold(0, (total, group) => total + group.count);

    expect(hardWaves, greaterThan(normalWaves));
    expect(bundle.level.startingGold, lessThan(normal.level.startingGold));
    // The goals are authored, not scaled: the same two on both modes.
    expect(bundle.level.objectives, normal.level.objectives);
    expect(bundle.level.coreHealth, normal.level.coreHealth);
  });
}
