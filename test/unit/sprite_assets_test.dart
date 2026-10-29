import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The Flame layers load sprites by definition id — `tower_<id>.png`,
/// `enemy_<id>.png` — so a shipped definition without its art would fail at
/// mount time on a player's device. This is the same on-disk contract the SFX
/// cue map has: the file must exist before the session ever runs.
void main() {
  test('every shipped tower has its sprite', () {
    for (final id in _ids('assets/data/towers/towers.json', 'towers')) {
      expect(
        File('assets/images/tower_$id.png').existsSync(),
        isTrue,
        reason: 'assets/images/tower_$id.png is missing from the bundle',
      );
    }
  });

  test('every shipped enemy has its sprite', () {
    for (final id in _ids('assets/data/enemies/enemies.json', 'enemies')) {
      expect(
        File('assets/images/enemy_$id.png').existsSync(),
        isTrue,
        reason: 'assets/images/enemy_$id.png is missing from the bundle',
      );
    }
  });

  test('the shared art ships too', () {
    for (final file in ['projectile.png', 'map_grass.png', 'map_dirt.png']) {
      expect(
        File('assets/images/$file').existsSync(),
        isTrue,
        reason: 'assets/images/$file is missing from the bundle',
      );
    }
  });
}

/// Definition ids listed under [key] in the shipped JSON file.
List<String> _ids(String path, String key) {
  final decoded = jsonDecode(File(path).readAsStringSync()) as Map;
  final definitions = decoded[key] as List;
  return [
    for (final definition in definitions) (definition as Map)['id'] as String,
  ];
}
