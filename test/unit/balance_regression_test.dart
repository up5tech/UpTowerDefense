import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/data/level_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/map_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_repository.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';

/// Balance regression gate (PLAN Phase 11).
///
/// The exploratory instrument is `tool/balance_probe.dart`; this test pins the
/// findings that must survive every future data edit:
///
/// 1. **Opening pacing.** The first three levels stay fully winnable by the
///    naive fill-then-upgrade plan a first-time player follows — no leaks and
///    the core untouched, i.e. still a three-star run each. A buff or nerf that
///    costs the opening its comfortable pace fails here instead of reaching a
///    player.
/// 2. **Order-matched control.** Every support-vs-damage comparison builds the
///    same pads in the same order and differs only in which slot holds the
///    support tower. Round 3 showed build order alone moves ember_03 from 9 to
///    13 core, so a plan judged against a differently-ordered control measures
///    the order, not the tower — the structural check below keeps that trap
///    from reopening.
/// 3. **Campaign outcomes.** The seven levels after the opening are pinned to
///    exactly what the probe measures today — win or loss, core left and leaks
///    — under each of its four strategies. Balance edits are supposed to move
///    these numbers; the point is that they cannot move *silently*.
///
/// The policy mirrors the probe deliberately: this file is the gate, that one
/// is the exploration tool, and neither should change the other's numbers by
/// refactoring alone. When a change to `assets/data/` is meant to rebalance,
/// re-run `dart run tool/balance_probe.dart`, review its table, and update the
/// pinned values here in the same change — never to silence a surprise.
const double _dt = 1 / 60;

/// Same safety bound as the probe: no shipped level needs more than a couple
/// of minutes of simulation, so a run still going at this point is stuck.
const double _timeLimit = 900;

/// The probe's four strategies, copied from `tool/balance_probe.dart` —
/// same plans, same pad order, same fill-then-upgrade policy. Keep the two in
/// sync: a plan edited here but not there (or vice versa) breaks the promise
/// that the gate and the probe measure the same thing.
const Map<String, Map<String, List<(String, String)>>> _probePlans = {
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
  },
};

/// One strategy's plan for one map, looked up the way the probe picks it.
List<(String, String)> _plan(String strategy, String mapId) =>
    _probePlans[strategy]![mapId]!;

