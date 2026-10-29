import 'package:flutter_test/flutter_test.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_repository.dart';
import 'package:up_tower_defense/features/gameplay/data/level_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/data/map_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_repository.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/map_validation.dart';

/// The shared stress scenario for Phase 12's profiling tests (PLAN §8).
///
/// One scenario, measured twice: `stress_frame_cost_test.dart` times the
/// simulation half of a frame (`LevelSession.advance`), and
/// `stress_fx_cost_test.dart` times the effect layer's half (publish, update
/// and render recording) fed by the same event stream. Sharing the scenario is
/// the point — both numbers describe the same worst-case frame, so re-tuning
/// the wave or the build re-measures everything together instead of drifting
/// two unrelated fixtures apart.
///
/// What the scenario holds: a synthetic map whose 23 build pads (shipped maps
/// have six) guard only the far two thirds of the route, rangers up front and
/// cannons on the deep pads, all upgraded to max, plus a wave dense enough to
/// hold thousands of enemies and a twelve-thousand-deep spawn queue at once.

/// Game-loop frame delta the simulation advances with, matching the engine.
const double stressFrameDt = 1 / 60;

/// Build pad centers for the synthetic stress map, as `y` to the x positions
/// of one row. The rows guard only the far two thirds of the route: the entry
/// third deliberately has no pad in range, because with coverage at the spawn
/// point the splash towers evaporated the whole crowd a few hundred units in,
/// twenty of the towers sat target-starved, and the "stress" frame measured
/// an idle back half. An uncovered entry gives the stream room to build, so
/// the crowd reaches every tower. The geometry still obeys the rules
/// `MapValidator` enforces — checked in [startStressSession] rather than
/// trusted here.
const Map<int, List<int>> _padRows = {
  170: [604, 680, 756, 832, 908],
  380: [560, 640, 760, 840, 920, 1000, 1080, 1160, 1236],
  640: [560, 640, 720, 800, 880, 960, 1040, 1120, 1200],
};

/// The stress map: meadow_gate's route with three rows of pads around it, so
/// every tower on the field has something to shoot at.
String _stressMapJson() {
  var index = 0;
  final pads = <String>[];
  for (final row in _padRows.entries) {
    for (final x in row.value) {
      index += 1;
      pads.add(
        '    { "id": "pad_$index", "label": "$index", '
        '"center": [$x, ${row.key}] }',
      );
    }
  }

  return '''
{
  "id": "stress_lab",
  "displayName": "Stress Lab",
  "world": [1280, 720],
  "buildPadRadius": 34,
  "route": [
    [0, 500],
    [300, 500],
    [300, 260],
    [700, 260],
    [700, 500],
    [1150, 500]
  ],
  "core": [1150, 500],
  "buildPads": [
${pads.join(',\n')}
  ]
}
''';
}

/// The stress wave: three interleaved groups adding up to about 185 spawns
/// per second for more than a minute, weighted toward the tanky end so the
/// crowd survives long enough to walk the whole route. Density and the build
/// above are tuned together: the earlier 35/second of light enemies under a
/// splash build was cleared at the route entrance, leaving most towers
/// target-starved and the "stress" frame measuring an idle map. The core
/// health is large enough that leaks can never end the attempt, so a profiling
/// window stays `playing` from first frame to last.
const String _stressLevelJson = '''
{
  "id": "stress_lab",
  "displayName": "Stress Lab",
  "mapId": "stress_lab",
  "coreHealth": 100000,
  "startingGold": 20000,
  "waveTransitionSeconds": 1,
  "waves": [
    {
      "id": "wave_01",
      "groups": [
        {
          "enemyId": "brute",
          "count": 8125,
          "spawnIntervalSeconds": 0.008,
          "initialDelaySeconds": 0.5
        },
        {
          "enemyId": "boss",
          "count": 500,
          "spawnIntervalSeconds": 0.13,
          "initialDelaySeconds": 1.0
        },
        {
          "enemyId": "grunt",
          "count": 3420,
          "spawnIntervalSeconds": 0.019,
          "initialDelaySeconds": 0.1
        }
      ]
    },
    {
      "id": "wave_02",
      "groups": [
        {
          "enemyId": "boss",
          "count": 50,
          "spawnIntervalSeconds": 0.5,
          "initialDelaySeconds": 1.0
        }
      ]
    }
  ]
}
''';

/// Which tower goes on which pad: single-target rangers everywhere except the
/// deepest pads (x >= 1000), which hold cannons. Both halves are measured
/// choices. A mixed build *at the entrance* was measured (2026-10) and any
/// splash tower there acts as an impenetrable wall at the first point of
/// contact — each blast hits the whole stacked approach and clears it, so the
/// towers downstream never saw a target and only 10 of 23 fired. Rangers are
/// a sieve instead: each zone kills its share and the crowd flows on, so every
/// pad fights. The back-line cannons then exercise the splash path (an O(n)
/// scan per hit, the single most expensive simulation operation) against a
/// crowd that has already spread across the whole route.
const String _wallTowerId = 'ranger';

/// Splash tower for the deep pads described above.
const String _backLineTowerId = 'cannon';

/// Route x coordinate from which a pad takes the splash tower.
const double _backLineX = 1000;

/// Decodes the stress scenario and starts its wave: a [LevelSession] whose
/// every pad holds a max-level tower, ready for a profiling window.
///
/// The scenario's own invariants are asserted here so every test that starts
/// it measures the same field — a scenario that silently loads differently in
/// two tests would make their numbers incomparable.
Future<LevelSession> startStressSession() async {
  final map = MapJsonDecoder.decode(_stressMapJson());
  final validation = const MapValidator().validate(map);
  expect(
    validation.isValid,
    isTrue,
    reason:
        'the stress map itself must satisfy every map rule: '
        '${validation.issues.join('; ')}',
  );
  expect(
    map.buildPads,
    hasLength(23),
    reason:
        'the scenario is defined as 23 build pads; changing the pads means '
        're-reading every density threshold in the profiling tests',
  );

  final enemies = await EnemyRepository().load(ContentCatalog.enemies);
  final towers = await TowerRepository().load(ContentCatalog.towers);
  final level = LevelJsonDecoder.decode(_stressLevelJson);

  final session = LevelSession(
    level: level,
    map: map,
    enemyCatalog: enemies,
    towerCatalog: towers,
  );

  // Fill the field the way a late game would: every pad built, every tower
  // upgraded to its max level. Gold is ample, so any refusal here means a
  // build rule broke, not that the scenario is poor.
  for (var i = 0; i < map.buildPads.length; i++) {
    final pad = map.buildPads[i];
    final towerId = pad.position.x >= _backLineX
        ? _backLineTowerId
        : _wallTowerId;
    final definition = towers[towerId];
    expect(
      definition,
      isNotNull,
      reason: 'the build needs "$towerId" in the shipped catalog',
    );
    final buildable = definition!;
    expect(
      session.canBuildOn(pad.id, buildable),
      isTrue,
      reason: '${pad.id} refused the initial build',
    );
    session.buildTower(pad.id, buildable);
  }
  for (final pad in map.buildPads) {
    while (session.canUpgradeAt(pad.id)) {
      session.upgradeTowerAt(pad.id);
    }
    expect(
      session.towerAtPad(pad.id)?.isMaxLevel,
      isTrue,
      reason: '${pad.id} did not reach max level before the measured run',
    );
  }
  expect(session.towerCount, map.buildPads.length);

  expect(
    session.startNextWave(),
    isTrue,
    reason: 'the stress wave must start before the run is measured',
  );

  return session;
}
