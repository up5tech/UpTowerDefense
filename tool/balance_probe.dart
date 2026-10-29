// Development balance probe.
//
//   dart run tool/balance_probe.dart
//
// Runs every campaign level headlessly through the real `LevelSession` under a
// set of fixed build strategies and prints how each one fared — outcome, core
// health left, leaks and gold earned — so "does this tower have a useful
// situation" and "does the campaign ramp at a manageable pace" can be answered
// with numbers instead of opinion. The first table also reports each pad's
// distance to the route against every tower's base range, using the same
// geometry the targeting rule uses, which answers "can this pad fire at all".
//
// Pure Dart, no Flutter and no AssetBundle: content is read from disk, the same
// rule `validate_content.dart` follows, so it runs in a terminal or in CI.
//
// The strategies are deliberately naive — fill pads in a fixed order, then
// upgrade in that order — because they stand in for a new player following the
// obvious plan. A tower that only pays off with clever play still shows up here
// as "mix does not beat pure ranger", which is exactly what a reviewer needs to
// see before tuning.
import 'dart:io';

import 'package:up_tower_defense/features/campaign/data/campaign_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/data/level_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/data/map_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_session.dart';
import 'package:up_tower_defense/features/gameplay/domain/map_geometry.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';

const String _dataDir = 'assets/data';

/// Frame delta the engine itself uses.
const double _dt = 1 / 60;

/// Simulated seconds after which a run is declared stuck (never seen: the
/// levels resolve in a couple of minutes of game time).
const double _timeLimit = 900;

