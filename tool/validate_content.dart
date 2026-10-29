// Development content validator.
//
//   dart run tool/validate_content.dart
//
// Loads every shipped content file from disk, decodes it with the same decoders
// the game uses, validates it, and cross-checks the campaign against the level
// files. Exits non-zero on the first failing run so it can be used as a gate.
//
// This is deliberately pure Dart (no Flutter, no AssetBundle): it reads the
// files directly, which is what lets it run in a terminal or in CI without an
// emulator. `test/unit/campaign_assets_test.dart` covers the same ground through
// the asset bundle, and is the gate that runs with the test suite.
import 'dart:io';

import 'package:up_tower_defense/features/campaign/data/campaign_json_decoder.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_definition.dart';
import 'package:up_tower_defense/features/campaign/domain/campaign_validation.dart';
import 'package:up_tower_defense/features/gameplay/data/content_catalog.dart';
import 'package:up_tower_defense/features/gameplay/data/enemy_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/data/level_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/data/map_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/data/tower_json_decoder.dart';
import 'package:up_tower_defense/features/gameplay/domain/enemy_validation.dart';
import 'package:up_tower_defense/features/gameplay/domain/level_validation.dart';
import 'package:up_tower_defense/features/gameplay/domain/map_validation.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/enemy_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/level_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/map_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/models/tower_definition.dart';
import 'package:up_tower_defense/features/gameplay/domain/tower_validation.dart';

const String _dataDir = 'assets/data';

final List<String> _problems = [];

void main() {
  final maps = _loadMaps();
  final enemies = _loadEnemies();
  final towers = _loadTowers();
  final levels = _loadLevels(maps, enemies);
  _loadEndless(maps, enemies);
  final campaign = _loadCampaign(levels.keys.toSet());

  if (campaign != null) {
    _checkCampaignNames(campaign, levels);
  }

  if (_problems.isEmpty) {
    stdout.writeln(
      'Content OK — ${maps.length} maps, ${enemies.length} enemies, '
      '${towers.length} towers, ${levels.length} levels, '
      '${campaign?.regions.length ?? 0} regions.',
    );
    exit(0);
  }

  stderr.writeln('Content problems (${_problems.length}):');
  for (final problem in _problems) {
    stderr.writeln('  - $problem');
  }
  exit(1);
}

Map<String, MapDefinition> _loadMaps() {
  final maps = <String, MapDefinition>{};
  for (final file in _jsonFiles('$_dataDir/maps')) {
    try {
      final map = MapJsonDecoder.decode(file.readAsStringSync());
      final validation = const MapValidator().validate(map);
      _report('maps/${_name(file)}', validation.issues);
      if (maps.containsKey(map.id)) {
        _problems.add('maps/${_name(file)}: duplicate map id "${map.id}"');
      }
      maps[map.id] = map;
    } on Object catch (error) {
      _problems.add('maps/${_name(file)}: $error');
    }
  }

  // A map that ships but is not registered can never be loaded by a level.
  final registered = ContentCatalog.mapAssetsById.keys.toSet();
  for (final id in maps.keys) {
    if (!registered.contains(id)) {
      _problems.add('map "$id" is not registered in ContentCatalog');
    }
  }
  for (final id in registered) {
    if (!maps.containsKey(id)) {
      _problems.add('ContentCatalog registers missing map "$id"');
    }
  }

  return maps;
}

List<EnemyDefinition> _loadEnemies() {
  final file = File('$_dataDir/enemies/enemies.json');
  try {
    final enemies = EnemyJsonDecoder.decode(file.readAsStringSync());
    _report(
      'enemies/enemies.json',
      const EnemyValidator().validate(enemies).issues,
    );
    return enemies;
  } on Object catch (error) {
    _problems.add('enemies/enemies.json: $error');
    return const [];
  }
}

List<TowerDefinition> _loadTowers() {
  final file = File('$_dataDir/towers/towers.json');
  try {
    final towers = TowerJsonDecoder.decode(file.readAsStringSync());
    _report(
      'towers/towers.json',
      const TowerValidator().validate(towers).issues,
    );
    return towers;
  } on Object catch (error) {
    _problems.add('towers/towers.json: $error');
    return const [];
  }
}

