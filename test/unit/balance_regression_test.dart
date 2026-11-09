import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/campaign/data/campaign_repository.dart';
import 'package:up_tower_defense/features/campaign/domain/level_rating.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/difficulty_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/level_bundle.dart';
import 'package:up_tower_defense/features/gameplay/data/level_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/map_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_repository.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/difficulty.dart';

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
/// 3. **Campaign outcomes.** The levels after the opening are pinned to
///    exactly what the probe measures today — win or loss, core left and leaks
///    — under each of its strategies. Balance edits are supposed to move
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

/// The probe's strategies, copied from `tool/balance_probe.dart` —
/// same plans, same pad order, same fill-then-upgrade policy. Keep the two in
/// sync: a plan edited here but not there (or vice versa) breaks the promise
/// that the gate and the probe measure the same thing.
const Map<String, Map<String, List<(String, String)>>> _probePlans = {
  // A deliberately under-built plan for the levels whose goals a player meets
  // first. Keyed by level id because a `maxTowers` cap is per level, while
  // every other strategy keys by the map it plays. Two pads satisfy a cap of 2
  // or 3 — the cap is an upper bound — so this answers "can the goal pair be
  // met?" rather than "can every pad win?" (D68).
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
  'arc slot': {
    'meadow_gate': [
      ('pad_a', 'ranger'),
      ('pad_c', 'ranger'),
      ('pad_b', 'arc'),
      ('pad_e', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_f', 'ranger'),
    ],
    'ember_pass': [
      ('pad_a', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_c', 'arc'),
      ('pad_d', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_f', 'ranger'),
    ],
    'hollow_court': [
      ('pad_a', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_c', 'arc'),
      ('pad_e', 'ranger'),
      ('pad_f', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_g', 'ranger'),
    ],
  },
  'beacon slot': {
    'meadow_gate': [
      ('pad_a', 'ranger'),
      ('pad_c', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_f', 'beacon'),
    ],
    'ember_pass': [
      ('pad_a', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_c', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_f', 'beacon'),
    ],
    'hollow_court': [
      ('pad_a', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_c', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_f', 'ranger'),
      ('pad_b', 'ranger'),
      ('pad_g', 'beacon'),
    ],
  },
  'cannon arc mix': {
    'meadow_gate': [
      ('pad_a', 'ranger'),
      ('pad_c', 'cannon'),
      ('pad_e', 'cannon'),
      ('pad_b', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_f', 'arc'),
    ],
    'ember_pass': [
      ('pad_a', 'ranger'),
      ('pad_b', 'cannon'),
      ('pad_c', 'cannon'),
      ('pad_d', 'ranger'),
      ('pad_e', 'ranger'),
      ('pad_f', 'arc'),
    ],
    'hollow_court': [
      ('pad_a', 'ranger'),
      ('pad_d', 'ranger'),
      ('pad_c', 'cannon'),
      ('pad_e', 'cannon'),
      ('pad_f', 'ranger'),
      ('pad_b', 'arc'),
      ('pad_g', 'ranger'),
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

/// One strategy's plan for one attempt, looked up the way the probe picks it.
///
/// A level-keyed entry wins over the map's, because a goal cap belongs to a
/// level while a build order belongs to a map.
List<(String, String)> _plan(
  String strategy,
  String levelId,
  String mapId,
) => _probePlans[strategy]![levelId] ?? _probePlans[strategy]![mapId]!;

/// Probe-measured outcomes for the ten levels after the opening, per strategy:
/// `(victory, coreHealth, leaks)`.
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
///
/// Region 3 (V2-1) added five rows measured under the same four plans. They
/// were tuned over several probe runs rather than written once: the first dry
/// of the new map leaked nothing at all, which is why `hollow_03` now runs
/// sixteen runners at half-second spacing and `hollow_05` fields two surging
/// bosses. The D69 surge itself did not move a single ember row, which is the
/// evidence that the mechanic costs the shipped campaign nothing. The V2-2
/// roster fix (D79) then put bulwark and splitter spawns into `hollow_03`–
/// `hollow_05`, which is why those three rows sit closer to the edge than the
/// rest of the table.
///
/// The V2-2 roster audit added the three plans that were missing: `arc slot`
/// and `beacon slot` give each new tower a same-slot control against
/// `rangers only` (V2_PLAN §10's "every tower beats an order-matched control
/// somewhere"), and `cannon arc mix` is the mixed plan that keeps Hard's
/// `hollow_03`–`hollow_05` from resting on `cannon crossfire` alone. Arc beats
/// its control on seven levels and loses on two; Beacon wins only meadow_05
/// and loses six — the weakest slot in the roster, which is exactly what the
/// pin is for.
const Map<String, Map<String, (bool, int, int)>> _pinnedOutcomes = {
  'meadow_04': {
    'rangers only': (true, 18, 0),
    'cannon crossfire': (true, 18, 0),
    'frost control': (true, 18, 0),
    'arc slot': (true, 17, 1),
    'beacon slot': (true, 18, 0),
    'cannon arc mix': (true, 18, 0),
    'no-frost control': (true, 18, 0),
  },
  'meadow_05': {
    'rangers only': (true, 14, 1),
    'cannon crossfire': (true, 16, 0),
    'frost control': (true, 14, 1),
    'arc slot': (true, 16, 0),
    'beacon slot': (true, 16, 0),
    'cannon arc mix': (true, 16, 0),
    'no-frost control': (true, 16, 0),
  },
  'ember_01': {
    'rangers only': (true, 16, 0),
    'cannon crossfire': (true, 16, 0),
    'frost control': (true, 16, 0),
    'arc slot': (true, 16, 0),
    'beacon slot': (true, 16, 0),
    'cannon arc mix': (true, 16, 0),
    'no-frost control': (true, 16, 0),
  },
  'ember_02': {
    'rangers only': (true, 15, 0),
    'cannon crossfire': (true, 14, 1),
    'frost control': (true, 15, 0),
    'arc slot': (true, 15, 0),
    'beacon slot': (true, 15, 0),
    'cannon arc mix': (true, 14, 1),
    'no-frost control': (true, 15, 0),
  },
  'ember_03': {
    'rangers only': (true, 9, 3),
    'cannon crossfire': (true, 13, 1),
    'frost control': (true, 9, 3),
    'arc slot': (true, 13, 1),
    'beacon slot': (true, 9, 3),
    'cannon arc mix': (true, 13, 1),
    'no-frost control': (true, 13, 1),
  },
  'ember_04': {
    'rangers only': (true, 6, 3),
    'cannon crossfire': (true, 12, 0),
    'frost control': (true, 2, 5),
    'arc slot': (true, 8, 2),
    'beacon slot': (true, 2, 5),
    'cannon arc mix': (true, 12, 0),
    'no-frost control': (true, 10, 1),
  },
  'ember_05': {
    'rangers only': (true, 10, 1),
    'cannon crossfire': (true, 12, 0),
    'frost control': (true, 12, 0),
    'arc slot': (true, 10, 1),
    'beacon slot': (true, 8, 2),
    'cannon arc mix': (true, 12, 0),
    'no-frost control': (true, 10, 1),
  },
  'hollow_01': {
    'rangers only': (true, 18, 1),
    'cannon crossfire': (true, 20, 0),
    'frost control': (true, 18, 1),
    'arc slot': (true, 20, 0),
    'beacon slot': (true, 16, 2),
    'cannon arc mix': (true, 20, 0),
    'no-frost control': (true, 18, 1),
  },
  'hollow_02': {
    'rangers only': (true, 16, 2),
    'cannon crossfire': (true, 20, 0),
    'frost control': (true, 18, 1),
    'arc slot': (true, 20, 0),
    'beacon slot': (true, 16, 2),
    'cannon arc mix': (true, 20, 0),
    'no-frost control': (true, 16, 2),
  },
  'hollow_03': {
    'rangers only': (true, 3, 12),
    'cannon crossfire': (true, 20, 0),
    'frost control': (true, 7, 10),
    'arc slot': (true, 20, 0),
    'beacon slot': (false, 0, 14),
    'cannon arc mix': (true, 20, 0),
    'no-frost control': (true, 18, 1),
  },
  'hollow_04': {
    'rangers only': (true, 15, 5),
    'cannon crossfire': (true, 20, 0),
    'frost control': (true, 17, 3),
    'arc slot': (true, 15, 5),
    'beacon slot': (true, 8, 9),
    'cannon arc mix': (true, 20, 0),
    'no-frost control': (true, 1, 17),
  },
  'hollow_05': {
    'rangers only': (true, 2, 6),
    'cannon crossfire': (true, 14, 0),
    'frost control': (true, 2, 6),
    'arc slot': (true, 6, 4),
    'beacon slot': (false, 0, 7),
    'cannon arc mix': (true, 14, 0),
    'no-frost control': (true, 4, 5),
  },
};

class _Outcome {
  const _Outcome({
    required this.victory,
    required this.coreHealth,
    required this.leaks,
    required this.objectivesMet,
    required this.objectiveCount,
    required this.stars,
  });

  final bool victory;
  final int coreHealth;
  final int leaks;
  final int objectivesMet;
  final int objectiveCount;
  final int stars;
}

/// Orders two runs the way the pinned table reads a row: victory first, then
/// core health left, then fewer leaks. Negative when [a] is better, positive
/// when [b] is, zero on a tie.
int _compareOutcomes(_Outcome a, _Outcome b) {
  if (a.victory != b.victory) {
    return a.victory ? -1 : 1;
  }
  if (a.coreHealth != b.coreHealth) {
    return b.coreHealth - a.coreHealth;
  }
  return a.leaks - b.leaks;
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

  final victory = session.phase == LevelPhase.victory;
  final objectives = session.objectiveStatuses;
  return _Outcome(
    victory: victory,
    coreHealth: session.coreHealth,
    leaks: session.leaks,
    objectivesMet: session.objectivesMet,
    objectiveCount: objectives.length,
    // The same rule the game awards with, so a pin cannot promise stars the
    // player would not receive (D68).
    stars: LevelRating.starsForRun(
      victorious: victory,
      coreHealth: session.coreHealth,
      maxCoreHealth: bundle.level.coreHealth,
      objectives: objectives,
    ),
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
  late final Map<Difficulty, DifficultyProfile> profiles;
  late final List<String> levelIds;

  setUpAll(() async {
    repository = LevelRepository(
      mapRepository: MapRepository(),
      enemyRepository: EnemyRepository(),
      towerRepository: TowerRepository(),
    );
    profiles = await DifficultyRepository().load();
    levelIds = (await CampaignRepository().load(ContentCatalog.campaign))
        .levelIds;
  });

  Future<LevelBundle> load(
    String levelId, {
    Difficulty difficulty = Difficulty.normal,
  }) {
    return repository.load(
      ContentCatalog.levelAssetFor(levelId),
      profile: profiles[difficulty]!,
    );
  }

  group('three-star achievability', () {
    test('the opening three levels can earn three stars', () async {
      for (final levelId in const ['meadow_01', 'meadow_02', 'meadow_03']) {
        final bundle = await load(levelId);
        final outcome = _run(
          bundle,
          _plan('capped starter', levelId, bundle.map.id),
        );

        expect(outcome.victory, isTrue, reason: '$levelId must stay beatable');
        expect(
          outcome.objectiveCount,
          2,
          reason: '$levelId declares two goals',
        );
        expect(
          outcome.objectivesMet,
          2,
          reason:
              '$levelId ships goals a capped two-tower build cannot meet. '
              'Re-run `dart run tool/balance_probe.dart`, then either re-time '
              'the goal or fix the level — a three-star rating nobody can '
              'reach is a content bug (D68).',
        );
        expect(outcome.stars, 3, reason: '$levelId must be worth three stars');
      }
    });
  });

  group('opening pacing', () {
    test('the first three levels stay untouched by the naive plan', () async {
      for (final levelId in const ['meadow_01', 'meadow_02', 'meadow_03']) {
        final bundle = await load(levelId);
        final outcome = _run(
          bundle,
          _plan('rangers only', levelId, bundle.map.id),
        );

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
        final outcome = _run(
          bundle,
          _plan('frost control', levelId, bundle.map.id),
        );

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
      'each control builds the same pads as its plan, in order',
      () async {
        // (control, plan) pairs: every same-slot comparison the probe makes,
        // on one level per map. `rangers only` controls the single-swap plans;
        // `cannon crossfire` controls the mix, which differs from it by one
        // slot only.
        const comparisons = [
          ('rangers only', 'frost control'),
          ('rangers only', 'arc slot'),
          ('rangers only', 'beacon slot'),
          ('cannon crossfire', 'cannon arc mix'),
        ];
        const levels = [
          ('meadow_01', 'meadow_gate'),
          ('ember_01', 'ember_pass'),
          ('hollow_01', 'hollow_court'),
        ];

        for (final (controlName, planName) in comparisons) {
          for (final (levelId, mapId) in levels) {
            final control = _plan(controlName, levelId, mapId);
            final support = _plan(planName, levelId, mapId);
            final bundle = await load(levelId);
            final where = '$levelId / $controlName vs $planName';

            expect(
              [for (final (padId, _) in support) padId],
              [for (final (padId, _) in control) padId],
              reason:
                  '$where: a control that builds different pads, or in a '
                  'different order, measures the order instead of the tower',
            );

            // Every shipped pad exactly once, so the comparison covers the
            // whole build space rather than quietly skipping a slot.
            final controlPads = [for (final (padId, _) in control) padId];
            expect(
              controlPads.toSet(),
              {for (final pad in bundle.map.buildPads) pad.id},
              reason:
                  '$where: the plans must fill every pad of ${bundle.map.id}',
            );
            expect(
              controlPads.toSet(),
              hasLength(controlPads.length),
              reason: '$where: a pad appears twice in the plan',
            );

            // The plans differ only by swapping a damage slot for another
            // tower.
            final swapped = [
              for (var i = 0; i < control.length; i++)
                if (control[i].$2 != support[i].$2) i,
            ];
            expect(swapped, isNotEmpty, reason: '$where: nothing is compared');
            for (final i in swapped) {
              expect(control[i].$2, 'ranger', reason: '$where slot $i');
              expect(support[i].$2, isNot('ranger'), reason: '$where slot $i');
            }

            // Both plans only use towers the shipped catalog offers.
            for (final (_, towerId) in [...control, ...support]) {
              expect(
                bundle.towers.contains(towerId),
                isTrue,
                reason: '$where references unknown tower "$towerId"',
              );
            }
          }
        }
      },
    );
  });

  group('new tower coverage', () {
    // V2_PLAN's definition of done: every tower beats an order-matched
    // control somewhere and never loses everywhere. `arc slot` and
    // `beacon slot` are the V2-2 towers' same-slot plans against
    // `rangers only`, measured on every campaign level — not only the pinned
    // ones — so a tower that wins one niche cannot hide behind the table.
    for (final planName in const ['arc slot', 'beacon slot']) {
      test(
        '$planName beats its control somewhere, loses nowhere always',
        () async {
          final wins = <String>[];
          final losses = <String>[];

          for (final levelId in levelIds) {
            final bundle = await load(levelId);
            final control = _run(
              bundle,
              _plan('rangers only', levelId, bundle.map.id),
            );
            final plan = _run(bundle, _plan(planName, levelId, bundle.map.id));
            final comparison = _compareOutcomes(plan, control);
            if (comparison < 0) {
              wins.add(levelId);
            } else if (comparison > 0) {
              losses.add(levelId);
            }
          }

          expect(
            wins,
            isNotEmpty,
            reason:
                '$planName never beats `rangers only` on any level. V2_PLAN '
                'requires every tower to win somewhere; re-run '
                '`dart run tool/balance_probe.dart` and report the structural '
                'cause before tuning numbers (D54/D56 precedent).',
          );
          expect(
            losses.length,
            lessThan(levelIds.length),
            reason:
                '$planName loses to `rangers only` on every level — it has no '
                'situation in the campaign at all.',
          );
        },
      );
    }
  });

  group('pinned campaign outcomes', () {
    for (final entry in _pinnedOutcomes.entries) {
      final levelId = entry.key;

      test('$levelId matches the probe under every strategy', () async {
        final bundle = await load(levelId);

        for (final strategy in entry.value.entries) {
          final (victory, coreHealth, leaks) = strategy.value;
          final outcome = _run(
            bundle,
            _plan(strategy.key, levelId, bundle.map.id),
          );
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