/// Probe-measured outcomes for the seven levels after the opening, per
/// strategy: `(victory, coreHealth, leaks)`.
///
/// These are the probe's numbers as of D57, and every one of them is supposed
/// to change when balance data changes — deliberately, by editing this table
/// alongside the data after re-reading the probe. A failure here means the
/// data moved without anybody looking at the campaign it moves.
///
/// Updated with the D62 pad move: ember_04's `rangers only` row went 4 → 6
/// core and its `frost control` row 6 → 2, the two rows the relocated pads
/// `pad_e`/`pad_f` move. Every other row of the table survived that change
/// untouched, which is why the move could be judged rather than guessed.
const Map<String, Map<String, (bool, int, int)>> _pinnedOutcomes = {
  'meadow_04': {
    'rangers only': (true, 18, 0),
    'cannon crossfire': (true, 18, 0),
    'frost control': (true, 18, 0),
    'no-frost control': (true, 18, 0),
  },
  'meadow_05': {
    'rangers only': (true, 14, 1),
    'cannon crossfire': (true, 16, 0),
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
    'cannon crossfire': (true, 13, 1),
    'frost control': (true, 9, 3),
    'no-frost control': (true, 13, 1),
  },
  'ember_04': {
    'rangers only': (true, 6, 3),
    'cannon crossfire': (true, 12, 0),
    'frost control': (true, 2, 5),
    'no-frost control': (true, 10, 1),
  },
  'ember_05': {
    'rangers only': (true, 10, 1),
    'cannon crossfire': (true, 12, 0),
    'frost control': (true, 12, 0),
    'no-frost control': (true, 10, 1),
  },
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

/// Runs one attempt under a fixed plan, the way the probe does.
///
/// Building and upgrading are attempted every frame and only succeed through
/// the session's own rules, so the policy can never cheat the economy — it is
/// the same check the build panel performs.
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

  // Damage towers before support, so a plan never loses on upgrade priority
  // rather than on the tower it chose — the same fairness rule the probe uses.
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

  setUpAll(() {
    repository = LevelRepository(
      mapRepository: MapRepository(),
      enemyRepository: EnemyRepository(),
      towerRepository: TowerRepository(),
    );
  });

  Future<LevelBundle> load(String levelId) {
    return repository.load(ContentCatalog.levelAssetFor(levelId));
  }

  group('opening pacing', () {
    test('the first three levels stay untouched by the naive plan', () async {
      for (final levelId in const ['meadow_01', 'meadow_02', 'meadow_03']) {
        final bundle = await load(levelId);
        final outcome = _run(bundle, _plan('rangers only', bundle.map.id));

        expect(outcome.victory, isTrue, reason: '$levelId must stay beatable');
        expect(
          outcome.leaks,
          0,
          reason:
              '$levelId leaks under the naive plan: the opening is meant '
              'to teach without punishing',
        );
        expect(
          outcome.coreHealth,
          bundle.level.coreHealth,
          reason: '$levelId must still be a three-star run for the naive plan',
        );
      }
    });

    test('the first three levels stay winnable with a support build', () async {
      for (final levelId in const ['meadow_01', 'meadow_02', 'meadow_03']) {
        final bundle = await load(levelId);
        final outcome = _run(bundle, _plan('frost control', bundle.map.id));

        expect(
          outcome.victory,
          isTrue,
          reason:
              '$levelId must stay beatable even when the player spends a '
              'slot on a frost',
        );
      }
    });
  });

  group('order-matched control', () {
    test(
      'each control builds the same pads as its support plan, in order',
      () async {
        const comparisons = [
          ('meadow_01', 'meadow_gate'),
          ('ember_01', 'ember_pass'),
        ];

        for (final (levelId, mapId) in comparisons) {
          final control = _plan('rangers only', mapId);
          final support = _plan('frost control', mapId);
          final bundle = await load(levelId);

          expect(
            [for (final (padId, _) in support) padId],
            [for (final (padId, _) in control) padId],
            reason:
                '$levelId: a control that builds different pads, or in a '
                'different order, measures the order instead of the tower',
          );

          // Every shipped pad exactly once, so the comparison covers the whole
          // build space rather than quietly skipping a slot.
          final controlPads = [for (final (padId, _) in control) padId];
          expect(
            controlPads.toSet(),
            {for (final pad in bundle.map.buildPads) pad.id},
            reason:
                '$levelId: the plans must fill every pad of ${bundle.map.id}',
          );
          expect(
            controlPads.toSet(),
            hasLength(controlPads.length),
            reason: '$levelId: a pad appears twice in the plan',
          );

          // The plans differ only by swapping a damage slot for a support slot.
          final swapped = [
            for (var i = 0; i < control.length; i++)
              if (control[i].$2 != support[i].$2) i,
          ];
          expect(swapped, isNotEmpty, reason: '$levelId: nothing is compared');
          for (final i in swapped) {
            expect(control[i].$2, 'ranger', reason: '$levelId slot $i');
            expect(support[i].$2, isNot('ranger'), reason: '$levelId slot $i');
          }

          // Both plans only use towers the shipped catalog offers.
          for (final (_, towerId) in [...control, ...support]) {
            expect(
              bundle.towers.contains(towerId),
              isTrue,
              reason: '$levelId references unknown tower "$towerId"',
            );
          }
        }
      },
    );
  });

  group('pinned campaign outcomes', () {
    for (final entry in _pinnedOutcomes.entries) {
      final levelId = entry.key;

      test('$levelId matches the probe under every strategy', () async {
        final bundle = await load(levelId);

        for (final strategy in entry.value.entries) {
          final (victory, coreHealth, leaks) = strategy.value;
          final outcome = _run(bundle, _plan(strategy.key, bundle.map.id));
          final where = '$levelId / ${strategy.key}';

          expect(
            outcome.victory,
            victory,
            reason:
                '$where flipped a win to a loss (or back). Re-run '
                '`dart run tool/balance_probe.dart` and update the pinned '
                'table deliberately if the change is intended.',
          );
          expect(
            outcome.coreHealth,
            coreHealth,
            reason:
                '$where: core health moved. Re-run the probe, review the '
                'whole campaign table, and update this pin in the same '
                'change as the data.',
          );
          expect(
            outcome.leaks,
            leaks,
            reason:
                '$where: leak count moved. Re-run the probe and update this '
                'pin alongside the data that moved it.',
          );
        }
      });
    }
  });
}