/// Validates the endless challenge level, which lives beside the campaign's
/// `levels/` directory on purpose: it is not a campaign entry, so the
/// campaign cross-check must never see it (D62).
void _loadEndless(
  Map<String, MapDefinition> maps,
  List<EnemyDefinition> enemies,
) {
  const scope = 'endless.json';
  final file = File('$_dataDir/endless.json');
  if (!file.existsSync()) {
    _problems.add('$scope: file is missing');
    return;
  }
  try {
    final level = LevelJsonDecoder.decode(file.readAsStringSync());
    if (!level.endless) {
      _problems.add('$scope: must set "endless": true');
    }
    final map = maps[level.mapId];
    if (map == null) {
      _problems.add('$scope: references unknown map "${level.mapId}"');
      return;
    }
    _report(
      scope,
      const LevelValidator()
          .validate(
            level: level,
            map: map,
            enemies: EnemyCatalog(enemies),
          )
          .issues,
    );
  } on Object catch (error) {
    _problems.add('$scope: $error');
  }
}

Map<String, LevelDefinition> _loadLevels(
  Map<String, MapDefinition> maps,
  List<EnemyDefinition> enemies,
) {
  final catalog = EnemyCatalog(enemies);
  final levels = <String, LevelDefinition>{};

  for (final file in _jsonFiles('$_dataDir/levels')) {
    final scope = 'levels/${_name(file)}';
    try {
      final level = LevelJsonDecoder.decode(file.readAsStringSync());
      // Everything in levels/ is a campaign level: an endless one can never
      // reach victory, so its unlock chain would soft-lock the campaign (D62).
      if (level.endless) {
        _problems.add(
          '$scope: must not set "endless": true; the endless challenge '
          'belongs in endless.json, outside levels/',
        );
      }
      if (levels.containsKey(level.id)) {
        _problems.add('$scope: duplicate level id "${level.id}"');
      }
      levels[level.id] = level;

      final map = maps[level.mapId];
      if (map == null) {
        _problems.add('$scope: references unknown map "${level.mapId}"');
        continue;
      }
      _report(
        scope,
        const LevelValidator()
            .validate(level: level, map: map, enemies: catalog)
            .issues,
      );
    } on Object catch (error) {
      _problems.add('$scope: $error');
    }
  }

  return levels;
}

CampaignDefinition? _loadCampaign(Set<String> knownLevelIds) {
  final file = File('$_dataDir/campaign.json');
  try {
    final campaign = CampaignJsonDecoder.decode(file.readAsStringSync());
    _report(
      'campaign.json',
      const CampaignValidator()
          .validate(campaign: campaign, knownLevelIds: knownLevelIds)
          .issues,
    );

    // Every shipped level must be reachable, and every listed level must exist.
    for (final levelId in knownLevelIds) {
      if (!campaign.contains(levelId)) {
        _problems.add('campaign.json: level "$levelId" is not in the campaign');
      }
    }

    return campaign;
  } on Object catch (error) {
    _problems.add('campaign.json: $error');
    return null;
  }
}

/// The campaign shows level names without loading the levels, so the two must
/// agree or the picker would disagree with the HUD.
void _checkCampaignNames(
  CampaignDefinition campaign,
  Map<String, LevelDefinition> levels,
) {
  for (final levelId in campaign.levelIds) {
    final level = levels[levelId];
    if (level == null) {
      continue;
    }
    final campaignName = campaign.displayNameOf(levelId);
    if (campaignName != level.displayName) {
      _problems.add(
        'campaign.json: "$levelId" is called "$campaignName" but the level '
        'file says "${level.displayName}"',
      );
    }
  }
}

List<File> _jsonFiles(String directory) {
  final dir = Directory(directory);
  if (!dir.existsSync()) {
    _problems.add('$directory: directory is missing');
    return const [];
  }
  final files =
      dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.json'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    _problems.add('$directory: no JSON files');
  }
  return files;
}

String _name(File file) => file.uri.pathSegments.last;

void _report(String scope, List<String> issues) {
  for (final issue in issues) {
    _problems.add('$scope: $issue');
  }
}