/// One plan per strategy: an ordered `(pad, tower)` build sequence per map.
///
/// Pads are filled in this order, then every pad is upgraded in the same order
/// until the gold runs out. The plans deliberately place support towers where
/// they overlap a damage tower's zone — `pad_f` on each map was added in round
/// 3 precisely because its zone sits inside two rangers' zones — so a strategy
/// that still loses has lost on merit, not because the probe placed it badly.
/// The only difference between plans is which towers appear, so outcome
/// differences are attributable to that choice alone.
const Map<String, Map<String, List<(String, String)>>> _strategies = {
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
  // Frost is built *last*, after every damage tower is up: the realistic
  // deployment for a support tower, and the harshest fair test of its slot —
  // the amplifier now multiplies five placed rangers instead of one. The
  // order-matched control for this build order is `rangers only`, whose pad
  // sequence it copies exactly.
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
  // Entry-zone pads first, every slot a ranger. Kept after `frost control`
  // moved to a late-frost build (whose matched control is now `rangers only`,
  // whose pad sequence it copies) because it documents the one confound every
  // comparison here must avoid: this order alone takes ember_03 from 9 core to
  // 13, so a plan is only ever judged against a control that builds the same
  // pads in the same order.
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

class _RunResult {
  _RunResult({
    required this.victory,
    required this.coreHealth,
    required this.leaks,
    required this.kills,
    required this.goldEarned,
    required this.elapsed,
    required this.towerCount,
  });

  final bool victory;
  final int coreHealth;
  final int leaks;
  final int kills;
  final int goldEarned;
  final double elapsed;
  final int towerCount;
}

void main() {
  final maps = _loadMaps();
  final enemies = _loadEnemies();
  final towers = _loadTowers();
  final levels = _loadLevels();
  final campaign = CampaignJsonDecoder.decode(
    File('$_dataDir/campaign.json').readAsStringSync(),
  );

  final enemyCatalog = EnemyCatalog(enemies);
  final towerCatalog = TowerCatalog(towers);

  _printCoverage(maps);

  stdout.writeln();
  stdout.writeln(
    'Simulated outcomes (naive fill-then-upgrade policy, waves started as '
    'soon as allowed):',
  );
  stdout.writeln(
    [
      'level'.padRight(12),
      'strategy'.padRight(18),
      'result'.padRight(8),
      'core'.padLeft(5),
      'leaks'.padLeft(6),
      'kills'.padLeft(6),
      'gold'.padLeft(6),
      'time'.padLeft(7),
    ].join(),
  );

  for (final levelId in campaign.levelIds) {
    final level = levels[levelId];
    if (level == null) {
      stdout.writeln('$levelId: missing level file');
      continue;
    }
    final map = maps[level.mapId];
    if (map == null) {
      stdout.writeln('$levelId: missing map ${level.mapId}');
      continue;
    }
    for (final strategy in _strategies.entries) {
      final plan = strategy.value[map.id];
      if (plan == null) {
        stdout.writeln('${level.id}: no plan for map ${map.id}');
        continue;
      }
      final result = _run(
        level: level,
        map: map,
        enemyCatalog: enemyCatalog,
        towerCatalog: towerCatalog,
        plan: plan,
      );
      final outcome = result.victory ? 'win' : 'LOSE';
      stdout.writeln(
        [
          level.id.padRight(12),
          strategy.key.padRight(18),
          outcome.padRight(8),
          result.coreHealth.toString().padLeft(5),
          result.leaks.toString().padLeft(6),
          result.kills.toString().padLeft(6),
          result.goldEarned.toString().padLeft(6),
          '${result.elapsed.toStringAsFixed(0)}s'.padLeft(7),
        ].join(),
      );
    }
    stdout.writeln();
  }
}

/// Fills pads, upgrades, and starts waves for as long as the level allows.
///
/// Building and upgrading are attempted every frame and only succeed when the
/// session's own rules allow them, so the policy can never cheat the economy —
/// it is the same check the build panel does.
_RunResult _run({
  required LevelDefinition level,
  required MapDefinition map,
  required EnemyCatalog enemyCatalog,
  required TowerCatalog towerCatalog,
  required List<(String, String)> plan,
}) {
  final session = LevelSession(
    level: level,
    map: map,
    enemyCatalog: enemyCatalog,
    towerCatalog: towerCatalog,
  );

  while (session.elapsed < _timeLimit) {
    _act(session, towerCatalog, plan);
    if (session.canStartNextWave) {
      session.startNextWave();
    }
    session.advance(_dt);

    if (session.phase == LevelPhase.victory ||
        session.phase == LevelPhase.defeat) {
      break;
    }
  }

  return _RunResult(
    victory: session.phase == LevelPhase.victory,
    coreHealth: session.coreHealth,
    leaks: session.leaks,
    kills: session.kills,
    goldEarned: session.goldEarned,
    elapsed: session.elapsed,
    towerCount: session.towerCount,
  );
}

void _act(
  LevelSession session,
  TowerCatalog catalog,
  List<(String, String)> plan,
) {
  if (session.towerCount < plan.length) {
    final (padId, towerId) = plan[session.towerCount];
    final definition = catalog[towerId];
    if (definition != null && session.canBuildOn(padId, definition)) {
      session.buildTower(padId, definition);
    }
    return;
  }

  // Damage towers are upgraded before support towers: a ranger upgrade buys
  // far more DPS per gold than a cannon or frost one, so any plan that
  // upgraded its support first would be losing on the policy, not on the
  // tower. Keeping this order for every strategy keeps the comparison fair.
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

/// Pad-to-route distance against every base range, from the geometry the
/// targeting rule itself uses.
void _printCoverage(Map<String, MapDefinition> maps) {
  final ranges = <String, double>{};
  for (final file in _jsonFiles('$_dataDir/towers')) {
    for (final tower in TowerJsonDecoder.decode(file.readAsStringSync())) {
      ranges[tower.id] = tower.baseStats.range;
    }
  }

  for (final map in maps.values) {
    final geometry = MapGeometry(map);
    stdout.writeln(
      'Pad coverage on ${map.id} '
      '(distance to route vs base range: ${ranges.entries.map((e) => '${e.key} ${e.value.toStringAsFixed(0)}').join(', ')}):',
    );
    for (final pad in map.buildPads) {
      final distance = geometry.distanceToRoute(pad.position);
      final reachable = [
        for (final entry in ranges.entries)
          if (distance <= entry.value) entry.key,
      ];
      stdout.writeln(
        '  ${pad.label}  distance ${distance.toStringAsFixed(0).padLeft(4)}'
        '  ${reachable.isEmpty ? 'REACHES NO TOWER' : 'in range of ${reachable.join(', ')}'}',
      );
    }
  }
}

Map<String, MapDefinition> _loadMaps() {
  return {
    for (final file in _jsonFiles('$_dataDir/maps'))
      _idOf(file): MapJsonDecoder.decode(file.readAsStringSync()),
  };
}

List<EnemyDefinition> _loadEnemies() {
  return EnemyJsonDecoder.decode(
    File('$_dataDir/enemies/enemies.json').readAsStringSync(),
  );
}

List<TowerDefinition> _loadTowers() {
  return TowerJsonDecoder.decode(
    File('$_dataDir/towers/towers.json').readAsStringSync(),
  );
}

Map<String, LevelDefinition> _loadLevels() {
  return {
    for (final file in _jsonFiles('$_dataDir/levels'))
      _idOf(file): LevelJsonDecoder.decode(file.readAsStringSync()),
  };
}

/// Level and map ids are file names by convention (see `ContentCatalog`).
String _idOf(File file) {
  return file.uri.pathSegments.last.replaceFirst(RegExp(r'\.json$'), '');
}

List<File> _jsonFiles(String directory) {
  final files =
      Directory(directory)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return files;
}
